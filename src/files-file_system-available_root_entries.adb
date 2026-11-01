with Hostkit.Fs;
with Hostkit.Mounts;
separate (Files.File_System)
function Available_Root_Entries return Root_Entry_Vectors.Vector is
   Roots : Root_Entry_Vectors.Vector;
   Max_Discovered_Roots : constant Natural := 1_024;
   Max_Root_Entries_Scanned : constant Natural := 4_096;
   Root_Entries_Scanned : Natural := 0;
   --  The folders the host's conventions give this user (the home, the
   --  Windows profile drive, share and OneDrive, where Linux mounts media).
   Places    : constant Hostkit.Fs.User_Place_List := Hostkit.Fs.User_Places;
   User_Name : constant String := Files.Environment.Value ("USER");

   function Place_Of (Kind : Hostkit.Fs.User_Place_Kind) return String is
   begin
      for Place of Places loop
         if Hostkit.Fs."=" (Place.Kind, Kind) then
            return To_String (Place.Path);
         end if;
      end loop;
      return "";
   end Place_Of;

   Desktop_Mounts : constant String := Place_Of (Hostkit.Fs.Desktop_Mounts_Parent);

   function Starts_With (Text : String; Prefix : String) return Boolean renames Files.Types.Starts_With;

   function Is_Pseudo_Mount_Type (Filesystem_Type : String) return Boolean is
      Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
   begin
      return Normalized = ""
        or else Normalized = "autofs"
        or else Normalized = "binfmt_misc"
        or else Normalized = "bpf"
        or else Normalized = "cgroup"
        or else Normalized = "cgroup2"
        or else Normalized = "configfs"
        or else Normalized = "debugfs"
        or else Normalized = "devpts"
        or else Normalized = "devtmpfs"
        or else Normalized = "efivarfs"
        or else Normalized = "fusectl"
        or else Normalized = "hugetlbfs"
        or else Normalized = "mqueue"
        or else Normalized = "nsfs"
        or else Normalized = "overlay"
        or else Normalized = "proc"
        or else Normalized = "pstore"
        or else Normalized = "ramfs"
        or else Normalized = "rpc_pipefs"
        or else Normalized = "securityfs"
        or else Normalized = "squashfs"
        or else Normalized = "sysfs"
        or else Normalized = "tmpfs"
        or else Normalized = "tracefs";
   end Is_Pseudo_Mount_Type;

   function Is_Network_Filesystem_Type (Filesystem_Type : String) return Boolean is
      Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
   begin
      return Normalized = "9p"
        or else Normalized = "afpfs"
        or else Normalized = "cifs"
        or else Normalized = "davfs"
        or else Normalized = "fuse.gvfsd-fuse"
        or else Normalized = "fuse.sshfs"
        or else Normalized = "ncpfs"
        or else Normalized = "nfs"
        or else Normalized = "nfs4"
        or else Normalized = "smb3"
        or else Normalized = "sshfs";
   end Is_Network_Filesystem_Type;

   function Root_Kind_For_Mount
     (Mount_Point     : String;
      Filesystem_Type : String)
      return Root_Kind is
   begin
      if Is_Network_Filesystem_Type (Filesystem_Type)
        or else Starts_With (Mount_Point, "//")
        or else Starts_With (Mount_Point, "\\")
        or else Starts_With (Mount_Point, "/run/user/")
      then
         return Root_Network_Mount;
      end if;

      return Root_Mount;
   end Root_Kind_For_Mount;

   function Is_User_Visible_Mount_Point (Mount_Point : String) return Boolean is
     (Files.File_System.Is_User_Visible_Mount_Point
        (Mount_Point, Desktop_Mounts));

   function Is_Displayable_Root_Mount
     (Mount_Point     : String;
      Filesystem_Type : String)
      return Boolean is
   begin
      return Is_User_Visible_Mount_Point (Mount_Point)
        and then not Is_Pseudo_Mount_Type (Filesystem_Type);
   end Is_Displayable_Root_Mount;

   --  The host's mount table, read once for the whole discovery.
   Mounts : constant Hostkit.Mounts.Mount_Vectors.Vector := Hostkit.Mounts.Table;

   function Filesystem_Type_For (Path : String) return String is
      Found : Boolean;
      Mount : constant Hostkit.Mounts.Mount := Hostkit.Mounts.Find (Mounts, Path, Found);
   begin
      return (if Found then To_String (Mount.Filesystem_Type) else "");
   end Filesystem_Type_For;

   function Contains_Root (Path : String) return Boolean is
   begin
      for Root of Roots loop
         if To_String (Root.Path) = Path then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Root;

   procedure Append_If_Directory
     (Path : String;
      Kind : Root_Kind)
   is
      Full : Unbounded_String;
      Name : Unbounded_String;
      Label : Unbounded_String;
      Effective_Kind : Root_Kind := Kind;
   begin
      if Natural (Roots.Length) >= Max_Discovered_Roots then
         return;
      end if;
      if Files.Fs_Primitives.Directory_Exists (Path)
      then
         Full := To_Unbounded_String (Ada.Directories.Full_Name (Path));
         Name := To_Unbounded_String (Ada.Directories.Simple_Name (To_String (Full)));
         if Length (Name) = 0 then
            Name := Full;
         end if;
         if Kind in Root_Mount | Root_User_Mount | Root_Network_Mount | Root_Filesystem then
            declare
               Filesystem_Type : constant String := Filesystem_Type_For (To_String (Full));
            begin
               if Kind in Root_Mount | Root_User_Mount
                 and then Is_Network_Filesystem_Type (Filesystem_Type)
               then
                  Effective_Kind := Root_Network_Mount;
               end if;

               Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
               if Filesystem_Type /= "" and then Ada.Strings.Fixed.Index (To_String (Label), "|") > 0 then
                  Append (Label, "|");
                  Append (Label, Filesystem_Type);
               end if;
            end;
         else
            Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
         end if;
         if not Contains_Root (To_String (Full)) then
            Roots.Append
              (Root_Entry'
                 (Path  => Full,
                  Label => Label,
                  Kind  => Effective_Kind,
                  Volume_Name => Name,
                  Ready => Root_Ready,
                  Removable => Effective_Kind = Root_Mount or else Effective_Kind = Root_User_Mount));
         end if;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Roots");
   end Append_If_Directory;

   procedure Append_Children
     (Parent : String;
      Kind   : Root_Kind)
   is
      Search : Ada.Directories.Search_Type;
      Child  : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      if Root_Entries_Scanned >= Max_Root_Entries_Scanned
        or else Natural (Roots.Length) >= Max_Discovered_Roots
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Parent,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => False,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => False]);
      Started := True;

      while Root_Entries_Scanned < Max_Root_Entries_Scanned
        and then Natural (Roots.Length) < Max_Discovered_Roots
        and then Ada.Directories.More_Entries (Search)
      loop
         Ada.Directories.Get_Next_Entry (Search, Child);
         Root_Entries_Scanned := Root_Entries_Scanned + 1;
         declare
            Name : constant String := Ada.Directories.Simple_Name (Child);
            Full : constant String := Ada.Directories.Full_Name (Child);
         begin
            if Name /= "." and then Name /= ".." then
               if User_Name /= ""
                 and then (Parent = "/media" or else Parent = "/run/media")
                 and then Name = User_Name
               then
                  Append_Children (Full, Kind);
               else
                  Append_If_Directory (Full, Kind);
               end if;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
   exception
      when others =>
         Safe_End_Search (Search, Started);
         null;
   end Append_Children;

   procedure Append_Proc_Mounts is
   begin
      for Mount of Mounts loop
         declare
            Mount_Point     : constant String := To_String (Mount.Mount_Point);
            Filesystem_Type : constant String := To_String (Mount.Filesystem_Type);
         begin
            if Is_Displayable_Root_Mount (Mount_Point, Filesystem_Type) then
               Append_If_Directory (Mount_Point, Root_Kind_For_Mount (Mount_Point, Filesystem_Type));
            end if;
         end;
      end loop;
   end Append_Proc_Mounts;
begin
   --  "/" is the filesystem root only where it names one. On Windows it is
   --  drive-relative -- it resolves to the root of whatever drive the process
   --  happens to sit on -- so offering it here put a phantom "Filesystem" root
   --  at the top of the tree, ahead of, and duplicating, a real drive letter.
   --  The drive loop below is what enumerates roots there.
   if Files_Config.Alire_Host_OS /= "windows" then
      Append_If_Directory ("/", Root_Filesystem);
   end if;
   Append_Proc_Mounts;
   --  The home first, so it keeps its own kind should another place name it.
   for Place of Places loop
      if Hostkit.Fs."=" (Place.Kind, Hostkit.Fs.Home_Place) then
         Append_If_Directory (To_String (Place.Path), Root_Home);
      end if;
   end loop;
   Append_If_Directory (Ada.Directories.Current_Directory, Root_Current);
   Append_Children ("/mnt", Root_Mount);
   Append_Children ("/media", Root_Mount);
   Append_Children ("/run/media", Root_User_Mount);
   Append_Children ("/Volumes", Root_Mount);
   Append_Children ("/System/Volumes", Root_Mount);

   for Drive in Character range 'A' .. 'Z' loop
      Append_If_Directory (String'(1 => Drive) & ":\", Root_Windows_Drive);
   end loop;
   for Place of Places loop
      declare
         Path : constant String := To_String (Place.Path);
      begin
         case Place.Kind is
            when Hostkit.Fs.Home_Place =>
               null;
            when Hostkit.Fs.Drive_Place =>
               Append_If_Directory (Path, Root_Windows_Drive);
            when Hostkit.Fs.Profile_Place | Hostkit.Fs.Cloud_Place =>
               Append_If_Directory (Path, Root_User_Mount);
            when Hostkit.Fs.Network_Place =>
               Append_If_Directory (Path, Root_Network_Mount);
            when Hostkit.Fs.Removable_Media_Parent =>
               Append_Children (Path, Root_User_Mount);
            when Hostkit.Fs.Desktop_Mounts_Parent =>
               Append_Children (Path, Root_Network_Mount);
         end case;
      end;
   end loop;

   if Roots.Is_Empty then
      declare
         Full : constant String := Ada.Directories.Full_Name (Ada.Directories.Current_Directory);
      begin
         Roots.Append
           (Root_Entry'
              (Path  => To_Unbounded_String (Full),
               Label => To_Unbounded_String (Root_Label (Full, Root_Current)),
               Kind  => Root_Current,
               Volume_Name => To_Unbounded_String (Ada.Directories.Simple_Name (Full)),
               Ready => Root_Ready,
               Removable => False));
      end;
   end if;

   declare
      function Less (Left : Root_Entry; Right : Root_Entry) return Boolean is
      begin
         return To_String (Left.Path) < To_String (Right.Path);
      end Less;

      package Sorting is new Root_Entry_Vectors.Generic_Sorting ("<" => Less);
   begin
      Sorting.Sort (Roots);
   end;

   return Roots;
end Available_Root_Entries;

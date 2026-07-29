with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Files.Fs;
with Files_Config;
with Files.Platform.Macos;
with Files.Platform.Metadata;
with Files.Platform.Windows;

separate (Files.File_System)
package body Roots is
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   use type Ada.Directories.File_Kind;
   type Volume_Size_Info is record
      Capacity_Bytes   : Long_Long_Integer := 0;
      Free_Bytes       : Long_Long_Integer := 0;
      Inode_Count      : Long_Long_Integer := 0;
      Free_Inode_Count : Long_Long_Integer := 0;
      Name_Max         : Natural := 0;
      Read_Only        : Boolean := False;
      Known            : Boolean := False;
      Inodes_Known     : Boolean := False;
      Name_Max_Known   : Boolean := False;
      Read_Only_Known  : Boolean := False;
   end record;

   type Mount_Metadata is record
      Source_Device   : Unbounded_String;
      Filesystem_Type : Unbounded_String;
      Mount_Options   : Unbounded_String;
      Removable       : Boolean := False;
      Removable_Known : Boolean := False;
      Found           : Boolean := False;
   end record;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info);

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String;

   function Simple_Device_Name (Source : String) return String;

   function Parent_Block_Device_Name (Device : String) return String;

   function Read_First_Line (Path : String) return String;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata;

   function Root_Label (Path : String; Kind : Root_Kind) return String is
   begin
      case Kind is
         when Root_Filesystem =>
            return (if Path = "/" then "root.filesystem" else Path);
         when Root_Home =>
            return "root.home";
         when Root_Current =>
            return "root.current";
         when Root_Mount =>
            return "root.mount|" & Ada.Directories.Simple_Name (Path);
         when Root_User_Mount =>
            return "root.user_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Network_Mount =>
            return "root.network_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Windows_Drive =>
            return "root.drive|" & Path;
         when Root_Favorite =>
            return "root.favorite|" & Ada.Directories.Simple_Name (Path);
      end case;
   exception
      when others =>
         return Path;
   end Root_Label;

   function Available_Root_Entries return Root_Entry_Vectors.Vector is
      Roots : Root_Entry_Vectors.Vector;
      Home                    : constant String := Safe_Environment_Value ("HOME");
      User_Profile            : constant String := Safe_Environment_Value ("USERPROFILE");
      Xdg_Runtime_Dir         : constant String := Safe_Environment_Value ("XDG_RUNTIME_DIR");
      User_Name               : constant String := Safe_Environment_Value ("USER");
      Home_Drive              : constant String := Safe_Environment_Value ("HOMEDRIVE");
      Home_Path               : constant String := Safe_Environment_Value ("HOMEPATH");
      System_Drive            : constant String := Safe_Environment_Value ("SystemDrive");
      Home_Share              : constant String := Safe_Environment_Value ("HOMESHARE");
      One_Drive               : constant String := Safe_Environment_Value ("OneDrive");
      One_Drive_Commercial    : constant String := Safe_Environment_Value ("OneDriveCommercial");
      One_Drive_Consumer      : constant String := Safe_Environment_Value ("OneDriveConsumer");
      Home_Drive_Profile      : constant String :=
        (if Home_Drive /= "" and then Home_Path /= "" then Home_Drive & Home_Path else "");

      function Field_From
        (Line  : String;
         Index : Positive)
         return String
      is
         Current : Positive := 1;
         Start   : Natural := 0;
      begin
         for Position in Line'Range loop
            if Line (Position) /= ' ' and then Start = 0 then
               Start := Position;
            elsif Line (Position) = ' ' and then Start /= 0 then
               if Current = Index then
                  return Line (Start .. Position - 1);
               end if;
               Current := Current + 1;
               Start := 0;
            end if;
         end loop;

         if Start /= 0 and then Current = Index then
            return Line (Start .. Line'Last);
         end if;

         return "";
      end Field_From;

      function Starts_With
        (Text   : String;
         Prefix : String)
         return Boolean is
      begin
         return Text'Length >= Prefix'Length
           and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

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
         Runtime_Gvfs : constant String :=
           (if Xdg_Runtime_Dir = "" then "" else Join_Path (Xdg_Runtime_Dir, "gvfs"));

         function Is_Mount_Container return Boolean is
         begin
            return Mount_Point = "/mnt"
              or else Mount_Point = "/media"
              or else Mount_Point = "/run/media"
              or else Mount_Point = "/Volumes"
              or else Mount_Point = "/System/Volumes"
              or else (Runtime_Gvfs /= "" and then Mount_Point = Runtime_Gvfs);
         end Is_Mount_Container;
      begin
         return not Is_Mount_Container
           and then
             (Mount_Point = "/"
           or else Starts_With (Mount_Point, "/mnt/")
           or else Starts_With (Mount_Point, "/media/")
           or else Starts_With (Mount_Point, "/run/media/")
           or else Starts_With (Mount_Point, "/Volumes/")
           or else Starts_With (Mount_Point, "/System/Volumes/")
           or else
             (Runtime_Gvfs /= ""
              and then Starts_With (Mount_Point, Runtime_Gvfs & "/")));
      end Is_User_Visible_Mount_Point;

      function Is_Displayable_Root_Mount
        (Mount_Point     : String;
         Filesystem_Type : String)
         return Boolean is
      begin
         return Is_User_Visible_Mount_Point (Mount_Point)
           and then not Is_Pseudo_Mount_Type (Filesystem_Type);
      end Is_Displayable_Root_Mount;

      function Filesystem_Type_For (Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Buffer : String (1 .. 4096);
         Last   : Natural;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return "";
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Line        : constant String := Buffer (1 .. Last);
               Mount_Point : constant String := Field_From (Line, 2);
            begin
               if Mount_Point = Path then
                  Ada.Text_IO.Close (File);
                  return Field_From (Line, 3);
               end if;
            end;
         end loop;

         Ada.Text_IO.Close (File);
         return "";
      exception
         when others =>
            Safe_Close (File);
            return "";
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
         if Files.Fs.Directory_Exists (Path)
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
         when others =>
            null;
      end Append_If_Directory;

      procedure Append_Children
        (Parent : String;
         Kind   : Root_Kind)
      is
         Search : Ada.Directories.Search_Type;
         Child  : Ada.Directories.Directory_Entry_Type;
         Started : Boolean := False;
      begin
         if not Ada.Directories.Exists (Parent)
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

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Child);
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
         File   : Ada.Text_IO.File_Type;
         Buffer : String (1 .. 4096);
         Last   : Natural;

         function Octal_Value (Value : Character) return Natural is
         begin
            if Value in '0' .. '7' then
               return Character'Pos (Value) - Character'Pos ('0');
            else
               return Natural'Last;
            end if;
         end Octal_Value;

         function Decode_Mount_Escapes (Value : String) return String is
            Result : Unbounded_String;
            Index  : Natural := Value'First;
         begin
            while Index <= Value'Last loop
               if Value (Index) = '\'
                 and then Index + 3 <= Value'Last
                 and then Octal_Value (Value (Index + 1)) /= Natural'Last
                 and then Octal_Value (Value (Index + 2)) /= Natural'Last
                 and then Octal_Value (Value (Index + 3)) /= Natural'Last
               then
                  declare
                     Code : constant Natural :=
                       Octal_Value (Value (Index + 1)) * 64
                       + Octal_Value (Value (Index + 2)) * 8
                       + Octal_Value (Value (Index + 3));
                  begin
                     if Code <= Character'Pos (Character'Last) then
                        Append (Result, Character'Val (Code));
                        Index := Index + 4;
                     else
                        Append (Result, Value (Index));
                        Index := Index + 1;
                     end if;
                  end;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end loop;

            return To_String (Result);
         end Decode_Mount_Escapes;

         function Mount_Field
           (Line  : String;
            Index : Positive)
            return String is
         begin
            return Decode_Mount_Escapes (Field_From (Line, Index));
         end Mount_Field;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return;
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Line            : constant String := Buffer (1 .. Last);
               Mount_Point     : constant String := Mount_Field (Line, 2);
               Filesystem_Type : constant String := Field_From (Line, 3);
            begin
               if Is_Displayable_Root_Mount (Mount_Point, Filesystem_Type) then
                  Append_If_Directory (Mount_Point, Root_Kind_For_Mount (Mount_Point, Filesystem_Type));
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when others =>
            Safe_Close (File);
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
      if Home /= "" then
         Append_If_Directory (Home, Root_Home);
      end if;
      if User_Profile /= "" then
         Append_If_Directory (User_Profile, Root_Home);
      end if;
      Append_If_Directory (Ada.Directories.Current_Directory, Root_Current);
      Append_Children ("/mnt", Root_Mount);
      Append_Children ("/media", Root_Mount);
      Append_Children ("/run/media", Root_User_Mount);
      Append_Children ("/Volumes", Root_Mount);
      Append_Children ("/System/Volumes", Root_Mount);
      if Xdg_Runtime_Dir /= "" then
         Append_Children (Join_Path (Xdg_Runtime_Dir, "gvfs"), Root_Network_Mount);
      end if;
      if User_Name /= "" then
         declare
            Run_Media_User : constant String := "/run/media/" & User_Name;
         begin
            Append_Children (Run_Media_User, Root_User_Mount);
         end;
      end if;

      for Drive in Character range 'A' .. 'Z' loop
         Append_If_Directory (String'(1 => Drive) & ":\", Root_Windows_Drive);
      end loop;
      if Home_Drive /= "" then
         Append_If_Directory (Home_Drive & "\", Root_Windows_Drive);
      end if;
      if Home_Drive_Profile /= "" then
         Append_If_Directory (Home_Drive_Profile, Root_User_Mount);
      end if;
      if System_Drive /= "" then
         Append_If_Directory (System_Drive & "\", Root_Windows_Drive);
      end if;
      if Home_Share /= "" then
         Append_If_Directory (Home_Share, Root_Network_Mount);
      end if;
      if One_Drive /= "" then
         Append_If_Directory (One_Drive, Root_User_Mount);
      end if;
      if One_Drive_Commercial /= "" then
         Append_If_Directory (One_Drive_Commercial, Root_User_Mount);
      end if;
      if One_Drive_Consumer /= "" then
         Append_If_Directory (One_Drive_Consumer, Root_User_Mount);
      end if;

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

   function Available_Roots return Files.Types.String_Vectors.Vector is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Roots   : Files.Types.String_Vectors.Vector;
   begin
      for Root of Entries loop
         Roots.Append (Root.Path);
      end loop;

      return Roots;
   end Available_Roots;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Result  : Root_Discovery_Diagnostics :=
        (Root_Count              => Natural (Entries.Length),
         Ready_Count             => 0,
         Removable_Count         => 0,
         Windows_Drive_Count     => 0,
         Mount_Count             => 0,
         User_Mount_Count        => 0,
         Network_Mount_Count     => 0,
         Duplicate_Paths_Removed => True,
         Deterministic_Order     => True);
   begin
      for Root of Entries loop
         if Root.Ready = Root_Ready then
            Result.Ready_Count := Result.Ready_Count + 1;
         end if;

         if Root.Removable then
            Result.Removable_Count := Result.Removable_Count + 1;
         end if;

         case Root.Kind is
            when Root_Windows_Drive =>
               Result.Windows_Drive_Count := Result.Windows_Drive_Count + 1;
            when Root_Mount =>
               Result.Mount_Count := Result.Mount_Count + 1;
            when Root_User_Mount =>
               Result.User_Mount_Count := Result.User_Mount_Count + 1;
            when Root_Network_Mount =>
               Result.Network_Mount_Count := Result.Network_Mount_Count + 1;
            when others =>
               null;
         end case;
      end loop;

      return Result;
   end Root_Discovery_Status;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities is
      Has_Proc_Mounts : constant Boolean := Ada.Directories.Exists ("/proc/mounts");
      Has_Sys_Block   : constant Boolean := Ada.Directories.Exists ("/sys/block");
      Has_Statvfs     : constant Boolean :=
        Files.Platform.Metadata.Volume_Capacity_Of ("/").Available;
   begin
      return
        (Labels_From_Platform_Api    => False,
         Readiness_From_Platform_Api => True,
         Removable_From_Platform_Api => Has_Sys_Block,
         Capacity_From_Platform_Api  => Has_Statvfs,
         Filesystem_Type_Available   => Has_Proc_Mounts,
         Eject_Available             => False,
         Native_Api_Name             =>
           To_Unbounded_String
             ((if Has_Statvfs and then Has_Proc_Mounts and then Has_Sys_Block then
                  "statvfs+proc.mounts+sysfs"
               elsif Has_Statvfs and then Has_Proc_Mounts then "statvfs+proc.mounts"
               elsif Has_Statvfs then "statvfs"
               elsif Has_Proc_Mounts and then Has_Sys_Block then "proc.mounts+sysfs"
               elsif Has_Proc_Mounts then "proc.mounts"
               elsif Has_Sys_Block then "sysfs"
               else "none")),
         Native_Binding_Status       =>
           (if Has_Statvfs or else Has_Proc_Mounts or else Has_Sys_Block
            then Native_API_Binding_Available
            else Native_API_Binding_Missing),
         Binding_Unit                => To_Unbounded_String ("Files.File_System"),
         Source_Device_Available     => Has_Proc_Mounts,
         Mount_Options_Available     => Has_Proc_Mounts,
         Network_Metadata_Available  => Has_Proc_Mounts,
         Removable_Status_Available  => Has_Sys_Block,
         Capacity_Bytes_Known        => Has_Statvfs,
         Free_Bytes_Known            => Has_Statvfs,
         Inode_Count_Known           => Has_Statvfs,
         Read_Only_Available         => Has_Statvfs,
         Name_Max_Available          => Has_Statvfs);
   end Root_Volume_Capabilities_Of_Current_Environment;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile is
   begin
      return
        (Permission_Errors_Recoverable => True,
         Symlink_Items_Represented     => True,
         Special_File_Items_Represented => True,
         Cross_Device_Rename_Recoverable => True,
         Trash_Preflight               => True,
         Metadata_Partial_Items        => True,
         Removable_Root_Metadata       => True,
         Native_Root_Volume_Details    => True);
   end Filesystem_Edge_Case_Profile_Of_Current_Environment;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
   is
      Caps : constant Root_Volume_Capabilities := Root_Volume_Capabilities_Of_Current_Environment;
   begin
      case Adapter is
         when Native_Adapter_Linux =>
            return
              (Adapter               => Native_Adapter_Linux,
               Trash_Binding_Status  =>
                 (if Trash_Backend_Of_Current_Environment in
                   Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home
                  then Native_API_Binding_Available
                  else Native_API_Binding_Missing),
               Volume_Binding_Status => Caps.Native_Binding_Status,
               Trash_API_Name        => To_Unbounded_String ("freedesktop.trash"),
               Volume_API_Name       => Caps.Native_Api_Name,
               Trash_Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
               Volume_Binding_Unit   => To_Unbounded_String ("Files.File_System.Root_Volume_Details_For"),
               Required_Library      => To_Unbounded_String ("libc"),
               Required_Framework    => Null_Unbounded_String,
               --  Only when Linux really is the target. The Windows and macOS
               --  profiles already answer this from their per-OS bodies; this
               --  branch used to say True unconditionally, so on a Mac both the
               --  Linux and the macOS adapter claimed to be the current one.
               Current_Target        => Files_Config.Alire_Host_OS = "linux",
               Trash_Can_Execute     => Trash_Is_Available,
               Volume_Can_Query      => Caps.Capacity_Bytes_Known or else Caps.Filesystem_Type_Available);
         when Native_Adapter_Windows =>
            return Files.Platform.Windows.API_Profile;
         when Native_Adapter_Macos =>
            return Files.Platform.Macos.API_Profile;
         when Native_Adapter_None =>
            return
              (Adapter               => Native_Adapter_None,
               Trash_Binding_Status  => Native_API_Binding_Missing,
               Volume_Binding_Status => Native_API_Binding_Missing,
               Trash_API_Name        => To_Unbounded_String ("none"),
               Volume_API_Name       => To_Unbounded_String ("none"),
               Trash_Binding_Unit    => To_Unbounded_String ("none"),
               Volume_Binding_Unit   => To_Unbounded_String ("none"),
               Required_Library      => Null_Unbounded_String,
               Required_Framework    => Null_Unbounded_String,
               Current_Target        => False,
               Trash_Can_Execute     => False,
               Volume_Can_Query      => False);
      end case;
   end Native_Platform_API_Profile_For;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info)
   is
      Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
        Files.Platform.Metadata.Volume_Capacity_Of (Path);
   begin
      Info :=
        (Capacity_Bytes   => Capacity.Capacity_Bytes,
         Free_Bytes       => Capacity.Free_Bytes,
         Inode_Count      => Capacity.Inode_Count,
         Free_Inode_Count => Capacity.Free_Inode_Count,
         Name_Max         => Capacity.Name_Max,
         Read_Only        => Capacity.Read_Only,
         Known            => Capacity.Available,
         Inodes_Known     => Capacity.Inodes_Known,
         Name_Max_Known   => Capacity.Name_Max_Known,
         Read_Only_Known  => Capacity.Read_Only_Known);
   end Volume_Size_For;

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String
   is
      Current : Positive := 1;
      Start   : Natural := 0;
   begin
      for Position in Line'Range loop
         if Line (Position) /= ' ' and then Start = 0 then
            Start := Position;
         elsif Line (Position) = ' ' and then Start /= 0 then
            if Current = Index then
               return Line (Start .. Position - 1);
            end if;
            Current := Current + 1;
            Start := 0;
         end if;
      end loop;

      if Start /= 0 and then Current = Index then
         return Line (Start .. Line'Last);
      end if;

      return "";
   end Mount_Field;

   function Simple_Device_Name (Source : String) return String is
      Start : Natural := Source'First;
   begin
      for Index in reverse Source'Range loop
         if Source (Index) = '/' then
            Start := Index + 1;
            exit;
         end if;
      end loop;

      if Start > Source'Last then
         return "";
      end if;

      return Source (Start .. Source'Last);
   end Simple_Device_Name;

   function Parent_Block_Device_Name (Device : String) return String is
      Last : Natural := Device'Last;
   begin
      if Device = "" then
         return "";
      end if;

      while Last >= Device'First and then Device (Last) in '0' .. '9' loop
         Last := Last - 1;
      end loop;

      if Last >= Device'First and then Device (Last) = 'p' then
         Last := Last - 1;
      end if;

      if Last < Device'First then
         return Device;
      end if;

      return Device (Device'First .. Last);
   end Parent_Block_Device_Name;

   function Read_First_Line (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 256);
      Last   : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Ada.Text_IO.Get_Line (File, Buffer, Last);
      Ada.Text_IO.Close (File);
      return Buffer (1 .. Last);
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Read_First_Line;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean
   is
      Device : constant String := Simple_Device_Name (Source);
      Parent : constant String := Parent_Block_Device_Name (Device);
      Value  : Unbounded_String;
   begin
      Known := False;
      if Device = "" or else Ada.Strings.Fixed.Index (Source, "/dev/") /= Source'First then
         return False;
      end if;

      Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Device & "/removable"));
      if To_String (Value) = "" and then Parent /= Device then
         Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Parent & "/removable"));
      end if;

      if To_String (Value) = "" then
         return False;
      end if;

      Known := True;
      return To_String (Value) = "1";
   end Removable_Status_For;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 4096);
      Last   : Natural;
      Result : Mount_Metadata;
   begin
      if not Ada.Directories.Exists ("/proc/mounts") then
         return Result;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         declare
            Line        : constant String := Buffer (1 .. Last);
            Mount_Point : constant String := Mount_Field (Line, 2);
         begin
            if Mount_Point = Path then
               declare
                  Source : constant String := Mount_Field (Line, 1);
                  Known  : Boolean := False;
               begin
                  Ada.Text_IO.Close (File);
                  Result.Source_Device := To_Unbounded_String (Source);
                  Result.Filesystem_Type := To_Unbounded_String (Mount_Field (Line, 3));
                  Result.Mount_Options := To_Unbounded_String (Mount_Field (Line, 4));
                  Result.Removable := Removable_Status_For (Source, Known);
                  Result.Removable_Known := Known;
                  Result.Found := True;
                  return Result;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return Result;
   exception
      when others =>
         Safe_Close (File);
         return (others => <>);
   end Mount_Metadata_For_Root;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
   is
      Path_Text : constant String := To_String (Root.Path);

      function Path_Is_Queryable return Boolean is
      begin
         if Path_Text = "" then
            return False;
         end if;

         for Character_Value of Path_Text loop
            if Character'Pos (Character_Value) < 32
              or else Character'Pos (Character_Value) = 127
            then
               return False;
            end if;
         end loop;

         return True;
      end Path_Is_Queryable;

      Queryable : constant Boolean := Path_Is_Queryable;
      Mount     : constant Mount_Metadata :=
        (if Queryable then Mount_Metadata_For_Root (Path_Text) else (others => <>));
      Volume    : Volume_Size_Info := (others => <>);

      function Adapter_Name return String is
         Has_Statvfs : constant Boolean := Volume.Known;
         Has_Proc    : constant Boolean := Mount.Found;
         Has_Sysfs   : constant Boolean := Mount.Removable_Known;
      begin
         if Has_Statvfs and then Has_Proc and then Has_Sysfs then
            return "statvfs+proc.mounts+sysfs";
         elsif Has_Statvfs and then Has_Proc then
            return "statvfs+proc.mounts";
         elsif Has_Statvfs then
            return "statvfs";
         elsif Has_Proc and then Has_Sysfs then
            return "proc.mounts+sysfs";
         elsif Has_Proc then
            return "proc.mounts";
         elsif Has_Sysfs then
            return "sysfs";
         else
            return "none";
         end if;
      end Adapter_Name;

      function Network_Filesystem_Type (Filesystem_Type : String) return Boolean is
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
      end Network_Filesystem_Type;

      function Path_Starts_With (Prefix : String) return Boolean is
      begin
         return Path_Text'Length >= Prefix'Length
           and then Path_Text (Path_Text'First .. Path_Text'First + Prefix'Length - 1) = Prefix;
      end Path_Starts_With;

      function Network_Root return Boolean is
      begin
         return Root.Kind = Root_Network_Mount
           or else Network_Filesystem_Type (To_String (Mount.Filesystem_Type))
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\");
      end Network_Root;

      function Remote_Protocol_For return String is
         Path_Lower : constant String := Files.Types.To_Lower (Path_Text);
         Type_Lower : constant String := Files.Types.To_Lower (To_String (Mount.Filesystem_Type));
      begin
         if Type_Lower = "cifs" or else Type_Lower = "smb3" then
            return "smb";
         elsif Type_Lower = "nfs" or else Type_Lower = "nfs4" then
            return "nfs";
         elsif Type_Lower = "sshfs" or else Type_Lower = "fuse.sshfs" then
            return "sshfs";
         elsif Type_Lower = "davfs" then
            return "webdav";
         elsif Type_Lower = "afpfs" then
            return "afp";
         elsif Type_Lower = "9p" then
            return "9p";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "smb-share:") > 0
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\")
         then
            return "smb";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "sftp:") > 0 then
            return "sftp";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "dav:") > 0
           or else Ada.Strings.Fixed.Index (Path_Lower, "davs:") > 0
         then
            return "webdav";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "afp-volume:") > 0 then
            return "afp";
         elsif Type_Lower = "fuse.gvfsd-fuse"
           or else Ada.Strings.Fixed.Index (Path_Lower, "/gvfs/") > 0
         then
            return "gvfs";
         elsif Network_Root then
            return "unknown";
         else
            return "";
         end if;
      end Remote_Protocol_For;

      function Auth_May_Be_Required_For (Protocol : String) return Boolean is
      begin
         return Protocol = "afp"
           or else Protocol = "sftp"
           or else Protocol = "smb"
           or else Protocol = "sshfs"
           or else Protocol = "webdav";
      end Auth_May_Be_Required_For;
   begin
      if Queryable then
         Volume_Size_For (Path_Text, Volume);
      end if;

      declare
         Is_Network : constant Boolean := Network_Root;
         Protocol   : constant String := Remote_Protocol_For;
      begin
         return
           (Path                 => Root.Path,
            Label                => Root.Volume_Name,
            Native_Api_Name      => To_Unbounded_String (Adapter_Name),
            Filesystem_Type      => Mount.Filesystem_Type,
            Source_Device        => Mount.Source_Device,
            Mount_Options        => Mount.Mount_Options,
            Capacity_Bytes       => Volume.Capacity_Bytes,
            Free_Bytes           => Volume.Free_Bytes,
            Inode_Count          => Volume.Inode_Count,
            Free_Inode_Count     => Volume.Free_Inode_Count,
            Capacity_Known       => Volume.Known,
            Free_Known           => Volume.Known,
            Inode_Count_Known    => Volume.Inodes_Known,
            Free_Inode_Known     => Volume.Inodes_Known,
            Read_Only            => Volume.Read_Only,
            Read_Only_Known      => Volume.Read_Only_Known,
            Name_Max             => Volume.Name_Max,
            Name_Max_Known       => Volume.Name_Max_Known,
            Removable_Known      => Mount.Removable_Known,
            Removable            => Mount.Removable,
            Ejectable            => False,
            Network_Mount        => Is_Network,
            Remote_Protocol      => To_Unbounded_String (Protocol),
            Offline_Possible     => Is_Network,
            Auth_May_Be_Required => Is_Network and then Auth_May_Be_Required_For (Protocol),
            Latency_Sensitive    => Is_Network,
            Special_Error_Recovery => Is_Network,
            Uses_Platform_Detail =>
              Volume.Known
              or else Volume.Inodes_Known
              or else Volume.Read_Only_Known
              or else Volume.Name_Max_Known
              or else Mount.Found
              or else Mount.Removable_Known);
      end;
   end Root_Volume_Details_For;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy is
   begin
      return
        (Uses_Extension_Mapping     => True,
         Uses_Mime_Sniffing         => False,
         Parses_Image_Dimensions    => True,
         Parses_Text_Encoding       => True,
         Parses_Archive_Entry_Count => True,
         Parses_Pdf_Page_Markers    => True,
         Parses_Media_Codecs        => False,
         Parses_Office_Package_Info => True);
   end Filetype_Metadata_Policy_Of_Current_Implementation;

end Roots;

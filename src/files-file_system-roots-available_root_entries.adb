separate (Files.File_System.Roots)
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

separate (Files_Suite.Operations)
   procedure Test_Trash_Backend_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_xdg_data";

      procedure Check is
         Mutation     : Files.File_System.Mutation_Result;
      begin
         --  On Windows the desktop trash is the Recycle Bin, which is always there:
         --  "no trash base exists" is not a state that platform can be in. Select
         --  the freedesktop backend explicitly, and the absence of a base is then
         --  meaningful on every host.
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Assert (not Files.File_System.Trash_Is_Available, "trash availability detects missing trash base");
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
            "trash backend reports unavailable when no trash base exists");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", "relative-trash-data");
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable
            and then not Files.File_System.Trash_Is_Available,
            "a relative XDG data home cannot redirect trash into the process directory");
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");

         --  And with nothing selected, each platform falls back to its own desktop
         --  trash: the Recycle Bin on Windows, the freedesktop layout elsewhere.
         Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Assert
              (Files.File_System.Trash_Backend_Of_Current_Environment
                 = Files.File_System.Trash_Windows_Recycle_Bin,
               "Windows falls back to the Recycle Bin, which needs no trash base");
            Assert (Files.File_System.Trash_Is_Available,
                    "the Recycle Bin is always available");
         else
            Assert
              (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
               "elsewhere, no trash base means no trash");
         end if;
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Assert
           (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
            "unavailable trash backend reports no metadata sidecar support");
         Write_File (Join (Root, "blocked-trash-parent"));
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Join (Root, "blocked-trash-parent"), "xdg"));
         Assert
           (not Files.File_System.Trash_Is_Available,
            "trash availability rejects a regular file in the trash parent chain");
         Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "missing-for-blocked-trash.txt"));
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.failed",
            "missing trash target still reports failed trash mutation");
         Mutation :=
           Files.File_System.Move_To_Trash_Preflight
             (Root & "/bad" & Character'Val (0) & "trash-target.txt");
         Assert (not Mutation.Success, "malformed trash target reports failed trash mutation");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.failed",
            "malformed trash target reports failed trash diagnostic");
         Write_File (Join (Root, "blocked-trash-target.txt"));
         Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "blocked-trash-target.txt"));
         Assert (not Mutation.Success, "trash preflight rejects blocked trash parent chain");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.unavailable",
            "blocked trash parent chain reports unavailable trash");
         Ada.Directories.Delete_File (Join (Root, "blocked-trash-parent"));
         Ada.Directories.Delete_File (Join (Root, "blocked-trash-target.txt"));
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Assert (Files.File_System.Trash_Is_Available, "trash availability detects XDG trash base");
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Xdg_Data_Home,
            "trash backend reports XDG data home when configured");
         Assert
           (Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
            "XDG trash backend reports trashinfo sidecar support");
         Assert
           (Files.File_System.Trash_Capabilities_Of_Current_Environment.Collision_Safe_Name,
            "XDG trash backend reports collision-safe naming");
         --  "/" is not a root on Windows; the drive is.
         Mutation := Files.File_System.Move_To_Trash_Preflight (Filesystem_Root);
         Assert (not Mutation.Success, "trash preflight rejects filesystem root");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.failed",
            "filesystem root trash preflight reports failed trash mutation");
         declare
            Prefix_Source : constant String := Join (Root, "trash-prefix-source");
            Prefix_Base   : constant String := Prefix_Source & "-xdg";
         begin
            Write_File (Prefix_Source);
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Prefix_Base);
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
            Mutation := Files.File_System.Move_To_Trash_Preflight (Prefix_Source);
            Assert (Mutation.Success, "trash preflight accepts sibling paths sharing a prefix");
            Files_Suite.Support.Assert_Equal
              (To_String (Mutation.Error_Key),
               "",
               "trash prefix-sibling preflight has no diagnostic");
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
            Ada.Directories.Delete_File (Prefix_Source);
         end;
         if Hostkit.Host.Current /= Hostkit.Host.Windows then
            declare
               Backslash_Data : constant String := Join (Root, "backslash-xdg");
               Backslash_Base : constant String := Join (Backslash_Data, "Trash");
               Backslash_Source : constant String := Join (Backslash_Data, "Trash\victim");
            begin
               Ada.Directories.Create_Path (Join (Backslash_Base, "files"));
               Ada.Directories.Create_Path (Join (Backslash_Base, "info"));
               Write_File (Backslash_Source, "sibling");
               Ada.Environment_Variables.Set ("XDG_DATA_HOME", Backslash_Data);
               Mutation := Files.File_System.Move_To_Trash_Preflight (Backslash_Source);
               Assert
                 (Mutation.Success,
                  "a POSIX backslash sibling is not mistaken for a child of the trash directory");
               Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
               Ada.Directories.Delete_File (Backslash_Source);
               Ada.Directories.Delete_Directory (Join (Backslash_Base, "files"));
               Ada.Directories.Delete_Directory (Join (Backslash_Base, "info"));
               Ada.Directories.Delete_Directory (Backslash_Base);
               Ada.Directories.Delete_Directory (Backslash_Data);
            end;
         end if;
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Trash_Backend_Selection;

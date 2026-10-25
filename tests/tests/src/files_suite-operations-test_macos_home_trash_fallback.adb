separate (Files_Suite.Operations)
   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mac_Home     : constant String := Root & "_mac_home";

      procedure Check is
         Mutation     : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Project_Tools.Files.Delete_Tree (Mac_Home);
         Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Mac_Home);
         Write_File (Join (Root, "mac-trash.txt"));
         Mutation := Files.File_System.Move_To_Trash (Join (Root, "mac-trash.txt"));
         Assert (Mutation.Success, "macOS-style home trash fallback moves files");
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Home,
            "trash backend reports macOS-style home trash when present");
         Assert
           (Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "mac-trash.txt")),
            "macOS-style home trash stores the file directly under ~/.Trash");
         Assert
           (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "files")),
            "macOS-style home trash does not create a freedesktop files/ subdirectory");
         Assert
           (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "info")),
            "macOS-style home trash does not create a freedesktop info/ subdirectory");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Macos_Home_Trash_Fallback;

separate (Files_Suite.Operations)
   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Stray_Home : constant String := Root & "_stray_home";

      procedure Check is
         Mutation : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Project_Tools.Files.Delete_Tree (Stray_Home);
         Ada.Directories.Create_Path (Join (Stray_Home, ".Trash"));
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Stray_Home);
         Write_File (Join (Root, "stray-trash.txt"));
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Home_Data,
            "a ~/.Trash folder does not switch the freedesktop trash to the macOS layout");
         Mutation := Files.File_System.Move_To_Trash (Join (Root, "stray-trash.txt"));
         Assert (Mutation.Success, "trashing beside a stray ~/.Trash succeeds");
         Assert
           (Ada.Directories.Exists
              (Join (Join (Join (Join (Join (Stray_Home, ".local"), "share"), "Trash"), "info"),
                     "stray-trash.txt.trashinfo")),
            "the item gets the info file that restoring it needs");
         Assert
           (not Ada.Directories.Exists (Join (Join (Stray_Home, ".Trash"), "stray-trash.txt")),
            "nothing is put into the stray ~/.Trash");
         Project_Tools.Files.Delete_Tree (Stray_Home);
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Stray_Home_Trash_Stays_Freedesktop;

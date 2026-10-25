separate (Files_Suite.Operations)
   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Stray_Home : constant String := Root & "_stray_home";

      --  With no backend asked for, the host decides what a ~/.Trash means:
      --  on Linux it is just a folder, on macOS it is the home trash.
      procedure Check is
         Mutation   : Files.File_System.Mutation_Result;
         Home_Trash : constant String := Join (Stray_Home, ".Trash");
      begin
         Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         Project_Tools.Files.Delete_Tree (Stray_Home);
         Ada.Directories.Create_Path (Home_Trash);
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Stray_Home);
         Write_File (Join (Root, "stray-trash.txt"));
         if Hostkit.Host.Current = Hostkit.Host.Linux then
            Assert
              (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Home_Data,
               "on Linux a ~/.Trash folder does not switch the freedesktop trash to the macOS layout");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, "stray-trash.txt"));
            Assert (Mutation.Success, "trashing beside a stray ~/.Trash succeeds");
            Assert
              (Ada.Directories.Exists
                 (Join (Join (Join (Join (Join (Stray_Home, ".local"), "share"), "Trash"), "info"),
                        "stray-trash.txt.trashinfo")),
               "the item gets the info file that restoring it needs");
            Assert
              (not Ada.Directories.Exists (Join (Home_Trash, "stray-trash.txt")),
               "nothing is put into the stray ~/.Trash");
         else
            Assert
              (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Home,
               "on macOS an existing ~/.Trash is the home trash");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, "stray-trash.txt"));
            Assert (Mutation.Success, "trashing into the macOS home trash succeeds");
            Assert
              (Ada.Directories.Exists (Join (Home_Trash, "stray-trash.txt")),
               "the item lands directly in ~/.Trash");
         end if;
         Project_Tools.Files.Delete_Tree (Stray_Home);
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux and then Hostkit.Host.Current /= Hostkit.Host.MacOS then
         Files_Suite.Support.Skip
           ("Test_Stray_Home_Trash_Stays_Freedesktop",
            "only Linux and macOS read a ~/.Trash folder; Windows uses the Recycle Bin");
         return;
      end if;
      With_Trash_Environment (Check'Access);
   end Test_Stray_Home_Trash_Stays_Freedesktop;

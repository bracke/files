separate (Files_Suite.Operations)
   procedure Test_Trash_Backspace_And_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Special_Path  : constant String := Join (Root, "space % file.txt");
      procedure Check is
         Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Load         : Files.File_System.Directory_Load_Result;
         Model        : Files.Model.Window_Model;
         Result       : Files.Controller.Controller_Result;
      begin
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);

         Write_File (Join (Root, "doomed2.txt"));
         Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "refresh loads second delete target");
         Select_Name (Model, "doomed2.txt");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Delete_Selected_Items_Command,
            "Backspace routes through same delete command");
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "Backspace delete uses trash operation");
         Assert (Ada.Directories.Exists (Join (Trash_File, "doomed2.txt")), "Backspace moves file to trash");

         Write_File (Special_Path);
         Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "refresh loads encoded trash target");
         Select_Name (Model, "space % file.txt");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "encoded trash target moves to trash");
         --  What this is about is the encoding of the awkward characters, and that is
         --  host-independent. The absolute path in front of them is not: it was spelled
         --  out here as Full_Name (Root) & "/...", which is only ever true on POSIX. A
         --  Windows path is "C:\..." and the encoder escapes its ':' and '\' too, so the
         --  literal never matched. Assert the part this test is named for, and leave the
         --  round-trip -- that the recorded path decodes back to the original location --
         --  to Test_Restore_From_Trash, which is what that test exists to prove.
         Assert
           (Project_Tools.Files.File_Contains
              (Join (Trash_Info, "space % file.txt.trashinfo"), "Path="),
            "trashinfo records the original path");
         Assert
           (Project_Tools.Files.File_Contains
              (Join (Trash_Info, "space % file.txt.trashinfo"), "space%20%25%20file.txt"),
            "trashinfo path percent-encodes spaces and percent signs");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Trash_Backspace_And_Encoding;

separate (Files_Suite.Operations)
   procedure Test_Multi_Selection_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");

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

         Write_File (Join (Root, "multi-a.txt"));
         Write_File (Join (Root, "multi-b.txt"));
         Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "refresh loads multi-delete targets");
         Files.Model.Set_Filter (Model, "multi-");
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Visible_Selection (Model, 2);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "multi-selection delete succeeds");
         Assert (Ada.Directories.Exists (Join (Trash_File, "multi-a.txt")), "multi-delete moves first file");
         Assert (Ada.Directories.Exists (Join (Trash_File, "multi-b.txt")), "multi-delete moves second file");
         Assert (not Ada.Directories.Exists (Join (Root, "multi-a.txt")), "multi-delete removes first source file");
         Assert (not Ada.Directories.Exists (Join (Root, "multi-b.txt")), "multi-delete removes second source file");

         Write_File (Join (Root, "partial-a.txt"));
         Write_File (Join (Root, "partial-b.txt"));
         Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "refresh loads partial-delete targets");
         Files.Model.Set_Filter (Model, "partial-");
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Visible_Selection (Model, 2);
         Ada.Directories.Delete_File (Join (Root, "partial-b.txt"));
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Failed,
            "partial multi-delete reports failure");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Operation.Error_Key),
            "error.trash.failed",
            "partial multi-delete reports trash failure");
         Assert
           (not Ada.Directories.Exists (Join (Trash_File, "partial-a.txt")),
            "partial multi-delete does not move earlier files before preflight failure");
         Assert
           (Ada.Directories.Exists (Join (Root, "partial-a.txt")),
            "partial multi-delete leaves earlier source files in place");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Item_Count (Model),
            1,
            "partial multi-delete reloads stale directory model");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.trash.failed",
            "partial multi-delete keeps error state");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Multi_Selection_Trash;

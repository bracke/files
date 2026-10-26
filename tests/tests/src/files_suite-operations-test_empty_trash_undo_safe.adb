with Files.Commands.Status;
separate (Files_Suite.Operations)
   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_undo_xdg_data";
      Source_Path  : constant String := Join (Root, "empty-undo.txt");
      --  Restores what the test changes, on failure too.
      Environment  : Files_Suite.Support.Environment_Guard;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Trashing a selected item records an undo-only Undo_Restore_Trash entry
      --  whose source is the payload's new location inside the trash.
      Write_File (Source_Path, "payload");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "undo-safe setup loads the ordinary directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "empty-undo.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "undo-safe setup trashes the item");
      Assert (Files.Model.Undo_Available (Model), "trashing records an undo entry");

      --  Navigate into the trash and empty it: the pending restore's source path
      --  is now permanently gone.
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "undo-safe setup opens the trash view");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "the trashed item is visible in the trash view");
      Result := Files.Controller.Execute_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "empty trash succeeds");
      Assert (Files.Model.Undo_Available (Model), "the dangling restore undo entry is still present");

      --  Undoing the restore whose source was emptied must fail safely, not crash.
      Result := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Result.Operation.Status /= Files.Operations.Operation_Success,
         "undoing a restore whose trashed source was emptied fails safely");
      Assert (not Ada.Directories.Exists (Source_Path), "the failed undo does not resurrect the emptied item");

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Empty_Trash_Undo_Safe;

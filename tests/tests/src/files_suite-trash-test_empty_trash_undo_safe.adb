with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Commands.Status;
with Files_Suite.Support.Guards;
with Files.Model.Jobs;
separate (Files_Suite.Trash)
   --  Undoing a trash whose item was emptied from the trash since fails
   --  safely: in process, and in a window (background transfers on, as the
   --  GUI always runs), where the trash, the emptying and the undo each run
   --  in a helper and the helper's history is merged back.
   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_undo_xdg_data";
      Source_Path  : constant String := Join (Root, "empty-undo.txt");
      --  Restores what the test changes, on failure too.
      Environment  : Files_Suite.Support.Guards.Environment_Guard;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Step         : Files.Operation_Results.Operation_Result;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Trashing a selected item records an undo-only Undo_Restore_Trash entry
      --  whose source is the payload's new location inside the trash.
      Write_File (Source_Path, "payload");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Assert (Load.Success, "undo-safe setup loads the ordinary directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "empty-undo.txt");
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "undo-safe setup trashes the item");
      Assert (Files.Model.History.Undo_Available (Model), "trashing records an undo entry");

      --  Navigate into the trash and empty it: the pending restore's source path
      --  is now permanently gone.
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Navigate_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Navigated,
         "undo-safe setup opens the trash view");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "the trashed item is visible in the trash view");
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "empty trash succeeds");
      Assert (Files.Model.History.Undo_Available (Model), "the dangling restore undo entry is still present");

      --  Undoing the restore whose source was emptied must fail safely, not crash.
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Result.Operation.Status /= Files.Operation_Results.Operation_Success,
         "undoing a restore whose trashed source was emptied fails safely");
      Assert (not Ada.Directories.Exists (Source_Path), "the failed undo does not resurrect the emptied item");

      --  In a window, each step through its helper.
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Reset_Root;
      Write_File (Source_Path, "payload");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Select_Name (Model, "empty-undo.txt");
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Step := Complete_Operation (Model, Settings, Result.Operation);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "a window's helper trashes the item");
      Assert (not Ada.Directories.Exists (Source_Path), "the item is in the trash");
      Assert (Files.Model.History.Undo_Available (Model), "the helper's trash is in the window's history");
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Navigate_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operation_Results.Operation_Navigated, "the window opens the trash view");
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Step := Complete_Operation (Model, Settings, Result.Operation);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "a window's helper empties the trash");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 0, "the trash view is empty");
      Assert (Files.Model.History.Undo_Available (Model), "the dangling undo stays in the window's history");
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Undo_Command, Model, Settings);
      Step := Complete_Operation (Model, Settings, Result.Operation);
      Await_View (Model, Settings);
      Assert (Step.Status /= Files.Operation_Results.Operation_Success,
              "a window's undo of a trash whose item was emptied fails safely");
      Assert (not Ada.Directories.Exists (Source_Path), "and does not bring the emptied item back");

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Empty_Trash_Undo_Safe;

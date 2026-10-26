with Files.Commands.Status;
separate (Files_Suite.Commands)
   procedure Test_Commands_Disabled_Without_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Navigate_Back_Command, Model),
              "back disabled initially");
      Files_Suite.Support.Run_Command (Files.Commands.Navigate_Back_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "a disabled back command does not change path");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "disabled back command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "disabled back returns operation data");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.history.back_unavailable",
         "disabled back records error");
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "disabled back click is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Navigate_Back_Command,
         "disabled back click reports command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "disabled back click returns operation data");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "delete disabled with no selection");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink disabled with no selection");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link disabled with no selection");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Deselect_All_Command, Model),
         "deselect-all disabled with nothing selected");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Invert_Selection_Command, Model),
         "invert-selection enabled with visible items");
      Files.Model.Select_All_Visible (Model);
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Deselect_All_Command, Model),
         "deselect-all enabled with a non-empty selection");
      Files.Model.Clear_Selection (Model);
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Undo_Command, Model),
         "undo disabled with no recorded history");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Redo_Command, Model),
         "redo disabled with no recorded history");
      --  The info pane can always be toggled, even with nothing selected: an
      --  empty selection simply shows an empty pane.
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Toggle_Info_Pane_Command, Model),
         "info toggle enabled with no selection");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "info toggle executes with no selection");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info toggle opens the info pane with no selection");
      --  Restore the closed state so later assertions see no transient panes.
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second info toggle closes the pane again");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "disabled delete command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "disabled delete returns operation data");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "disabled delete records error");
      Result := Files.Controller.Execute_Command (Files.Commands.Rename_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "disabled rename command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "disabled rename returns operation data");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "disabled rename records error");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel disabled with no transient state");
      Files.Model.Focus_Path_Input (Model);
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while path input has focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "drive selector command is controller-routed");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "drive selector reports successful state-only operation");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "drive selector clears stale error state");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while root selector is open");
      Files.Model.Cancel_Focus_Or_Edit (Model);
   end Test_Commands_Disabled_Without_Selection;

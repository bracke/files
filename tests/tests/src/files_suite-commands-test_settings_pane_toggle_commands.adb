separate (Files_Suite.Commands)
   procedure Test_Settings_Pane_Toggle_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Toggle_Settings_Pane_Command, Model),
         "settings pane command is enabled in the normal model state");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "pure settings command does not open unseeded settings pane");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model),
         "save settings is disabled without settings pane");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model),
         "reset settings is disabled without settings pane");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "controller opens settings pane with editable draft");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "settings toggle reports successful state-only operation");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "settings pane receives editable settings focus");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Files.Model.Begin_Create_File (Model, "settings-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert
        (Files.Model.Settings_Pane_Is_Open (Model),
         "controller opens settings pane over pending create");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "settings pane opening clears pending create state");
      Assert
        (not Files.Model.Rename_Is_Active (Model),
         "settings pane opening clears pending rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "settings pane opening focuses settings after clearing edit state");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "pure settings command can close seeded settings pane");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "controller reopens settings pane with editable draft");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model), "save settings is enabled");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model), "reset settings is enabled");
      Files.Controller.Replace_Focused_Text (Model, "details");
      Result := Files.Controller.Execute_Command (Files.Commands.Reset_Settings_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Reset_Settings_Command,
         "reset settings command is reported");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "reset settings reports success");
      Result := Files.Controller.Execute_Command (Files.Commands.Save_Settings_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Save_Settings_Command,
         "pure save settings command is reported");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "pure save settings command keeps runtime path-resolution sentinel");
   end Test_Settings_Pane_Toggle_Commands;

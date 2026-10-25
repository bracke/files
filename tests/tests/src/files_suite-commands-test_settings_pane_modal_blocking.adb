separate (Files_Suite.Commands)
   procedure Test_Settings_Pane_Modal_Blocking (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Settings_Pane_Command,
         "control+comma routes settings command");
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma opens settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "control+comma closes open settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma reopens settings pane");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "Escape closes unfocused settings pane");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "closed settings text click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "closed settings text click does not focus input");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens from palette state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "settings pane opening closes command palette");
      Assert (not Files.Model.Rename_Is_Active (Model), "settings pane opening clears active rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "settings pane opening moves focus to settings input");
      Files.Model.Select_Visible (Model, 1);
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Save_Settings_Command),
         "settings pane allowlist includes save");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Delete_Selected_Items_Command),
         "settings pane allowlist excludes background delete");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "settings pane disables background delete command");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
         "settings pane disables background open command");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model),
         "settings pane keeps save command enabled");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Open_Command_Palette_Command, Model),
         "settings pane keeps palette command enabled");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "settings modal block preserves existing error");
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background item click");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "blocked item click keeps settings focus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background path text click");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "blocked text click keeps settings focus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings clicks route through the panel, not the generic text-click path");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after focus Escape");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "settings Escape clears settings focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane reopens after Escape close check");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert (Files.Model.Selected_Item (Model).Name = "Alpha.txt", "settings modal starts with stable selection");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background selection keys");
      Assert
        (Files.Model.Selected_Item (Model).Name = "Alpha.txt",
         "settings pane keeps background selection unchanged");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings text-clicks are handled by the panel, not the generic path");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette can open over settings pane");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before history enablement check");
   end Test_Settings_Pane_Modal_Blocking;

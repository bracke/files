separate (Files_Suite.Commands)
   procedure Test_Settings_Field_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Files.Controller.Replace_Focused_Text (Model, "details");
      Result := Files.Controller.Execute_Command (Files.Commands.Reset_Settings_Command, Model, Settings);
      --  Opening the pane now focuses the first setting, not the preamble action
      --  buttons. The settings caret is not movable -- it always rests at the end
      --  of the focused value -- so a manually set cursor is superseded by that end
      --  position. Focus the icon-theme field (appearance is the third section, its
      --  second field -- a Choice whose displayed value mirrors the draft) to check
      --  this on a real, non-empty setting; the assert catches any layout drift.
      Files.Model.Settings_Set_Active_Section (Model, 3);
      Files.Model.Settings_Move_Focus (Model, 1);
      declare
         Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Draft.Scalars (Files.Settings.Icon_Theme_Setting) := To_Unbounded_String ("files-basic");
         Files.Model.Set_Settings_Draft (Model, Draft);
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Settings_Focused_Value (Model),
         "files-basic",
         "icon-theme field is focused for the settings caret check");
      Files.Model.Set_Text_Cursor_Position (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         Files.Model.Settings_Focused_Value (Model)'Length,
         "settings caret rests at the end of the focused value, ignoring a manual cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_S, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Save_Settings_Command,
         "control+s routes settings save command");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "control+s reports settings save command execution for runtime persistence");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "scalar settings field ignores add-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "scalar settings field ignores remove-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "scalar settings field ignores entry paging");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      declare
         Bad : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Bad.Scalars (Files.Settings.Show_Hidden_Files_Setting) := To_Unbounded_String ("maybe");
         Files.Model.Set_Settings_Draft (Model, Bad);
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "invalid settings field Return reports validation failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.settings.invalid_boolean",
         "invalid settings field Return reports diagnostic key");
      declare
         Good : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Good.Scalars (Files.Settings.Show_Hidden_Files_Setting) := To_Unbounded_String ("true");
         Files.Model.Set_Settings_Draft (Model, Good);
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "valid settings field Return reports validation success");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "valid settings draft field validates on Return");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "controller closes settings pane");
   end Test_Settings_Field_Keys;

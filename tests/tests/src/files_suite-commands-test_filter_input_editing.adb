separate (Files_Suite.Commands)
   procedure Test_Filter_Input_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Focus_Filter_Input (Model);

      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Append_Focused_Text (Model, "be");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter append updates text");
      Result := Files.Controller.Append_Focused_Text (Model, "ta");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "second filter append updates text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter text is updated through controller");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         4,
         "filter append leaves cursor at text end");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "filter input updates visible projection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Name (Model), "Beta.txt", "filter reconciles selection");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter click updates text cursor");
      Files_Suite.Support.Assert_Equal (Files.Model.Text_Cursor_Position (Model), 2, "filter click positions cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "filter Escape clears focus before refocus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "filter shortcut refocuses filter input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         4,
         "filter shortcut refocus places cursor at text end");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter click can reposition after refocus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "same filter cursor click is ignored");
      Result := Files.Controller.Append_Focused_Text (Model, "X");
      Files_Suite.Support.Assert_Equal (Files.Model.Filter_Text (Model), "beXta", "filter insert uses cursor position");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         3,
         "filter insert advances cursor from insertion point");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter Backspace edits text");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.No_Command,
         "filter Backspace does not route delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter Backspace removes character before cursor");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         2,
         "filter Backspace moves cursor backward");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter Delete edits text");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.No_Command,
         "filter Delete does not route delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "bea",
         "filter Delete removes character at cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter insert restores text at cursor");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Beta.txt",
         "text delete preserves selected visible item");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter Home moves text cursor");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         0,
         "filter Home moves cursor to start");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter Home at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter Backspace at start is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter Backspace at start leaves text unchanged");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal (Files.Model.Text_Cursor_Position (Model), 4, "filter End moves cursor to end");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter End at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter Right at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "filter Delete at end is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter Delete at end leaves text unchanged");
      Files.Controller.Replace_Focused_Text (Model, "b");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         1,
         "short filter replacement clamps cursor to end");
      Result := Files.Controller.Append_Focused_Text (Model, "eta");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "filter append after clamp updates text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "filter append after short replacement uses clamped cursor");
   end Test_Filter_Input_Editing;

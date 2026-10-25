separate (Files_Suite.Commands)
   procedure Test_Filter_Word_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Focus_Filter_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "alpha beta-gamma");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         16,
         "long filter replacement places cursor at end");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "Control+Left moves by word");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         11,
         "Control+Left stops before previous word");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "Control+Backspace deletes previous word");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "alpha gamma",
         "Control+Backspace removes previous word and separator");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         6,
         "Control+Backspace leaves cursor at word boundary");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "Control+Delete deletes next word");
      Files_Suite.Support.Assert_Equal (Files.Model.Filter_Text (Model), "alpha ", "Control+Delete removes next word");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "Control+Delete at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "Control+Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "Control+Backspace at start is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.UTF8.Word_Separator_Length ("x", Natural'Last),
         0,
         "word-separator lookup rejects an extreme out-of-range offset without raising");
      declare
         Malformed : constant String :=
           [Character'Val (16#E0#), Character'Val (16#80#),
            Character'Val (16#80#)];
      begin
         Files_Suite.Support.Assert_Equal
           (Files.UTF8.Next_Boundary (Malformed, 0), 1,
            "overlong UTF-8 bytes remain separate cursor and deletion units (next from 0)");
         Files_Suite.Support.Assert_Equal
           (Files.UTF8.Next_Boundary (Malformed, 1), 2,
            "overlong UTF-8 bytes remain separate cursor and deletion units (next from 1)");
         Files_Suite.Support.Assert_Equal
           (Files.UTF8.Previous_Boundary (Malformed, 3), 2,
            "overlong UTF-8 bytes remain separate cursor and deletion units (previous from 3)");
      end;
      Files.Controller.Replace_Focused_Text (Model, "beta");
   end Test_Filter_Word_Editing;

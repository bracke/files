separate (Files_Suite.Commands)
   procedure Test_Filter_Word_Control_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Focus_Filter_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.LF & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         6,
         "Control+Left treats line feed as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "Control+Backspace removes previous word across line feed");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.CR & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         6,
         "Control+Left treats carriage return as word separator");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.VT & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         6,
         "Control+Left treats vertical tab as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "beta",
         "Control+Backspace removes previous word across vertical tab");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.FF & "beta");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         5,
         "filter click positions cursor before form feed");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "alpha",
         "Control+Delete removes next word across form feed");

      declare
         C1_Break : constant Character := Character'Val (133);
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            6,
            "Control+Left treats C1 NEL as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "beta",
            "Control+Backspace removes previous word across C1 NEL");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            5,
            "filter click positions cursor before C1 NEL");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "alpha",
            "Control+Delete removes next word across C1 NEL");
      end;
   end Test_Filter_Word_Control_Separators;

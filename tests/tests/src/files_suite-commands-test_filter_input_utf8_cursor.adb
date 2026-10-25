separate (Files_Suite.Commands)
   procedure Test_Filter_Input_Utf8_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Model.Focus_Filter_Input (Model);
      declare
         Utf8_Text : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Combining_Text : constant String :=
           "e" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "a" & Utf8_Text & "b");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "filter click snaps UTF-8 cursor to character boundary");
         Files.Model.Set_Text_Cursor_Position (Model, 2);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "model cursor setter snaps UTF-8 cursor to character boundary");
         Files.Model.Set_Text_Cursor_Position (Model, 4);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            3,
            "filter Left moves before ASCII after UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "filter Left moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            0,
            "filter Left reaches start before UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "filter Right moves over ASCII before UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            3,
            "filter Right moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "ab",
            "filter Backspace removes whole UTF-8 input");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "filter Backspace lands before removed UTF-8 input");
         Files.Controller.Replace_Focused_Text (Model, "a" & Utf8_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "ab",
            "filter Delete removes whole UTF-8 input");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            1,
            "filter Delete keeps cursor before UTF-8 input");

         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            0,
            "model cursor setter snaps combining mark starts to the base boundary");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "filter Left at combining base is ignored");
         Files.Model.Set_Text_Cursor_Position (Model, Combining_Text'Length + 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            Combining_Text'Length,
            "filter Left moves before ASCII after combining text");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            0,
            "filter Left moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            Combining_Text'Length,
            "filter Right moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "b",
            "filter Backspace removes base and trailing combining marks together");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            0,
            "filter Backspace lands before removed combining sequence");
         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 0);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "b",
            "filter Delete removes base and trailing combining marks together");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            0,
            "filter Delete keeps cursor before removed combining sequence");
         Files.Controller.Replace_Focused_Text (Model, "e");
         Result :=
           Files.Controller.Append_Focused_Text
             (Model, Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#)));
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            Combining_Text,
            "filter append can add a trailing combining mark");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            Combining_Text'Length,
            "filter append leaves cursor after appended trailing combining mark");
      end;
   end Test_Filter_Input_Utf8_Cursor;

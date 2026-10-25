separate (Files_Suite.Commands)
   procedure Test_Filter_Word_Unicode_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Focus_Filter_Input (Model);
      declare
         NBSP : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            7,
            "Control+Left treats UTF-8 NBSP as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "beta",
            "Control+Backspace removes previous word across UTF-8 NBSP");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            5,
            "filter click positions cursor before UTF-8 NBSP");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "alpha",
            "Control+Delete removes next word across UTF-8 NBSP");
      end;
      --  Words of multibyte letters: offsets are bytes, a word is whole letters.
      declare
         function U (Code : Natural) return String is
           (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (Code)));
         Cafe : constant String := "caf" & U (16#E9#);                    --  5 bytes
         Uber : constant String := U (16#FC#) & "ber";                    --  5 bytes
         Nihongo : constant String := U (16#65E5#) & U (16#672C#) & U (16#8A9E#);  --  9 bytes
         Tesuto  : constant String := U (16#30C6#) & U (16#30B9#) & U (16#30C8#);  --  9 bytes
      begin
         Files.Controller.Replace_Focused_Text (Model, Cafe & " " & Uber);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            6,
            "Control+Left stops before a word of multibyte letters");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            Uber,
            "Control+Backspace removes a whole multibyte word");

         Files.Controller.Replace_Focused_Text (Model, Cafe & " " & Uber);
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 0);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right, Ctrl);
         Assert (Files.Model.Text_Cursor_Position (Model) in 5 | 6, "Control+Right ends after the whole first word");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            Cafe,
            "Control+Delete removes the next multibyte word");

         Files.Controller.Replace_Focused_Text (Model, Nihongo & " " & Tesuto);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            10,
            "Control+Left stops before a word of CJK letters");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            Tesuto,
            "Control+Backspace removes a whole CJK word");
      end;
      declare
         Line_Separator : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & Line_Separator & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Text_Cursor_Position (Model),
            8,
            "Control+Left treats UTF-8 line separator as word separator");
      end;
   end Test_Filter_Word_Unicode_Separators;

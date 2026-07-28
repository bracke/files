separate (Files.Controller)
   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result
   is
      Old_Text : constant String := Focused_Text (Model);
      Cursor   : constant Natural := Files.Model.Text_Cursor_Position (Model);
      New_Text : Unbounded_String;
   begin
      if Text = "" then
         return Make_Result (Controller_Ignored);
      end if;

      --  With no text field focused the file grid owns the keyboard: bare
      --  printable characters drive type-to-select instead of editing a field.
      --  Modifier combinations (Ctrl/Alt shortcuts) never reach here because the
      --  GLFW character callback only emits printable text, so shortcuts stay on
      --  the command path.
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         declare
            Matched : Boolean;
         begin
            Files.Model.Type_Ahead_Input (Model, Text, Matched);
            return Make_Result (if Matched then Controller_Selection_Moved else Controller_Ignored);
         end;
      end if;

      --  Rename edits broadcast to every synchronized caret rather than the
      --  single focused buffer.
      if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Insert_At_Carets (Model, Text)
              then Controller_Text_Updated
              else Controller_Ignored);
      end if;

      if Cursor = 0 then
         New_Text := To_Unbounded_String (Text & Old_Text);
      elsif Cursor >= Old_Text'Length then
         New_Text := To_Unbounded_String (Old_Text & Text);
      else
         New_Text :=
           To_Unbounded_String
             (Old_Text (Old_Text'First .. Old_Text'First + Cursor - 1)
              & Text
              & Old_Text (Old_Text'First + Cursor .. Old_Text'Last));
      end if;

      Replace_Focused_Text (Model, To_String (New_Text));
      Files.Model.Set_Text_Cursor_Position (Model, Cursor + Text'Length);
      return Make_Result (Controller_Text_Updated);
   end Append_Focused_Text;

separate (Files.Controller)
   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result
   is
      Old_Text : constant String := Files.Model.Focused_Text (Model);
      Cursor   : constant Natural := Files.Model.Text_Cursor_Position (Model);
   begin
      --  Printable characters arrive through GLFW's character callback rather
      --  than the normal key translator. The overlay on top contains them
      --  unless it is a text overlay with its own field focused, even when a
      --  field underneath still holds model focus.
      if Text = "" or else Files.Model.Character_Input_Is_Contained (Model) then
         return Make_Result (Controller_Ignored);
      end if;

      --  With no text field focused the file grid owns the keyboard: bare
      --  printable characters drive type-to-select instead of editing a field.
      --  Modifier combinations (Ctrl/Alt shortcuts) never reach here because the
      --  GLFW character callback only emits printable text, so shortcuts stay on
      --  the command path.
      if Files.Model.Focus (Model) = Files.UI_Types.Focus_None then
         --  The selected item's details follow on the window's next poll
         --  (Window_Polls.Poll_Selected_Item_Extra), as for every selection.
         declare
            Matched : Boolean;
         begin
            Files.Model.Selection.Type_Ahead_Input (Model, Text, Matched);
            return Make_Result (if Matched then Controller_Selection_Moved else Controller_Ignored);
         end;
      end if;

      --  Rename edits broadcast to every synchronized caret rather than the
      --  single focused buffer.
      if Files.Model.Focus (Model) = Files.UI_Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename.Insert_At_Carets (Model, Text)
              then Controller_Text_Updated
              else Controller_Ignored);
      end if;

      Replace_Focused_Text (Model, Guikit.Utf8.Editing.Insert_At (Old_Text, Cursor, Text));
      Files.Model.Set_Text_Cursor_Position (Model, Cursor + Text'Length);
      return Make_Result (Controller_Text_Updated);
   end Append_Focused_Text;

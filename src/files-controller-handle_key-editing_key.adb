separate (Files.Controller.Handle_Key)
procedure Editing_Key (Handled : out Boolean; Result : out Controller_Result) is
   --  The caret moves of a focused text field.
   type Caret_Move is (Word_Left, Word_Right, Char_Left, Char_Right, To_Home, To_End);

   --  Move the focused field's caret: every caret of a multi-rename at once,
   --  otherwise the field's single caret. Text_Updated when a caret moved,
   --  Ignored when it was already there.
   function Move_Caret (Move : Caret_Move) return Controller_Result is
      Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
   begin
      if Files.Model.Focus (Model) = Files.UI_Types.Focus_Rename_Input then
         return
           Make_Result
             (if (case Move is
                    when Word_Left  =>
                      Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Left, By_Word => True),
                    when Word_Right =>
                      Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Right, By_Word => True),
                    when Char_Left  => Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Left),
                    when Char_Right => Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Right),
                    when To_Home    => Files.Model.Rename.Set_All_Carets_Home (Model),
                    when To_End     => Files.Model.Rename.Set_All_Carets_End (Model))
              then Controller_Text_Updated
              else Controller_Ignored);
      end if;

      case Move is
         when Word_Left =>
            Files.Model.Set_Text_Cursor_Position
              (Model,
               Guikit.Bidi.Caret_Step
                 (Files.Model.Focused_Text (Model), Old_Position, Rightward => False, By_Word => True));
         when Word_Right =>
            Files.Model.Set_Text_Cursor_Position
              (Model,
               Guikit.Bidi.Caret_Step
                 (Files.Model.Focused_Text (Model), Old_Position, Rightward => True, By_Word => True));
         when Char_Left =>
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left);
         when Char_Right =>
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Right);
         when To_Home =>
            Files.Model.Set_Text_Cursor_Position (Model, 0);
         when To_End =>
            Files.Model.Set_Text_Cursor_Position (Model, Files.Model.Focused_Text (Model)'Length);
      end case;
      return Changed_Result (Old_Position, Files.Model.Text_Cursor_Position (Model), Controller_Text_Updated);
   end Move_Caret;
   Plain         : constant Boolean := Modifiers = Guikit.Input.No_Modifiers;
   --  A text field has the keyboard; the palette's query field has no caret
   --  of its own to move (its arrows move the result highlight).
   Field_Focused : constant Boolean := Files.Model.Focus (Model) /= Files.UI_Types.Focus_None;
   Caret_Field   : constant Boolean :=
     Field_Focused and then Files.Model.Focus (Model) /= Files.UI_Types.Focus_Command_Palette;
begin
   Handled := True;
   case Key is
      when Guikit.Input.Key_Return =>
         if Plain then
            Result := Commit_Focused_Text (Model, Settings, Modifiers);
            return;
         elsif not Field_Focused then
            Result := Execute_Non_Settings_Command
              (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
            return;
         end if;
      when Guikit.Input.Key_Backspace | Guikit.Input.Key_Delete =>
         if Field_Focused and then (Plain or else Control_Only) then
            Result := Delete_Focused_Text
              (Model,
               (if Key = Guikit.Input.Key_Backspace then Delete_Backward else Delete_Forward),
               By_Word => Control_Only);
            return;
         end if;
      when Guikit.Input.Key_Left | Guikit.Input.Key_Right =>
         if Field_Focused and then Control_Only then
            Result := Move_Caret (if Key = Guikit.Input.Key_Left then Word_Left else Word_Right);
            return;
         elsif Caret_Field and then Plain then
            Result := Move_Caret (if Key = Guikit.Input.Key_Left then Char_Left else Char_Right);
            return;
         end if;
      when Guikit.Input.Key_Home | Guikit.Input.Key_End =>
         if Caret_Field and then Plain then
            Result := Move_Caret (if Key = Guikit.Input.Key_Home then To_Home else To_End);
            return;
         end if;
      when others =>
         null;
   end case;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Editing_Key;

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
      if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if (case Move is
                    when Word_Left  =>
                      Files.Model.Rename.Rename_Move_All_Carets (Model, Guikit.Input.Move_Left, By_Word => True),
                    when Word_Right =>
                      Files.Model.Rename.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right, By_Word => True),
                    when Char_Left  => Files.Model.Rename.Rename_Move_All_Carets (Model, Guikit.Input.Move_Left),
                    when Char_Right => Files.Model.Rename.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right),
                    when To_Home    => Files.Model.Rename.Rename_Set_All_Carets_Home (Model),
                    when To_End     => Files.Model.Rename.Rename_Set_All_Carets_End (Model))
              then Controller_Text_Updated
              else Controller_Ignored);
      end if;

      case Move is
         when Word_Left =>
            Files.Model.Set_Text_Cursor_Position
              (Model, Guikit.Utf8.Editing.Previous_Word_Boundary (Focused_Text (Model), Old_Position));
         when Word_Right =>
            Files.Model.Set_Text_Cursor_Position
              (Model, Guikit.Utf8.Editing.Next_Word_Boundary (Focused_Text (Model), Old_Position));
         when Char_Left =>
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left);
         when Char_Right =>
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Right);
         when To_Home =>
            Files.Model.Set_Text_Cursor_Position (Model, 0);
         when To_End =>
            Files.Model.Set_Text_Cursor_Position (Model, Focused_Text (Model)'Length);
      end case;
      return Changed_Result (Old_Position, Files.Model.Text_Cursor_Position (Model), Controller_Text_Updated);
   end Move_Caret;
begin
   Handled := True;
   if Key = Guikit.Input.Key_Return then
      if Modifiers = Guikit.Input.No_Modifiers then
         Result := Commit_Focused_Text (Model, Settings, Modifiers);
         return;
      elsif Files.Model.Focus (Model) = Files.Types.Focus_None then
         Result := Execute_Non_Settings_Command
           (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
         return;
      end if;
   elsif Key = Guikit.Input.Key_Backspace
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text (Model, Delete_Backward, By_Word => True);
      return;
   elsif Key = Guikit.Input.Key_Delete
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text (Model, Delete_Forward, By_Word => True);
      return;
   elsif Key = Guikit.Input.Key_Left
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Move_Caret (Word_Left);
      return;
   elsif Key = Guikit.Input.Key_Right
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Move_Caret (Word_Right);
      return;
   elsif Key = Guikit.Input.Key_Backspace
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text (Model, Delete_Backward, By_Word => False);
      return;
   elsif Key = Guikit.Input.Key_Delete
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text (Model, Delete_Forward, By_Word => False);
      return;
   elsif Key = Guikit.Input.Key_Left
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      Result := Move_Caret (Char_Left);
      return;
   elsif Key = Guikit.Input.Key_Right
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      Result := Move_Caret (Char_Right);
      return;
   elsif Key = Guikit.Input.Key_Home
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane.Is_Open (Model)
   then
      --  Plain Home in the file grid selects the first visible item. This has
      --  no modifier, so it never collides with Alt+Home = navigate home.
      Result := First_Selection_Result (Model);
      return;
   elsif Key = Guikit.Input.Key_End
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane.Is_Open (Model)
   then
      --  Plain End in the file grid selects the last visible item.
      Result := Last_Selection_Result (Model);
      return;
   elsif Key = Guikit.Input.Key_Home
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      Result := Move_Caret (To_Home);
      return;
   elsif Key = Guikit.Input.Key_End
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      Result := Move_Caret (To_End);
      return;
   elsif Key = Guikit.Input.Key_Page_Up
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane.Is_Open (Model)
   then
      --  With the info pane open Page Up scrolls it; over the file grid it
      --  pages the selection up by a page (like the arrow keys move it).
      if Files.Model.Info_Pane_Is_Open (Model) then
         Result := Scroll_Info_Result (Model, -10);
         return;
      else
         Result := Page_Selection_Result (Model, Down => False);
         return;
      end if;
   elsif Key = Guikit.Input.Key_Page_Down
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane.Is_Open (Model)
   then
      if Files.Model.Info_Pane_Is_Open (Model) then
         Result := Scroll_Info_Result (Model, 10);
         return;
      else
         Result := Page_Selection_Result (Model, Down => True);
         return;
      end if;
   elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
      if Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Rename.Rename_Is_Active (Model)
        and then not Files.Model.Temporary_Item_Is_Active (Model)
      then
         if Files.Model.Settings_Pane.Is_Open (Model) then
            Files.Model.Settings_Pane.Toggle (Model);
            Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
            return;
         else
            Result := Make_Result (Controller_Ignored, Files.Commands.Close_Command_Palette_Command);
            return;
         end if;
      else
         Files.Model.Cancel_Focus_Or_Edit (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Editing_Key;

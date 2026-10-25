separate (Files.Controller.Handle_Key)
procedure Editing_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Key = Guikit.Input.Key_Return then
      if Modifiers = Guikit.Input.No_Modifiers then
         Result := Commit_Focused_Text (Model, Settings, Modifiers);
         return;
      elsif Files.Model.Focus (Model) = Files.Types.Focus_None then
         Result := Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
         return;
      end if;
   elsif Key = Guikit.Input.Key_Backspace
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text_Word_Backward (Model);
      return;
   elsif Key = Guikit.Input.Key_Delete
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text_Word_Forward (Model);
      return;
   elsif Key = Guikit.Input.Key_Left
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Left)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Set_Text_Cursor_Position
           (Model, Previous_Word_Boundary (Focused_Text (Model), Old_Position));
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_Right
     and then Control_Only
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Right)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Set_Text_Cursor_Position
           (Model, Next_Word_Boundary (Focused_Text (Model), Old_Position));
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_Backspace
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text_Backward (Model);
      return;
   elsif Key = Guikit.Input.Key_Delete
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
   then
      Result := Delete_Focused_Text_Forward (Model);
      return;
   elsif Key = Guikit.Input.Key_Left
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Left)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left);
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_Right
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Right);
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_Home
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane_Is_Open (Model)
   then
      --  Plain Home in the file grid selects the first visible item. This has
      --  no modifier, so it never collides with Alt+Home = navigate home.
      Result := First_Selection_Result (Model);
      return;
   elsif Key = Guikit.Input.Key_End
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane_Is_Open (Model)
   then
      --  Plain End in the file grid selects the last visible item.
      Result := Last_Selection_Result (Model);
      return;
   elsif Key = Guikit.Input.Key_Home
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Set_All_Carets_Home (Model)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Set_Text_Cursor_Position (Model, 0);
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_End
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) /= Files.Types.Focus_None
     and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
   then
      declare
         Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
      begin
         if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
            Result :=
              Make_Result
                (if Files.Model.Rename_Set_All_Carets_End (Model)
                 then Controller_Text_Updated
                 else Controller_Ignored);
            return;
         end if;
         Files.Model.Set_Text_Cursor_Position (Model, Focused_Text (Model)'Length);
         Result :=
           Make_Result
             (if Files.Model.Text_Cursor_Position (Model) = Old_Position
              then Controller_Ignored
              else Controller_Text_Updated);
         return;
      end;
   elsif Key = Guikit.Input.Key_Page_Up
     and then Modifiers = Guikit.Input.No_Modifiers
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
     and then not Files.Model.Settings_Pane_Is_Open (Model)
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
     and then not Files.Model.Settings_Pane_Is_Open (Model)
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
        and then not Files.Model.Rename_Is_Active (Model)
        and then not Files.Model.Temporary_Item_Is_Active (Model)
      then
         if Files.Model.Settings_Pane_Is_Open (Model) then
            Files.Model.Toggle_Settings_Pane (Model);
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

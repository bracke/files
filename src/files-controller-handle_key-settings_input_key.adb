separate (Files.Controller.Handle_Key)
procedure Settings_Input_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input then
      if Files.Model.Settings_Is_Capturing (Model) then
         --  A Shortcut row is armed: every key is a chord to capture, not a
         --  navigation or shortcut, until the capture ends.
         Result := Capture_Settings_Shortcut (Model, Key, Modifiers);
         return;
      elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Toggle_Settings_Pane (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Settings_Move_Focus (Model, -1);
         Result := Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         return;
      elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Settings_Move_Focus (Model, 1);
         Result := Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         return;
      elsif (Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Right)
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         --  Left/Right cycle the focused toggle/choice or step a number (a
         --  no-op on text fields); the emitted change is applied to the draft.
         Files.Model.Settings_Cycle_Choice (Model, Forward => Key = Guikit.Input.Key_Right);
         Result := Applied_Settings_Change (Model);
         return;
      elsif Key = Guikit.Input.Key_Tab
        and then not Modifiers (Guikit.Input.Control_Key)
        and then not Modifiers (Guikit.Input.Alt_Key)
        and then not Modifiers (Guikit.Input.Meta_Key)
      then
         --  Tab / Shift+Tab walk the fields like Down / Up, as in any dialog.
         Files.Model.Settings_Move_Focus (Model, (if Modifiers (Guikit.Input.Shift_Key) then -1 else 1));
         Result := Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         return;
      elsif Key = Guikit.Input.Key_Space
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Settings_Focused_Kind (Model) in
          Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice
      then
         --  Space flips a focused toggle or advances a choice; in a text
         --  field it stays a typed space.
         Files.Model.Settings_Cycle_Choice (Model, Forward => True);
         Result := Applied_Settings_Change (Model);
         return;
      elsif Key = Guikit.Input.Key_Tab
        and then Modifiers (Guikit.Input.Control_Key)
        and then not Modifiers (Guikit.Input.Alt_Key)
        and then not Modifiers (Guikit.Input.Meta_Key)
      then
         --  Ctrl+Tab / Ctrl+Shift+Tab switch between the section tabs -- the
         --  keyboard equivalent of clicking the tab switcher.
         Cycle_Settings_Section (Model, Forward => not Modifiers (Guikit.Input.Shift_Key));
         Result := Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         return;
      elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
         --  Enter on a focused Shortcut row arms press-to-capture (the
         --  keyboard equivalent of clicking it); otherwise fall through to the
         --  general Return handling below.
         Files.Model.Settings_Begin_Capture (Model);
         if Files.Model.Settings_Is_Capturing (Model) then
            Result := Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
            return;
         end if;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Settings_Input_Key;

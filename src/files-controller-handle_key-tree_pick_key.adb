separate (Files.Controller.Handle_Key)
--  The destination pick on top owns the keyboard: the arrows move the
--  picked folder, Enter confirms it as the picker's Choose button does, and
--  every other key is consumed. The tree shown as an ordinary side panel
--  leaves grid navigation alone (Tree_Keyboard_Key).
procedure Tree_Pick_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Up | Guikit.Input.Key_Down | Guikit.Input.Key_Left | Guikit.Input.Key_Right =>
         Result := Move_Tree_Highlight (Pick => True);
      when Guikit.Input.Key_Return =>
         Result := Confirm_Tree_Pick (Model, Settings);
      when others =>
         null;
   end case;
end Tree_Pick_Key;

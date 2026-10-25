separate (Files.Controller.Handle_Key)
--  Only the modal destination-pick tree owns the keyboard; the tree shown
--  as an ordinary side panel leaves grid navigation alone. Escape cancels
--  the pick and closes the panel if the Copy/Move-To command opened it.
procedure Tree_Pick_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Tree_Pick_Is_Active (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.End_Tree_Pick (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif Key in Guikit.Input.Key_Up | Guikit.Input.Key_Down
                 | Guikit.Input.Key_Left | Guikit.Input.Key_Right
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         Result := Move_Tree_Highlight (Pick => True);
         return;
      else
         --  Enter confirms the pick on the Interaction seam (running the copy or
         --  move needs the settings path); every other key is consumed.
         Result := Make_Result (Controller_Ignored);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Tree_Pick_Key;

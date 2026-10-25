separate (Files.Controller.Handle_Key)
--  The label picker owns the keyboard while open: Escape closes it, the
--  arrows move its highlight, Enter applies the highlighted swatch (on the
--  Interaction seam), and every other key is consumed so it does not leak
--  through to move the selection on the grid behind.
procedure Label_Picker_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Label_Picker_Is_Open (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Close_Label_Picker (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif (Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Up)
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         Files.Model.Move_Label_Picker_Highlight (Model, -1);
         Result := Make_Result (Controller_Selection_Moved);
         return;
      elsif (Key = Guikit.Input.Key_Right or else Key = Guikit.Input.Key_Down)
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         Files.Model.Move_Label_Picker_Highlight (Model, 1);
         Result := Make_Result (Controller_Selection_Moved);
         return;
      else
         --  Enter is applied on the Interaction seam (choosing a label writes
         --  settings, which the read-only controller cannot); every other key
         --  is consumed so the grid behind the picker stays put.
         Result := Make_Result (Controller_Ignored);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Label_Picker_Key;

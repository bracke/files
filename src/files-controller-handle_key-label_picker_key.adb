with Files.Model.Label_Picker;
separate (Files.Controller.Handle_Key)
--  The label picker on top owns the keyboard: the arrows move its
--  highlight, Enter asks for the highlighted swatch to be applied (as a
--  click on it is, by the interaction layer, which holds the settings
--  path), and every other key is consumed so it does not leak through to
--  move the selection on the grid behind.
procedure Label_Picker_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Left | Guikit.Input.Key_Up =>
         Files.Model.Label_Picker.Move_Highlight (Model, -1);
         Result := Make_Result (Controller_Selection_Moved);
      when Guikit.Input.Key_Right | Guikit.Input.Key_Down =>
         Files.Model.Label_Picker.Move_Highlight (Model, 1);
         Result := Make_Result (Controller_Selection_Moved);
      when Guikit.Input.Key_Return =>
         Result :=
           (Make_Result (Controller_Activation_Requested) with delta
              Activation => Choose_Label,
              Label      => Files.Model.Label_Picker.Highlight_Color (Model));
      when others =>
         null;
   end case;
end Label_Picker_Key;

separate (Files.Controller.Handle_Key)
procedure Palette_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Command_Palette_Is_Open (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Close_Command_Palette (Model);
         Result := Make_Result (Controller_Palette_Updated, Files.Commands.Close_Command_Palette_Command);
         return;
      elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Commit_Focused_Text (Model, Settings, Modifiers);
         return;
      elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Move_Selection (Model, -1);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Move_Selection (Model, 1);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Move_Selection (Model, -1);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Move_Selection (Model, 1);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Select_First (Model);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Select_Last (Model);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Page_Up and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Page (Model, Down => False);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      elsif Key = Guikit.Input.Key_Page_Down and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Palette_Page (Model, Down => True);
         Result := Make_Result (Controller_Palette_Updated);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Palette_Key;

separate (Files.Controller.Handle_Key)
procedure Sort_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Sort_Menu_Is_Open (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Close_Sort_Menu (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Move_Sort_Menu_Highlight (Model, -1);
         Result := Make_Result (Controller_Selection_Moved);
         return;
      elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Move_Sort_Menu_Highlight (Model, 1);
         Result := Make_Result (Controller_Selection_Moved);
         return;
      elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
         declare
            Command : constant Files.Commands.Command_Id :=
              Files.Commands.Sort_Command (Files.Model.Sort_Menu_Highlight_Field (Model));
         begin
            Files.Model.Close_Sort_Menu (Model);
            Result := Execute_Command (Command, Model, Settings, Modifiers);
            return;
         end;
      else
         Result := Make_Result (Controller_Ignored);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Sort_Menu_Key;

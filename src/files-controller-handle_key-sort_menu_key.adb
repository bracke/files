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
            use type Files.Model.Sort_Field;
            Field   : constant Files.Model.Sort_Field :=
              Files.Model.Sort_Menu_Highlight_Field (Model);
            Command : constant Files.Commands.Command_Id :=
              (case Field is
                  when Files.Model.Sort_Name    => Files.Commands.Sort_By_Name_Command,
                  when Files.Model.Sort_Size    => Files.Commands.Sort_By_Size_Command,
                  when Files.Model.Sort_Type    => Files.Commands.Sort_By_Type_Command,
                  when Files.Model.Sort_Created => Files.Commands.Sort_By_Created_Command,
                  when Files.Model.Sort_Changed => Files.Commands.Sort_By_Changed_Command);
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

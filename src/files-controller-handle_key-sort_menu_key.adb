with Files.Model.Sort_Menu;
separate (Files.Controller.Handle_Key)
--  The sort menu on top owns the keyboard: Up and Down move its highlight,
--  Enter sorts by the highlighted field, and every other key is consumed.
procedure Sort_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Up =>
         Files.Model.Sort_Menu.Move_Highlight (Model, -1);
         Result := Make_Result (Controller_Selection_Moved);
      when Guikit.Input.Key_Down =>
         Files.Model.Sort_Menu.Move_Highlight (Model, 1);
         Result := Make_Result (Controller_Selection_Moved);
      when Guikit.Input.Key_Return =>
         declare
            Command : constant Files.Commands.Command_Id :=
              Files.Commands.Sort_Command (Files.Model.Sort_Menu.Highlight_Field (Model));
         begin
            Files.Model.Sort_Menu.Close (Model);
            Result := Execute_Non_Settings_Command (Command, Model, Settings, Modifiers);
         end;
      when others =>
         null;
   end case;
end Sort_Menu_Key;

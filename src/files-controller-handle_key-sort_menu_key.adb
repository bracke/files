with Files.UI_Types;
with Files.Model.Sort_Menu;
separate (Files.Controller.Handle_Key)
--  The sort menu on top owns the keyboard: Up and Down move its highlight,
--  Home and End jump to its first and last row, Enter sorts by the
--  highlighted field, and every other key is consumed.
procedure Sort_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
   Old : constant Natural := Files.Model.Sort_Menu.Highlight (Model);

   --  Move the highlight by Step rows (clamped at the ends) and report
   --  whether it moved.
   function Moved (Step : Integer) return Controller_Result is
   begin
      Files.Model.Sort_Menu.Move_Highlight (Model, Step);
      return Changed_Result (Old, Files.Model.Sort_Menu.Highlight (Model), Controller_Selection_Moved);
   end Moved;
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Up =>
         Result := Moved (-1);
      when Guikit.Input.Key_Down =>
         Result := Moved (1);
      when Guikit.Input.Key_Home =>
         Result := Moved (-Files.UI_Types.Sort_Menu_Rows);
      when Guikit.Input.Key_End =>
         Result := Moved (Files.UI_Types.Sort_Menu_Rows);
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

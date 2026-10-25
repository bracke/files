separate (Files.Controller.Handle_Key)
--  The folder tree side panel, when Tab gave it the keyboard: arrows move
--  its highlight, Enter opens the highlighted folder in the main view and
--  Escape hands the keyboard back to the grid. Other keys fall through, so
--  the window's shortcuts still work.
procedure Tree_Keyboard_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Tree_Has_Keyboard (Model) and then Modifiers = Guikit.Input.No_Modifiers then
      if Key in Guikit.Input.Key_Up | Guikit.Input.Key_Down
              | Guikit.Input.Key_Left | Guikit.Input.Key_Right
      then
         Result := Move_Tree_Highlight (Pick => False);
         return;
      elsif Key = Guikit.Input.Key_Escape then
         Files.Model.Take_Tree_Keyboard (Model);
         Result := Make_Result (Controller_Text_Updated);
         return;
      elsif Key = Guikit.Input.Key_Return then
         declare
            Cursor : constant String := Files.Model.Tree_Cursor (Model);
         begin
            for Row of Files.Model.Tree_Visible_Rows (Model) loop
               if To_String (Row.Path) = Cursor then
                  Result := Handle_Tree_Click (Model, Settings, Row.Node_Index, Toggle => False);
                  return;
               end if;
            end loop;
            Result := Make_Result (Controller_Ignored);
            return;
         end;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Tree_Keyboard_Key;

separate (Files.Controller.Handle_Key)
--  The folder tree side panel, when Tab gave it the keyboard: arrows move
--  its highlight, Enter opens the highlighted folder in the main view and
--  Escape hands the keyboard back to the grid. Other keys fall through, so
--  the window's shortcuts still work.
procedure Tree_Keyboard_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Tree_Panel.Has_Keyboard (Model) and then Modifiers = Guikit.Input.No_Modifiers then
      if Key in Guikit.Input.Key_Up | Guikit.Input.Key_Down
              | Guikit.Input.Key_Left | Guikit.Input.Key_Right
      then
         Result := Move_Tree_Highlight (Pick => False);
         return;
      elsif Action.Kind = Files.Events.Command_Input_Action
        and then Files.Commands."=" (Action.Command, Files.Commands.Close_Overlay_Command)
      then
         --  The close key (Escape unless rebound) hands the keyboard back.
         Files.Model.Tree_Panel.Take_Keyboard (Model);
         Result := Make_Result (Controller_Text_Updated);
         return;
      elsif Key = Guikit.Input.Key_Return then
         declare
            Cursor : constant String := Files.Model.Tree_Panel.Cursor (Model);
         begin
            for Row of Files.Model.Tree_Panel.Visible_Rows (Model) loop
               if To_String (Row.Path) = Cursor then
                  Result := Activate_Tree_Node (Model, Settings, Row.Node_Index);
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

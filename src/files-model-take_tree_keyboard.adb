separate (Files.Model)
procedure Take_Tree_Keyboard
  (Model : in out Window_Model) is
begin
   if Model.Tree_Keyboard_Value then
      Touch (Model);
      Model.Tree_Keyboard_Value := False;
   end if;
end Take_Tree_Keyboard;

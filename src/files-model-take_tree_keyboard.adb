separate (Files.Model)
procedure Take_Tree_Keyboard
  (Model : in out Window_Model) is
begin
   if Model.Tree_Keyboard_Value then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Keyboard_Value := False;
   end if;
end Take_Tree_Keyboard;

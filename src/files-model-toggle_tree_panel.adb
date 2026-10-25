separate (Files.Model)
procedure Toggle_Tree_Panel
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Tree_Panel_Open := not Model.Tree_Panel_Open;
   if not Model.Tree_Panel_Open then
      Model.Tree_Panel_Scroll := 0;
      Model.Tree_Keyboard_Value := False;
   end if;
end Toggle_Tree_Panel;

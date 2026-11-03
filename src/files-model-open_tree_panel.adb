separate (Files.Model)
procedure Open_Tree_Panel
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Tree_Panel_Open := True;
end Open_Tree_Panel;

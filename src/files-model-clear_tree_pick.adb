separate (Files.Model)
procedure Clear_Tree_Pick
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Tree_Pick := (others => <>);
end Clear_Tree_Pick;

separate (Files.Model)
procedure Tree_Set_Children
  (Model    : in out Window_Model;
   Index    : Positive;
   Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Files.Folder_Tree.Set_Children (Model.Folder_Tree_Value, Index, Children);
   Clamp_Tree_Panel_Scroll (Model);
   Reconcile_Tree_Pick_Target (Model, Index);
end Tree_Set_Children;

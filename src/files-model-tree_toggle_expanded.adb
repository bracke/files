separate (Files.Model)
procedure Tree_Toggle_Expanded
  (Model : in out Window_Model;
   Index : Positive) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Files.Folder_Tree.Toggle_Expanded (Model.Folder_Tree_Value, Index);
   Clamp_Tree_Panel_Scroll (Model);
   Reconcile_Tree_Pick_Target (Model, Index);
end Tree_Toggle_Expanded;

separate (Files.Model)
function Paste_Execution_Created_Tree_Revisions
  (Model : Window_Model) return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Exec.Tree_Revisions;
end Paste_Execution_Created_Tree_Revisions;

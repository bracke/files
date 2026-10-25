separate (Files.Model)
function Paste_Execution_Undo_To
  (Model : Window_Model)
   return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Exec.Undo_To;
end Paste_Execution_Undo_To;

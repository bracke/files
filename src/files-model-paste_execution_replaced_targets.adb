separate (Files.Model)
function Paste_Execution_Replaced_Targets
  (Model : Window_Model) return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Exec.Replaced_Targets;
end Paste_Execution_Replaced_Targets;

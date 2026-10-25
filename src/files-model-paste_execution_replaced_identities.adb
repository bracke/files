separate (Files.Model)
function Paste_Execution_Replaced_Identities
  (Model : Window_Model) return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Exec.Replaced_Identities;
end Paste_Execution_Replaced_Identities;

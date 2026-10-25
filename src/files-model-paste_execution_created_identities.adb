separate (Files.Model)
function Paste_Execution_Created_Identities
  (Model : Window_Model)
   return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Exec.Identities;
end Paste_Execution_Created_Identities;

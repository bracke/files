separate (Files.Model)
function Paste_Execution_Verified_Created_Count
  (Model : Window_Model) return Natural is
begin
   return Model.Paste_Exec.Verified_Created_Count;
end Paste_Execution_Verified_Created_Count;

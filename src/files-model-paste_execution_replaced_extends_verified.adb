separate (Files.Model)
function Paste_Execution_Replaced_Extends_Verified
  (Model : Window_Model) return Boolean is
begin
   return Model.Paste_Exec.Verified_Replaced_Count =
     Natural (Model.Paste_Exec.Replaced_Trash.Length);
end Paste_Execution_Replaced_Extends_Verified;

separate (Files.Model)
function Paste_Execution_Write_Extends_Verified
  (Model : Window_Model) return Boolean is
begin
   return Model.Paste_Exec.Verified_Created_Count =
     Natural (Model.Paste_Exec.Undo_From.Length);
end Paste_Execution_Write_Extends_Verified;

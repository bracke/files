separate (Files.Model)
function Paste_Execution_Cancelled
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Paste_Exec.Cancelled;
end Paste_Execution_Cancelled;

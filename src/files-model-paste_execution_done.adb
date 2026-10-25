separate (Files.Model)
function Paste_Execution_Done
  (Model : Window_Model)
   return Natural is
begin
   return Model.Paste_Exec.Done;
end Paste_Execution_Done;

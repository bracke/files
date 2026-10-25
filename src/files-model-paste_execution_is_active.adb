separate (Files.Model)
function Paste_Execution_Is_Active
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Paste_Exec.Active;
end Paste_Execution_Is_Active;

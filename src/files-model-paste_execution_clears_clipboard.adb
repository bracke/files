separate (Files.Model)
function Paste_Execution_Clears_Clipboard
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Paste_Exec.Clears_Clipboard;
end Paste_Execution_Clears_Clipboard;

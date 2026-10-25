separate (Files.Model)
function Paste_Execution_Cursor
  (Model : Window_Model)
   return Natural is
begin
   return Model.Paste_Exec.Cursor;
end Paste_Execution_Cursor;

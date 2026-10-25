separate (Files.Model)
function Paste_Execution_Current_Name
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Paste_Exec.Current);
end Paste_Execution_Current_Name;

separate (Files.Model)
function Paste_Execution_First_Dest
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Paste_Exec.First_Dest);
end Paste_Execution_First_Dest;

separate (Files.Model)
function Ownership_Input_Text
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Ownership_Input.Text);
end Ownership_Input_Text;

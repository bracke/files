separate (Files.Model)
function Path_Input_Text
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Path_Input.Text);
end Path_Input_Text;

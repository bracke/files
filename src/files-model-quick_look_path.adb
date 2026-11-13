separate (Files.Model)
function Quick_Look_Path
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Quick_Look.Path);
end Quick_Look_Path;

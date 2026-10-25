separate (Files.Model)
function Open_With_Applications
  (Model : Window_Model)
   return Files.Desktop_Applications.Application_Vectors.Vector is
begin
   return Model.Open_With_Applications_Value;
end Open_With_Applications;

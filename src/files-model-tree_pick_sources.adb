separate (Files.Model)
function Tree_Pick_Sources
  (Model : Window_Model)
   return Files.Types.String_Vectors.Vector is
begin
   return Model.Tree_Pick.Sources;
end Tree_Pick_Sources;

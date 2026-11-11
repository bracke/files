separate (Files.Model)
function Temporary_Item_Name
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Temporary.Name);
end Temporary_Item_Name;

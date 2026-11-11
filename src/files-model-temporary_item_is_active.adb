separate (Files.Model)
function Temporary_Item_Is_Active
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Temporary.Active;
end Temporary_Item_Is_Active;

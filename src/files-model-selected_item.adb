separate (Files.Model)
function Selected_Item
  (Model : Window_Model)
   return Files.Items.Directory_Item
is
   Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
begin
   if Selected_Count (Model) = 0 then
      return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
   elsif Item_Index = Temporary_Item_Index then
      return Support.Temporary_Item (Model);
   end if;

   return Model.Items.Element (Positive (Item_Index));
end Selected_Item;

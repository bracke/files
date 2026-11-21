separate (Files.Model)
function Visible_Item
  (Model         : Window_Model;
   Visible_Index : Positive)
   return Files.Items.Directory_Item
is
   Item_Index : constant Natural := Support.Selection_Index_Of_Visible (Model, Visible_Index);
begin
   if Item_Index = Temporary_Item_Index then
      return Support.Temporary_Item (Model);
   elsif Item_Index /= 0 then
      return Model.Items.Element (Positive (Item_Index));
   else
      return Files.Item_Lists.Make_Item ("", "", Files.Types.Unknown_Item);
   end if;
end Visible_Item;

separate (Files.Model)
function Visible_Item
  (Model         : Window_Model;
   Visible_Index : Positive)
   return Files.Items.Directory_Item
is
   Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
begin
   if Item_Index /= 0 then
      return Model.Items.Element (Positive (Item_Index));
   elsif Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model) then
      return Support.Temporary_Item (Model);
   else
      return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
   end if;
end Visible_Item;

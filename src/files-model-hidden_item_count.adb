separate (Files.Model)
function Hidden_Item_Count
  (Model : Window_Model)
   return Natural
is
begin
   --  Counted with the visible-row map, which every write to the items
   --  invalidates: a rebuild asks for it on every frame.
   Support.Ensure_Visible_Map (Model);
   return Model.Hidden_Items;
end Hidden_Item_Count;

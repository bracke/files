with Files.Items;
separate (Files.Model)
procedure For_Each_Visible_Row
  (Model : Window_Model;
   Visit : not null access procedure
     (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean))
is
   Selected : constant Selection_Flags := Selected_Flags (Model);
begin
   --  The visible rows as the cached map has them (Item_Is_Visible's test,
   --  worked out once per listing and filter, not once per call).
   Ensure_Visible_Map (Model);
   for Index of Model.Visible_Items loop
      Visit (Model.Items (Index), Index, Selected (Index));
   end loop;

   if Temporary_Is_Visible (Model) then
      Visit
        (Support.Temporary_Item (Model),
         0,
         Selection_Contains (Model, Temporary_Item_Index));
   end if;
end For_Each_Visible_Row;

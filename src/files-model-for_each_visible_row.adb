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
        ((if Model.Temporary_Is_Directory then
             Files.File_System.Make_Item
               (Parent_Path => Current_Path (Model),
                Name        => To_String (Model.Temporary_Name_Value),
                Kind        => Files.Types.Directory_Item)
          else
             Files.File_System.Make_Item
               (Parent_Path => Current_Path (Model),
                Name        => To_String (Model.Temporary_Name_Value),
                Kind        => Files.Types.Regular_File_Item,
                Filetype    => "text/plain")),
         0,
         Selection_Contains (Model, Temporary_Item_Index));
   end if;
end For_Each_Visible_Row;

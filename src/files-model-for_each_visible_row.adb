with Files.Items;
separate (Files.Model)
procedure For_Each_Visible_Row
  (Model : Window_Model;
   Visit : not null access procedure
     (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean))
is
   Filter   : constant String := To_String (Model.Filter_Value);
   Selected : constant Selection_Flags := Selected_Flags (Model);
begin
   for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
      declare
         --  Referenced in place, never copied (thumbnail pixels included).
         Item : Files.Items.Directory_Item renames Model.Items (Index);
      begin
         --  Same test as Item_Is_Visible, which every index mapping
         --  (clicks, selection, rename) uses: search results show every
         --  hit, including content matches whose name lacks the query.
         if Model.Search_Results_Active
           or else Filter = ""
           or else Files.Types.Contains_Case_Insensitive (To_String (Item.Name), Filter)
         then
            Visit (Item, Natural (Index), Selected (Index));
         end if;
      end;
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

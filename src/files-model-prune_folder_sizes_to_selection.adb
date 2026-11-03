separate (Files.Model)
procedure Prune_Folder_Sizes_To_Selection
  (Model : in out Window_Model) is
   use type Files.Types.Item_Kind;
   Kept : Folder_Size_Maps.Map;
begin
   --  Rebuild the cache keeping only entries for directories still selected.
   for Index of Model.Selected_Item_Indexes loop
      if Index in Model.Items.First_Index .. Model.Items.Last_Index then
         declare
            Item : Files.Items.Directory_Item renames Model.Items (Index);
         begin
            if Item.Kind = Files.Types.Directory_Item
              and then Model.Folder_Sizes.Contains (Item.Full_Path)
            then
               Kept.Include (Item.Full_Path, Model.Folder_Sizes.Element (Item.Full_Path));
            end if;
         end;
      end if;
   end loop;
   if not Folder_Size_Maps."=" (Model.Folder_Sizes, Kept) then
      Touch_Header (Model);
      Model.Folder_Sizes := Kept;
   end if;
end Prune_Folder_Sizes_To_Selection;

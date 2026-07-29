separate (Files.Model)
   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model) is
      use type Files.Types.Item_Kind;
      Kept : Folder_Size_Maps.Map;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      --  Rebuild the cache keeping only entries for directories still selected.
      for Item of Selected_Items (Model) loop
         if Item.Kind = Files.Types.Directory_Item
           and then Model.Folder_Sizes.Contains (Item.Full_Path)
         then
            Kept.Include (Item.Full_Path, Model.Folder_Sizes.Element (Item.Full_Path));
         end if;
      end loop;
      Model.Folder_Sizes := Kept;
   end Prune_Folder_Sizes_To_Selection;

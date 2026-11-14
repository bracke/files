separate (Files.Rendering.Build_Snapshot_Into)
   --  Combined selection total: every selected file's size plus the recursive
   --  size of each selected folder. Computed for any selection (not only when
   --  the info pane is open) so the bottom bar's total counts folder contents.
   --  Folders not yet measured mark the total pending (still growing).
   procedure Snapshot_Selection is
      Total   : Long_Long_Integer := 0;
      Pending : Boolean := False;

      procedure Add (Amount : Long_Long_Integer) is
      begin
         if Amount > 0 and then Total <= Long_Long_Integer'Last - Amount then
            Total := Total + Amount;
         elsif Amount > 0 then
            Total := Long_Long_Integer'Last;
         end if;
      end Add;

      procedure Count (Item : Files.Items.Directory_Item) is
      begin
         if Item.Kind = Files.Types.Directory_Item then
            if Files.Model.Folder_Sizes.Cached_For (Model, To_String (Item.Full_Path)) then
               Add (Files.Model.Folder_Sizes.Value
                      (Model, To_String (Item.Full_Path)).Total_Bytes);
            else
               Pending := True;
            end if;
         elsif Item.Size_Available then
            Add (Item.Size);
         end if;
      end Count;
   begin
      if Snapshot.Selected_Count = 0 then
         return;
      end if;
      Files.Model.Selection.For_Each_Selected_Item (Model, Count'Access);
      Snapshot.Selection_Total_Bytes := Total;
      Snapshot.Selection_Total_Pending := Pending;
   end Snapshot_Selection;

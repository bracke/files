separate (Files.Rendering.Build_Snapshot_Into)
   --  Combined selection total: every selected file's size plus the recursive
   --  size of each selected folder. Computed for any selection (not only when
   --  the info pane is open) so the bottom bar's total counts folder contents.
   --  Folders not yet measured mark the total pending (still growing). A
   --  build that kept the rows keeps the total too while neither the
   --  selection nor the folder sizes moved: with a whole large folder
   --  selected, summing it again cost every header change a walk of it.
   procedure Snapshot_Selection is
      Selection : constant Natural := Files.Model.Selection_Revision (Model);
      Sizes     : constant Natural := Files.Model.Folder_Sizes.Revision (Model);
      Total     : Long_Long_Integer := 0;
      Pending   : Boolean := False;

      procedure Add (Amount : Long_Long_Integer) is
      begin
         if Amount > 0 and then Total <= Long_Long_Integer'Last - Amount then
            Total := Total + Amount;
         elsif Amount > 0 then
            Total := Long_Long_Integer'Last;
         end if;
      end Add;

      procedure Count (Item : Files.Items.Directory_Item) is
         Known : Boolean;
         Bytes : Long_Long_Integer;
      begin
         if Item.Kind = Files.Types.Directory_Item then
            Files.Model.Folder_Sizes.Find (Model, Item.Full_Path, Known, Bytes);
            if Known then
               Add (Bytes);
            else
               Pending := True;
            end if;
         elsif Item.Size_Available then
            Add (Item.Size);
         end if;
      end Count;
   begin
      if Snapshot.Selected_Count = 0 then
         Snapshot.Selection_Total_Bytes := 0;
         Snapshot.Selection_Total_Pending := False;
      elsif not (Keep_Rows
                 and then Snapshot.Total_Selection_Revision = Selection
                 and then Snapshot.Total_Sizes_Revision = Sizes)
      then
         declare
            Kept : Boolean;
         begin
            --  The model keeps the total across folder-size hand-overs; only
            --  a selection it has not seen yet is summed here.
            Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Total, Pending);
            if not Kept then
               Total := 0;
               Pending := False;
               Files.Model.Selection.For_Each_Selected_Item (Model, Count'Access);
            end if;
         end;
         Snapshot.Selection_Total_Bytes := Total;
         Snapshot.Selection_Total_Pending := Pending;
      end if;
      Snapshot.Total_Selection_Revision := Selection;
      Snapshot.Total_Sizes_Revision := Sizes;
   end Snapshot_Selection;

separate (Files.Rendering.Build_Snapshot_Into)
   --  The rows kept from the last build, in the same visible order (group headers
   --  between them): only which are selected is set again.
   procedure Reuse_Rows is
      Row : Natural := 0;

      procedure Mark
        (Item       : Files.Items.Directory_Item;
         Item_Index : Natural;
         Selected   : Boolean)
      is
         pragma Unreferenced (Item, Item_Index);
      begin
         loop
            Row := Row + 1;
            exit when not Snapshot.Items (Row).Is_Group_Header;
         end loop;
         Snapshot.Items (Row).Selected := Selected;
      end Mark;
   begin
      Files.Model.For_Each_Visible_Row (Model, Mark'Access);
   end Reuse_Rows;

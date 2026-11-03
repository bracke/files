with Ada.Containers;
separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Transport_Budget (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  One 64x64 RGBA thumbnail, shared: copying it only counts it.
      Pixels : Files.Types.Byte_Vectors.Vector;
      Items  : Files.Items.Item_Vectors.Vector;
      Thumb_Bytes : constant := 64 * 64 * 4;
      Fits   : constant Natural := Files.Job_Records.Max_Thumbnail_Transport_Bytes / Thumb_Bytes;
      Kept   : Natural := 0;
   begin
      Pixels.Append (0, Ada.Containers.Count_Type (Thumb_Bytes));
      declare
         Shared : constant Files.Shared_Bytes.Bytes := Files.Shared_Bytes.To_Shared (Pixels);
         Item   : Files.Items.Directory_Item;
      begin
         Item.Thumbnail_Available := True;
         Item.Thumbnail_Pixels := Shared;
         Items.Append (Item, Ada.Containers.Count_Type (Fits + 3));
      end;
      Files.Job_Records.Fit_Thumbnails (Items);
      for Item of Items loop
         if Item.Thumbnail_Available then
            Kept := Kept + 1;
         else
            Assert (Files.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels), "a dropped thumbnail carries no pixels");
         end if;
      end loop;
      Files_Suite.Support.Assert_Equal (Kept, Fits, "the first thumbnails up to the budget are kept");
      Files_Suite.Support.Assert_Equal
        (Natural (Items.Length), Fits + 3, "every item is still there, the rest with their icons");
   end Test_Thumbnail_Transport_Budget;

with Files.Item_Lists;
with Ada.Containers;
with Ada.Streams.Stream_IO;
separate (Files_Suite.Thumbnails)
   procedure Test_Thumbnail_Transport_Budget (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  One 64x64 RGBA thumbnail, shared: copying it only counts it.
      Pixels : Files.Types.Byte_Vectors.Vector;
      Items  : Files.Items.Item_Vectors.Vector;
      Thumb_Bytes : constant := 64 * 64 * 4;
      Fits   : constant Natural := Files.Job_Payloads.Max_Thumbnail_Transport_Bytes / Thumb_Bytes;
      Kept   : Natural := 0;
   begin
      Pixels.Append (0, Ada.Containers.Count_Type (Thumb_Bytes));
      declare
         Shared : constant Guikit.Shared_Bytes.Bytes := Guikit.Shared_Bytes.To_Shared (Pixels);
         Item   : Files.Items.Directory_Item;
      begin
         Item.Thumbnail_Available := True;
         Item.Thumbnail_Width := 64;
         Item.Thumbnail_Height := 64;
         Item.Thumbnail_Pixels := Shared;
         Items.Append (Item, Ada.Containers.Count_Type (Fits + 3));
      end;
      Files.Job_Payloads.Fit_Thumbnails (Items);
      for Item of Items loop
         if Item.Thumbnail_Available then
            Kept := Kept + 1;
         else
            Assert (Guikit.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels), "a dropped thumbnail carries no pixels");
            Assert
              (Item.Thumbnail_Width = 0 and then Item.Thumbnail_Height = 0, "a dropped thumbnail carries no size");
         end if;
      end loop;
      Files_Suite.Support.Assert_Equal (Kept, Fits, "the first thumbnails up to the budget are kept");
      Files_Suite.Support.Assert_Equal
        (Natural (Items.Length), Fits + 3, "every item is still there, the rest with their icons");

      --  A dropped item is what the helper then writes: it must encode and
      --  read back (only the dropped tail, to keep the kept 256 MiB off disk).
      declare
         Path    : constant String := Hostkit.Fs.Join (Root, "fitted-items");
         File    : Ada.Streams.Stream_IO.File_Type;
         Dropped : Files.Items.Item_Vectors.Vector;
         Back    : Files.Items.Item_Vectors.Vector;
         Photo   : Files.Items.Directory_Item;
      begin
         Reset_Root;
         Photo := Files.Item_Lists.Make_Item (Root, "photo.png", Files.Types.Regular_File_Item);
         Photo.Thumbnail_Available := Items.Last_Element.Thumbnail_Available;
         Photo.Thumbnail_Width := Items.Last_Element.Thumbnail_Width;
         Photo.Thumbnail_Height := Items.Last_Element.Thumbnail_Height;
         Photo.Thumbnail_Pixels := Items.Last_Element.Thumbnail_Pixels;
         Dropped.Append (Photo);
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         Files.Job_Payloads.Write_Items (Ada.Streams.Stream_IO.Stream (File), Dropped);
         Ada.Streams.Stream_IO.Close (File);
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
         Back := Files.Job_Payloads.Read_Items (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         Files_Suite.Support.Assert_Equal
           (Natural (Back.Length), 1, "an item whose thumbnail was dropped round-trips through the job record");
         Assert (not Back.First_Element.Thumbnail_Available, "and its thumbnail stays dropped");
      end;
   end Test_Thumbnail_Transport_Budget;

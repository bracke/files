with Files.File_System.Thumbnails.Testing;
separate (Files_Suite.Operations)
   --  A cache listing counts only thumbnails against its cap, as a prune
   --  does: foreign files in the cache directory never make it look
   --  oversized and drop it to per-item checks.
   procedure Test_Thumbnail_Listing_Counts_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cache  : constant String := Join (Root, "listing-cap-cache");
      Cap    : constant := 4;
      Listed : Boolean;
      Count  : Natural;

      function Thumbnail (Index : Natural) return String is
         Digest : String (1 .. 64) := [others => 'b'];
      begin
         Digest (64) := Character'Val (Character'Pos ('0') + Index);
         return Join (Cache, "thumb_png_64_" & Digest & ".ppm");
      end Thumbnail;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Cache);
      for Index in 1 .. 3 loop
         Write_Binary_File (Thumbnail (Index), "P6");
      end loop;
      --  Many more foreign files than the cap.
      for Index in 1 .. 4 * Cap loop
         Write_Binary_File (Join (Cache, "foreign-" & Files.Types.Natural_Text (Index) & ".txt"), "x");
      end loop;
      Files.File_System.Thumbnails.Testing.List_Cache (Cache, Cap, Listed, Count);
      Assert (Listed, "foreign files do not cap the listing");
      Files_Suite.Support.Assert_Equal (Count, 3, "the listing holds the thumbnails only");

      --  Thumbnails past the cap still make it unlisted.
      for Index in 4 .. Cap + 1 loop
         Write_Binary_File (Thumbnail (Index), "P6");
      end loop;
      Files.File_System.Thumbnails.Testing.List_Cache (Cache, Cap, Listed, Count);
      Assert (not Listed and then Count = 0, "more thumbnails than the cap leave the cache unlisted");
   end Test_Thumbnail_Listing_Counts_Thumbnails;

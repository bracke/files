with Files.File_System.Thumbnails;
separate (Files_Suite.Thumbnails)
   --  A cache holding more thumbnails than one prune collects is still
   --  pruned: each pass evicts enough that the next one collects them all,
   --  and from then on the byte budget applies, oldest first. What a pass
   --  collects is the oldest, whatever order the directory lists them in,
   --  so the thumbnails evicted are always the oldest and the newest survive.
   procedure Test_Thumbnail_Cache_Prune_Past_Cap (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cache     : constant String := Join (Root, "prune-cap-cache");
      Cap       : constant := 4;
      Count     : constant := 10;
      Payload   : constant String (1 .. 100) := [others => 'x'];

      function Thumbnail (Index : Natural) return String is
         Digest : String (1 .. 64) := [others => 'a'];
      begin
         Digest (64) := Character'Val (Character'Pos ('0') + Index);
         return Join (Cache, "thumb_png_64_" & Digest & ".ppm");
      end Thumbnail;

      --  Whether exactly the newest Kept thumbnails are left.
      function Only_Newest (Kept : Natural) return Boolean is
      begin
         for Index in 0 .. Count - 1 loop
            if Path_Exists (Thumbnail (Index)) /= (Index >= Count - Kept) then
               return False;
            end if;
         end loop;
         return True;
      end Only_Newest;

      function Remaining return Natural is
         Found : Natural := 0;
      begin
         for Index in 0 .. Count - 1 loop
            if Path_Exists (Thumbnail (Index)) then
               Found := Found + 1;
            end if;
         end loop;
         return Found;
      end Remaining;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Cache);
      declare
         Now : constant Long_Long_Integer :=
           Long_Long_Integer
             (Ada.Calendar."-" (Ada.Calendar.Clock, Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0)));
      begin
         for Index in 0 .. Count - 1 loop
            Write_File (Thumbnail (Index), Payload);
            --  Thumbnail 0 oldest, Count - 1 newest.
            Assert
              (Hostkit.Metadata.Set_File_Times
                 (Thumbnail (Index), Now - Long_Long_Integer (1_000 - Index), Now - Long_Long_Integer (1_000 - Index)),
               "set the cache files' times oldest first");
         end loop;
      end;

      --  A budget far above what is there: only the cap forces eviction.
      Files.File_System.Thumbnails.Prune_Thumbnail_Cache (Cache, 1_000_000, Max_Entries => Cap);
      Assert (Remaining < Count, "a pass over a cache past the cap still evicts");
      --  Six past a cap of four: the four collected are the four oldest,
      --  and all four are needed to make room.
      Files_Suite.Support.Assert_Equal (Remaining, Count - Cap, "the first pass evicts the four it collected");
      Assert (Only_Newest (Remaining), "the first pass evicts the oldest thumbnails and keeps the newest");
      for Pass in 1 .. Count loop
         exit when Remaining <= Cap;
         Files.File_System.Thumbnails.Prune_Thumbnail_Cache (Cache, 1_000_000, Max_Entries => Cap);
      end loop;
      Assert (Remaining <= Cap, "repeated passes bring the cache back under the cap");
      --  Two past the cap, plus a margin of one: three more of the oldest.
      Files_Suite.Support.Assert_Equal (Remaining, 3, "the second pass evicts only the overflow and its margin");
      Assert (Only_Newest (Remaining), "every pass evicts the oldest; the newest thumbnails survive");

      --  Under the cap the budget applies again, oldest first.
      declare
         Before : constant Natural := Remaining;
         Newest : Natural := 0;
      begin
         for Index in 0 .. Count - 1 loop
            if Path_Exists (Thumbnail (Index)) then
               Newest := Index;
            end if;
         end loop;
         Files.File_System.Thumbnails.Prune_Thumbnail_Cache (Cache, 150, Max_Entries => Cap);
         Assert (Before >= 1 and then Remaining = 1, "the budget applies once the cache is under the cap");
         Assert (Path_Exists (Thumbnail (Newest)), "the newest thumbnail left survives");
         Assert (Only_Newest (1), "the budget evicts oldest first: only the newest thumbnail is left");
      end;
   end Test_Thumbnail_Cache_Prune_Past_Cap;

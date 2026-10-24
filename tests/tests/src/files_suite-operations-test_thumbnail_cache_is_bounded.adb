separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cache : constant String := Join (Root, "prune-cache");

      Digest_A : constant String (1 .. 64) := [others => 'a'];
      Digest_B : constant String (1 .. 64) := [others => 'b'];
      Digest_C : constant String (1 .. 64) := [others => 'c'];

      --  Distinct sizes so the totals are unambiguous, and written oldest first
      --  with a delay between them so the modification times genuinely order.
      Old_One : constant String := Join (Cache, "thumb_png_64_" & Digest_A & ".ppm");
      Old_Two : constant String := Join (Cache, "thumb_png_64_" & Digest_B & ".ppm");
      Newest  : constant String := Join (Cache, "thumb_png_64_" & Digest_C & ".ppm");
      Unrelated : constant String := Join (Cache, "notes.txt");

      function Filler (Count : Natural) return String is
         Text : constant String (1 .. Count) := [others => 'x'];
      begin
         return Text;
      end Filler;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Cache);

      Write_File (Old_One, Filler (4_000));
      Write_File (Old_Two, Filler (4_000));
      Write_File (Newest, Filler (4_000));
      Write_File (Unrelated, Filler (9_000));
      --  Order the files by setting their times, not by sleeping between writes.
      declare
         Now : constant Long_Long_Integer :=
           Long_Long_Integer
             (Ada.Calendar."-" (Ada.Calendar.Clock, Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0)));
      begin
         Assert (Hostkit.Metadata.Set_File_Times (Old_One, Now - 300, Now - 300)
                 and then Hostkit.Metadata.Set_File_Times (Old_Two, Now - 200, Now - 200)
                 and then Hostkit.Metadata.Set_File_Times (Newest, Now - 100, Now - 100),
                 "set the cache files' times oldest first");
      end;

      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Files.File_System.Prune_Thumbnail_Cache (Cache, 0);
         Files.File_Identities.Testing.Set_Unavailable (False);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Assert
        (Path_Exists (Old_One) and then Path_Exists (Old_Two)
         and then Path_Exists (Newest),
         "cache pruning refuses identity-free deletion candidates");

      --  Comfortably above the total: nothing is touched.
      Files.File_System.Prune_Thumbnail_Cache (Cache, 1_000_000);
      Assert
        (Path_Exists (Old_One) and then Path_Exists (Old_Two) and then Path_Exists (Newest),
         "a cache inside its budget is left alone");

      --  Room for roughly one file: the two oldest go, the newest stays.
      Files.File_System.Prune_Thumbnail_Cache (Cache, 5_000);
      Assert (Path_Exists (Newest), "the most recently written thumbnail survives");
      Assert
        (not Path_Exists (Old_One) and then not Path_Exists (Old_Two),
         "and the older ones are the ones evicted");
      Assert
        (File_Has_Bytes (Unrelated, Filler (9_000)),
         "cache pruning never deletes an unrelated file");

      --  Housekeeping must never be a precondition for anything.
      Files.File_System.Prune_Thumbnail_Cache (Join (Root, "no-such-cache"), 1);
      Assert (True, "pruning a cache directory that does not exist is harmless");

      --  Directory_Exists follows symlinks.  Pruning must not consequently
      --  treat an arbitrary link target as cache contents and delete from it.
      declare
         Real_Directory : constant String := Join (Root, "real-prune-target");
         Linked_Cache   : constant String := Join (Root, "linked-prune-cache");
         Kept_File      : constant String := Join (Real_Directory, "keep.txt");
      begin
         Ada.Directories.Create_Path (Real_Directory);
         Write_File (Kept_File, Filler (4_000));

         if Files_Suite.Support.Create_Symlink (Real_Directory, Linked_Cache) then
            Files.File_System.Prune_Thumbnail_Cache (Linked_Cache, 0);
            Assert (Hostkit.Fs.Is_Link (Linked_Cache),
                    "cache pruning leaves a linked cache root in place");
            Assert (File_Has_Bytes (Kept_File, Filler (4_000)),
                    "cache pruning never deletes from a linked directory target");
         end if;
      end;
   end Test_Thumbnail_Cache_Is_Bounded;

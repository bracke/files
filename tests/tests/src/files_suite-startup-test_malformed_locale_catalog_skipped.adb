with Files.Localization.Testing;
with Files.Resources;
with Files_Suite.Support.Disk;
separate (Files_Suite.Startup)
   --  Locale catalogs were loaded strictly into the one runtime: a single
   --  malformed one made the whole runtime invalid, and every text then
   --  rendered as its raw key. A locale catalog that does not load is now
   --  skipped, the base catalog and the others staying as they were.
   procedure Test_Malformed_Locale_Catalog_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base   : constant String := Files.Resources.Share_Path ("files.catalog");
      Share  : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "share-malformed");
      Broken : constant String := Files_Suite.Support.Disk.Join (Share, "files-da.catalog");
      Good   : constant String := Files_Suite.Support.Disk.Join (Share, "files-da-good.catalog");
      Loaded : Boolean;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Share);
      --  An ICU message left open, and a line that is no key=value pair.
      Files_Suite.Support.Disk.Write_File
        (Broken,
         "da.command.view.small = {count, plural, one {x}" & ASCII.LF
         & "this line is not a catalog entry" & ASCII.LF);
      Files_Suite.Support.Disk.Write_File (Good, "da.command.view.small = Lille" & ASCII.LF);

      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Render_With_Shard (Base, Broken, "en", "command.view.small", Loaded),
         "Small Icons",
         "the base catalog still renders after a malformed locale catalog");
      Assert (not Loaded, "the malformed locale catalog is skipped");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Render_With_Shard (Base, Broken, "da", "command.view.small", Loaded),
         "Small Icons",
         "its locale falls back to the base catalog, not to the raw key");
      Assert (not Loaded, "the malformed locale catalog is skipped again");

      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Render_With_Shard (Base, Good, "da", "command.view.small", Loaded),
         "Lille",
         "a well-formed locale catalog is added as before");
      Assert (Loaded, "and reported loaded");
      Files_Suite.Support.Disk.Reset_Root;
   end Test_Malformed_Locale_Catalog_Skipped;

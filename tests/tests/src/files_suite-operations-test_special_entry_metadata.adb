with Files_Suite.Support.Disk;
with Files_Suite.Listings;
separate (Files_Suite.Operations)
   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "special-entries");
      Load     : Files.File_System.Directory_Load_Result;
      Links    : Natural := 0;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "folder"));
      if not (Hostkit.Fs.Create_Link ("folder", Join (Dir, "to-folder"))
              and then Hostkit.Fs.Create_Link ("missing", Join (Dir, "dangling")))
      then
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Special_Entry_Metadata");
         return;
      end if;
      Load := Files_Suite.Listings.Load_Directory (Dir, Settings);
      for Item of Load.Items loop
         if To_String (Item.Name) in "to-folder" | "dangling" then
            Links := Links + 1;
            Assert (not Item.Metadata_Error,
                    "a link without a regular-file target reports no metadata error: " & To_String (Item.Name));
            if To_String (Item.Name) = "to-folder" then
               Assert (Item.Modified_Available and then Item.Mode_Available,
                       "a link to a folder still reports its times and mode");
            end if;
         end if;
      end loop;
      Files_Suite.Support.Assert_Equal (Links, 2, "the listing shows both links");
   end Test_Special_Entry_Metadata;

separate (Files_Suite.Operations)
   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "special-entries");
      Load     : Files.File_System.Directory_Load_Result;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Special_Entry_Metadata", "needs Linux");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "folder"));
      Assert (Hostkit.Fs.Create_Link ("folder", Join (Dir, "to-folder")), "prepare a link to a folder");
      Assert (Hostkit.Fs.Create_Link ("missing", Join (Dir, "dangling")), "prepare a dangling link");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      for Item of Load.Items loop
         if To_String (Item.Name) in "to-folder" | "dangling" then
            Assert (not Item.Metadata_Error,
                    "a link without a regular-file target reports no metadata error: " & To_String (Item.Name));
            if To_String (Item.Name) = "to-folder" then
               Assert (Item.Modified_Available and then Item.Mode_Available,
                       "a link to a folder still reports its times and mode");
            end if;
         end if;
      end loop;
   end Test_Special_Entry_Metadata;

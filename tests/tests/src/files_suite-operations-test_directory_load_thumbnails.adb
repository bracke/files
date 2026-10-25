separate (Files_Suite.Operations)
   procedure Test_Directory_Load_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Decoded_Png_Source : constant String := Join (Root, "decoded-picture.png");
      Cache_Home : constant String := Join (Root, "cache-home");
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Reset_Root;
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      Write_Binary_File
        (Decoded_Png_Source,
         Minimal_Png_RGB
           (2,
            2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));

      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Load := Files.File_System.Load_Directory (Root, Settings);
      declare
         Found_Auto_Thumbnail : Boolean := False;
         Extension_Settings    : Files.Settings.Settings_Model := Settings;
         Extension_Load        : Files.File_System.Directory_Load_Result;
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = "decoded-picture.png" then
               Found_Auto_Thumbnail := True;
               Assert (Item.Thumbnail_Available, "directory loading auto-generates image thumbnails");
               Files_Suite.Support.Assert_Equal
                 (Item.Thumbnail_Width,
                  64,
                  "auto-generated thumbnail records default width");
               Files_Suite.Support.Assert_Equal
                 (Item.Thumbnail_Height,
                  64,
                  "auto-generated thumbnail records default height");
               Files_Suite.Support.Assert_Equal
                 (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels),
                  64 * 64 * 4,
                  "auto-generated thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "auto-thumbnail image item is loaded");

         Files.Settings.Add_Extension_Mapping (Extension_Settings, "webp", "application/octet-stream");
         Write_File (Join (Root, "extension-only.webp"), "not a decoded image");
         Extension_Load := Files.File_System.Load_Directory (Root, Extension_Settings);
         Found_Auto_Thumbnail := False;
         for Item of Extension_Load.Items loop
            if To_String (Item.Name) = "extension-only.webp" then
               Found_Auto_Thumbnail := True;
               Assert
                 (Item.Thumbnail_Available,
                  "directory loading auto-generates thumbnails for image extensions");
               Files_Suite.Support.Assert_Equal
                 (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels),
                  64 * 64 * 4,
                  "image-extension thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "image-extension thumbnail item is loaded");
      end;
   end Test_Directory_Load_Thumbnails;

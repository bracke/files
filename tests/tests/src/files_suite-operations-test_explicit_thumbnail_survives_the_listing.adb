separate (Files_Suite.Operations)
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Not_Image  : constant String := Join (Root, "notes.txt");
      Cache      : constant String := Join (Root, "explicit-cache");
      Generated  : Files.File_System.Thumbnail_Result;
      Listed     : Files.File_System.Directory_Load_Result;
      Found      : Boolean := False;
      Had_Cache  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache  : Unbounded_String;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      if Had_Cache then
         Old_Cache := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      Reset_Root;
      Write_File (Not_Image, "just text, no image anywhere in it");
      Ada.Directories.Create_Path (Cache);

      --  The command's own path: generate for whatever is selected, image or not.
      Generated := Files.File_System.Generate_Thumbnail (Not_Image, Cache);
      Assert
        (Generated.Status = Files.File_System.Thumbnail_Generated,
         "the thumbnail command produces something even for a text file");

      --  Point the listing at that cache and read the directory back.
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Join (Root, "explicit-xdg"));
      Ada.Directories.Create_Path (Join (Join (Join (Root, "explicit-xdg"), "files"), "thumbnails"));
      Ada.Directories.Copy_File
        (To_String (Generated.Thumbnail_Path),
         Join (Join (Join (Join (Root, "explicit-xdg"), "files"), "thumbnails"),
               Ada.Directories.Simple_Name (To_String (Generated.Thumbnail_Path))));

      Listed := Files.File_System.Load_Directory (Root, Settings);
      for Item of Listed.Items loop
         if To_String (Item.Name) = "notes.txt" then
            Found := True;
            Assert
              (Item.Thumbnail_Available,
               "a text file with a thumbnail in the cache still shows it when listed");
            Assert
              (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels) > 0,
               "and the pixels come with it");
         end if;
      end loop;

      Assert (Found, "the text file is listed");

      if Had_Cache then
         Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Cache));
      else
         Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
      end if;
   end Test_Explicit_Thumbnail_Survives_The_Listing;

separate (Files_Suite.Operations)
   procedure Test_Plain_Listing_Makes_No_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Photo    : constant String := Join (Root, "plain-listing-photo.png");
      Load     : Files.File_System.Directory_Load_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      function Cache_File return String is
        (Files.File_System.Thumbnail_Path_For
           (Photo, Files.File_System.Default_Thumbnail_Cache_Directory (Root), 64));
   begin
      Reset_Root;
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Join (Root, "plain-cache-home"));
      Write_Binary_File
        (Photo,
         Minimal_Png_RGB
           (2, 2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));

      --  Search walks, emptying the Trash, the reload after every operation and
      --  startup all list with plain Load_Directory; none may decode the photo.
      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "the folder lists");
      Assert (Files.File_System.Thumbnails_Missing (Load.Items),
              "a plain listing leaves the photo without a thumbnail");
      Assert (not Ada.Directories.Exists (Cache_File),
              "a plain listing writes no thumbnail cache file");

      --  The background listing is the one that makes it.
      Load := Files.File_System.Load_Directory_Generating_Thumbnails (Root, Settings);
      Assert (Load.Success and then not Files.File_System.Thumbnails_Missing (Load.Items),
              "the generating listing makes the photo's thumbnail");
      Assert (Ada.Directories.Exists (Cache_File), "and writes its cache file");
   end Test_Plain_Listing_Makes_No_Thumbnails;

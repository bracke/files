separate (Files_Suite.Operations)
   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Photos   : constant String := Join (Root, "photos");
      Had_Cache : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache : constant String := Ada.Environment_Variables.Value ("XDG_CACHE_HOME", "");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);

      procedure Restore is
      begin
         if Had_Cache then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Old_Cache);
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;
      end Restore;

      function Photo_Has_Thumbnail return Boolean is
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            if To_String (Files.Model.Visible_Item (Model, Index).Name) = "photo.png" then
               return Files.Model.Visible_Item (Model, Index).Thumbnail_Available;
            end if;
         end loop;
         return False;
      end Photo_Has_Thumbnail;
   begin
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Join (Root, "cache-home"));
      Ada.Directories.Create_Path (Photos);
      Write_Binary_File
        (Join (Photos, "photo.png"),
         Minimal_Png_RGB
           (2, 2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));

      Load := Files.File_System.Load_Directory_Deferring_Thumbnails (Photos, Settings);
      Assert (Load.Success and then Files.File_System.Thumbnails_Missing (Load.Items),
              "a listing the UI waits on does not decode the new photo");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "photos");
      Step := Files.Operations.Open_Selected (Model, Settings);
      Assert (Files.Model.Current_Path (Model) = Photos and then not Photo_Has_Thumbnail,
              "opening the folder shows it at once, before its thumbnail exists");
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "and starts the background listing that makes it");
      Await_View (Model, Settings);
      Assert (Photo_Has_Thumbnail, "the background listing brings the thumbnail");
      Restore;
   exception
      when others => Restore; raise;
   end Test_Navigation_Defers_Thumbnails;

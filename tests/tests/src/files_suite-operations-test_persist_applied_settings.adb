separate (Files_Suite.Operations)
   --  A scalar applied as the user drags or scrolls (the zoom by wheel, a
   --  column width, the window's size) is saved as it stands; a save that
   --  fails says so and keeps the value for the session.
   procedure Test_Persist_Applied_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "persisted.settings");
      Folder   : constant String := Join (Root, "settings-is-a-folder");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Settings.Font_Pixel_Size := Files.Settings.Clamp_Font_Pixel_Size (Settings.Font_Pixel_Size + 3);
      Files.Controller.Persist_Settings (Model, Settings, Path);
      declare
         Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Load_File (Path);
      begin
         Assert (Loaded.Success, "the settings are written");
         Files_Suite.Support.Assert_Equal
           (Loaded.Settings.Font_Pixel_Size, Settings.Font_Pixel_Size, "with the size as it stands");
      end;
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), "", "a save that works reports nothing");
      Files.Controller.Persist_Settings (Model, Settings, Folder);
      Assert (Files.Model.Last_Error_Key (Model) /= "", "a save that fails says so");
      Reset_Root;
   end Test_Persist_Applied_Settings;

separate (Files_Suite.Operations)
   --  Settings that already would not load (another writer got them there)
   --  still take a small change in memory: refusing every later change would
   --  only lock the user out. A change that makes loadable settings
   --  unloadable is still refused.
   procedure Test_Commit_When_Already_Unloadable (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Saved    : Files.Settings.Settings_Write_Result;
      pragma Unreferenced (Saved);
      Batch    : Natural := 0;
   begin
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      while Files.Settings.Loadable (Settings) and then Batch < 1_000 loop
         for Index in Batch * 100 + 1 .. Batch * 100 + 100 loop
            Files.Settings.Toggle_Favorite_Path (Settings, "/nowhere/" & Index'Image);
         end loop;
         Batch := Batch + 1;
      end loop;
      Assert (not Files.Settings.Loadable (Settings), "the settings no longer load");
      Saved := Files.Controller.Commit_Settings
        (Model, Settings, (Settings with delta Font_Pixel_Size => Settings.Font_Pixel_Size + 1), "");
      Assert (Settings.Font_Pixel_Size = Files.Settings.Default_Settings.Font_Pixel_Size + 1,
              "a zoom is still taken");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says it is not saved");
   end Test_Commit_When_Already_Unloadable;

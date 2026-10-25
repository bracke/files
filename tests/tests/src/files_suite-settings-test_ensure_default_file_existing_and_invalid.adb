separate (Files_Suite.Settings)
   procedure Test_Ensure_Default_File_Existing_And_Invalid (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded         : Files.Settings.Settings_Parse_Result;
      Ensured_Path   : constant String := Join (Join (Root, "created-config"), "settings.conf");
      Ensured        : Files.Settings.Settings_Write_Result;
      Blocked_Parent : constant String := Join (Root, "blocked-parent");
      Blocked_Path   : constant String := Join (Blocked_Parent, "settings.conf");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      Ada.Directories.Create_Path (Join (Root, "created-config"));
      Write_File (Blocked_Parent, "not a directory");
      Write_File (Ensured_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings accepts existing regular file");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Details,
         "ensure default settings does not overwrite");
      Ensured := Files.Settings.Ensure_Default_File (Join (Root, "settings-dir"));
      Assert (not Ensured.Success, "ensure default settings rejects directory path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.not_file",
         "ensure default settings reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File (Blocked_Path);
      Assert (not Ensured.Success, "ensure default settings rejects a file used as parent directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Path),
         Blocked_Path,
         "ensure default settings parent failure reports requested settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.not_file",
         "ensure default settings parent failure reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File ("");
      Assert (not Ensured.Success, "ensure default settings rejects empty settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.save",
         "ensure default settings empty path reports save diagnostic");
   end Test_Ensure_Default_File_Existing_And_Invalid;

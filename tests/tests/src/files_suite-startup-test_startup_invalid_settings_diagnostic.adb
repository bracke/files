separate (Files_Suite.Startup)
   procedure Test_Startup_Invalid_Settings_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-invalid-settings");
      Settings_Path : constant String := Join (Root, "bad.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Full_Dir      : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));
      Write_File (Join (Dir, ".hidden"));
      Write_File (Join (Dir, "shown.txt"));
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = maybe" & ASCII.LF);

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Windows.Length),
         1,
         "invalid settings do not block valid paths");
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length),
         1,
         "invalid settings add one startup diagnostic");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Path),
         To_String (Full_Dir),
         "invalid settings still open the normalized requested path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model),
         To_String (Full_Dir),
         "invalid settings startup model still uses normalized path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Input_Path),
         Settings_Path,
         "settings diagnostic records the settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Error_Key),
         "error.settings.invalid_boolean",
         "settings diagnostic records the parse error");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Settings_Path),
         "",
         "an unreadable settings file makes the session read-only so defaults never overwrite it");
      Files_Suite.Support.Assert_Equal
        (Startup.Settings.Default_View,
         Files.Settings.Default_Settings.Default_View,
         "invalid settings leave startup result on default settings");
      Assert
        (not Startup.Settings.Show_Hidden_Files,
         "invalid settings do not leak partially parsed hidden-file setting");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model),
         1,
         "default settings are used after failure");
   end Test_Startup_Invalid_Settings_Diagnostic;

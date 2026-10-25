separate (Files_Suite.Startup)
   procedure Test_Startup_Settings_Path_Not_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-settings-directory");
      Settings_Path : constant String := Join (Root, "settings-as-directory");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Full_Dir      : Unbounded_String;
      Report        : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Settings_Path);
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));
      Write_File (Join (Dir, ".hidden"));
      Write_File (Join (Dir, "shown.txt"));

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Windows.Length),
         1,
         "settings directory does not block valid paths");
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length),
         1,
         "settings directory adds one startup diagnostic");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Path),
         To_String (Full_Dir),
         "settings directory startup window records normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model),
         To_String (Full_Dir),
         "settings directory startup model uses normalized path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Input_Path),
         Settings_Path,
         "settings directory diagnostic records the settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Error_Key),
         "error.settings.not_file",
         "settings directory diagnostic records the not-file error");
      Files_Suite.Support.Assert_Equal
        (Startup.Settings.Default_View,
         Files.Settings.Default_Settings.Default_View,
         "settings directory leaves startup result on default settings");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model),
         1,
         "default settings are used when startup settings path is a directory");

      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Settings_Path & ": " &
            Files.Localization.Text ("error.settings.not_file")) > 0,
         "startup report localizes settings directory diagnostics");
   end Test_Startup_Settings_Path_Not_File;

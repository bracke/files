separate (Files_Suite.Startup)
   procedure Test_Startup_Loads_Settings_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-settings");
      Settings_Path : constant String := Join (Root, "files.conf");
      Created_Path  : constant String := Join (Join (Root, "startup-created"), "settings.conf");
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
        (Join
           (Dir,
            Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
            & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#)
            & ".txt"));
      Write_File
        (Join
           (Dir,
            Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#))
            & ".txt"));
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "default_view_mode = details" & ASCII.LF &
         "show_hidden_files = true" & ASCII.LF);

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length),
         0,
         "valid settings do not add startup diagnostics");
      Files_Suite.Support.Assert_Equal (Natural (Startup.Windows.Length), 1, "valid startup path opens one window");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Settings_Path),
         Settings_Path,
         "startup result records loaded settings path");
      Files_Suite.Support.Assert_Equal
        (Startup.Settings.Default_View,
         Files.Types.Details,
         "startup result exposes loaded default view");
      Assert (Startup.Settings.Show_Hidden_Files, "startup result exposes loaded hidden-file setting");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Path),
         To_String (Full_Dir),
         "settings startup window records normalized path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Title),
         To_String (Full_Dir),
         "settings startup window title records normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model),
         To_String (Full_Dir),
         "settings startup model uses normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Startup.Windows.Element (1).Model),
         Files.Types.Details,
         "view setting loads");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model),
         4,
         "hidden-file setting affects startup load");
      Assert
        (Files.Application.Windows.Headless_Smoke_Test (Startup),
         "startup windows with Unicode and fallback filenames pass headless render smoke test");

      Args.Clear;
      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Created_Path);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length),
         0,
         "missing startup settings are created without diagnostics");
      Assert (Ada.Directories.Exists (Created_Path), "startup creates missing default settings file");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Settings_Path),
         Created_Path,
         "startup result records created settings path");
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Windows.Length),
         1,
         "startup still opens path after creating settings file");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Startup.Settings, "txt"),
         "text/plain",
         "startup result exposes created default settings");
   end Test_Startup_Loads_Settings_File;

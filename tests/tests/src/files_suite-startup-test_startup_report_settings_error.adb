separate (Files_Suite.Startup)
   procedure Test_Startup_Report_Settings_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "report-settings-dir");
      Settings_Path : constant String := Join (Root, "bad-report-settings.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Report        : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = not-a-boolean" & ASCII.LF);
      Args.Append (To_Unbounded_String (Dir));

      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.window.ready") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "startup report includes the valid window after settings failure");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Settings_Path & ": " &
            Files.Localization.Text ("error.settings.invalid_boolean")) > 0,
         "startup report localizes settings parse diagnostics");
   end Test_Startup_Report_Settings_Error;

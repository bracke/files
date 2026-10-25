separate (Files_Suite.Startup)
   procedure Test_Startup_And_Runtime_Smoke_Reports (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "report-dir");
      Missing  : constant String := Join (Root, "missing-report-dir");
      Args     : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Startup  : Files.Application.Startup_Result;
      Report   : Unbounded_String;
      Smoke    : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Args.Append (To_Unbounded_String (Dir));
      Args.Append (To_Unbounded_String (Missing));

      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.window.ready") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "startup report uses localized window label");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Missing & ": " &
            Files.Localization.Text ("error.path.missing")) > 0,
         "startup report uses localized error label and diagnostic");
      Smoke := To_Unbounded_String (Files.Application.Runtime_Smoke_Report (Startup, Width => 800, Height => 400));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke),
            Files.Localization.Text ("runtime.smoke.window") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "runtime smoke report uses localized window label");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.vertices") & ": ") > 0,
         "runtime smoke report uses localized vertex-count label");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.text_failed")) > 0,
         "runtime smoke rejects a startup that contains path errors");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), "runtime-smoke: FAIL") > 0,
         "runtime smoke emits FAIL when any requested path failed");
      Startup.Errors.Clear;
      Smoke := To_Unbounded_String (Files.Application.Runtime_Smoke_Report (Startup, Width => 800, Height => 400));
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.ready")) > 0,
         "runtime smoke report exposes successful headless render quality");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), "runtime-smoke: PASS") > 0,
         "runtime smoke report emits the fixed ASCII PASS verdict marker for CI");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.frames_attempted") & ": 1") > 0,
         "runtime smoke report exposes headless render quality frame count");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.missing_glyphs") & ": 0") > 0,
         "runtime smoke report exposes missing-glyph fallback count");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.font") & ": ") > 0,
         "runtime smoke report exposes selected text font path");
      Smoke := To_Unbounded_String (Files.Application.Runtime_Smoke_Report (Startup, Width => 1, Height => 1));
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.text_failed")) > 0,
         "runtime smoke reports zero-glyph text batches as failures");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), "runtime-smoke: FAIL") > 0,
         "runtime smoke report emits the fixed ASCII FAIL verdict marker for CI");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Application.Runtime_Smoke_Report ((others => <>)),
            Files.Localization.Text ("runtime.smoke.no_windows")) > 0,
         "runtime smoke report uses localized empty-startup diagnostic");
      declare
         Quality : constant Files.Application.Windows.Smoke.Headless_Render_Quality_Result :=
           Files.Application.Windows.Smoke.Headless_Render_Quality_Report (Startup, Width => 1000, Height => 800);
      begin
         Files_Suite.Support.Assert_Equal (Quality.Window_Count, 1, "headless render quality report counts windows");
         Files_Suite.Support.Assert_Equal
           (Quality.Nonblank_Frames,
            1,
            "headless render quality report catches blank frames");
         Files_Suite.Support.Assert_Equal
           (Quality.Text_Glyph_Frames,
            1,
            "headless render quality report catches missing text output");
         Files_Suite.Support.Assert_Equal
           (Quality.Icon_Frames,
            1,
            "headless render quality report catches missing icon output");
         Files_Suite.Support.Assert_Equal
           (Quality.Toolbar_Icon_Frames,
            1,
            "headless render quality report catches missing toolbar icons");
         Files_Suite.Support.Assert_Equal
           (Quality.Drag_Preview_Frames,
            1,
            "headless render quality report catches invisible drag previews");
         Files_Suite.Support.Assert_Equal
           (Quality.Missing_Glyph_Count,
            0,
            "headless render quality report catches missing glyphs");
         Assert (Quality.Passed, "headless render quality report passes for startup windows");
      end;
   end Test_Startup_And_Runtime_Smoke_Reports;

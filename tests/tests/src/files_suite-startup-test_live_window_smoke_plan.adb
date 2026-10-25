separate (Files_Suite.Startup)
   procedure Test_Live_Window_Smoke_Plan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "report-dir");
      Missing  : constant String := Join (Root, "missing-report-dir");
      Args     : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Startup  : Files.Application.Startup_Result;
      Caps     : constant Files.Application.Windows.Desktop_Capabilities :=
        Files.Application.Windows.Runtime_Capabilities;
      Plan     : Files.Application.Windows.Live_Smoke_Plan;
      Live_Result : Files.Application.Windows.Live_Smoke_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Args.Append (To_Unbounded_String (Dir));
      Args.Append (To_Unbounded_String (Missing));

      --  The startup the runner sees once its path errors are cleared.
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Startup.Errors.Clear;
      Plan := Files.Application.Windows.Live_Window_Smoke_Plan (Width => 640, Height => 360);
      Files_Suite.Support.Assert_Equal (Plan.Width, 640, "live smoke plan records requested width");
      Files_Suite.Support.Assert_Equal (Plan.Height, 360, "live smoke plan records requested height");
      Files_Suite.Support.Assert_Equal
        (Plan.Frame_Count,
         2,
         "live smoke plan records two frames for readback validation");
      Files_Suite.Support.Assert_Equal
        (Plan.Input_Poll_Count,
         1,
         "live smoke plan records deterministic input poll count");
      Files_Suite.Support.Assert_Equal
        (Plan.Can_Run,
         Caps.Live_Window_Smoke_Ready,
         "live smoke plan readiness matches runtime capabilities");
      Assert (To_String (Plan.Reason_Key) /= "", "live smoke plan exposes localized reason key");
      Live_Result := Files.Application.Windows.Evaluate_Live_Window_Smoke (Plan);
      Assert
        (Live_Result.Skipped_By_Plan = not Plan.Can_Run,
         "live smoke result records whether the plan skipped execution");
      Files_Suite.Support.Assert_Equal
        (Live_Result.Frames_Attempted,
         0,
         "live smoke preflight reports zero attempted frames");
      Files_Suite.Support.Assert_Equal
        (Live_Result.Frames_Presented,
         0,
         "live smoke preflight reports zero presented frames");
      Assert (not Live_Result.Window_Created, "headless live smoke evaluation does not create a window");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "headless live smoke evaluation does not fake framebuffer readback");
      Assert (To_String (Live_Result.Error_Key) /= "", "live smoke result exposes status key");
      Live_Result := Files.Application.Windows.Run_Live_Window_Smoke ((others => <>), Plan);
      Assert (not Live_Result.Window_Created, "live smoke runner does not create windows for empty startup");
      Files_Suite.Support.Assert_Equal
        (Live_Result.Frames_Attempted,
         0,
         "empty live smoke startup reports zero attempted frames");
      Files_Suite.Support.Assert_Equal
        (Live_Result.Frames_Presented,
         0,
         "empty live smoke startup reports zero presented frames");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "empty live smoke runner does not fake framebuffer readback");
      Files_Suite.Support.Assert_Equal
        (To_String (Live_Result.Error_Key),
         "runtime.smoke.no_windows",
         "live smoke runner reports empty startup");
      Plan.Can_Run := False;
      Plan.Reason_Key := To_Unbounded_String ("runtime.smoke.no_display");
      Live_Result := Files.Application.Windows.Run_Live_Window_Smoke (Startup, Plan);
      Assert (Live_Result.Skipped_By_Plan, "live smoke runner skips when plan cannot run");
      Assert (not Live_Result.Attempted, "live smoke runner does not attempt skipped plan");
      Files_Suite.Support.Assert_Equal
        (Live_Result.Frames_Attempted,
         0,
         "skipped live smoke startup reports zero attempted frames");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "skipped live smoke runner does not fake framebuffer readback");
   end Test_Live_Window_Smoke_Plan;

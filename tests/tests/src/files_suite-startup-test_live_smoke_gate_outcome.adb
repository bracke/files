separate (Files_Suite.Startup)
   procedure Test_Live_Smoke_Gate_Outcome (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Application.Windows.Smoke.Live_Smoke_Gate;
      Skipped     : Files.Application.Windows.Smoke.Live_Smoke_Result;
      No_Device   : Files.Application.Windows.Smoke.Live_Smoke_Result;
      Passed      : Files.Application.Windows.Smoke.Live_Smoke_Result;
      Failed      : Files.Application.Windows.Smoke.Live_Smoke_Result;
      No_Readback : Files.Application.Windows.Smoke.Live_Smoke_Result;
      Dirty_Exit  : Files.Application.Windows.Smoke.Live_Smoke_Result;
   begin
      --  A plan skipped for want of a display or Vulkan maps to Skip.
      Skipped.Skipped_By_Plan := True;
      Skipped.Attempted := False;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (Skipped) =
           Files.Application.Windows.Smoke.Live_Smoke_Skip,
         "skipped-by-plan live smoke maps to Skip");

      --  An attempted run in which no usable Vulkan device initialized (missing
      --  or unusable ICD) is an environment gap and maps to Skip.
      No_Device.Attempted := True;
      No_Device.Skipped_By_Plan := False;
      No_Device.Vulkan_Device_Ready := False;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (No_Device) =
           Files.Application.Windows.Smoke.Live_Smoke_Skip,
         "attempted live smoke without a usable Vulkan device maps to Skip");

      --  An attempted run with a clean, structurally valid frame maps to Pass.
      Passed.Attempted := True;
      Passed.Skipped_By_Plan := False;
      Passed.Vulkan_Device_Ready := True;
      Passed.Framebuffer_Readback_Ready := True;
      Passed.Framebuffer_Passed := True;
      Passed.Closed_Cleanly := True;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (Passed) =
           Files.Application.Windows.Smoke.Live_Smoke_Pass,
         "attempted passing live smoke maps to Pass");

      --  An attempted run whose frame failed structural analysis maps to Fail.
      Failed := Passed;
      Failed.Framebuffer_Passed := False;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (Failed) =
           Files.Application.Windows.Smoke.Live_Smoke_Fail,
         "attempted degenerate live smoke maps to Fail");

      --  A run that never produced a framebuffer readback maps to Fail.
      No_Readback := Passed;
      No_Readback.Framebuffer_Readback_Ready := False;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (No_Readback) =
           Files.Application.Windows.Smoke.Live_Smoke_Fail,
         "attempted live smoke without readback maps to Fail");

      --  A run interrupted after a window opened (unclean close) maps to Fail.
      Dirty_Exit := Passed;
      Dirty_Exit.Closed_Cleanly := False;
      Assert
        (Files.Application.Windows.Smoke.Gate_Outcome (Dirty_Exit) =
           Files.Application.Windows.Smoke.Live_Smoke_Fail,
         "attempted live smoke that did not close cleanly maps to Fail");
   end Test_Live_Smoke_Gate_Outcome;

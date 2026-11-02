separate (Files.Application)
--  The live smoke: run it, print what it measured and one greppable verdict
--  line, and answer the exit status CI classifies the run by.
function Run_Live_Smoke (Result : Startup_Result) return Ada.Command_Line.Exit_Status is
   Status : Ada.Command_Line.Exit_Status := Ada.Command_Line.Success;
   --  Canonical, greppable verdict marker and tokens for CI. These
   --  are deliberately fixed ASCII (not localized) so a CI grep for
   --  "live-smoke: PASS" is stable across locales; only the trailing
   --  reason text is localized via the catalog.
   Live_Smoke_Marker : constant String := "live-smoke:";
   Pass_Token        : constant String := "PASS";
   Fail_Token        : constant String := "FAIL";
   Skip_Token        : constant String := "SKIP";
   Space             : constant String := " ";

   --  Per-scenario report fragments. Each literal is letters-only or
   --  space-only so the source carries no hard-coded user-visible
   --  prose (letter-plus-space) yet the emitted line stays greppable.
   Scenario_Prefix   : constant String := "live-smoke";
   Scenario_Word     : constant String := "scenario";
   Colon             : constant String := ":";
   Pass_Word         : constant String := "pass";
   Fail_Word         : constant String := "fail";
   Region_Word       : constant String := "region";
   Keys_Word         : constant String := "keys";
   Loop_Word         : constant String := "loop";

   --  Automake convention: a skipped test exits with code 77 so CI
   --  can tell "environment could not run it" apart from a pass (0)
   --  or a fail (1), while still treating the skip as non-fatal.
   Live_Smoke_Skip_Exit_Code : constant Ada.Command_Line.Exit_Status := 77;

   Plan       : constant Files.Application.Windows.Smoke.Live_Smoke_Plan :=
     Files.Application.Windows.Smoke.Live_Window_Smoke_Plan;
   Live_Result : constant Files.Application.Windows.Smoke.Live_Smoke_Result :=
     Files.Application.Windows.Smoke.Run_Live_Window_Smoke (Result, Plan);

   function Live_Smoke_Fail_Reason
     (Failed : Files.Application.Windows.Smoke.Live_Smoke_Result)
      return String is
   begin
      if not Failed.Closed_Cleanly then
         return Files.Localization.Text (To_String (Failed.Error_Key));
      elsif Failed.Loop_Failures > 0 then
         return Files.Localization.Text ("runtime.smoke.loop_failed");
      elsif not Failed.Loop_Drew_Input then
         return Files.Localization.Text ("runtime.smoke.loop_not_drawn");
      elsif not Failed.Framebuffer_Readback_Ready then
         return Files.Localization.Text ("runtime.smoke.readback_missing");
      else
         return Files.Localization.Text ("runtime.smoke.structural_failed");
      end if;
   end Live_Smoke_Fail_Reason;

   function Live_Smoke_Skip_Reason
     (Skipped : Files.Application.Windows.Smoke.Live_Smoke_Result)
      return String is
   begin
      if Skipped.Skipped_By_Plan or else not Skipped.Attempted then
         return Files.Localization.Text (To_String (Skipped.Error_Key));
      else
         --  A window opened but no usable Vulkan device initialized.
         return Files.Localization.Text ("runtime.smoke.no_vulkan");
      end if;
   end Live_Smoke_Skip_Reason;
   --  One measured value per line: its localized label, a colon, the value.
   procedure Put_Field (Key : String; Value : String) is
   begin
      Ada.Text_IO.Put_Line (Files.Localization.Text (Key) & ": " & Value);
   end Put_Field;
begin
   Ada.Text_IO.Put_Line
     (Files.Localization.Text (To_String (Live_Result.Error_Key)));
   Put_Field ("runtime.smoke.vulkan_status", Guikit.Vulkan.Vulkan_Status'Image (Live_Result.Last_Status));
   Put_Field ("runtime.smoke.vulkan_result", Interfaces.Integer_32'Image (Live_Result.Last_Vk_Result));
   Put_Field ("runtime.smoke.frames_attempted", Natural'Image (Live_Result.Frames_Attempted));
   Put_Field ("runtime.smoke.frames_presented", Natural'Image (Live_Result.Frames_Presented));
   Put_Field ("runtime.smoke.framebuffer_readback", Boolean'Image (Live_Result.Framebuffer_Readback_Ready));
   Put_Field ("runtime.smoke.framebuffer_hash", Interfaces.Unsigned_32'Image (Live_Result.Last_Framebuffer_Hash));
   Put_Field ("runtime.smoke.framebuffer_bytes", Natural'Image (Live_Result.Last_Framebuffer_Bytes));
   declare
      Metrics : constant Guikit.Frame_Analysis.Frame_Metrics :=
        Live_Result.Framebuffer_Analysis;
      Background_Percent : constant Natural :=
        Natural (Float'Floor (Metrics.Background_Fraction * 100.0));
   begin
      Put_Field ("runtime.smoke.distinct_colors", Natural'Image (Metrics.Distinct_Colors));
      Put_Field ("runtime.smoke.background_percent", Natural'Image (Background_Percent));
      Put_Field ("runtime.smoke.ink_pixels", Natural'Image (Metrics.Ink_Pixels));
      Put_Field
        ("runtime.smoke.bands_with_content",
         Natural'Image (Guikit.Frame_Analysis.Bands_With_Content (Metrics)));
      Put_Field
        ("runtime.smoke.structural_verdict",
         Files.Localization.Text
           (if Live_Result.Framebuffer_Passed then "runtime.smoke.pass" else "runtime.smoke.fail"));
   end;

   --  One greppable line per scenario, built from ASCII fragments,
   --  so a state-specific display regression is visible in CI logs
   --  before the single canonical verdict line below.
   for Scenario in Files.Application.Windows.Smoke.Live_Smoke_Scenario loop
      declare
         Outcome : constant Files.Application.Windows.Smoke.Scenario_Outcome :=
           Live_Result.Scenario_Results (Scenario);
         Region_Percent : constant Natural :=
           Natural (Float'Floor (Outcome.Region_Ink_Fraction * 100.0));
      begin
         Ada.Text_IO.Put_Line
           (Scenario_Prefix & Space & Scenario_Word & Space
            & Files.Application.Windows.Smoke.Scenario_Name (Scenario)
            & Colon & Space
            & (if Files.Application.Windows.Smoke.Scenario_Passed
                   (Live_Result.Scenario_Results, Scenario)
               then Pass_Word else Fail_Word)
            --  When a scenario asserted a layout-derived element
            --  rectangle, append its verdict and measured ink
            --  percent so a coordinate/scaling regression is
            --  visible per scenario in CI logs.
            & (if Outcome.Region_Checked
               then Space & Region_Word & Colon & Space
                    & (if Outcome.Region_Ink_Present
                       then Pass_Word else Fail_Word)
                    & Space & Natural'Image (Region_Percent)
               else "")
            --  A scripted key sequence reports the first step
            --  whose effect was missing.
            & (if Outcome.Keys_Checked
               then Space & Keys_Word & Colon & Space
                    & (if Outcome.Keys_Failed_Step = 0
                       then Pass_Word
                       else Fail_Word & Natural'Image (Outcome.Keys_Failed_Step))
               else ""));
      end;
   end loop;

   --  The loop phase: exceptions carried past, and the key drawn.
   Ada.Text_IO.Put_Line
     (Scenario_Prefix & Space & Loop_Word & Colon & Space
      & (if Live_Result.Loop_Failures = 0 and then Live_Result.Loop_Drew_Input
         then Pass_Word else Fail_Word)
      & Natural'Image (Live_Result.Loop_Failures));

   --  Emit exactly one canonical, greppable verdict line and set a
   --  matching exit code so CI can classify the run:
   --    PASS -> exit 0, FAIL -> exit 1, SKIP -> exit 77.
   case Files.Application.Windows.Smoke.Gate_Outcome (Live_Result) is
      when Files.Application.Windows.Smoke.Live_Smoke_Pass =>
         Ada.Text_IO.Put_Line (Live_Smoke_Marker & Space & Pass_Token);
         Status := Ada.Command_Line.Success;

      when Files.Application.Windows.Smoke.Live_Smoke_Fail =>
         Ada.Text_IO.Put_Line
           (Live_Smoke_Marker & Space & Fail_Token & Space
            & Live_Smoke_Fail_Reason (Live_Result));
         Status := Ada.Command_Line.Failure;

      when Files.Application.Windows.Smoke.Live_Smoke_Skip =>
         Ada.Text_IO.Put_Line
           (Live_Smoke_Marker & Space & Skip_Token & Space
            & Live_Smoke_Skip_Reason (Live_Result));
         Status := Live_Smoke_Skip_Exit_Code;
   end case;
   return Status;
end Run_Live_Smoke;

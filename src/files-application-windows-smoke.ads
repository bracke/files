with Guikit.Frame_Analysis;
with Interfaces;

--  The --runtime-smoke and --live-smoke harnesses: headless render-quality
--  checks, and a live run that renders named application states in real
--  windows and checks each read-back framebuffer.
package Files.Application.Windows.Smoke is

   type Live_Smoke_Plan is record
      Can_Run          : Boolean := False;
      Needs_Display    : Boolean := True;
      Needs_Vulkan     : Boolean := True;
      Width            : Natural := 1024;
      Height           : Natural := 768;
      Frame_Count      : Positive := 1;
      Input_Poll_Count : Positive := 1;
      Reason_Key       : UString;
   end record;

   --  Named application states the multi-scenario live smoke renders in order.
   --
   --  Scenario_Default renders the unchanged startup state and is the baseline
   --  every other scenario's framebuffer is compared against; the remaining
   --  scenarios each apply one distinct state (a selection, an overflowing
   --  scrolled list, the item context menu, the command palette, a near-maximum
   --  font size, the light theme, and the details view) so a state-specific
   --  display regression is caught rather than only the startup frame.
   type Live_Smoke_Scenario is
     (Scenario_Default,
      Scenario_Selection,
      Scenario_Scrolled,
      Scenario_Context_Menu,
      Scenario_Palette,
      Scenario_Root_Selector,
      Scenario_Sort_Menu,
      Scenario_Tree_Panel,
      Scenario_Settings,
      --  The settings panel on each further tab (by position, 2 .. 7), then
      --  with the light theme and at a large font, so every tab and both
      --  extremes of the panel's styling are rendered, not just the first.
      Scenario_Settings_Tab_2,
      Scenario_Settings_Tab_3,
      Scenario_Settings_Tab_4,
      Scenario_Settings_Tab_5,
      Scenario_Settings_Tab_6,
      Scenario_Settings_Tab_7,
      Scenario_Settings_Light,
      Scenario_Settings_Large_Font,
      --  The settings panel driven by real key presses through the window's
      --  own key queue (open, move, toggle, switch tabs, close, reopen), each
      --  checked against the model and followed by a rendered frame.
      Scenario_Settings_Keyboard,
      Scenario_Large_Font,
      Scenario_Light_Theme,
      Scenario_Details_View,
      Scenario_Quick_Look,
      Scenario_Quick_Look_Image);

   --  Per-scenario live smoke outcome captured from the framebuffer readback.
   type Scenario_Outcome is record
      Rendered       : Boolean := False;
      --  True when the scenario produced at least one rendered frame.
      Readback_Ready : Boolean := False;
      --  True when a framebuffer readback was captured for the scenario.
      Passed         : Boolean := False;
      --  True when the scenario frame passed structural analysis.
      Hash           : Interfaces.Unsigned_32 := 0;
      --  Hash of the scenario's last read-back framebuffer.
      Region_Checked : Boolean := False;
      --  True when the scenario asserted a layout-derived UI element rectangle
      --  against the read-back framebuffer (only some scenarios do).
      Region_Ink_Present : Boolean := False;
      --  True when that layout-derived rectangle held drawn content, proving
      --  the element rendered at its computed pixel position. Meaningful only
      --  when Region_Checked is set.
      Region_Ink_Fraction : Float := 0.0;
      --  Measured ink fraction of the checked region, retained for diagnostics.
      Keys_Checked : Boolean := False;
      --  True when the scenario drove a scripted key sequence.
      Keys_Failed_Step : Natural := 0;
      --  The first scripted key step whose expected effect did not happen, or
      --  zero when every step passed. Meaningful only when Keys_Checked is set.
   end record;

   type Scenario_Outcome_Array is array (Live_Smoke_Scenario) of Scenario_Outcome;

   type Live_Smoke_Result is record
      Attempted          : Boolean := False;
      Window_Created     : Boolean := False;
      Frame_Rendered     : Boolean := False;
      Frames_Attempted   : Natural := 0;
      Frames_Presented   : Natural := 0;
      Input_Polled       : Boolean := False;
      Closed_Cleanly     : Boolean := False;
      Skipped_By_Plan    : Boolean := True;
      Last_Status        : Guikit.Vulkan.Vulkan_Status :=
        Guikit.Vulkan.Vulkan_Not_Initialized;
      Last_Vk_Result     : Interfaces.Integer_32 := 0;
      Framebuffer_Readback_Ready : Boolean := False;
      Last_Framebuffer_Hash : Interfaces.Unsigned_32 := 0;
      Last_Framebuffer_Bytes : Natural := 0;
      Framebuffer_Analysis : Guikit.Frame_Analysis.Frame_Metrics;
      Framebuffer_Passed : Boolean := False;
      Vulkan_Device_Ready : Boolean := False;
      Scenario_Results   : Scenario_Outcome_Array;
      --  Per-scenario structural verdict and framebuffer hash captured by the
      --  multi-scenario live smoke; Framebuffer_* above mirror the default
      --  scenario's frame for the legacy single-frame diagnostics.
      Error_Key          : UString;
   end record;

   --  CI gate taxonomy for a live-window smoke run.
   --
   --  Live_Smoke_Pass marks a rendered frame that passed structural analysis,
   --  Live_Smoke_Fail marks an attempted-but-degenerate or errored frame, and
   --  Live_Smoke_Skip marks an environment that could not run the smoke.
   type Live_Smoke_Gate is (Live_Smoke_Pass, Live_Smoke_Fail, Live_Smoke_Skip);

   type Headless_Render_Quality_Result is record
      Window_Count        : Natural := 0;
      Frame_Count         : Natural := 0;
      Nonblank_Frames     : Natural := 0;
      Text_Glyph_Frames   : Natural := 0;
      Icon_Frames         : Natural := 0;
      Toolbar_Icon_Frames : Natural := 0;
      Drag_Preview_Frames : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Failed_Frames       : Natural := 0;
      Passed              : Boolean := False;
      Error_Key           : UString;
   end record;

   --  Validate startup window models through the render pipeline without opening native windows.
   --
   --  @param Startup Startup result containing window models to validate.
   --  @return True when each startup window can produce a non-empty frame.
   function Headless_Smoke_Test
     (Startup : Startup_Result)
      return Boolean;

   --  Validate render quality gates without opening native windows.
   --
   --  @param Startup Startup result containing window models to validate.
   --  @param Width Framebuffer width used for frame construction.
   --  @param Height Framebuffer height used for frame construction.
   --  @return Structured headless render-quality counters.
   function Headless_Render_Quality_Report
     (Startup : Startup_Result;
      Width   : Natural := 1024;
      Height  : Natural := 768)
      return Headless_Render_Quality_Result;

   --  Return the live-window smoke-test plan for the current environment.
   --
   --  @param Width Requested smoke window width in pixels.
   --  @param Height Requested smoke window height in pixels.
   --  @return Plan describing whether a live smoke can run and why.
   function Live_Window_Smoke_Plan
     (Width  : Natural := 1024;
      Height : Natural := 768)
      return Live_Smoke_Plan;

   --  Evaluate a live-window smoke plan without opening a native window.
   --
   --  This returns the execution contract a live harness must satisfy. It does
   --  not create windows in headless test runs.
   --
   --  @param Plan Live smoke plan to evaluate.
   --  @return Structured live smoke execution result.
   function Evaluate_Live_Window_Smoke
     (Plan : Live_Smoke_Plan)
      return Live_Smoke_Result;

   --  Execute a bounded live-window smoke test when Plan allows it.
   --
   --  This opens one native window for each startup window, polls input,
   --  renders the requested frame count, releases all windows, and returns a
   --  structured result. If Plan cannot run, it returns the skipped result.
   --
   --  @param Startup Startup result containing window models to smoke-test.
   --  @param Plan Live smoke plan to execute.
   --  @return Structured live smoke execution result.
   function Run_Live_Window_Smoke
     (Startup : Startup_Result;
      Plan    : Live_Smoke_Plan)
      return Live_Smoke_Result;

   --  Return the stable ASCII identifier of a live smoke scenario.
   --
   --  The identifier is a lowercase, letters-and-underscore fragment used to
   --  build the greppable per-scenario report line; it is deliberately not
   --  localized so CI can match it across locales.
   --
   --  @param Scenario Scenario to name.
   --  @return ASCII scenario identifier.
   function Scenario_Name
     (Scenario : Live_Smoke_Scenario)
      return String;

   --  Return whether a single scenario contributed to an overall pass.
   --
   --  A scenario contributes to a pass when its frame passed structural
   --  analysis and, for every non-default scenario, its framebuffer hash
   --  differs from the default scenario's hash (proving the state actually
   --  changed the render). This never asserts equality against a golden image.
   --
   --  @param Outcomes Per-scenario outcomes captured by the live smoke.
   --  @param Scenario Scenario to evaluate.
   --  @return True when the scenario passed and, if non-default, differs from
   --    the default scenario.
   function Scenario_Passed
     (Outcomes : Scenario_Outcome_Array;
      Scenario : Live_Smoke_Scenario)
      return Boolean;

   --  Aggregate the per-scenario outcomes into the overall live smoke verdict.
   --
   --  The verdict is a pure, headless decision: it passes only when every
   --  scenario passed structural analysis and every non-default scenario's
   --  framebuffer hash differs from the default scenario's hash. It is a robust
   --  inequality check, never a golden-image equality assertion.
   --
   --  @param Outcomes Per-scenario outcomes captured by the live smoke.
   --  @return True when every scenario contributed to a pass.
   function Scenarios_Verdict
     (Outcomes : Scenario_Outcome_Array)
      return Boolean;

   --  Classify a live-window smoke result into the CI gate taxonomy.
   --
   --  The mapping is pure and headless. A plan that was skipped or never
   --  attempted yields Live_Smoke_Skip, as does an attempted run in which no
   --  usable Vulkan device initialized (a missing or unusable ICD is an
   --  environment gap, not a rendering defect). An attempted run whose frame
   --  passed structural analysis, produced a framebuffer readback, and closed
   --  cleanly yields Live_Smoke_Pass; any other attempted run with a ready
   --  Vulkan device yields Live_Smoke_Fail.
   --
   --  @param Result Live smoke execution result to classify.
   --  @return Gate outcome describing pass, fail, or skip.
   function Gate_Outcome
     (Result : Live_Smoke_Result)
      return Live_Smoke_Gate;

end Files.Application.Windows.Smoke;

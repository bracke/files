--  Test-only access to Files.Application.Windows.Smoke's private part.
package Files.Application.Windows.Smoke.Testing is

   --  One window model rendered as --runtime-smoke renders each startup
   --  window (Smoke.Check_Window_Frame).
   --
   --  @param Model Window model to render.
   --  @param Settings Settings the window is drawn with.
   --  @param Width Framebuffer width used for frame construction.
   --  @param Height Framebuffer height used for frame construction.
   --  @return What the frame came to.
   function Check_Window_Frame
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check;

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

end Files.Application.Windows.Smoke.Testing;

package body Files.Application.Windows.Smoke.Testing is

   function Check_Window_Frame
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check
     renames Files.Application.Windows.Smoke.Check_Window_Frame;

   function Evaluate_Live_Window_Smoke
     (Plan : Live_Smoke_Plan)
      return Live_Smoke_Result renames Files.Application.Windows.Smoke.Evaluate_Live_Window_Smoke;

   function Scenarios_Verdict
     (Outcomes : Scenario_Outcome_Array)
      return Boolean renames Files.Application.Windows.Smoke.Scenarios_Verdict;

end Files.Application.Windows.Smoke.Testing;

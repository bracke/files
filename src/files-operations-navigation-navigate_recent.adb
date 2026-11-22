separate (Files.Operations.Navigation)
function Navigate_Recent
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   Files.Model.Navigate_Recent (Model, Files.Refresh.Load_Recent_Items (Settings));
   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Navigated);
end Navigate_Recent;

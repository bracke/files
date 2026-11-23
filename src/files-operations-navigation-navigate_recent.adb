separate (Files.Operations.Navigation)
function Navigate_Recent
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   --  Already shown, the view is listed again in place (keeping the place
   --  in it), not entered a second time.
   if Files.Model.Recent.In_Recent_View (Model) then
      return Files.Operations.Support.Reload_Current_Directory (Model, Settings, Preserve_Selection => True);
   end if;
   Files.Model.Navigate_Recent (Model, Files.Refresh.Load_Recent_Items (Settings));
   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Navigated);
end Navigate_Recent;

separate (Files.Operations)
function Refresh
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result is
begin
   if Files.Model.Background_Transfers (Model) then
      return Files.Refresh_Jobs.Start (Model, Settings, Force => True);
   end if;
   --  The virtual recent view has no backing directory to reload; rebuild its
   --  synthetic listing from the current recent paths instead.
   if Files.Model.In_Recent_View (Model) then
      return Navigate_Recent (Model, Settings);
   end if;
   --  Preserve the complete current selection across a manual refresh when
   --  those items still exist.
   return Reload_Current_Directory
     (Model, Settings, Preserve_Selection => True);
end Refresh;

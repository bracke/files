with Files.Model.Filtering;
with Files.Model.Jobs;
with Files.Model.Recent;
separate (Files.Operations)
function Refresh
  (Model         : in out Files.Model.Window_Model;
   Settings      : Files.Settings.Settings_Model;
   Measure_Again : Boolean := True)
   return Operation_Result is
begin
   --  Asked for by the user, so folder sizes are measured again too: a
   --  watched reload keeps them (a write deep inside a folder does not move
   --  the folder's own time, so nothing there says they are stale).
   if Measure_Again then
      Files.Model.Folder_Sizes.Clear (Model);
   end if;
   if Files.Model.Jobs.Background_Transfers (Model) then
      return Files.Refresh.Start (Model, Settings, Force => True);
   end if;
   --  The virtual recent view has no backing directory to reload; rebuild its
   --  synthetic listing from the current recent paths instead.
   if Files.Model.Recent.In_Recent_View (Model) then
      return Files.Operations.Navigation.Navigate_Recent (Model, Settings);
   end if;
   --  Refresh lists the folder again, ending a search as a forced
   --  background refresh does (Files.Refresh.Start); an operation's own
   --  reload searches again instead (Reload_Current_Directory).
   Files.Model.Filtering.Clear_Search_Results (Model);
   --  Preserve the complete current selection across a manual refresh when
   --  those items still exist.
   return Reload_Current_Directory
     (Model, Settings, Preserve_Selection => True);
end Refresh;

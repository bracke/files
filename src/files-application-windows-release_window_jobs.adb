separate (Files.Application.Windows)
procedure Release_Window_Jobs
  (Model : in out Files.Model.Window_Model;
   Watch : in out Files.Refresh_Jobs.Watch_Session) is
begin
   Files.Window_Polls.Cancel_Folder_Scan (Model);
   Files.Model.End_Foreground_Job (Model);
   Files.Refresh_Jobs.Cancel (Model);
   Files.Refresh_Jobs.Release_Watch (Watch);
end Release_Window_Jobs;

with Files.Operations.Paste;
separate (Files.Application.Windows)
procedure Release_Window_Jobs
  (Model : in out Files.Model.Window_Model;
   Watch : in out Files.Refresh.Watch_Session)
is
   use type Files.Model.Foreground_Job_Kind;
begin
   Files.Application.Window_Polls.Cancel_Folder_Scan (Model);
   if Files.Model.Foreground_Job_Is_Active (Model) then
      --  Asked to stop as the user's Cancel asks, not just dropped: a helper
      --  keeps its grace to put back an original it was replacing
      --  (Files.Jobs.Process), and what the paste did so far -- the
      --  originals it preserved among it -- reaches the history, which sends
      --  those to the system trash as the window ends. Dropped, the helper
      --  was killed mid-replace and the originals stayed in hidden stages.
      Files.Job_Drivers.Foreground.Cancel (Model);
      if Files.Model.Foreground_Job (Model) = Files.Model.Paste_Job then
         begin
            Files.Operations.Paste.Record_Paste_So_Far (Model);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Application.Windows");
         end;
      end if;
   end if;
   Files.Model.End_Foreground_Job (Model);
   Files.Refresh.Cancel (Model);
   Files.Refresh.Release_Watch (Watch);
end Release_Window_Jobs;

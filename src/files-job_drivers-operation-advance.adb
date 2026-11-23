with Files.Model.Jobs;
with Files.Model.Recent;
separate (Files.Job_Drivers.Operation)
function Advance
  (Model : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result
is
   Job       : constant Files.Jobs.Process.Session := Files.Model.Jobs.Background_Operation (Model);
   Transport : constant String := Files.Jobs.Process.Path (Job, "");
   Finished  : Boolean;
   Cancelled : Boolean := False;
   Done      : Outcome;
   Work      : Request;
   Same_View       : Boolean := False;
   --  Whether the failure handler could read which operation this was.
   Known_Kind      : Boolean := False;
   --  What already ran before a failure, so the handler does not run it
   --  again: a second merge would drop what was recorded after the
   --  first (an untracked creation), as the journal never held it.
   Merged          : Boolean := False;
   Settled         : Boolean := False;
   Recovered       : Boolean := False;
   --  The helper's journal could not be read even after Defer_Merge's
   --  grace: its history is given up, and the operation reports
   --  Undo_Lost_Key beside its own outcome.
   History_Lost    : Boolean := False;

   --  Leave the job, transport and all, for a later poll to merge its
   --  journal: the operation still shows as running meanwhile.
   Still_Finishing : constant Files.Operation_Results.Operation_Result :=
     (Status => Files.Operation_Results.Operation_Success, others => <>);

   --  Say, beside whatever the window now reports, that the history was
   --  given up -- for anything but a search, which records none. Called
   --  after the operation's own diagnostic is set and before a reload
   --  starts, so the reload keeps it.
   procedure Note_History_Lost (Kind : Operation_Kind) is separate;

   function Failed_Key return String is
     (if Known_Kind then Failure_Key (Work.Kind) else "error.operation.failed");

   --  The view the job started from is still on screen: no navigation since
   --  (not even away and back), and nothing that decides how it lists
   --  changed (Same_Listing: a zoom, a column or a recent path shared from
   --  another window does not), so it may refresh that view and report its
   --  diagnostic there even though edits in the view moved its revision.
   function Matches_Current_View
     (Candidate : Request)
      return Boolean is
     (Candidate.Root = Files.Model.Current_Path (Model)
      and then Candidate.Recent = Files.Model.Recent.In_Recent_View (Model)
      and then Files.Settings.Same_Listing (Candidate.Settings, Settings, Candidate.Recent)
      and then Candidate.View_Incarnation = Files.Model.View_Incarnation (Model));

   --  Additionally nothing listing-visible changed since the job started,
   --  so its directory snapshot can replace the items directly.
   function Matches_Current_Context
     (Candidate : Request)
      return Boolean is
     (Matches_Current_View (Candidate)
      and then Candidate.Context_Revision =
        Files.Model.Listing_Revision (Model));

   procedure Reload_Current_View (Select_Name : String := ""; Select_Path : String := "") is separate;

   --  What the operation reports: nothing, when it was cancelled.
   function Reported return Files.Operation_Results.Operation_Result is
     (if Cancelled then (Status => Files.Operation_Results.Operation_Success, others => <>) else Done.Result);

   function Choose return Disposition is separate;

   procedure Apply_Snapshot is separate;

   --  The operation's diagnostic in the view it ran in; a cancelled one
   --  clears it.
   function Report_In_View return Files.Operation_Results.Operation_Result is separate;

   --  Merge the helper's journal into the window's history (Merge_Journal),
   --  once: Merged is set when it is done with. A journal that cannot be
   --  read yet is left to a later poll (Defer_Merge) until Merge_Grace has
   --  passed; then its history is given up (History_Lost).
   --  @param Missing Set when there is no journal at all.
   --  @return False when it is left to a later poll: return Still_Finishing.
   function Settle_Journal (Missing : out Boolean) return Boolean is separate;

   --  The view the job started from, if still shown, says Key (nothing,
   --  when cancelled) and is read again; a history given up is said in
   --  any view, for an operation whose kind is known. Another view now
   --  shown is left be.
   procedure Conclude_In_Origin (Key : String; Kind_Known : Boolean) is separate;

   --  After a failure: what did not run yet runs once, and the operation
   --  fails with Failed_Key (or reports nothing, when cancelled).
   function Finish_Failed return Files.Operation_Results.Operation_Result is separate;

   --  What the helper renamed, moved or removed did happen, whatever the
   --  window shows now: labels and favorites follow it.
   procedure Note_Moves is separate;

   --  What a failed helper published, or one whose history was given up,
   --  is recovered from its own journal of what it created.
   procedure Recover_If_Owed (Choice : Disposition) is separate;

   --  Carry out Choice: the view work and what the operation reports.
   function Act_On (Choice : Disposition) return Files.Operation_Results.Operation_Result is separate;

   Missing_Journal : Boolean;
begin
   Files.Jobs.Process.Poll (Job, Finished, Cancelled);
   if not Finished then
      return (Status => Files.Operation_Results.Operation_Success, others => <>);
   end if;
   Done := Read_Outcome (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Result_File));
   Work := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
   if Done.Kind /= Work.Kind or else Done.Recent /= Work.Recent then
      raise Ada.IO_Exceptions.Data_Error;
   end if;
   --  Merged, not replaced: entries the journal left out stay, and what
   --  the merge retires has its payloads released here. A journal that
   --  cannot be read yet is asked for again on later polls, nothing else
   --  done meanwhile; only once Merge_Grace has passed is its history
   --  given up. None at all fails the operation, without reading again.
   if not Settle_Journal (Missing_Journal) then
      return Still_Finishing;
   elsif Missing_Journal then
      raise Ada.IO_Exceptions.Data_Error;
   end if;
   Note_Moves;
   Files.Operations.Undo_Recording.Settle_History (Model);
   Settled := True;
   Same_View := Matches_Current_View (Work);
   declare
      Choice : constant Disposition := Choose;
   begin
      Files.Model.Jobs.End_Foreground_Job (Model);
      Recover_If_Owed (Choice);
      if After_Merge /= null then
         --  Test seam: it raises, as if the view work had failed.
         After_Merge (Model);
      end if;
      return Act_On (Choice);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Job_Drivers.Operation");
      --  Only what did not run yet: a failure after the merge keeps what
      --  was recorded since. A journal that cannot be read yet keeps the
      --  job for a later poll, as on success: nothing else is done until
      --  it is read or given up.
      if not Merged and then not Settle_Journal (Missing_Journal) then
         return Still_Finishing;
      end if;
      return Finish_Failed;
end Advance;

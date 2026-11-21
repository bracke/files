with Files.UI_Types;
with Files.Model.Jobs;
with Files.Bounded_Streams;
with Files.Undo_Recording;
with Files.Window_Polls;
with Files.Helper_Modes;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with Files.Job_Context;
with Files.Job_Records;
with Files.Lease_Streams;
with Files.History_Journal;
with Files.Refresh_Jobs;
with Files.Process_Jobs;
with Files.Path_Checks;
with Files.Model.Pasting;
with Files.Model.History;
with Files.Model.Selection;
with Files.Settings.Path_References;
with Files.Undo_History;
with Ada.Real_Time;

package body Files.Operation_Jobs is
   use Ada.Strings.Unbounded;
   use type Files.Operation_Results.Operation_Status;
   use type Files.History_Journal.Read_Outcome;

   --  How long a finished helper whose journal could not be read is kept,
   --  its transport and all, its journal read once a poll, before its
   --  history is given up and the operation reported with Undo_Lost_Key.
   Merge_Grace : constant Duration := 2.0;

   --  What an operation whose helper's history could not be taken back
   --  reports beside its own outcome: what it did may not be undoable.
   Undo_Lost_Key : constant String := "error.operation.undo_unavailable";

   Request_Header : constant String := "files-operation-request-4";
   --  Version 2 dropped the operation result's copies of its action's
   --  executable, argument count and shell flag. The header changes with the
   --  layout so a helper from another build is refused, not misread.
   --  Version 3 carries the path moves as one list of (kind, from, to)
   --  records instead of two parallel path lists. Request version 4 adds
   --  the Sequence of the entry an Undo takes.
   Result_Header : constant String := "files-operation-result-3";

   package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  The message for a job of Kind that failed without saying why.
   function Failure_Key (Kind : Operation_Kind) return String is
     (case Kind is
         when Duplicate                          => "error.duplicate.failed",
         when Compress_Zip | Compress_Seven_Zip  => "error.compress.failed",
         when Extract                            => "error.extract.failed",
         when Search_Names | Search_Contents     => "error.search.failed",
         when Trash                              => "error.trash.failed",
         when Delete_Permanently                 => "error.permanent_delete.failed",
         when Restore                            => "error.trash.restore_failed",
         when Empty_Trash                        => "error.trash.empty_failed",
         when Undo                               => "error.undo.failed",
         when Redo                               => "error.redo.failed");

   function Valid_Absolute_Path (Path : String; Max_Length : Natural := Natural'Last) return Boolean
     renames Files.Path_Checks.Valid_Absolute_Path;

   function Request_Path_Is_Consistent
     (Root   : String;
      Recent : Boolean) return Boolean is
     ((if Recent then Root = "" else Valid_Absolute_Path (Root)));

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work : Request)
   is
   begin
      if not Request_Path_Is_Consistent
        (To_String (Work.Root), Work.Recent)
      then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Operation_Kind'Output (Stream, Work.Kind);
      Files.Bounded_Streams.Output_String
        (Stream, To_String (Work.Root), Files.Job_Records.Max_Path_Length);
      Boolean'Output (Stream, Work.Recent);
      Files.Bounded_Streams.Output_String
        (Stream, To_String (Work.Query), Files.Job_Records.Max_Text_Length);
      Files.Job_Records.Write_Items (Stream, Work.Selected);
      Files.Job_Records.Write_Settings (Stream, Work.Settings);
      Natural'Output (Stream, Work.Context_Revision);
      Natural'Output (Stream, Work.View_Incarnation);
      Natural'Output (Stream, Work.Undo_Sequence);
   end Write_Request;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work   : out Request) is
   begin
      Work.Kind := Operation_Kind'Input (Stream);
      Work.Root := To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Files.Job_Records.Max_Path_Length));
      Work.Recent := Boolean'Input (Stream);
      Work.Query :=
        To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Files.Job_Records.Max_Text_Length));
      Work.Selected := Files.Job_Records.Read_Items (Stream);
      Work.Settings := Files.Job_Records.Read_Settings (Stream);
      Work.Context_Revision := Natural'Input (Stream);
      Work.View_Incarnation := Natural'Input (Stream);
      Work.Undo_Sequence := Natural'Input (Stream);
   end Read_Request_Body;

   function Request_Is_Consistent (Work : Request) return Boolean is
     (Request_Path_Is_Consistent (To_String (Work.Root), Work.Recent));

   function Read_Request_Record is new Files.Lease_Streams.Read_Record
     (Request, Read_Request_Body, Request_Is_Consistent);

   function Read_Request (Path : String) return Request is
     (Read_Request_Record (Path, Request_Header, Long_Long_Integer (Files.Job_Records.Max_Transport_Bytes)));

   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done : Outcome)
   is
   begin
      String'Output (Stream, Result_Header);
      Operation_Kind'Output (Stream, Done.Kind);
      Boolean'Output (Stream, Done.Recent);
      Files.Job_Records.Write_Operation_Result (Stream, Done.Result);
      Files.Job_Records.Write_Items (Stream, Done.Items);
      Files.Bounded_Streams.Output_String
        (Stream, To_String (Done.Selection), Files.Job_Records.Max_Path_Length);
      Files.Bounded_Streams.Output_String
        (Stream, To_String (Done.Visible_Error),
         Files.Job_Records.Max_Error_Length);
      Files.Job_Records.Write_Signature (Stream, Done.Signature);
      Files.Job_Records.Write_Path_Moves (Stream, Done.Moves);
   end Write_Outcome;

   procedure Read_Outcome_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done   : out Outcome) is
   begin
      Done.Kind := Operation_Kind'Input (Stream);
      Done.Recent := Boolean'Input (Stream);
      Done.Result := Files.Job_Records.Read_Operation_Result (Stream);
      Done.Items := Files.Job_Records.Read_Items (Stream);
      Done.Selection :=
        To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Files.Job_Records.Max_Path_Length));
      Done.Visible_Error :=
        To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Files.Job_Records.Max_Error_Length));
      Done.Signature := Files.Job_Records.Read_Signature (Stream);
      Done.Moves := Files.Job_Records.Read_Path_Moves (Stream);
   end Read_Outcome_Body;

   --  Read_Path_Moves has checked every move against its kind already.
   function Outcome_Is_Consistent (Done : Outcome) return Boolean is
     (Natural (Done.Moves.Length) <= Files.Job_Records.Max_Path_Moves);

   function Read_Outcome_Record is new Files.Lease_Streams.Read_Record
     (Outcome, Read_Outcome_Body, Outcome_Is_Consistent);

   function Read_Outcome (Path : String) return Outcome is
     (Read_Outcome_Record (Path, Result_Header, Long_Long_Integer (Files.Job_Records.Max_Transport_Bytes)));

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind : Operation_Kind) return Files.Operation_Results.Operation_Result
   is
      Job  : Files.Process_Jobs.Session;
      Work : Request :=
        (Kind => Kind, Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Recent => Files.Model.In_Recent_View (Model), Query => To_Unbounded_String (Files.Model.Filter_Text (Model)),
         Selected => Files.Model.Selection.Selected_Items (Model), Settings => Settings,
         Context_Revision => 0,
         View_Incarnation => Files.Model.View_Incarnation (Model),
         Undo_Sequence    =>
           (if Kind = Undo and then not Files.Model.History.Undo_Entries (Model).Is_Empty
            then Files.Model.History.Undo_Entries (Model).Last_Element.Sequence
            else 0));
   begin
      if Files.Model.Foreground_Job_Is_Active (Model) or else Files.Model.Pasting.Conflict_Is_Active (Model) then
         return (Status => Files.Operation_Results.Operation_Disabled, others => <>);
      end if;
      if Kind in Search_Names | Search_Contents and then Length (Work.Query) = 0 then
         Files.Model.Set_Error (Model, "error.filter.empty");
         return (Status => Files.Operation_Results.Operation_Disabled,
                 Error_Key => To_Unbounded_String ("error.filter.empty"), others => <>);
      end if;
      if (Kind = Undo and then Files.Model.History.Undo_Entries (Model).Is_Empty)
        or else (Kind = Redo and then Files.Model.History.Redo_Entries (Model).Is_Empty)
      then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.undo.failed"), others => <>);
      end if;
      if Kind not in Search_Names | Search_Contents | Undo | Redo | Empty_Trash
        and then (Work.Selected.Is_Empty or else Files.Model.Selection.Includes_Temporary (Model))
      then
         declare
            --  Removing or restoring nothing is a selection problem; any other
            --  kind fails the way it fails without a reason of its own.
            Key : constant String :=
              (if Kind in Trash | Delete_Permanently | Restore then "error.selection.empty"
               else Failure_Key (Kind));
         begin
            Files.Model.Set_Error (Model, Key);
            return (Status    => Files.Operation_Results.Operation_Failed,
                    Error_Key => To_Unbounded_String (Key),
                    others    => <>);
         end;
      end if;
      --  Clearing an earlier diagnostic is itself listing-visible state. Capture
      --  the operation generation afterwards so ordinary startup does not make
      --  its own result stale, while later listing changes still do.
      Files.Model.Set_Error (Model, "");
      Work.Context_Revision := Files.Model.Listing_Revision (Model);
      Files.Process_Jobs.Reserve (Job);
      Files.History_Journal.Save_To
        (Files.Process_Jobs.Path (Job, ""), Files.Model.History.State (Model),
         Mode => Files.History_Journal.Must_Commit);
      declare
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Request (Stream, Work);
         end Write;
      begin
         Files.Process_Jobs.Launch_With_Request (Job, Files.Helper_Modes.Operation, Write'Access);
      end;
      Files.Model.Jobs.Begin_Operation_Job
        (Model, Job,
         (case Kind is
             when Duplicate => "command.file.duplicate",
             when Compress_Zip => "command.file.compress_zip",
             when Compress_Seven_Zip => "command.file.compress_7z",
             when Extract => "command.file.extract",
             when Search_Names => "command.directory.search_recursive",
             when Search_Contents => "command.search.contents",
             when Trash => "command.file.delete",
             when Delete_Permanently => "command.file.delete_permanently",
             when Restore => "command.trash.restore",
             when Empty_Trash => "command.trash.empty",
             when Undo => "command.edit.undo",
             when Redo => "command.edit.redo"));
      return (Status => Files.Operation_Results.Operation_Success, Path => Work.Root, others => <>);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operation_Jobs");
         Files.Process_Jobs.Reset (Job);
         Files.Model.Set_Error (Model, Failure_Key (Kind));
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String (Failure_Key (Kind)), others => <>);
   end Start;

   --  A redo the helper did not finish: each entry it published joins the
   --  top redo entry's progress (its identity, tree revision and completion
   --  marker), so a retry skips it instead of meeting it as a collision.
   procedure Recover_Redo_Progress
     (Model   : in out Files.Model.Window_Model;
      Created : Files.Job_Context.Journal_Entry_Vectors.Vector)
   is
      Undo_Stack : constant Files.Undo_History.Undo_Entry_Vectors.Vector := Files.Model.History.Undo_Entries (Model);
      Redo_Stack : Files.Undo_History.Undo_Entry_Vectors.Vector := Files.Model.History.Redo_Entries (Model);
   begin
      if Redo_Stack.Is_Empty then
         return;
      end if;
      declare
         Action : Files.Undo_History.Undo_Entry := Redo_Stack.Last_Element;
         --  Each destination's place in the entry, and what is completed:
         --  looked up per created entry, not scanned for.
         Places    : Index_Maps.Map;
         Completed : Files.Settings.Path_References.Path_Sets.Set;
      begin
         for Index in Action.Items.First_Index .. Action.Items.Last_Index loop
            if not Places.Contains (To_String (Action.Items (Index).From)) then
               Places.Insert (To_String (Action.Items (Index).From), Index);
            end if;
         end loop;
         for Path of Action.Forward_Completed loop
            Completed.Include (To_String (Path));
         end loop;
         for Published of Created loop
            declare
               Dest : constant String := To_String (Published.Destination);
            begin
               if Places.Contains (Dest) and then not Completed.Contains (Dest) then
                  Action.Items (Places.Element (Dest)).Identity := Published.Identity;
                  Action.Items (Places.Element (Dest)).Tree_Revision := Published.Tree_Revision;
                  Action.Forward_Completed.Append (Published.Destination);
                  Completed.Include (Dest);
               end if;
            end;
         end loop;
         Redo_Stack.Replace_Element (Redo_Stack.Last_Index, Action);
         Files.Model.History.Restore (Model, Undo_Stack, Redo_Stack);
      end;
   end Recover_Redo_Progress;

   --  What a creating helper published that no undo entry records becomes
   --  one undo-only entry, verified as published, so it can still be undone.
   procedure Record_Untracked_Creations
     (Model   : in out Files.Model.Window_Model;
      Created : Files.Job_Context.Journal_Entry_Vectors.Vector)
   is
      Untracked : Files.Undo_History.Undo_Item_Vectors.Vector;
      --  Every path the undo history already records as created.
      Recorded : Files.Settings.Path_References.Path_Sets.Set;
   begin
      for Action of Files.Model.History.Undo_Entries (Model) loop
         for Item of Action.Items loop
            Recorded.Include (To_String (Item.From));
         end loop;
      end loop;
      for Published of Created loop
         if not Recorded.Contains (To_String (Published.Destination)) then
            Untracked.Append
              (Files.Undo_History.Undo_Item'
                 (From          => Published.Destination,
                  Identity      => Published.Identity,
                  Tree_Revision => Published.Tree_Revision,
                  others        => <>));
         end if;
      end loop;
      if not Untracked.Is_Empty then
         Files.Undo_Recording.Record_Undo
           (Model, Files.Undo_History.Undo_Delete_Created, Files.Undo_Recording.Verified (Untracked),
            Redoable => False);
      end if;
   end Record_Untracked_Creations;

   --  A finished helper's journal merged into the window's history: read
   --  once, without waiting. One there but not readable this moment
   --  (another process holding it, a transient refusal) answers Unreadable,
   --  and Advance keeps the job and reads it again on a later poll
   --  (Defer_Merge). None at all is not waited for.
   function Merge_Journal
     (Directory : String;
      Model     : in out Files.Model.Window_Model)
      return Files.History_Journal.Read_Outcome
   is
      Journal : Files.History_Journal.Journal_Contents;
      Outcome : constant Files.History_Journal.Read_Outcome := Files.History_Journal.Read (Directory, Journal);
   begin
      if Outcome = Files.History_Journal.Read_Whole then
         Files.Model.History.Merge (Model, Journal.Undo, Journal.Redo, Journal.State);
      end if;
      return Outcome;
   end Merge_Journal;

   --  Leave the merge of the modal job's unreadable journal to a later
   --  poll, unless Merge_Grace has passed since its first refusal. The wait
   --  is the window's (Files.Model.Jobs.Defer_Operation_Merge), so it ends with
   --  the job however the job ends.
   --  @return True when it is left to a later poll.
   function Defer_Merge (Model : in out Files.Model.Window_Model; Directory : String) return Boolean is
      use type Ada.Real_Time.Time;
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      if not Files.Model.Jobs.Operation_Merge_Deferred (Model) then
         Files.Model.Jobs.Defer_Operation_Merge (Model, Now + Ada.Real_Time.To_Time_Span (Merge_Grace));
         return True;
      elsif Now < Files.Model.Jobs.Operation_Merge_Deadline (Model) then
         return True;
      end if;
      Files.Diagnostics.Trace ("Files.Operation_Jobs", "history_journal_given_up=" & Directory);
      return False;
   end Defer_Merge;

   --  A helper that ended without success, or whose journal could not be
   --  read, may still have published entries: read from its own journal of
   --  what it created, they join the history. An Undo whose journal was
   --  lost though it succeeded (Undone) did the step its request named:
   --  that entry leaves the undo stack, so Undo is not offered for it again,
   --  and Redo is not offered: what the helper would have recorded for it is
   --  lost, and the older steps the redo stack held are retired with it.
   procedure Recover_Undo
     (Model  : in out Files.Model.Window_Model;
      Job    : Files.Process_Jobs.Session;
      Undone : Boolean := False)
   is
      Work : constant Request := Read_Request (Files.Process_Jobs.Path (Job, Files.Process_Jobs.Request_File));
   begin
      if Work.Kind = Redo then
         Recover_Redo_Progress (Model, Files.Job_Context.Read_Created (Files.Process_Jobs.Path (Job, "")));
      elsif Work.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract then
         Record_Untracked_Creations (Model, Files.Job_Context.Read_Created (Files.Process_Jobs.Path (Job, "")));
      elsif Work.Kind = Undo and then Undone then
         if Files.Model.History.Drop_Undone (Model, Work.Undo_Sequence) then
            Files.Undo_Recording.Settle_History (Model);
         else
            Files.Diagnostics.Trace
              ("Files.Operation_Jobs", "undone_entry_not_newest=" & Files.Types.Natural_Text (Work.Undo_Sequence));
         end if;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operation_Jobs");
   end Recover_Undo;

   --  What a finished operation does to the window's view:
   --    * Discard: a search for a view or query no longer shown is dropped.
   --    * Reload_View: a destructive operation, or a creating one that failed
   --      or was cancelled, has the view it started from read again.
   --    * Apply_Snapshot: its listing, of the view as it still is, replaces
   --      the items.
   --    * Owe_Reload: same view, but a later listing change: read again once
   --      its diagnostic is final.
   --    * Report: same view, nothing to show but its diagnostic.
   --    * Leave_View: another view is shown now; its result is returned and
   --      the view left be.
   type Disposition is (Discard, Reload_View, Apply_Snapshot, Owe_Reload, Report, Leave_View);

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result
   is
      Job       : constant Files.Process_Jobs.Session := Files.Model.Jobs.Background_Operation (Model);
      Transport : constant String := Files.Process_Jobs.Path (Job, "");
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
      procedure Note_History_Lost (Kind : Operation_Kind) is
      begin
         if History_Lost and then Kind not in Search_Names | Search_Contents then
            if Files.Model.Last_Error_Key (Model) = "" then
               Files.Model.Set_Error (Model, Undo_Lost_Key);
            else
               Files.Model.Set_Error_Notice (Model, Undo_Lost_Key);
            end if;
         end if;
      end Note_History_Lost;

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
         and then Candidate.Recent = Files.Model.In_Recent_View (Model)
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

      procedure Reload_Current_View (Select_Name : String := "") is
         Reload : constant Files.Operation_Results.Operation_Result :=
           Files.Refresh_Jobs.Start (Model, Settings, True, Select_Name);
         pragma Unreferenced (Reload);
      begin
         null;
      end Reload_Current_View;

      --  What the operation reports: nothing, when it was cancelled.
      function Reported return Files.Operation_Results.Operation_Result is
        (if Cancelled then (Status => Files.Operation_Results.Operation_Success, others => <>) else Done.Result);

      function Choose return Disposition is
         Succeeded : constant Boolean :=
           not Cancelled and then Done.Result.Status = Files.Operation_Results.Operation_Success;
      begin
         if Done.Kind in Search_Names | Search_Contents
           and then (not Matches_Current_Context (Work) or else Work.Query /= Files.Model.Filter_Text (Model))
         then
            return Discard;
         elsif Done.Kind in Trash | Delete_Permanently | Restore | Empty_Trash | Undo | Redo
           or else (Done.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract and then not Succeeded)
         then
            return Reload_View;
         elsif Succeeded and then Matches_Current_Context (Work) then
            return Apply_Snapshot;
         elsif not Same_View then
            return Leave_View;
         elsif Succeeded and then Done.Kind not in Search_Names | Search_Contents then
            return Owe_Reload;
         else
            return Report;
         end if;
      end Choose;

      procedure Apply_Snapshot is
      begin
         if Done.Recent then
            Files.Model.Navigate_Recent (Model, Done.Items);
         else
            Files.Model.Replace_Items (Model, Done.Items);
         end if;
         Files.Model.Set_Directory_Signature (Model, Done.Signature);
         if Done.Kind in Search_Names | Search_Contents then
            Files.Model.Note_Search_Results
              (Model,
               (if Done.Kind = Search_Names then Files.UI_Types.Search_Names
                else Files.UI_Types.Search_Contents));
         else
            Files.Model.Clear_Search_Results (Model);
            if Length (Done.Selection) > 0 then
               declare
                  Selected : constant Boolean :=
                    Files.Model.Selection.Select_By_Name (Model, To_String (Done.Selection));
                  pragma Unreferenced (Selected);
               begin
                  null;
               end;
            end if;
         end if;
      end Apply_Snapshot;

      --  The operation's diagnostic in the view it ran in; a cancelled one
      --  clears it.
      function Report_In_View return Files.Operation_Results.Operation_Result is
      begin
         if Cancelled then
            Files.Model.Set_Error (Model, "");
            return Reported;
         end if;
         Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
         Note_History_Lost (Done.Kind);
         Files.Window_Polls.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
         return Done.Result;
      end Report_In_View;

      --  Merge the helper's journal into the window's history (Merge_Journal),
      --  once: Merged is set when it is done with. A journal that cannot be
      --  read yet is left to a later poll (Defer_Merge) until Merge_Grace has
      --  passed; then its history is given up (History_Lost).
      --  @param Missing Set when there is no journal at all.
      --  @return False when it is left to a later poll: return Still_Finishing.
      function Settle_Journal (Missing : out Boolean) return Boolean is
      begin
         Missing := False;
         case Merge_Journal (Transport, Model) is
            when Files.History_Journal.Read_Whole =>
               null;
            when Files.History_Journal.Unreadable =>
               if Defer_Merge (Model, Transport) then
                  return False;
               end if;
               History_Lost := True;
            when Files.History_Journal.No_Journal =>
               Missing := True;
         end case;
         Merged := True;
         return True;
      end Settle_Journal;

      --  The view the job started from, if still shown, says Key (nothing,
      --  when cancelled) and is read again; a history given up is said in
      --  any view, for an operation whose kind is known. Another view now
      --  shown is left be.
      procedure Conclude_In_Origin (Key : String; Kind_Known : Boolean) is
      begin
         if Same_View then
            Files.Model.Set_Error (Model, (if Cancelled then "" else Key));
         end if;
         if Kind_Known then
            Note_History_Lost (Work.Kind);
         end if;
         if Same_View then
            Reload_Current_View;
         end if;
      end Conclude_In_Origin;

      --  After a failure: what did not run yet runs once, and the operation
      --  fails with Failed_Key (or reports nothing, when cancelled).
      function Finish_Failed return Files.Operation_Results.Operation_Result is
      begin
         --  Outcome decoding can fail before the request was read. Recover its
         --  identity independently so a same-view mutation is still reloaded,
         --  while an old job cannot disturb a newer view.
         begin
            Work := Read_Request (Files.Process_Jobs.Path (Job, Files.Process_Jobs.Request_File));
            Known_Kind := True;
            Same_View := Matches_Current_View (Work);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Operation_Jobs");
               Same_View := False;
         end;
         Files.Model.End_Foreground_Job (Model);
         if not Settled then
            Files.Undo_Recording.Settle_History (Model);
         end if;
         if not Recovered then
            Recover_Undo (Model, Job);
         end if;
         --  Even an interrupted destructive operation may have changed its
         --  original view, but it must not refresh a different current view.
         Conclude_In_Origin (Failed_Key, Known_Kind);
         if Cancelled then
            return (Status => Files.Operation_Results.Operation_Success, others => <>);
         end if;
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String (Failed_Key), others => <>);
      end Finish_Failed;

      Missing_Journal : Boolean;
   begin
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      if not Finished then
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      end if;
      Done := Read_Outcome (Files.Process_Jobs.Path (Job, Files.Process_Jobs.Result_File));
      Work := Read_Request (Files.Process_Jobs.Path (Job, Files.Process_Jobs.Request_File));
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
      --  What the helper renamed, moved or removed did happen, whatever the
      --  window shows now: labels and favorites follow it.
      for Move of Done.Moves loop
         case Move.Kind is
            when Files.Types.Removed =>
               Files.Model.Note_Path_Removed (Model, To_String (Move.From));
            when Files.Types.Moved =>
               Files.Model.Note_Path_Move (Model, To_String (Move.From), To_String (Move.To));
         end case;
      end loop;
      Files.Undo_Recording.Settle_History (Model);
      Settled := True;
      Same_View := Matches_Current_View (Work);
      declare
         Choice : constant Disposition := Choose;
      begin
         Files.Model.End_Foreground_Job (Model);
         --  What a failed helper published, or one whose history was given
         --  up, is recovered from its own journal of what it created.
         if Choice /= Discard
           and then (History_Lost or else Done.Result.Status /= Files.Operation_Results.Operation_Success)
         then
            Recover_Undo
              (Model, Job,
               Undone =>
                 History_Lost and then not Cancelled
                 and then Done.Result.Status = Files.Operation_Results.Operation_Success);
            Recovered := True;
         end if;
         if After_Merge /= null then
            --  Test seam: it raises, as if the view work had failed.
            After_Merge (Model);
         end if;
         case Choice is
            when Discard =>
               return (Status => Files.Operation_Results.Operation_Success, others => <>);
            when Reload_View =>
               --  Finalize error/history before the refresh captures this
               --  revision. A result from an older view must not refresh or
               --  alter the diagnostic of the view now displayed, but an
               --  edit within the same view must not cost it the reload.
               Conclude_In_Origin (To_String (Done.Visible_Error), Kind_Known => True);
               return Reported;
            when Leave_View =>
               --  The filesystem work and restored history remain valid, but
               --  its directory snapshot and diagnostic belong to the view it
               --  started from, not the one now displayed. A history given
               --  up is still said, as it concerns the window's Undo.
               Note_History_Lost (Done.Kind);
               return Reported;
            when Apply_Snapshot =>
               Apply_Snapshot;
               return Report_In_View;
            when Owe_Reload =>
               --  Its snapshot predates a later listing change: reread it
               --  rather than leave the operation's new entries unlisted,
               --  once the diagnostic it must preserve is final.
               Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
               Note_History_Lost (Done.Kind);
               Reload_Current_View (To_String (Done.Selection));
               Files.Window_Polls.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
               return Done.Result;
            when Report =>
               return Report_In_View;
         end case;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operation_Jobs");
         --  Only what did not run yet: a failure after the merge keeps what
         --  was recorded since. A journal that cannot be read yet keeps the
         --  job for a later poll, as on success: nothing else is done until
         --  it is read or given up.
         if not Merged and then not Settle_Journal (Missing_Journal) then
            return Still_Finishing;
         end if;
         return Finish_Failed;
   end Advance;
end Files.Operation_Jobs;

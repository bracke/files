with Files.Model.Recent;
with Files.Model.Filtering;
with Files.UI_Types;
with Files.Model.Jobs;
with Files.IO.Record_Fields;
with Files.Operations.Undo_Recording;
with Files.Jobs.Helper_Modes;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with Files.Jobs.Context;
with Files.Job_Payloads;
with Files.Jobs.Records;
with Files.IO.Lease_Streams;
with Files.Undo.Journal;
with Files.Refresh;
with Files.Jobs.Process;
with Files.Path_Checks;
with Files.Model.Pasting;
with Files.Model.History;
with Files.Model.Selection;
with Files.Settings.Path_References;
with Files.Undo.History;
with Ada.Real_Time;
with Files.Text_Basics;

package body Files.Job_Drivers.Operation is
   use Ada.Strings.Unbounded;
   use type Files.Operation_Results.Operation_Status;
   use type Files.Undo.Journal.Read_Outcome;

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
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Root), Files.Jobs.Records.Max_Path_Length);
      Boolean'Output (Stream, Work.Recent);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Query), Files.Jobs.Records.Max_Text_Length);
      Files.Job_Payloads.Write_Items (Stream, Work.Selected);
      Files.Job_Payloads.Write_Settings (Stream, Work.Settings);
      Natural'Output (Stream, Work.Context_Revision);
      Natural'Output (Stream, Work.View_Incarnation);
      Natural'Output (Stream, Work.Undo_Sequence);
   end Write_Request;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work   : out Request) is
   begin
      Work.Kind := Operation_Kind'Input (Stream);
      Work.Root :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Recent := Boolean'Input (Stream);
      Work.Query :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Text_Length));
      Work.Selected := Files.Job_Payloads.Read_Items (Stream);
      Work.Settings := Files.Job_Payloads.Read_Settings (Stream);
      Work.Context_Revision := Natural'Input (Stream);
      Work.View_Incarnation := Natural'Input (Stream);
      Work.Undo_Sequence := Natural'Input (Stream);
   end Read_Request_Body;

   function Request_Is_Consistent (Work : Request) return Boolean is
     (Request_Path_Is_Consistent (To_String (Work.Root), Work.Recent));

   function Read_Request_Record is new Files.IO.Lease_Streams.Read_Record
     (Request, Read_Request_Body, Request_Is_Consistent);

   function Read_Request (Path : String) return Request is
     (Read_Request_Record (Path, Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done : Outcome)
   is
   begin
      String'Output (Stream, Result_Header);
      Operation_Kind'Output (Stream, Done.Kind);
      Boolean'Output (Stream, Done.Recent);
      Files.Job_Payloads.Write_Operation_Result (Stream, Done.Result);
      Files.Job_Payloads.Write_Items (Stream, Done.Items);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Done.Selection), Files.Jobs.Records.Max_Path_Length);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Done.Visible_Error),
         Files.Jobs.Records.Max_Error_Length);
      Files.Jobs.Records.Write_Signature (Stream, Done.Signature);
      Files.Jobs.Records.Write_Path_Moves (Stream, Done.Moves);
   end Write_Outcome;

   procedure Read_Outcome_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done   : out Outcome) is
   begin
      Done.Kind := Operation_Kind'Input (Stream);
      Done.Recent := Boolean'Input (Stream);
      Done.Result := Files.Job_Payloads.Read_Operation_Result (Stream);
      Done.Items := Files.Job_Payloads.Read_Items (Stream);
      Done.Selection :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Done.Visible_Error :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
      Done.Signature := Files.Jobs.Records.Read_Signature (Stream);
      Done.Moves := Files.Jobs.Records.Read_Path_Moves (Stream);
   end Read_Outcome_Body;

   --  Read_Path_Moves has checked every move against its kind already.
   function Outcome_Is_Consistent (Done : Outcome) return Boolean is
     (Natural (Done.Moves.Length) <= Files.Jobs.Records.Max_Path_Moves);

   function Read_Outcome_Record is new Files.IO.Lease_Streams.Read_Record
     (Outcome, Read_Outcome_Body, Outcome_Is_Consistent);

   function Read_Outcome (Path : String) return Outcome is
     (Read_Outcome_Record (Path, Result_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind : Operation_Kind) return Files.Operation_Results.Operation_Result
   is
      Job  : Files.Jobs.Process.Session;
      Work : Request :=
        (Kind => Kind, Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Recent => Files.Model.Recent.In_Recent_View (Model),
         Query => To_Unbounded_String (Files.Model.Filtering.Filter_Text (Model)),
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
      Files.Jobs.Process.Reserve (Job);
      Files.Undo.Journal.Save_To
        (Files.Jobs.Process.Path (Job, ""), Files.Model.History.State (Model),
         Mode => Files.Undo.Journal.Must_Commit);
      declare
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Request (Stream, Work);
         end Write;
      begin
         Files.Jobs.Process.Launch_With_Request (Job, Files.Jobs.Helper_Modes.Operation, Write'Access);
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
         Files.Diagnostics.Note (Swallowed, "Files.Job_Drivers.Operation");
         Files.Jobs.Process.Reset (Job);
         Files.Model.Set_Error (Model, Failure_Key (Kind));
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String (Failure_Key (Kind)), others => <>);
   end Start;

   --  A redo the helper did not finish: each entry it published joins the
   --  top redo entry's progress (its identity, tree revision and completion
   --  marker), so a retry skips it instead of meeting it as a collision.
   procedure Recover_Redo_Progress
     (Model   : in out Files.Model.Window_Model;
      Created : Files.Jobs.Context.Journal_Entry_Vectors.Vector)
   is
      Undo_Stack : constant Files.Undo.History.Undo_Entry_Vectors.Vector := Files.Model.History.Undo_Entries (Model);
      Redo_Stack : Files.Undo.History.Undo_Entry_Vectors.Vector := Files.Model.History.Redo_Entries (Model);
   begin
      if Redo_Stack.Is_Empty then
         return;
      end if;
      declare
         Action : Files.Undo.History.Undo_Entry := Redo_Stack.Last_Element;
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
      Created : Files.Jobs.Context.Journal_Entry_Vectors.Vector)
   is
      Untracked : Files.Undo.History.Undo_Item_Vectors.Vector;
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
              (Files.Undo.History.Undo_Item'
                 (From          => Published.Destination,
                  Identity      => Published.Identity,
                  Tree_Revision => Published.Tree_Revision,
                  others        => <>));
         end if;
      end loop;
      if not Untracked.Is_Empty then
         Files.Operations.Undo_Recording.Record_Undo
           (Model, Files.Undo.History.Undo_Delete_Created, Files.Operations.Undo_Recording.Verified (Untracked),
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
      return Files.Undo.Journal.Read_Outcome
   is
      Journal : Files.Undo.Journal.Journal_Contents;
      Outcome : constant Files.Undo.Journal.Read_Outcome := Files.Undo.Journal.Read (Directory, Journal);
   begin
      if Outcome = Files.Undo.Journal.Read_Whole then
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
      Files.Diagnostics.Trace ("Files.Job_Drivers.Operation", "history_journal_given_up=" & Directory);
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
      Job    : Files.Jobs.Process.Session;
      Undone : Boolean := False)
   is
      Work : constant Request := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
   begin
      if Work.Kind = Redo then
         Recover_Redo_Progress (Model, Files.Jobs.Context.Read_Created (Files.Jobs.Process.Path (Job, "")));
      elsif Work.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract then
         Record_Untracked_Creations (Model, Files.Jobs.Context.Read_Created (Files.Jobs.Process.Path (Job, "")));
      elsif Work.Kind = Undo and then Undone then
         if Files.Model.History.Drop_Undone (Model, Work.Undo_Sequence) then
            Files.Operations.Undo_Recording.Settle_History (Model);
         else
            Files.Diagnostics.Trace
              ("Files.Job_Drivers.Operation",
               "undone_entry_not_newest=" & Files.Text_Basics.Natural_Text (Work.Undo_Sequence));
         end if;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Job_Drivers.Operation");
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
   is separate;
end Files.Job_Drivers.Operation;

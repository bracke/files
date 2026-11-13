--  A paste, a drop or a Copy to.../Move to... as the model holds it: the
--  conflict dialog that resolves its collisions, and the execution that
--  works through its resolved actions, with the transfer job that runs
--  them.
package Files.Model.Pasting is

   --  Enter the pending paste-conflict sub-mode. The work-list, the set of
   --  existing destination paths, and the copy/move mode are recorded, the
   --  policy starts at Policy_Ask with no per-item overrides, and the dialog is
   --  positioned at the first unresolved conflict (Index).
   --
   --  @param Model Model to update.
   --  @param Items Full paste work-list.
   --  @param Existing Destination paths that already exist.
   --  @param Mode Copy or move mode for the whole batch.
   --  @param Index One-based index of the first unresolved conflict.
   --  @param Clear_Clipboard Whether finalizing a move should clear the
   --    clipboard (True for clipboard paste, False for drag-and-drop).
   procedure Begin_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True);

   --  The paste-conflict state as it stands: what the dialog asks about,
   --  and the choices made so far. A copy, for a caller that reads several
   --  of its fields once (resolving a choice).
   --
   --  @param Model Model to inspect.
   --  @return A copy of the conflict state.
   function Conflict_Of (Model : Window_Model) return Paste_Conflict_State;

   --  Whether the pending paste-conflict dialog is active.
   --
   --  @param Model Model to inspect.
   --  @return True while a paste is paused awaiting conflict decisions.
   function Conflict_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The leaf name of the conflict currently shown.
   --
   --  @param Model Model to inspect.
   --  @return The colliding destination name, or "" when inactive.
   function Conflict_Name
     (Model : Window_Model)
      return String;

   --  Whether the dialog's "apply to all remaining" toggle is on.
   --
   --  @param Model Model to inspect.
   --  @return True when the next decision should apply to every remaining conflict.
   function Conflict_Apply_All
     (Model : Window_Model)
      return Boolean;

   --  Flip the dialog's "apply to all remaining" toggle.
   --
   --  @param Model Model to update.
   procedure Toggle_Conflict_Apply_All
     (Model : in out Window_Model);

   --  Record the batch-wide policy (used when a decision is applied to all).
   --
   --  @param Model Model to update.
   --  @param Policy New conflict policy.
   procedure Set_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy);

   --  Record a per-item decision for one work-list index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index.
   --  @param Decision Chosen per-item decision.
   procedure Set_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision);

   --  Move the dialog to a different conflict index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index of the next conflict.
   procedure Set_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive);

   --  Clear the pending paste-conflict sub-mode, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Conflict
     (Model : in out Window_Model);

   --  Arm a resumable paste execution from a fully resolved action list. The
   --  execution starts at the first action with no items completed; Total counts
   --  only the actions that actually write (non-skip), so progress reflects the
   --  real copies/moves. The batched driver advances it a few actions at a time.
   --
   --  @param Model Model to update.
   --  @param Actions Fully resolved paste actions (post conflict resolution).
   --  @param Mode Copy or move mode for the whole batch.
   --  @param Clear_Clipboard Whether finalizing a move should clear the
   --    clipboard (True for clipboard paste, False for drag-and-drop).
   --  @param Batch The copy context the writes share (hard links kept as
   --    links), made by the caller: the model makes no transport itself.
   procedure Begin_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True;
      Batch           : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  The paste being carried out, as it stands. A copy, for a caller that
   --  reads several of its fields once (finishing the paste); progress read
   --  every frame has its own queries, which copy nothing.
   --
   --  @param Model Model to inspect.
   --  @return A copy of the execution state.
   function Execution_Of (Model : Window_Model) return Paste_Execution_State;

   --  The helper running the current paste action: a handle the model holds
   --  as data, which Files.Operations starts, polls and cancels.
   --
   --  @param Model Window to inspect.
   --  @return Its transfer session (inactive between actions).
   function Job (Model : Window_Model) return Files.Transfer_Jobs.Session;

   --  Store the transfer session after driving it.
   --
   --  @param Model Window to update.
   --  @param Job Its transfer session.
   procedure Set_Job (Model : in out Window_Model; Job : Files.Transfer_Jobs.Session);

   --  The current paste action has been handed to a helper: show its name.
   --
   --  @param Model Window to update.
   procedure Note_Action_Started (Model : in out Window_Model);

   --  Whether a resumable paste execution is currently in flight.
   --
   --  @param Model Model to inspect.
   --  @return True between Begin_Execution and Clear_Execution.
   function Execution_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The number of write actions completed so far.
   --
   --  @param Model Model to inspect.
   --  @return Count of items already copied or moved.
   function Execution_Done
     (Model : Window_Model)
      return Natural;

   --  The total number of write actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of items to copy or move (skips excluded).
   function Execution_Total
     (Model : Window_Model)
      return Natural;

   --  The leaf name of the item most recently written, for the progress display.
   --
   --  @param Model Model to inspect.
   --  @return The current item's simple name, or "" before the first write.
   function Execution_Current_Name
     (Model : Window_Model)
      return String;

   --  The copy/move mode of the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Copy or move mode.
   function Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode;

   --  Whether the armed execution has been asked to cancel.
   --
   --  @param Model Model to inspect.
   --  @return True once Cancel_Paste_Execution has been requested.
   function Execution_Cancelled
     (Model : Window_Model)
      return Boolean;

   --  The cursor position: the number of actions already consumed.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based count of processed actions (writes and skips).
   function Execution_Cursor
     (Model : Window_Model)
      return Natural;

   --  The number of resolved actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of actions (writes and skips).
   function Execution_Action_Count
     (Model : Window_Model)
      return Natural;

   --  The resolved action at a one-based index.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based action index (1 .. Execution_Action_Count).
   --  @return The resolved action to execute.
   function Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action;

   --  @param Model Window owning the active copy batch.
   --  @return Shared private hard-link journal, or an empty session.
   function Execution_Copy_Context (Model : Window_Model) return Files.Copy_Context.Session;

   --  Whether a preserved original recorded next would extend the verified
   --  prefix, i.e. every original recorded so far was verified. Only then
   --  does the operations layer check the live entry before recording.
   --  @param Model Window owning the current paste batch.
   --  @return True when all recorded originals are verified.
   function Replaced_Extends_Verified
     (Model : Window_Model) return Boolean;

   --  Record a preserved original and its identity for the paste's Undo.
   --  The operations layer resolves the original destination and checks the
   --  live entry first; this touches no filesystem.
   --  @param Model Model to update.
   --  @param Trash_Path The overwritten original's location inside the trash.
   --  @param Identity Snapshot captured when the original was preserved.
   --  @param Original_Path Original destination of the preserved entry.
   --  @param Verified True when the live entry at Trash_Path matched Identity
   --    while the verified prefix could still be extended.
   procedure Record_Replaced_Trash
     (Model : in out Window_Model; Trash_Path : Files.Types.UString; Identity : String;
      Original_Path : String; Verified : Boolean);

   --  Advance the cursor past a skipped action without recording a write.
   --
   --  @param Model Model to update.
   procedure Skip_Action
     (Model : in out Window_Model);

   --  Record a completed write: advance the cursor, bump Done, remember the
   --  current name and first destination, and accumulate the undo pair.
   --
   --  @param Model Model to update.
   --  @param Dest_Path Destination path just written.
   --  @param Source_Path Source path just copied or moved.
   --  @param Name Leaf name shown as the current progress item.
   --  @param Identity Entry identity captured by the process that published the destination.
   --  @param Tree_Revision Directory or regular-file revision captured before publication.
   --  @param Verified True when the publication snapshot was verified (by a
   --    recovery checkpoint or against the live entry by the operations
   --    layer) while the verified prefix could still be extended.
   procedure Record_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String;
      Identity    : String;
      Tree_Revision : String;
      Verified    : Boolean);

   --  Whether a write recorded next would extend the verified prefix, i.e.
   --  every write recorded so far was verified. Only then does the operations
   --  layer check the published entry before recording.
   --  @param Model Window owning the current paste batch.
   --  @return True when all recorded writes are verified.
   function Write_Extends_Verified
     (Model : Window_Model) return Boolean;

   --  Record how a cancellation of the armed execution went: when every
   --  helper was told (Files.Operations.Cancel_Paste_Execution tells them),
   --  the next advance finalizes over the items completed so far
   --  (already-written files are kept); otherwise it stays cancellable.
   --
   --  @param Model Model to update.
   --  @param Requested Whether every helper accepted the request.
   procedure Set_Cancelled
     (Model     : in out Window_Model;
      Requested : Boolean);

   --  Clear the resumable paste execution, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Execution
     (Model : in out Window_Model);

end Files.Model.Pasting;

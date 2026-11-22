with Files.File_System_Types;
with Files.Model;
with Files.Paste;
with Files.Settings;
with Files.Types;

--  Pasting and dropping: planning a paste, asking about conflicts, running it
--  step by step, and recording its one Undo.
package Files.Operations.Paste is

   --  A user's answer to a paste-conflict prompt (mirrors the dialog buttons).
   type Conflict_Choice is
     (Choice_Replace,
      Choice_Skip,
      Choice_Rename,
      Choice_Cancel);

   --  Begin a clipboard paste (copy or move) into the current directory,
   --  resolving name collisions interactively.
   --
   --  Sources are validated as for a drag-and-drop import. When no destination
   --  name collides the paste executes immediately (identical to the old
   --  behaviour minus the silent auto-rename). When one or more names collide,
   --  the model enters the pending paste-conflict sub-mode so the shell can show
   --  the conflict dialog; nothing is written until the user resolves them.
   --
   --  Also the entry point for drag-and-drop imports into the current directory:
   --  callers pass From_Clipboard => False so that finalizing a move does not
   --  clear the (unrelated) clipboard.
   --
   --  @param Model Window model receiving the pasted paths.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Source_Paths Clipboard or dropped source paths.
   --  @param Mode Copy or move (cut) mode.
   --  @param From_Clipboard True for a clipboard paste (a completed move clears
   --    the clipboard), False for a drag-and-drop import.
   --  @return Success when executed or when the dialog was armed; a failure
   --    result with a localized error key on a validation failure.
   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result;

   --  Begin a copy or move of the given sources into an explicit destination
   --  directory, using the same collision handling and resumable progress
   --  execution as Begin_Paste (which is this with Destination = current path).
   --  Used by the Copy to.../Move to... destination picker and by drag-and-drop
   --  imports onto a specific target directory.
   --
   --  @param Model Window model receiving the operation.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Source_Paths Source paths to copy or move.
   --  @param Destination Directory that receives the entries.
   --  @param Mode Copy or move mode.
   --  @param From_Clipboard True for a clipboard paste (a completed move clears
   --    the clipboard), False for a drag-and-drop import.
   --  @return Success when executed or when the conflict dialog was armed; a
   --    failure result with a localized error key on a validation failure.
   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result;

   --  Apply one conflict decision to the pending paste. Records the choice
   --  (per-item, or batch-wide when Apply_All is set), then either advances to
   --  the next unresolved conflict or, once none remain, executes the resolved
   --  copies/moves, records undo, reloads, and clears the sub-mode. Choice_Cancel
   --  aborts the whole paste with no filesystem change.
   --
   --  @param Model Window model in the pending paste-conflict sub-mode.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Choice The user's decision for the current conflict.
   --  @param Apply_All True to apply the decision to every remaining conflict.
   --  @return Structured operation result; Disabled when no paste is pending.
   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result;

   --  Advance an armed paste execution by up to Max_Items resolved actions,
   --  copying or moving each written item through Execute_Drop_Import and
   --  updating the model's progress counters. When the cursor reaches the end of
   --  the action list (or a cancellation was requested) the execution finalizes:
   --  it records a single undo covering the items actually completed (move is
   --  reversed by moving back, copy by deleting the created copies), clears the
   --  move-mode clipboard, reloads the directory, and clears the execution state.
   --  A no-op Success is returned when no execution is active.
   --
   --  @param Model Window model holding the armed execution.
   --  @param Settings Settings model used for the finalizing directory reload.
   --  @param Max_Items Maximum resolved actions to process this call.
   --  @return Success while still in progress or after a clean finalize; a
   --    failure result with a localized error key when a write failed.
   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result;

   --  Request cancellation of the armed paste execution. Already-completed items
   --  are kept (like real file managers); the next Advance_Paste_Execution
   --  finalizes over the completed set. Does nothing when no execution is active.
   --
   --  @param Model Window model holding the armed execution.
   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model);

   --  Arm a paste (Files.Model.Pasting.Begin_Execution) with the copy context
   --  its writes share when there is more than one: a batch transport, so
   --  made here and not by the model.
   --
   --  @param Model Model to update.
   --  @param Actions Fully resolved paste actions.
   --  @param Mode Copy or move for the whole batch.
   --  @param Clear_Clipboard Whether finishing a move clears the clipboard.
   procedure Begin_Paste_Execution
     (Model           : in out Files.Model.Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True);

   --  Record what an armed paste has done so far as its one Undo entry --
   --  the items written and the originals a Replace preserved -- and consume
   --  a cut's clipboard, leaving the paste armed for
   --  Files.Model.End_Foreground_Job. A window closing mid-paste calls this
   --  before it lets the paste go, so the originals preserved so far reach
   --  its history, which sends them to the system trash as it ends, instead
   --  of being dropped with the paste in hidden stages.
   --
   --  @param Model Window whose paste is armed; nothing without one.
   procedure Record_Paste_So_Far (Model : in out Files.Model.Window_Model);

private

   --  A failed move's copy that had to stay at its destination while its
   --  source is still where it was: nothing moved, so its undo deletes the
   --  copy, as a copy's does, instead of moving it back onto the source.
   type Kept_Copy is record
      Dest_Path     : Files.Types.UString;
      Source_Path   : Files.Types.UString;
      Identity      : Files.Types.UString;
      Tree_Revision : Files.Types.UString;
   end record;

   --  No copy kept.
   No_Kept_Copy : constant Kept_Copy := (others => <>);

   --  Record_Paste_So_Far, with a failed move's copy left beside its still
   --  present source (Kept) joining the entry.
   --
   --  @param Model Window whose paste is armed.
   --  @param Kept The kept copy, or none.
   procedure Record_Paste_Execution
     (Model : in out Files.Model.Window_Model;
      Kept  : Kept_Copy := No_Kept_Copy);

   --  Finish an armed paste execution: record its one Undo, reload, and
   --  report Error_Key (a mid-run failure) or the Undo it could not record.
   --
   --  @param Model Window whose paste finishes.
   --  @param Settings Current settings.
   --  @param Error_Key Mid-run failure, or "".
   --  @param Kept A failed move's copy left beside its still present source.
   --  @return The paste's result.
   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Kept      : Kept_Copy := No_Kept_Copy)
      return Operation_Result;

end Files.Operations.Paste;

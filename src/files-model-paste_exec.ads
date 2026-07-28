--  The paste exec state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Paste_Exec is

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
   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True);

   --  Whether a resumable paste execution is currently in flight.
   --
   --  @param Model Model to inspect.
   --  @return True between Begin_Paste_Execution and Clear_Paste_Execution.
   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The number of write actions completed so far.
   --
   --  @param Model Model to inspect.
   --  @return Count of items already copied or moved.
   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural;

   --  The total number of write actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of items to copy or move (skips excluded).
   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural;

   --  The leaf name of the item most recently written, for the progress display.
   --
   --  @param Model Model to inspect.
   --  @return The current item's simple name, or "" before the first write.
   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String;

   --  The copy/move mode of the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Copy or move mode.
   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode;

   --  Whether finalizing this execution's move should clear the clipboard.
   --
   --  @param Model Model to inspect.
   --  @return True for a clipboard-originated paste, False for drag-and-drop.
   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean;

   --  Whether the armed execution has been asked to cancel.
   --
   --  @param Model Model to inspect.
   --  @return True once Cancel_Paste_Execution has been requested.
   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean;

   --  The cursor position: the number of actions already consumed.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based count of processed actions (writes and skips).
   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural;

   --  The number of resolved actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of actions (writes and skips).
   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural;

   --  The resolved action at a one-based index.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based action index (1 .. Paste_Execution_Action_Count).
   --  @return The resolved action to execute.
   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action;

   --  The accumulated undo "from" paths (destinations) for completed writes.
   --
   --  @param Model Model to inspect.
   --  @return Destination paths written so far.
   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The accumulated undo "to" paths (sources) for completed writes.
   --
   --  @param Model Model to inspect.
   --  @return Source paths written so far.
   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Trash locations of destinations this paste overwrote via Replace, so the
   --  undo entry can restore each overwritten original from the trash.
   --
   --  @param Model Model to inspect.
   --  @return The trash locations of replaced destinations so far.
   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Record that a Replace moved a destination to the trash at Trash_Path, so
   --  undo can later restore it. Called once per replaced destination.
   --
   --  @param Model Model to update.
   --  @param Trash_Path The overwritten original's location inside the trash.
   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString);

   --  The first destination path written, reported as the operation result path.
   --
   --  @param Model Model to inspect.
   --  @return The first written destination, or "" when nothing was written.
   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String;

   --  Advance the cursor past a skipped action without recording a write.
   --
   --  @param Model Model to update.
   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model);

   --  Record a completed write: advance the cursor, bump Done, remember the
   --  current name and first destination, and accumulate the undo pair.
   --
   --  @param Model Model to update.
   --  @param Dest_Path Destination path just written.
   --  @param Source_Path Source path just copied or moved.
   --  @param Name Leaf name shown as the current progress item.
   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String);

   --  Request cancellation of the armed execution; the next advance finalizes
   --  over the items completed so far (already-written files are kept).
   --
   --  @param Model Model to update.
   procedure Cancel_Paste_Execution
     (Model : in out Window_Model);

   --  Clear the resumable paste execution, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Paste_Execution
     (Model : in out Window_Model);

end Files.Model.Paste_Exec;

--  The undo and redo history: recording, taking and merging entries, and
--  the payloads retired entries leave for the operations layer.
package Files.Model.History is

   --  @param Model Window whose history to snapshot.
   --  @return Undo stack, oldest first.
   function Undo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector;

   --  @param Model Window whose history to snapshot.
   --  @return Redo stack, oldest first.
   function Redo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector;

   --  Restore checkpointed history after filtering structurally unusable
   --  actions and completion markers. Identity snapshots are retained without
   --  consulting current pathnames so refused operations remain retryable.
   --  Entries without a Sequence (a journal from an older build) are given
   --  one, and the next Sequence is past every one the history holds.
   --  @param Model Window whose checkpointed history to restore.
   --  @param Undo Undo stack, oldest first.
   --  @param Redo Redo stack, oldest first.
   --  @param State The journal's state; Redo_Retired starts over as False.
   procedure Set_History
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State := (others => <>));

   --  @param Model Window whose journal state to read.
   --  @return The journal state to write beside its stacks.
   function History_State (Model : Window_Model) return History_Journal_State;

   --  Take back the history a background helper journaled, merging it into
   --  the window's own instead of replacing it: an entry the journal does
   --  not hold stays when the journal lists it as unjournaled (it left the
   --  journal only to fit it, or the helper never saw it) and goes when the
   --  helper retired it (the helper released its payloads). Redo entries the
   --  helper never saw are retired here when its new record retired its redo
   --  stack, and the merged undo stack keeps the depth cap; payloads of what
   --  is retired here are queued for Take_Retired_History.
   --
   --  @param Model Window whose history to merge into.
   --  @param Undo Journaled undo stack, oldest first.
   --  @param Redo Journaled redo stack, oldest first.
   --  @param State The journal's state.
   procedure Merge_History
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State);

   --  Start recording a performed action: advance the model revision and, for
   --  a completed rename or move, note each path move whether or not the
   --  action ends up undoable. Undo_None or an empty From only advances the
   --  revision. Touches no filesystem; Commit_Undo_Record finishes the record.
   --
   --  @param Model Model to update.
   --  @param Kind  Kind of the performed action.
   --  @param From  Current (new) locations of the action's items.
   --  @param To    Old locations, parallel to From.
   procedure Begin_Undo_Record
     (Model : in out Window_Model;
      Kind  : Undo_Action_Kind;
      From  : Files.Types.String_Vectors.Vector;
      To    : Files.Types.String_Vectors.Vector);

   --  Finish recording an action whose members the operations layer has
   --  already verified against the filesystem: the redo stack is retired (a
   --  new operation invalidates any pending redo) and, when Action keeps any
   --  From path, Action is pushed and the oldest entries past the depth cap
   --  are retired. Redo payloads are queued for deletion; payloads of entries
   --  past the cap, and of an Action that records nothing, are queued for
   --  release to the system trash. Both, and the journal save, wait for
   --  Take_Retired_History; nothing touches the filesystem here.
   --
   --  @param Model  Model whose history is updated.
   --  @param Action Verified entry; an empty From records nothing.
   --  @return True when Action was pushed onto the undo stack.
   function Commit_Undo_Record
     (Model  : in out Window_Model;
      Action : Undo_Entry) return Boolean;

   --  Hand over, and forget, what history mutations left for the operations
   --  layer: recovery payloads of retired entries to delete, payloads of an
   --  ended history to release to the system trash, and whether the history
   --  changed since the journal was last saved.
   --
   --  @param Model         Model whose pending history work to drain.
   --  @param Discarded     Restore_Trash payloads no entry references any more.
   --  @param Released      Restore_Trash payloads of a released history.
   --  @param Journal_Dirty True when the history journal must be saved.
   procedure Take_Retired_History
     (Model         : in out Window_Model;
      Discarded     : out Files.Types.String_Vectors.Vector;
      Released      : out Files.Types.String_Vectors.Vector;
      Journal_Dirty : out Boolean);

   --  End the history with its window: originals a paste replaced, kept in a
   --  hidden recovery folder only so Undo could put them back, are queued to
   --  go to the system trash under their own names (Take_Retired_History).
   --
   --  @param Model Model to update.
   procedure Release_History
     (Model : in out Window_Model);

   --  Forget the entire undo and redo history, queueing the retired recovery
   --  payloads and the journal save for Take_Retired_History.
   --
   --  @param Model Model to update.
   procedure Clear_Undo
     (Model : in out Window_Model);

   --  Return whether an undoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the undo stack is non-empty.
   function Undo_Available
     (Model : Window_Model)
      return Boolean;

   --  Return whether a redoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the redo stack is non-empty.
   function Redo_Available
     (Model : Window_Model)
      return Boolean;

   --  Pop the top entry off the undo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Pop the top entry off the redo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Push an action onto the redo stack (after a successful undo), queueing
   --  the journal save for Take_Retired_History.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Push an action back onto the undo stack (after a successful redo),
   --  leaving the redo stack untouched and queueing the journal save for
   --  Take_Retired_History.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Return the top undo entry's "from" (current) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of current locations, parallel to the entry's To paths.
   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

end Files.Model.History;

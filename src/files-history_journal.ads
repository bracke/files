with Files.Model;

--  Atomic helper-local snapshots retain partial history across cancellation.
package Files.History_Journal is
   --  Persist explicit history stacks in a private helper transport.
   --  Entries too old or too large for the journal's caps are left out of
   --  it, never failing the save: the oldest first, and the newest of a
   --  stack only when it does not fit even alone. Each one left out is
   --  listed in the journal ("not journaled") by its Sequence, together with
   --  those State already lists, so a window merging the journal back keeps
   --  its own copy (Merge).
   --  @param Directory Absolute private helper transport directory.
   --  @param Undo Undo stack to persist.
   --  @param Redo Redo stack to persist.
   --  @param Required Raise when the snapshot cannot be committed.
   --  @param State The history's journal state, written with the stacks.
   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      Required : Boolean := False;
      State : Files.Model.History_Journal_State := (others => <>));

   --  @param Model Helper model whose history to persist.
   --  @param Required Stop the helper if this snapshot cannot be committed.
   procedure Save (Model : Files.Model.Window_Model; Required : Boolean := False);

   --  Save_Stacks of Model's history and journal state, into Directory.
   --  @param Directory Absolute private helper transport directory.
   --  @param Model Model whose history to persist.
   --  @param Required Raise when the snapshot cannot be committed.
   procedure Save_To (Directory : String; Model : Files.Model.Window_Model; Required : Boolean := False);

   --  Whether a journal of Model's history would hold the newest entry of
   --  the undo (or redo) stack: a helper can undo (or redo) only what its
   --  journal gave it, so an entry too large for the journal is undone or
   --  redone in the window instead.
   --  @param Model Model whose history to measure.
   --  @param Redo True for the redo stack.
   --  @return True when that stack is empty or its newest entry is journaled.
   function Journals_Newest (Model : Files.Model.Window_Model; Redo : Boolean) return Boolean;

   --  Write the history with Action's progress in it, for a crashed helper's
   --  retry to resume from. Each write rewrites (and syncs) the whole
   --  journal, so progress that a retry finds again on its own -- a marker
   --  whose step checks its result on disk -- is written at most once a
   --  second (Force False); one a retry could not reconstruct is written now.
   --
   --  @param Model Helper model with the active action removed from its stack.
   --  @param Action Updated retry progress for the active action.
   --  @param Redo True when the action belongs on the redo stack.
   --  @param Force Write now, rather than within the second.
   procedure Checkpoint
     (Model : Files.Model.Window_Model; Action : Files.Model.Undo_Entry; Redo : Boolean; Force : Boolean := True);

   --  @param Directory Absolute private helper transport directory.
   --  @param Model Parent model receiving the checkpointed stacks.
   --  @return True when a complete snapshot was recovered.
   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean;

   --  Take back a helper's journal into the window's history without losing
   --  what the journal left out (Files.Model.Merge_History).
   --  @param Directory Absolute private helper transport directory.
   --  @param Model Window model whose history to merge into.
   --  @return True when a complete snapshot was read and merged.
   function Merge (Directory : String; Model : in out Files.Model.Window_Model) return Boolean;
end Files.History_Journal;

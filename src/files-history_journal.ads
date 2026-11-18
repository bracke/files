with Files.Model;

--  Atomic helper-local snapshots retain partial history across cancellation.
package Files.History_Journal is
   --  Persist explicit history stacks in a private helper transport.
   --  Entries too old or too large for the journal's caps are left out of
   --  it, never failing the save: the oldest first, and the newest of a
   --  stack only when it does not fit even alone. Each one left out is
   --  listed in the journal ("not journaled") by its Sequence, together with
   --  those State already lists, so a window merging the journal back keeps
   --  its own copy (Merge). That list has a cap: a Sequence past it is
   --  listed instead as dropped, and the window merging the journal retires
   --  that entry, releasing the originals it preserved to the system trash.
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
   --  @param Side Which stack.
   --  @return True when that stack is empty or its newest entry is journaled.
   function Journals_Newest (Model : Files.Model.Window_Model; Side : Files.Model.History_Side) return Boolean;

   --  Write the history with Action's progress in it, for a crashed helper's
   --  retry to resume from. Each write rewrites (and syncs) the whole
   --  journal, so progress that a retry finds again on its own -- a marker
   --  whose step checks its result on disk -- is written at most once a
   --  second (Force False); one a retry could not reconstruct is written now.
   --
   --  @param Model Helper model with the active action removed from its stack.
   --  @param Action Updated retry progress for the active action.
   --  @param Side The stack the action belongs on.
   --  @param Force Write now, rather than within the second.
   procedure Checkpoint
     (Model  : Files.Model.Window_Model;
      Action : Files.Model.Undo_Entry;
      Side   : Files.Model.History_Side;
      Force  : Boolean := True);

   --  @param Directory Absolute private helper transport directory.
   --  @param Model Parent model receiving the checkpointed stacks.
   --  @return True when a complete snapshot was recovered.
   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean;

   --  What taking a helper's journal back came to: merged; no journal there
   --  at all (surely absent); or one there that could not be read whole
   --  this time (held, refused, torn), which a later try may read.
   type Merge_Outcome is (Merged, No_Journal, Unreadable);

   --  Take back a helper's journal into the window's history without losing
   --  what the journal left out (Files.Model.History.Merge).
   --  @param Directory Absolute private helper transport directory.
   --  @param Model Window model whose history to merge into.
   --  @return Merged when a complete snapshot was read and merged.
   function Merge (Directory : String; Model : in out Files.Model.Window_Model) return Merge_Outcome;

private

   --  Test seam (Files.History_Journal.Testing): how many of the next
   --  journal reads are refused, as a journal held a moment by another
   --  process is. Zero outside the test suite.
   Refused_Reads : Natural := 0;

end Files.History_Journal;

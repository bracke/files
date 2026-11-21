with Files.Undo.History;

--  Atomic helper-local snapshots retain partial history across cancellation.
package Files.Undo.Journal is
   --  Whether a save must commit its snapshot: Must_Commit raises when it
   --  cannot (stopping a helper whose work needs it); Best_Effort traces
   --  the failure and goes on.
   type Save_Mode is (Best_Effort, Must_Commit);

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
   --  @param Mode Must_Commit raises when the snapshot cannot be committed.
   --  @param State The history's journal state, written with the stacks.
   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Undo.History.Undo_Entry_Vectors.Vector;
      Mode : Save_Mode := Best_Effort;
      State : Files.Undo.History.History_Journal_State := (others => <>));

   --  Save_Stacks of History's stacks and journal state, into the current
   --  job's transport (Files.Jobs.Context.Directory).
   --  @param History Helper history to persist (Files.Model.History.State).
   --  @param Mode Must_Commit stops the helper if this snapshot cannot be committed.
   procedure Save (History : Files.Undo.History.Undo_History_State; Mode : Save_Mode := Best_Effort);

   --  Save_Stacks of History's stacks and journal state, into Directory.
   --  @param Directory Absolute private helper transport directory.
   --  @param History History to persist.
   --  @param Mode Must_Commit raises when the snapshot cannot be committed.
   procedure Save_To
     (Directory : String;
      History   : Files.Undo.History.Undo_History_State;
      Mode      : Save_Mode := Best_Effort);

   --  Whether a journal of History would hold the newest entry of the undo
   --  (or redo) stack: a helper can undo (or redo) only what its journal
   --  gave it, so an entry too large for the journal is undone or redone in
   --  the window instead.
   --  @param History History to measure.
   --  @param Side Which stack.
   --  @return True when that stack is empty or its newest entry is journaled.
   function Journals_Newest
     (History : Files.Undo.History.Undo_History_State;
      Side    : Files.Undo.History.History_Side) return Boolean;

   --  When Checkpoint writes the journal.
   type Checkpoint_Timing is (Write_Now, Within_Second);

   --  Write the history with Action's progress in it, for a crashed helper's
   --  retry to resume from. Each write rewrites (and syncs) the whole
   --  journal, so progress that a retry finds again on its own -- a marker
   --  whose step checks its result on disk -- is written at most once a
   --  second (Within_Second); one a retry could not reconstruct is written
   --  now (Write_Now).
   --
   --  @param History Helper history with the active action removed from its stack.
   --  @param Action Updated retry progress for the active action.
   --  @param Side The stack the action belongs on.
   --  @param Timing Write_Now, or Within_Second: skipped when the last
   --    checkpoint was written less than a second ago.
   procedure Checkpoint
     (History : Files.Undo.History.Undo_History_State;
      Action  : Files.Undo.History.Undo_Entry;
      Side    : Files.Undo.History.History_Side;
      Timing  : Checkpoint_Timing := Write_Now);

   --  What a journal holds: its stacks and its state.
   type Journal_Contents is record
      Undo, Redo : Files.Undo.History.Undo_Entry_Vectors.Vector;
      State      : Files.Undo.History.History_Journal_State;
   end record;

   --  What reading a helper's journal came to: read whole; no journal there
   --  at all (surely absent); or one that could not be read whole this
   --  time (held, refused, torn, or a transport folder that is a link or
   --  not a valid path, which is a refusal, not an absence), which a later
   --  try may read.
   type Read_Outcome is (Read_Whole, No_Journal, Unreadable);

   --  Read the journal in Directory, for the window's history to take back
   --  (Files.Model.History.Restore replaces the history with it, a helper's
   --  side, where the journal is the whole history; Files.Model.History.Merge
   --  merges it into a window's without losing what it left out).
   --  @param Directory Absolute private helper transport directory.
   --  @param Contents Set to what the journal holds; empty unless Read_Whole.
   --  @return Read_Whole when a complete snapshot was read.
   function Read (Directory : String; Contents : out Journal_Contents) return Read_Outcome;

private

   --  Test seam (Files.Undo.Journal.Testing): how many of the next
   --  journal reads are refused, as a journal held a moment by another
   --  process is. Zero outside the test suite.
   Refused_Reads : Natural := 0;

end Files.Undo.Journal;

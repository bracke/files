--  Test seam of Files.Undo.Journal: a journal briefly unreadable.
package Files.Undo.Journal.Testing is

   --  Refuse the next Count journal reads, as a journal another process holds
   --  a moment is; 0 disarms.
   --
   --  @param Count How many reads to refuse.
   procedure Refuse_Reads (Count : Natural);

   --  @return How many of the refusals Refuse_Reads armed are still to come.
   function Refusals_Left return Natural;

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

end Files.Undo.Journal.Testing;

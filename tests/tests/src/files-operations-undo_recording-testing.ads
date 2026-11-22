--  Seams into undo recording for the test suite.
package Files.Operations.Undo_Recording.Testing is

   --  From now on count, from zero, each attempt Try_Record_Undo makes to
   --  record an entry (Count True); or stop counting (False).
   --
   --  @param Count Whether to count.
   procedure Count_Undo_Records (Count : Boolean);

   --  @return The attempts counted since Count_Undo_Records (True).
   function Undo_Records return Natural;

   --  Make the batch Undo throttle (Checkpoint_Undo) read a fake clock, on
   --  which no second ever passes between a batch's records, except that its
   --  Advance_At'th reading (counting from one; zero for never) moves it one
   --  second on, where it stays (Fake True); or the real clock again (False).
   --
   --  @param Fake Whether to use the fake clock.
   --  @param Advance_At The reading that moves the clock one second on.
   procedure Fake_Checkpoint_Clock (Fake : Boolean; Advance_At : Natural := 0);

   --  @return How often the fake clock was read since Fake_Checkpoint_Clock.
   function Checkpoint_Clock_Readings return Natural;

   --  Record a performed action in the undo history, keeping only items
   --  whose publication identity still matches the live entry. Created
   --  directories also require a matching recursive revision, and every
   --  payload needed by Undo and Redo must be complete and valid. Replacement
   --  actions are recorded only when every created and preserved entry is
   --  verifiable, since their reverse steps are inseparable.
   --
   --  Each item is as the action left it (Files.Undo.History.Undo_Item), with its
   --  provenance (Files.Undo.History.Item_Provenance): a Captured item has its
   --  identity, and a creation its tree revision, captured here; a Verified
   --  one is trusted without a fresh check. A trash restoration without a To
   --  has its trash origin read. A Captured replaced original has its
   --  identity and target captured likewise. Then the model records the
   --  entry, and the payloads the record retires are deleted and the history
   --  journal saved (Settle_History). A move's kept copies (Kept) stay in its entry,
   --  which is then undo-only, while they verify; with no moved item left
   --  they are recorded alone as created entries, and one that does not
   --  verify on a path an original returns to makes the whole action
   --  unrecordable.
   --
   --  @param Model Model whose history is updated.
   --  @param Kind Kind of action that can be undone.
   --  @param Items What the action changed, in order.
   --  @param Create_Kind Creation operation used by Redo.
   --  @param Redoable Whether a successful Undo may enter Redo history.
   --  @param Replaced Originals a replace preserved, to restore.
   --  @param Kept Copies a failed move kept beside their still present
   --    sources; for an Undo_Move only, which then deletes them first and is
   --    never redoable.
   --  @return True when a usable history entry was added.
   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector :=
        Files.Undo.History.Kept_Copy_Vectors.Empty_Vector) return Boolean;

end Files.Operations.Undo_Recording.Testing;

with Files.Model;
with Files.Undo.History;

--  Recording what an action did in the window's undo history: the one way
--  operations (Files.Operations) and the helper jobs that run them
--  (Files.Job_Drivers.Operation) add an entry, and settle what the history then
--  retires. Its own unit so Files.Job_Drivers.Operation records what a helper did
--  without depending on Files.Operations.
package Files.Operations.Undo_Recording is

   --  Items or originals whose identities are all read when recorded.
   --
   --  @param Items What the action changed.
   --  @return Them, each Captured.
   function Captured
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector;

   --  @param Originals Originals a replace preserved.
   --  @return Them, each Captured.
   function Captured
     (Originals : Files.Undo.History.Replaced_Original_Vectors.Vector)
      return Files.Undo.History.Recorded_Original_Vectors.Vector;

   --  Items carrying what the action published, unverified.
   --
   --  @param Items What the action changed.
   --  @return Them, each Published.
   function Published
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector;

   --  Items carrying what the action published and checked at publication.
   --
   --  @param Items What the action changed.
   --  @return Them, each Verified.
   function Verified
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector;

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

   --  Try_Record_Undo for callers that do not need to know whether an entry
   --  was added.
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
   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector);

   --  Carry out the filesystem work model history mutations queued: delete
   --  the recovery payloads of retired entries, release those of an ended
   --  history to the system trash, and save the history journal when the
   --  history changed. Call it right after each model history mutation.
   --
   --  @param Model Model whose queued history work to perform.
   procedure Settle_History (Model : in out Files.Model.Window_Model);

private
   --  What Try_Record_Undo calls on each attempt to record an entry.
   type Record_Hook is access procedure;

   --  Set only by the test suite (Files.Operations.Undo_Recording.Testing), to count
   --  the records a batch makes. The application never sets it.
   Undo_Record_Attempted : Record_Hook := null
     with Atomic;
end Files.Operations.Undo_Recording;

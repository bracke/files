with Files.Model;

--  Recording what an action did in the window's undo history: the one way
--  operations (Files.Operations) and the helper jobs that run them
--  (Files.Operation_Jobs) add an entry, and settle what the history then
--  retires. Its own unit so neither depends on the other for it.
package Files.Undo_Recording is

   --  What an action's records are known by beyond what they carry.
   type Undo_Provenance is record
      --  How many leading items carry their identity and tree revision, and
      --  how many leading replaced originals their identity and target, as
      --  they were published, even when empty: an empty one published never
      --  verifies. The rest have them captured here.
      Published_Main     : Natural := 0;
      Published_Restores : Natural := 0;
      --  How many leading items, and leading replaced originals, were
      --  verified when published, and may survive a later pathname
      --  replacement.
      Retain_Verified_Main     : Natural := 0;
      Retain_Verified_Restores : Natural := 0;
      --  Copies a failed move kept beside their still present sources; for
      --  an Undo_Move only, which then deletes them first and is never
      --  redoable.
      Kept : Files.Model.Kept_Copy_Vectors.Vector;
   end record;

   --  Record a performed action in the undo history, keeping only items
   --  whose publication identity still matches the live entry. Created
   --  directories also require a matching recursive revision, and every
   --  payload needed by Undo and Redo must be complete and valid. Replacement
   --  actions are recorded only when every created and preserved entry is
   --  verifiable, since their reverse steps are inseparable.
   --
   --  Each item is as the action left it (Files.Model.Undo_Item). An item
   --  past Provenance.Published_Main has its identity, and a creation its
   --  tree revision, captured here; a trash restoration without a To has its
   --  trash origin read. A replaced original past Published_Restores has its
   --  identity and target captured likewise. Then the model records the
   --  entry, and the
   --  payloads the record retires are deleted and the history journal saved
   --  (Settle_History). A move's kept copies (Provenance) stay in its entry,
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
   --  @param Provenance What was verified, and the kept copies.
   --  @return True when a usable history entry was added.
   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Undo_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Replaced_Original_Vectors.Vector :=
        Files.Model.Replaced_Original_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>)) return Boolean;

   --  Try_Record_Undo for callers that do not need to know whether an entry
   --  was added.
   --
   --  @param Model Model whose history is updated.
   --  @param Kind Kind of action that can be undone.
   --  @param Items What the action changed, in order.
   --  @param Create_Kind Creation operation used by Redo.
   --  @param Redoable Whether a successful Undo may enter Redo history.
   --  @param Replaced Originals a replace preserved, to restore.
   --  @param Provenance What was verified, and the kept copies.
   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Undo_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Replaced_Original_Vectors.Vector :=
        Files.Model.Replaced_Original_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>));

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

   --  Set only by the test suite (Files.Undo_Recording.Testing), to count
   --  the records a batch makes. The application never sets it.
   Undo_Record_Attempted : Record_Hook := null
     with Atomic;
end Files.Undo_Recording;

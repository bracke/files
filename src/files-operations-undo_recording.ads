with Ada.Real_Time;
with Files.Model;
with Files.Undo.History;

--  Recording what an action did in the window's undo history: the one way
--  operations (Files.Operations) and the helper jobs that run them
--  (Files.Job_Drivers.Operation) add an entry, and settle what the history then
--  retires, and the growing entry of a batch (Progressive_Undo,
--  Checkpoint_Undo, Finish_Undo). A public child, not the private Support,
--  because the job drivers record through it too; each concern child of
--  Files.Operations and each driver names it rather than reaching into
--  another's history code.
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

   --  The Undo entry of a batch (duplicate, extract, trash) that grows with
   --  it, so a batch stopped part way -- by a failure, a cancel, or a crash
   --  of the helper running it -- still undoes what it did. The batch
   --  appends each item it completes to the vectors and calls
   --  Checkpoint_Undo; once it ends, however it ends, it calls Finish_Undo.
   --
   --  Each record rewrites the whole Undo entry and the history journal, so
   --  one per item made a large batch quadratic, with a journal write per
   --  item. Checkpoint_Undo records the first item at once (an Undo exists
   --  from the start) and then at most once a second; a crash so loses only
   --  the last second's items from Undo, which stay where the batch put them
   --  (copies beside their sources, trashed items in the trash).
   --  Finish_Undo records whatever Checkpoint_Undo left out, so the entry a
   --  batch ends with covers all of it. A record attempt that keeps nothing
   --  (no member could be verified, as when something else touched every
   --  copy) is throttled the same way: it is retried at Finish_Undo, not on
   --  every item.
   type Progressive_Undo is record
      --  How the entry is recorded, as for Try_Record_Undo.
      Kind        : Files.Undo.History.Undo_Action_Kind := Files.Undo.History.Undo_Delete_Created;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := False;
      --  Whether each record also commits the history journal durably
      --  (Files.Undo.Journal.Save, Must_Commit), stopping a helper that
      --  cannot.
      Durable : Boolean := False;
      --  The batch appends an item for each entry it made, Published; once a
      --  record admitted them all, they are Verified (Try_Record_Undo).
      Items : Files.Undo.History.Recorded_Item_Vectors.Vector;
      --  Kept by Checkpoint_Undo and Finish_Undo: whether the top Undo entry
      --  is this batch's, whether a record was attempted, how many From
      --  members the last attempt covered, and when the last attempt was.
      Recorded        : Boolean := False;
      Attempted       : Boolean := False;
      Attempted_Count : Natural := 0;
      Last_Checkpoint : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

   --  Record Progress after an item was appended: at once for the first
   --  record, then once a second has passed since the last.
   --
   --  @param Model Model whose history is updated.
   --  @param Progress The batch's entry so far.
   procedure Checkpoint_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo);

   --  How a batch's Undo ended up.
   --    * Undo_Covered: the batch's entry is recorded (members that could
   --      not be verified are left out of it), or it appended nothing.
   --    * Undo_Unavailable: it appended items but no entry could be
   --      recorded. The batch's work stands, so it still succeeds, but with
   --      the "undo.unavailable" notice rather than a silent missing Undo.
   type Undo_Outcome is (Undo_Covered, Undo_Unavailable);

   --  The notice a batch whose Undo is unavailable shows.
   Undo_Unavailable_Notice : constant String := "undo.unavailable";

   --  The notice a trash batch shows when a native trash took an item
   --  without saying where it went, so Undo cannot bring that one back.
   Untracked_Trash_Notice : constant String := "undo.partial";

   --  Record whatever Checkpoint_Undo left out, so the entry covers every
   --  item appended. A record that raises propagates, so a batch that
   --  otherwise succeeded reports the failure rather than an Undo it does not
   --  have; a record that keeps nothing is reported as Undo_Unavailable.
   --
   --  @param Model Model whose history is updated.
   --  @param Progress The batch's entry.
   --  @return Whether the batch has its Undo.
   function Finish_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) return Undo_Outcome;

   --  Show Notice once a batch's Undo turned out unavailable, after the
   --  reload a successful batch ends with (which clears notices).
   --
   --  @param Model Window that shows the notice.
   --  @param Outcome The batch's Finish_Undo outcome.
   --  @param Result The batch's result; only a success is given the notice.
   procedure Note_Undo_Outcome
     (Model   : in out Files.Model.Window_Model;
      Outcome : Undo_Outcome;
      Result  : Operation_Result);

   --  Finish_Undo for a batch that has already failed: a record that fails
   --  (raises or keeps nothing) is noted, and the batch's own failure is
   --  what the caller reports.
   --
   --  @param Model Window whose Undo history holds the batch's entry.
   --  @param Progress The batch's entry so far.
   procedure Finish_Failed_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo);

private

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
   --  The clock a batch's Undo throttle (Checkpoint_Undo) reads.
   type Clock_Hook is access function return Ada.Real_Time.Time;

   --  Set only by the test suite (Files.Operations.Undo_Recording.Testing), so a test
   --  decides when "a second has passed" for the throttle; null reads
   --  Ada.Real_Time.Clock. The application never sets it.
   Checkpoint_Clock : Clock_Hook := null
     with Atomic;

   --  What Try_Record_Undo calls on each attempt to record an entry.
   type Record_Hook is access procedure;

   --  Set only by the test suite (Files.Operations.Undo_Recording.Testing), to count
   --  the records a batch makes. The application never sets it.
   Undo_Record_Attempted : Record_Hook := null
     with Atomic;
end Files.Operations.Undo_Recording;

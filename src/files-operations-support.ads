with Ada.Real_Time;

with Files.Items;
with Files.Model;
with Files.Settings;

--  Internal helpers shared by the Files.Operations subunits (one per operation).
--  A private child so only the Files.Operations hierarchy can see it; the public
--  Operation_Result/Operation_Status types come from the parent spec.
private package Files.Operations.Support is

   --  The empty open action (no executable, no arguments), used as the default
   --  Action for results that do not launch anything.
   --
   --  @return An open action with an empty executable and no arguments.
   function Empty_Action return Files.Settings.Open_Action;

   --  Ada.Directories.Exists raises Name_Error on a malformed path rather than
   --  returning False; this treats any failure as "does not exist" so it cannot
   --  escape an operation as an unhandled exception.
   --
   --  @param Path Filesystem path to test.
   --  @return True when Path exists, False when it does not or the test failed.
   function Exists_Safely (Path : String) return Boolean;

   --  How many numbered names (" 2", " (copy 3)") a new entry tries before
   --  giving up on a free one.
   Max_Name_Attempts : constant := 9_999;

   --  The first stem of Base & Marker (First), Base & Marker (First + 1),
   --  ... (up to Max_Name_Attempts) that names nothing in Directory, with
   --  Extension ("" for none), or the first one when all are taken: how a
   --  duplicate, a link, an archive or an extracted folder finds its name.
   --  Base is cut at a whole character where the name would otherwise be
   --  longer than Directory's filesystem stores; the marker and the
   --  extension are kept whole.
   --  @param Directory Where the new entry goes.
   --  @param Base The stem the names start from.
   --  @param Extension Its extension, without the dot.
   --  @param Marker What follows Base for an attempt (" (copy 2)", "").
   --  @param First The first attempt (0 where the bare name comes first).
   --  @param Attempt An attempt number.
   --  @return The free stem.
   function First_Free_Name
     (Directory : String;
      Base      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      First     : Natural := 1)
      return String;

   --  Construct an Operation_Result, folding an open action's fields into the
   --  flat result record.
   --
   --  @param Status Operation status to report.
   --  @param Error_Key Localisation key for an error, or "" when none.
   --  @param Path Path the result refers to, or "" when none.
   --  @param Action Open action whose fields are folded into the result.
   --  @param Attempted Whether a launch was attempted.
   --  @param Found Whether the executable was found.
   --  @param Exit_Known Whether an exit status is known.
   --  @param Exit_Status The child exit status when known.
   --  @return The assembled operation result.
   function Make_Result
     (Status      : Operation_Status;
      Error_Key   : String := "";
      Path        : String := "";
      Action      : Files.Settings.Open_Action := Empty_Action;
      Attempted   : Boolean := False;
      Found       : Boolean := False;
      Exit_Known  : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result;

   --  Set the model error and return a disabled result for a command that is not
   --  currently applicable.
   --
   --  @param Model Window model whose error state is set.
   --  @param Error_Key Localisation key for the disabled reason.
   --  @return A disabled operation result carrying Error_Key.
   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result;

   --  Whether Executable names something this host will actually run: an
   --  on-PATH command, or a path that is a regular executable file.
   --
   --  @param Executable Executable name to look up, or a path to a file.
   --  @return True when it resolves to a runnable executable.
   function Executable_Is_Available (Executable : String) return Boolean;

   --  Reload the model's current directory, optionally selecting Select_Name or
   --  restoring the complete current selection, and refresh its signature.
   --
   --  @param Model Window model whose current directory is reloaded.
   --  @param Settings Settings model used to classify the reload.
   --  @param Select_Name Item name to re-select after reload, or "" for none.
   --  @param Preserve_Selection Restore all current selected paths when no
   --    Select_Name is supplied.
   --  @return Success result, or a failed result when the reload fails.
   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "";
      Preserve_Selection : Boolean := False)
      return Operation_Result;

   --  A batch (duplicate, extract, links) stopped by a failure: when some
   --  of it was already written the listing is reloaded so that output shows
   --  (and the error survives the reload), otherwise only the error is set.
   --  @param Model Window that ran the batch.
   --  @param Settings Directory settings for the reload.
   --  @param Error_Key The failure reported.
   --  @param Directory The directory the result names.
   --  @param Wrote_Some Whether earlier items of the batch were written.
   --  @return The failed result.
   function Batch_Failed
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Error_Key  : String;
      Directory  : String;
      Wrote_Some : Boolean)
      return Operation_Result;

   --  Finalize an operation error before scheduling its reload: the error
   --  is what the operation reports, whatever the reload does.
   --  @param Model Window whose error and listing to update.
   --  @param Settings Directory settings for the reload.
   --  @param Error_Key Operation error to preserve through completion.
   --  @param Path The path the error's message names, or "" when none.
   procedure Reload_With_Error
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Error_Key : String;
      Path : String := "");

   --  A listing loaded with Load_Directory_Deferring_Thumbnails: when an
   --  image in it still lacks a thumbnail, start the background listing
   --  that makes them, so the window never waits on decoding.
   --  @param Model Window that shows Items.
   --  @param Settings Directory settings for the background listing.
   --  @param Items The listing just shown.
   procedure Generate_Missing_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Items    : Files.Items.Item_Vectors.Vector);

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
      Kind        : Files.Model.Undo_Action_Kind := Files.Model.Undo_Delete_Created;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := False;
      --  Whether each record also commits the history journal durably
      --  (Files.History_Journal.Save, Required), stopping a helper that
      --  cannot.
      Durable : Boolean := False;
      --  The batch appends to these, parallel to one another, as for
      --  Try_Record_Undo and its Provenance.
      From, To, Forward          : Files.Types.String_Vectors.Vector;
      Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
      --  Kept by Checkpoint_Undo and Finish_Undo: whether the top Undo entry
      --  is this batch's, whether a record was attempted, how many From
      --  members the last attempt covered, how many of those were verified
      --  (Retain_Verified_Main), and when the last attempt was.
      Recorded        : Boolean := False;
      Attempted       : Boolean := False;
      Attempted_Count : Natural := 0;
      Verified_Count  : Natural := 0;
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

end Files.Operations.Support;

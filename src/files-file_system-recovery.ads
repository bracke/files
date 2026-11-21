--  Private replacement backups for trash backends without programmatic restore.
with Files.Copy_Context;
private package Files.File_System.Recovery is
   --  @param Path Original destination to preserve.
   --  @param Backup Recoverable payload path. On failure it is empty -- the
   --    original is back at Path -- unless the original moved into the stage
   --    and could not be moved back; it then names where the original is.
   --  @return Result of preserving the original.
   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result;

   --  @param Path Possible recovery payload.
   --  @return True when Path identifies an application replacement backup.
   function Recognizes (Path : String) return Boolean;

   --  Permanently remove a recognized recovery payload and its sidecars.
   --  @param Path Recovery payload to discard.
   --  @return Mutation result with a localized error key on failure.
   function Discard (Path : String) return Mutation_Result;

   --  Take a payload out of its stage on purpose -- moved to where it goes,
   --  or removed -- so that a stop part way leaves a stage Sweep_Registry
   --  finishes rather than keeps for good. The stage is marked, durable and
   --  held, before Leave runs; once the payload has left, the stage and its
   --  record go. A payload that did not leave keeps its stage, record and
   --  all, and the marker goes with it whole again.
   --  @param Path Payload returned by Preserve.
   --  @param Leave Moves or removes the payload; True when it has left.
   --  @param Ran Whether Leave was called: False when another operation
   --    holds the stage or it could not be marked, the payload untouched.
   --  @return True when the payload left.
   function Vacate
     (Path  : String;
      Leave : not null access function return Boolean;
      Ran   : out Boolean)
      return Boolean;

   --  Drop the registry record for a payload whose stage was removed by a
   --  caller other than Discard or Restore (which unregister themselves).
   --  @param Payload Payload path returned by Preserve.
   procedure Unregister (Payload : String);

   --  @param Path Payload returned by Preserve.
   --  @return Original path from the recovery sidecar, or empty on failure.
   function Original_Path (Path : String) return String;

   --  Return every still-valid recovery payload recorded for this user. A
   --  pure query: nothing is removed, resumed or finished (Sweep_Registry
   --  does that).
   --  @return Valid registered payload paths; stale records are omitted.
   function Registered_Payloads return Files.Types.String_Vectors.Vector;

   --  Finish what the registry shows was interrupted: drop records whose
   --  stage is gone and duplicate records, move a stopped release's payload
   --  back, and remove a stage whose payload a restore or release moved out
   --  (it carries their marker). A registered stage with no payload and no
   --  marker is left alone while Preserve may still be filling it, perhaps
   --  in another process -- for Unfilled_Stage_Grace after it was made; one
   --  older than that was abandoned by a Preserve that stopped, and goes.
   procedure Sweep_Registry;

   --  How long after its stage was made a Preserve may still be filling it.
   --  Preserve moves the original in by a rename beside it, a moment's work;
   --  an hour leaves room for a stalled disk without keeping an abandoned
   --  stage for good.
   Unfilled_Stage_Grace : constant Duration := 3_600.0;

   --  @param Path Payload returned by Preserve.
   --  @param Expected_Identity Optional history snapshot verified before restoration.
   --  @param Expected_Original Destination captured when history was recorded.
   --  @return Result of restoring to its recorded original location.
   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result;

   --  Hand a payload nothing will restore any more (its history is ending)
   --  to the system trash under its original name, and remove its stage, so
   --  a replaced original is neither lost nor left hidden beside its folder.
   --  @param Path Payload returned by Preserve.
   --  @param To_Trash Moves an entry (Path) to the system trash, recording
   --    Original as where it came from.
   --  @return Success when the payload is in the trash and its stage gone;
   --    on failure the payload is left where it was.
   function Release
     (Path     : String;
      To_Trash : not null access function (Path, Original : String) return Mutation_Result)
      return Mutation_Result;

   --  What Move_By_Copy does with a published copy when the source cannot
   --  then be removed (it changed, it is not the item copied, or a sync or
   --  removal failed). A move takes the copy back, so the source stays the
   --  one item. A restore from the trash keeps it: the item is back, and the
   --  source stays in the trash, still listed there with its info file.
   type Unremoved_Source_Rule is (Take_Copy_Back, Keep_Both);

   --  The cross-device half of a move, where rename cannot go: copy Source
   --  to the new path Destination, then remove Source. Rename, trash, drop
   --  import and restore-from-trash all fall back to this.
   --  @param Source Entry to move.
   --  @param Destination New pathname; never replaced.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Identity The copy's identity, empty if no copy was published.
   --  @param Revision The copy's tree revision.
   --  @param Copy_Kept Set when, after a failure, the copy is still at
   --    Destination: its removal was refused, the source was set aside, or
   --    If_Source_Stays is Keep_Both.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal of a multi-item job.
   --  @param If_Source_Stays What becomes of the copy when Source cannot be removed.
   --  @param After_Copy Called with Source once the copy is published,
   --    before Source is checked and removed; null for none.
   --  @param Expected_Identity The identity Source must have when it is
   --    snapshotted for the copy, or "" for no check: another entry under
   --    its name is then refused with Fallback_Key, nothing copied. The
   --    snapshot is what the removal checks Source against afterwards, so
   --    only the entry named is ever copied and removed.
   --  @return Success when Destination holds the item and Source is gone;
   --    otherwise Source is where it was (unless set aside, see Copy_Kept).
   function Move_By_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := Job_Cancelled;
      Batch               : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session;
      If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
      After_Copy          : Copy_Hook := null;
      Expected_Identity   : String := "")
      return Mutation_Result;

   --  How Move_Or_Copy moved an entry, or why it did not.
   --  Renamed: one no-replace rename moved it. Copied: the rename could not
   --  cross a device boundary (or the filesystem has no no-replace rename),
   --  so Move_By_Copy ran and its result is returned. Refused: the rename
   --  was refused for a reason a copy would meet too (permission, a busy or
   --  vanished source, an occupied target), so nothing was copied.
   type Move_Route is (Renamed, Copied, Refused);

   --  The move every mover makes: a no-replace rename, and only where the
   --  rename cannot go (Copy_May_Replace_Move), the copy and delete of
   --  Move_By_Copy. A rename that raises counts as refused.
   --  @param Source Entry to move.
   --  @param Destination New pathname; never replaced.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Route Which way it went (see Move_Route).
   --  @param Identity The copy's identity when Route is Copied; else empty.
   --  @param Revision The copy's tree revision when Route is Copied; else empty.
   --  @param Copy_Kept Move_By_Copy's Copy_Kept when Route is Copied; else False.
   --  The remaining parameters are Move_By_Copy's, passed on when it runs.
   --  @return Success when Destination holds the item and Source is gone.
   function Move_Or_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Route               : out Move_Route;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := Job_Cancelled;
      Batch               : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session;
      If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
      After_Copy          : Copy_Hook := null;
      Expected_Identity   : String := "")
      return Mutation_Result;
end Files.File_System.Recovery;

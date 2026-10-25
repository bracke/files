--  Private replacement backups for trash backends without programmatic restore.
with Files.Copy_Context;
with Files.File_System.Support;
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

   --  Drop the registry record for a payload whose stage was removed by a
   --  caller other than Discard or Restore (which unregister themselves).
   --  @param Payload Payload path returned by Preserve.
   procedure Unregister (Payload : String);

   --  @param Path Payload returned by Preserve.
   --  @return Original path from the recovery sidecar, or empty on failure.
   function Original_Path (Path : String) return String;

   --  Return every still-valid recovery payload recorded for this user.
   --  @return Valid registered payload paths; stale records are omitted.
   function Registered_Payloads return Files.Types.String_Vectors.Vector;

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

   --  Remove a copied move's source atomically before recursive cleanup.
   --  @param Path Source whose complete destination copy has been published.
   --  @param Expected Identity and revision snapshot captured before copying.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Set_Aside Set when the source had changed since the copy and
   --    could not be put back: it is then only in its recovery stage, still
   --    registered, and the caller must keep its copy.
   --  @return Failure leaves the source at its pathname unless Set_Aside;
   --    success vacates its pathname.
   function Remove_Move_Source
     (Path         : String;
      Expected     : Support.Source_Snapshot;
      Fallback_Key : String;
      Set_Aside    : out Boolean) return Mutation_Result;

   --  The cross-device half of a move, where rename cannot go: copy Source
   --  to the new path Destination, then remove Source. Rename, trash, drop
   --  import and restore-from-trash all fall back to this.
   --  @param Source Entry to move.
   --  @param Destination New pathname; never replaced.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Identity The copy's identity, empty if no copy was published.
   --  @param Revision The copy's tree revision.
   --  @param Copy_Kept Set when, after a failure, the copy is still at
   --    Destination: its removal was refused, or the source was set aside.
   --  @param Cancel Optional cooperative cancellation.
   --  @param Batch Shared hard-link journal of a multi-item job.
   --  @return Success when Destination holds the item and Source is gone;
   --    otherwise Source is where it was (unless set aside, see Copy_Kept).
   function Move_By_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := null;
      Batch               : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result;
end Files.File_System.Recovery;

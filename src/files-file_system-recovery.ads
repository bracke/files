--  Private replacement backups for trash backends without programmatic restore.
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
   --  @param To_Trash Moves an entry to the system trash.
   --  @return Success when the payload is in the trash and its stage gone;
   --    on failure the payload is left where it was.
   function Release
     (Path     : String;
      To_Trash : not null access function (Path : String) return Mutation_Result) return Mutation_Result;

   --  Remove a copied move's source atomically before recursive cleanup.
   --  @param Path Source whose complete destination copy has been published.
   --  @param Expected Identity and revision snapshot captured before copying.
   --  @return Failure leaves the source untouched; success vacates its pathname.
   function Remove_Move_Source
     (Path : String; Expected : Support.Source_Snapshot) return Mutation_Result;
end Files.File_System.Recovery;

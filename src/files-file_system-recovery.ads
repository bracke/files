--  Private replacement backups for trash backends without programmatic restore.
with Files.File_System.Support;
private package Files.File_System.Recovery is
   --  @param Path Original destination to preserve.
   --  @param Backup Recoverable payload path, including on a partial move failure.
   --  @return Result of preserving the original.
   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result;

   --  @param Path Possible recovery payload.
   --  @return True when Path identifies an application replacement backup.
   function Recognizes (Path : String) return Boolean;

   --  Permanently remove a recognized recovery payload and its sidecars.
   --  @param Path Recovery payload to discard.
   --  @return Mutation result with a localized error key on failure.
   function Discard (Path : String) return Mutation_Result;

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

   --  Remove a copied move's source atomically before recursive cleanup.
   --  @param Path Source whose complete destination copy has been published.
   --  @param Expected Identity and revision snapshot captured before copying.
   --  @return Failure leaves the source untouched; success vacates its pathname.
   function Remove_Move_Source
     (Path : String; Expected : Support.Source_Snapshot) return Mutation_Result;
end Files.File_System.Recovery;

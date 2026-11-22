--  The replacement-recovery payloads a replace keeps, and the registry
--  that records them across folders: preserving, recognizing, releasing
--  and sweeping them. Clients with this, not the whole of Files.File_System.
package Files.File_System.Recovery_Registry is

   --  Return whether Path is an application-owned replacement recovery payload.
   --  @param Path Possible recovery payload path.
   --  @return True only for a recognized application recovery payload.
   function Is_Recovery_Payload (Path : String) return Boolean;

   --  Move a recovery payload nothing will restore any more -- its undo
   --  history is ending with the window -- to the system trash under its
   --  original name, and remove the hidden folder that held it.
   --  @param Path Recognized application recovery payload.
   --  @return Success when the payload is in the trash.
   function Release_Recovery_Payload (Path : String) return Mutation_Result;

   --  Return recoverable replacement payloads recorded across directories.
   --  Stale or damaged registry entries are omitted. A pure query: it
   --  changes nothing on disk (see Sweep_Recovery_Registry).
   --  @return Valid registered replacement-recovery payload paths.
   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector;

   --  Finish interrupted recovery work the registry records: drop stale and
   --  duplicate records, resume a stopped release, and remove a stage whose
   --  payload a restore or release moved out on purpose. A stage another
   --  operation is still filling is left alone, so this is safe to run while
   --  other processes preserve, restore or release.
   procedure Sweep_Recovery_Registry;

   --  Preserve an overwritten destination in a location this application can restore.
   --  Native trash backends use an adjacent recovery backup instead of the OS bin.
   --  @param Path Destination to preserve before replacement.
   --  @param Recovery_Path Payload for rollback and Undo.
   --  @return Result of preserving the destination.
   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result;
end Files.File_System.Recovery_Registry;

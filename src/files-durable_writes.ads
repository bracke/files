--  Crash-safe publication of a completely written temporary file.
package Files.Durable_Writes is
   --  Sync Temporary, atomically replace Target, then sync Target's directory.
   --  Directory syncing may be unsupported on hosts that journal directory
   --  entries themselves; an explicit failure is never accepted.
   --  @param Temporary Complete file to sync and publish.
   --  @param Target Destination atomically replaced by Temporary.
   --  @return True only when the required durability sequence succeeds.
   function Publish (Temporary, Target : String) return Boolean;
end Files.Durable_Writes;

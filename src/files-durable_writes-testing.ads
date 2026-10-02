with Hostkit.Durability;

package Files.Durable_Writes.Testing is
   --  Expose the pure publication-state classifier for fault-path tests without
   --  adding environment-controlled behavior to the application.
   --  @param File_Sync Temporary-file synchronization outcome.
   --  @param Replaced Whether the atomic replacement occurred.
   --  @param Directory_Sync Parent-directory synchronization outcome.
   --  @return The corresponding externally observable publication state.
   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result;
end Files.Durable_Writes.Testing;

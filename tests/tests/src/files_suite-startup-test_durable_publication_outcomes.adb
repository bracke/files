separate (Files_Suite.Startup)
   procedure Test_Durable_Publication_Outcomes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Hostkit.Durability;
      use Files.Durable_Writes;
      function Outcome
        (File_Sync      : Hostkit.Durability.Outcome;
         Replaced       : Boolean;
         Directory_Sync : Hostkit.Durability.Outcome)
         return Publication_Result
        renames Files.Durable_Writes.Testing.Outcome_Of;
   begin
      Assert
        (Outcome (Failed, True, Synced) = Not_Published,
         "a failed file sync must prevent publication");
      Assert
        (Outcome (Synced, False, Synced) = Not_Published,
         "a failed replacement must remain unpublished");
      Assert
        (Outcome (Synced, True, Failed) = Published_Not_Durable,
         "directory sync failure must retain the published state");
      Assert
        (Published (Outcome (Synced, True, Failed)),
         "the partial outcome must report publication");
      Assert
        (not Durable (Outcome (Synced, True, Failed)),
         "the partial outcome must not claim durability");
      Assert
        (Outcome (Synced, True, Synced) = Published_Durable,
         "a synced directory must produce a durable result");
      Assert
        (Outcome (Synced, True, Not_Supported) = Published_Durable,
         "journaled hosts without directory sync support are durable");
   end Test_Durable_Publication_Outcomes;

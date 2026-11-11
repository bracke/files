package body Files.Durable_Writes.Testing is
   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result
   is
   begin
      return Files.Durable_Writes.Outcome_Of
        (File_Sync, Replaced, Directory_Sync);
   end Outcome_Of;
end Files.Durable_Writes.Testing;

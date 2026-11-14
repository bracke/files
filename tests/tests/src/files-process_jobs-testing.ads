package Files.Process_Jobs.Testing is
   --  Model the state left by a failed first termination request so the public
   --  nonblocking poll path can exercise its retry against a real helper.
   --  @param Job Running helper session to place at its stop-retry deadline.
   procedure Simulate_Failed_Stop (Job : Session);

   --  Release the owner in tests that exercise abandoned-transport cleanup.
   --  @param Job Reserved transport whose lease is relinquished.
   procedure Release_Owner (Job : Session);

   --  Make the next Launch fail as a refused spawn does (a process limit).
   procedure Refuse_Next_Launch;

   --  @return How many times the orphan reaper has tried to remove a
   --    released transport itself, so a test can wait for that attempt.
   function Removal_Attempts return Natural;

   --  @return How many cleanup workers the orphan reaper has launched, so a
   --    test can tell that shutdown launched none.
   function Cleanup_Launches return Natural;

   --  Disarm a refusal that no Launch consumed, so it cannot leak into the
   --  next test.
   procedure Clear_Refusal;
end Files.Process_Jobs.Testing;

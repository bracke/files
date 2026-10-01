package Files.Process_Jobs.Testing is
   --  Model the state left by a failed first termination request so the public
   --  nonblocking poll path can exercise its retry against a real helper.
   --  @param Job Running helper session to place at its stop-retry deadline.
   procedure Simulate_Failed_Stop (Job : Session);

   --  Release the owner in tests that exercise abandoned-transport cleanup.
   --  @param Job Reserved transport whose lease is relinquished.
   procedure Release_Owner (Job : Session);
end Files.Process_Jobs.Testing;

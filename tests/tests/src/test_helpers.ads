--  The helper processes the test executable runs as, besides the suite: the
--  test-only fixtures a --files-test-* flag names, and the application's own
--  helpers (Files.Helper_Modes) whose work a test arms, through the
--  environment, to stall, fail or damage what it publishes.
package Test_Helpers is

   --  What this run of the test executable was started as. Only the first
   --  argument decides it; each mode checks its own argument count, and a run
   --  with any other count goes on as if no flag had been given.
   type Helper_Mode is
     (No_Test_Helper,
      Crash_Before_Marker,
      Crash_After_Lease,
      Hold_Before_Marker,
      No_Btime_Transport,
      Crash_With_Helper,
      Lease_Holder,
      Abandon_Transport,
      Drain_Reaper,
      Late_Shutdown_Owner,
      Blocked_Helper,
      Scavenge_Helper,
      Operation_Helper,
      Refresh_Helper,
      Watch_Helper,
      Transfer_Helper,
      Folder_Size_Helper,
      Cleanup_Helper);

   --  The mode the command line asks for, read once.
   --
   --  @return The mode named by the first argument, or No_Test_Helper.
   function Requested_Mode return Helper_Mode;

   --  Do what Mode does before the application's helpers are dispatched. A
   --  test-only fixture ends the process here; an application helper its
   --  test armed may stall, fail or end here, or go on to its real work.
   --
   --  @param Mode The mode the executable runs in.
   --  @param Stop True when the executable must return at once, its exit
   --         status already set.
   procedure Run_Before_Dispatch (Mode : Helper_Mode; Stop : out Boolean);

   --  Damage the result an application helper has just published, as the
   --  test that started it armed through the environment.
   --
   --  @param Mode The mode the helper ran in.
   procedure Damage_Result (Mode : Helper_Mode);

end Test_Helpers;

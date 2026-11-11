--  Test-only flush faults for Files.Durability, kept out of the program:
--  the same on every host, in the suite and in the helpers it starts (see
--  Install_From_Environment).
package Files.Durability.Testing is

   --  From now on, fail every flush of a path that ends with Suffix
   --  ("/payload" fails a staged copy's), as a failing disk would.
   --
   --  @param Suffix The path ending; separators compare as one.
   procedure Fail_Syncs_Ending_With (Suffix : String);

   --  From now on, fail the flush of a recovery stage that already holds
   --  its payload: the original has moved into it, and must be put back.
   procedure Fail_Stage_Sync;

   --  Flush everything again.
   procedure Clear;

   --  Arm the faults the environment names, for a helper the suite started:
   --  FILES_TEST_SYNC_FAULT_SUFFIX as Fail_Syncs_Ending_With, and
   --  FILES_TEST_STAGE_SYNC_FAULT (not empty) as Fail_Stage_Sync.
   procedure Install_From_Environment;

end Files.Durability.Testing;

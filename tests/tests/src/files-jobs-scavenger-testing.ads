--  Test-only views of Files.Jobs.Scavenger's recovery state.
package Files.Jobs.Scavenger.Testing is

   --  Why recovery is not Idle -- a scan queued, a coordinator running, a
   --  retry due -- with how the last coordinator ended, for a diagnostic.
   --
   --  @return The reason, or "" when Idle.
   function Busy_Reason return String;

   --  Whether this process reported Directory as unrecoverable.
   --  @param Directory The transport path as the scan listed it.
   --  @return True once a report for it was made.
   function Was_Reported (Directory : String) return Boolean;

   --  True when no scan is queued, none is running and no retry is
   --  scheduled: a test creating recovery fixtures waits for this first.
   --  @return Whether recovery is quiet.
   function Idle return Boolean;

end Files.Jobs.Scavenger.Testing;

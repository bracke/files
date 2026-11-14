--  Test-only views of Files.Job_Scavenger's recovery state.
package Files.Job_Scavenger.Testing is

   --  Why recovery is not Idle -- a scan queued, a coordinator running, a
   --  retry due -- with how the last coordinator ended, for a diagnostic.
   --
   --  @return The reason, or "" when Idle.
   function Busy_Reason return String;

end Files.Job_Scavenger.Testing;

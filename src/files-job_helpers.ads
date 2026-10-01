--  Private command-line protocol shared by the application and test executable.
package Files.Job_Helpers is
   --  Acquire the abandoned transport's exclusive lease and retry cleanup
   --  for a bounded number of attempts. Unresolved guarded
   --  records remain durable after this returns; no cleanup worker lives
   --  forever for a replacement or corrupt record it must refuse to delete.
   --  The timing parameters are exposed for deterministic regression tests.
   --  @param Directory Private transport directory to clean.
   --  @param Expected_Identity Identity captured when the transport was created.
   --  @param Attempt_Limit Maximum cleanup passes before returning.
   --  @param Initial_Retry_Delay Delay after the first unsuccessful pass.
   --  @param Maximum_Retry_Delay Upper bound for the exponential retry delay.
   --  @return True only when the transport pathname no longer exists.
   function Run_Cleanup
     (Directory          : String;
      Expected_Identity  : String;
      Attempt_Limit      : Positive := 8;
      Initial_Retry_Delay : Duration := 0.25;
      Maximum_Retry_Delay : Duration := 4.0) return Boolean;

   --  @return True after handling an internal worker command; False for normal startup.
   function Run_If_Requested return Boolean;
end Files.Job_Helpers;

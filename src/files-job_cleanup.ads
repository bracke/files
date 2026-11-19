--  Bounded cleanup for one validated helper transport.
package Files.Job_Cleanup is
   --  What becomes of a private stage record that still cannot be read:
   --  discarded once the call's last attempt has failed to read it, or kept
   --  for a later cleanup.
   type Unreadable_Records is (Discard_On_Last_Attempt, Keep_Unreadable);

   type Cleanup_Outcome is
     (Cleanup_Removed, Cleanup_Busy, Cleanup_Refused,
      Cleanup_Unrecoverable, Cleanup_Failed);

   --  Retry guarded stage and transport removal without waiting forever.
   --  Every pass claims the abandoned transport before inspecting or deleting
   --  contents; a live owner or unsafe candidate is never cleaned. The lease
   --  is released just before identity-bound root removal on Windows, then
   --  reacquired before any later cleanup pass.
   --  @param Directory Validated helper transport pathname.
   --  @param Expected_Identity Identity recorded when the transport was created.
   --  @param Attempt_Limit Maximum cleanup passes before returning.
   --  @param Initial_Retry_Delay Delay after the first unsuccessful pass.
   --  @param Maximum_Retry_Delay Upper bound for exponential retry delays.
   --  @param Unreadable Whether exhausting this call's retry budget may
   --  discard an unreadable private stage record (Discard_On_Last_Attempt).
   --  @return Removed only when the transport pathname no longer exists.
   function Run
     (Directory           : String;
      Expected_Identity   : String;
      Attempt_Limit       : Positive := 8;
      Initial_Retry_Delay : Duration := 0.25;
      Maximum_Retry_Delay : Duration := 4.0;
      Unreadable          : Unreadable_Records := Discard_On_Last_Attempt)
      return Cleanup_Outcome;
end Files.Job_Cleanup;

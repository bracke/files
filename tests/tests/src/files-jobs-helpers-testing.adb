with Files.Jobs.Cleanup;

package body Files.Jobs.Helpers.Testing is

   use type Files.Jobs.Cleanup.Cleanup_Outcome;

   function Run_Cleanup
     (Directory          : String;
      Expected_Identity  : String;
      Attempt_Limit      : Positive := 8;
      Initial_Retry_Delay : Duration := 0.25;
      Maximum_Retry_Delay : Duration := 4.0) return Boolean
   is
   begin
      return Files.Jobs.Cleanup.Run
        (Directory, Expected_Identity, Attempt_Limit,
         Initial_Retry_Delay, Maximum_Retry_Delay) =
           Files.Jobs.Cleanup.Cleanup_Removed;
   end Run_Cleanup;

end Files.Jobs.Helpers.Testing;

with Ada.Real_Time;

package body Files.Jobs.Process.Testing is
   procedure Simulate_Failed_Stop (Job : Session) is
   begin
      if Job.Shared /= null then
         Job.Shared.Helper.Stop_Requested := True;
         Job.Shared.Helper.Terminated := False;
         Job.Shared.Helper.Stop_Retry_At := Ada.Real_Time.Clock;
      end if;
   end Simulate_Failed_Stop;

   procedure Release_Owner (Job : Session) is
   begin
      if Job.Shared /= null then
         Files.Jobs.Transports.Release (Job.Shared.Owner);
      end if;
   end Release_Owner;

   procedure Refuse_Next_Launch is
   begin
      Test_Refuse_Next_Launch := True;
   end Refuse_Next_Launch;

   function Removal_Attempts return Natural is (Test_Removal_Attempts);

   function Cleanup_Launches return Natural is (Test_Cleanup_Launches);

   procedure Clear_Refusal is
   begin
      Test_Refuse_Next_Launch := False;
   end Clear_Refusal;
end Files.Jobs.Process.Testing;

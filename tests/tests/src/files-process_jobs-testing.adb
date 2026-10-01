with Ada.Real_Time;

package body Files.Process_Jobs.Testing is
   procedure Simulate_Failed_Stop (Job : Session) is
   begin
      if Job.Shared /= null then
         Job.Shared.Stop_Requested := True;
         Job.Shared.Terminated := False;
         Job.Shared.Stop_Retry_At := Ada.Real_Time.Clock;
      end if;
   end Simulate_Failed_Stop;

   procedure Release_Owner (Job : Session) is
   begin
      if Job.Shared /= null then
         Files.Job_Transports.Release (Job.Shared.Owner);
      end if;
   end Release_Owner;
end Files.Process_Jobs.Testing;

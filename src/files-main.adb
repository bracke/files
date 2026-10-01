with Files.Application;
with Files.Job_Helpers;
with Files.Job_Context;
with Files.Job_Scavenger;
with Files.Process_Jobs;
with Files.Recovery_CLI;
with Hostkit.Process;

procedure Files.Main is
   Reaped  : Boolean;
   Stopped : Boolean;
begin
   if Files.Recovery_CLI.Run_If_Requested then
      Files.Job_Scavenger.Shutdown (Reaped);
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown (Stopped);
      if not Reaped or else not Stopped then
         Hostkit.Process.End_Now (1);
      end if;
   elsif Files.Job_Helpers.Run_If_Requested then
      Files.Job_Scavenger.Shutdown (Reaped);
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown (Stopped);
      if not Reaped or else not Stopped then
         --  Ada task finalization could otherwise wait without a bound for
         --  the coordinator monitor or orphan reaper.
         Hostkit.Process.End_Now (1);
      end if;
   else
      Files.Job_Scavenger.Scavenge;
      Files.Application.Run;
      Files.Job_Scavenger.Shutdown (Reaped);
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown (Stopped);
      if not Reaped or else not Stopped then
         --  Recovery is durable and resumes on the next launch. If only its
         --  monitor is still in a host filesystem call, a normal window close
         --  is still a successful application exit.
         Hostkit.Process.End_Now (if Stopped then 0 else 1);
      end if;
   end if;
exception
   when others =>
      Files.Job_Scavenger.Shutdown (Reaped);
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown (Stopped);
      if not Reaped or else not Stopped then
         Hostkit.Process.End_Now (1);
      end if;
      raise;
end Files.Main;

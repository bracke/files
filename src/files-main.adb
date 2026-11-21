with Files.Application;
with Files.Job_Drivers.Helpers;
with Files.Jobs.Context;
with Files.Jobs.Scavenger;
with Files.Jobs.Process;
with Files.Recovery_CLI;
with Files.Diagnostics;
with Guikit.Errors;
with Hostkit.Process;
with Ada.Command_Line;

procedure Files.Main is
   Reaped  : Boolean;
   Stopped : Boolean;
   Status  : Ada.Command_Line.Exit_Status := Ada.Command_Line.Success;

   --  Stop the background workers every exit path stops: Reaped and Stopped
   --  say whether each finished in time.
   procedure Shut_Down_Workers is
   begin
      Files.Jobs.Scavenger.Shutdown (Reaped);
      Files.Jobs.Context.Shutdown;
      Files.Jobs.Process.Shutdown (Stopped);
   end Shut_Down_Workers;
begin
   --  What guikit catches and carries on past is recorded with ours.
   Guikit.Errors.Set_Reporter (Files.Diagnostics.Note'Access);
   if Files.Recovery_CLI.Run_If_Requested then
      Shut_Down_Workers;
      if not Reaped or else not Stopped then
         Hostkit.Process.End_Now (1);
      end if;
   elsif Files.Job_Drivers.Helpers.Run_If_Requested then
      Shut_Down_Workers;
      if not Reaped or else not Stopped then
         --  Ada task finalization could otherwise wait without a bound for
         --  the coordinator monitor or orphan reaper.
         Hostkit.Process.End_Now (1);
      end if;
   else
      Files.Jobs.Scavenger.Scavenge;
      Status := Files.Application.Run;
      Shut_Down_Workers;
      if not Reaped or else not Stopped then
         --  Recovery is durable and resumes on the next launch. If only its
         --  monitor is still in a host filesystem call, a normal window close
         --  is still a successful application exit.
         Hostkit.Process.End_Now
           (if Stopped then Integer (Status) else Integer (Ada.Command_Line.Failure));
      end if;
      Ada.Command_Line.Set_Exit_Status (Status);
   end if;
exception
   when others =>
      Shut_Down_Workers;
      if not Reaped or else not Stopped then
         Hostkit.Process.End_Now (1);
      end if;
      raise;
end Files.Main;

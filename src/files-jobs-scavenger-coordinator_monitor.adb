separate (Files.Jobs.Scavenger)
   task body Coordinator_Monitor is
      Monitored_Program : Files.Types.UString;
      Monitored_Child   : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Active            : Boolean := False;
      Attempts          : Natural := 0;
      Stopping          : Boolean := False;
      Requested         : Boolean;
      Requested_Program : Files.Types.UString;
      Retry_Pending     : Boolean := False;
      Retry_At          : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Retry_Seconds     : Natural := 1;
      --  How the last scan ended, for Busy_Reason.
      Last_End          : Unbounded_String;

      --  Busy_Reason's text for the state this loop leaves.
      function Why return String is
         Waiting : constant Duration :=
           (if Retry_Pending then Ada.Real_Time.To_Duration (Retry_At - Ada.Real_Time.Clock) else 0.0);
      begin
         return
           (if Active then "coordinator-running,attempt=" & Files.Text_Basics.Natural_Text (Attempts)
            elsif Retry_Pending
            then "retry-due,seconds=" & Files.Text_Basics.Natural_Text (Natural (Duration'Max (Waiting, 0.0)))
            else "")
           & (if Length (Last_End) > 0 then ";" & To_String (Last_End) else "");
      end Why;

      procedure Schedule_Retry (Program : Files.Types.UString) is
      begin
         Monitored_Program := Program;
         Attempts := 0;
         Retry_Pending := True;
         Retry_At := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (Retry_Seconds);
         Retry_Seconds := Natural'Min (60, Retry_Seconds * 2);
      end Schedule_Retry;

      procedure Scan_After_Launch_Failure (Program : Files.Types.UString) is
      begin
         if Run (Wait_For_Grace => False, Interruptible => True) then
            Retry_Pending := False;
            Retry_Seconds := 1;
            Last_End := To_Unbounded_String ("in-monitor-scan-finished");
         else
            Last_End := To_Unbounded_String ("in-monitor-scan-unresolved");
            Schedule_Retry (Program);
         end if;
      end Scan_After_Launch_Failure;

      --  Start Program as the scavenging coordinator.
      function Launch (Program : Files.Types.UString) return Boolean is
         Arguments : Hostkit.String_Vectors.Vector;
      begin
         Arguments.Append (To_Unbounded_String (Flag (Scavenge)));
         return Length (Program) > 0
           and then Files.Jobs.Helper_Modes.Start_Helper (Arguments, Monitored_Child, To_String (Program));
      end Launch;

      procedure Start_Coordinator (Program : Files.Types.UString) is
      begin
         Retry_Pending := False;
         Active := Launch (Program);
         if Active then
            Monitored_Program := Program;
            Attempts := 1;
         else
            Scan_After_Launch_Failure (Program);
         end if;
      end Start_Coordinator;

      --  Kill the child and collect it, polling every Reap_Poll_Interval.
      --  Wait answering False means the handle is invalid or the host refused
      --  the question; it will not start answering, and killing by the stale
      --  handle's id could hit a recycled PID, so that ends the reap like an
      --  exit does. The loop is also bounded: this task is library level, so
      --  an unkillable child must not keep it (and with it program exit)
      --  running forever. A child still running after Reap_Poll_Limit polls
      --  is left unreleased, since it has not been collected.
      procedure Stop_And_Reap is
         Reap_Poll_Interval : constant Duration := 0.05;
         Reap_Poll_Limit    : constant := 100;
      begin
         for Poll in 1 .. Reap_Poll_Limit loop
            exit when not Active;
            if Hostkit.Spawn.Supervision.Has_Ended (Monitored_Child) then
               Hostkit.Spawn.Release (Monitored_Child);
               Active := False;
            else
               declare
                  --  A refused stop is asked again on the next poll.
                  Sent : constant Boolean := Hostkit.Spawn.Supervision.Stop_Now (Monitored_Child);
                  pragma Unreferenced (Sent);
               begin
                  delay Reap_Poll_Interval;
               end;
            end if;
         end loop;
         Active := False;
      end Stop_And_Reap;

      --  The coordinator ended as Status says: a failed one is started once
      --  more, then retried with a back-off.
      procedure Settle_Ended (Status : Hostkit.Spawn.Status) is
         Success : constant Boolean :=
           Status.State = Hostkit.Spawn.Wait_Exited and then Status.Exit_Code = 0;
      begin
         Last_End := To_Unbounded_String
           ((case Status.State is
               when Hostkit.Spawn.Wait_Exited => "last-coordinator-exit=" & Status.Exit_Code'Image,
               when Hostkit.Spawn.Wait_Signalled => "last-coordinator-signalled",
               when others => "last-coordinator-lost"));
         Hostkit.Spawn.Release (Monitored_Child);
         Active := False;
         if not Success and then Attempts < 2 then
            Attempts := Attempts + 1;
            Active := Launch (Monitored_Program);
            if not Active then
               Scan_After_Launch_Failure (Monitored_Program);
            end if;
         elsif not Success then
            Schedule_Retry (Monitored_Program);
         else
            Retry_Pending := False;
            Retry_Seconds := 1;
         end if;
      end Settle_Ended;

      --  Whether the running coordinator has ended, and if so what follows.
      procedure Poll_Coordinator is
         Status : Hostkit.Spawn.Status;
      begin
         if not Hostkit.Spawn.Is_Valid (Monitored_Child) then
            --  The host will not answer for this handle, and it will not
            --  start to. Staying Active would poll it forever and never take
            --  another scan request, so drop it as Stop_And_Reap does and go
            --  back to accepting requests. Whether the scan finished is
            --  unknown, so count it as failed: a scan is safe to repeat, and
            --  the retry backs off.
            Last_End := To_Unbounded_String ("last-coordinator-unanswered");
            Hostkit.Spawn.Release (Monitored_Child);
            Active := False;
            Schedule_Retry (Monitored_Program);
         elsif Hostkit.Spawn.Supervision.Has_Ended (Monitored_Child, Status) then
            Settle_Ended (Status);
         end if;
      end Poll_Coordinator;

      --  With no coordinator running: start one for a queued request, or for
      --  a retry that is due.
      procedure Start_Next is
      begin
         Scan_Requests.Take (Requested, Requested_Program);
         if Requested then
            Start_Coordinator (Requested_Program);
         elsif Retry_Pending and then Ada.Real_Time.Clock >= Retry_At then
            Start_Coordinator (Monitored_Program);
         end if;
      end Start_Next;
   begin
      Main_Loop : loop
         select
            accept Stop do
               Stopping := True;
            end Stop;
         or
            delay 0.05;
         end select;
         if Stopping or else Monitor_Control.Stop_Requested then
            Stop_And_Reap;
            exit Main_Loop;
         end if;
         if Active then
            Poll_Coordinator;
         end if;
         if not Active then
            Start_Next;
         end if;
         Scan_Requests.Settle (Active or else Retry_Pending, Why);
      end loop Main_Loop;
      Scan_Requests.Settle (False);
      Monitor_Result.Mark_Complete;
   exception
      --  Without this an exception would end recovery scans silently and leave
      --  Monitor_Result incomplete, so Shutdown would never clean the report.
      when E : others =>
         Files.Diagnostics.Note (E, "Files.Jobs.Scavenger.Coordinator_Monitor");
         Scan_Requests.Settle (False);
         Monitor_Result.Mark_Complete;
   end Coordinator_Monitor;

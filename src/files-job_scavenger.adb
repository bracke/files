with Files.Diagnostics;
with Ada.Directories;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Streams;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.File_System;
with Files.Job_Cleanup;
with Files.Job_Transports;
with Files.Localization;
with Files.Types;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

package body Files.Job_Scavenger is
   use Ada.Strings.Unbounded;
   use type Files.Job_Cleanup.Cleanup_Outcome;
   use type Files.Job_Transports.Claim_Outcome;
   use type Hostkit.Lease_Files.Open_Outcome;
   use type Hostkit.Spawn.Spawn_Outcome;
   use type Hostkit.Spawn.Wait_State;
   use type Ada.Real_Time.Time;
   use type Ada.Streams.Stream_Element_Array;

   package Reported_Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   Report_Directory : Files.Types.UString;
   Report_Environment : constant String := "FILES_RECOVERY_REPORT_DIR";
   Report_Name : constant String := "unsafe";
   Report_Marker : constant Ada.Streams.Stream_Element_Array :=
     [Character'Pos ('u'), Character'Pos ('n'), Character'Pos ('s'),
      Character'Pos ('a'), Character'Pos ('f'), Character'Pos ('e'),
      Character'Pos (ASCII.LF)];
   Previous_Report_Directory : Files.Types.UString;
   Previous_Report_Existed : Boolean := False;

   function Has_Unrecoverable return Boolean is
      Report : Hostkit.Lease_Files.Lease;
      Read_Back : Ada.Streams.Stream_Element_Array (Report_Marker'Range);
      Valid : Boolean := False;
   begin
      if Length (Report_Directory) = 0
        or else Hostkit.Lease_Files.Open
          (Hostkit.Fs.Join (To_String (Report_Directory), Report_Name),
           Hostkit.Lease_Files.Shared, Writable => False, Item => Report) /=
             Hostkit.Lease_Files.Opened
      then
         return False;
      end if;
      Valid := Hostkit.Lease_Files.Size (Report) = Report_Marker'Length
        and then Hostkit.Lease_Files.Read_At (Report, Read_Back)
        and then Read_Back = Report_Marker;
      Hostkit.Lease_Files.Release (Report);
      return Valid;
   exception
      when others =>
         Hostkit.Lease_Files.Release (Report);
         return False;
   end Has_Unrecoverable;

   procedure Clean_Report is
   begin
      if Length (Report_Directory) = 0 then
         return;
      end if;
      declare
         Directory : constant String := To_String (Report_Directory);
         Target : constant String := Hostkit.Fs.Join (Directory, Report_Name);
      begin
         if Ada.Environment_Variables.Value (Report_Environment, "") = Directory then
            if Previous_Report_Existed then
               Ada.Environment_Variables.Set
                 (Report_Environment, To_String (Previous_Report_Directory));
            else
               Ada.Environment_Variables.Clear (Report_Environment);
            end if;
         end if;
         if Ada.Directories.Exists (Directory)
           and then not Hostkit.Fs.Is_Link (Directory)
         then
            if Ada.Directories.Exists (Target) then
               Ada.Directories.Delete_File (Target);
            end if;
            Ada.Directories.Delete_Directory (Directory);
         end if;
      end;
      Report_Directory := Null_Unbounded_String;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Job_Scavenger");
   end Clean_Report;

   protected Monitor_Result is
      procedure Mark_Complete;
      function Complete return Boolean;
   private
      Done : Boolean := False;
   end Monitor_Result;

   protected body Monitor_Result is
      procedure Mark_Complete is
      begin
         Done := True;
      end Mark_Complete;

      function Complete return Boolean is (Done);
   end Monitor_Result;

   protected Monitor_Control is
      procedure Request_Stop;
      function Stop_Requested return Boolean;
   private
      Stopping : Boolean := False;
   end Monitor_Control;

   protected body Monitor_Control is
      procedure Request_Stop is
      begin
         Stopping := True;
      end Request_Stop;

      function Stop_Requested return Boolean is (Stopping);
   end Monitor_Control;

   --  Requests for the monitor, and whether it is busy. Taking a request
   --  marks it busy in the same protected action, so Idle can never read a
   --  request as both no longer queued and not yet started.
   protected Scan_Requests is
      procedure Submit (Program : Files.Types.UString);
      procedure Take (Requested : out Boolean; Program : out Files.Types.UString);
      procedure Settle (Still_Busy : Boolean);
      function Quiet return Boolean;
   private
      Pending : Boolean := False;
      Pending_Program : Files.Types.UString;
      Busy : Boolean := False;
   end Scan_Requests;

   protected Terminal_Reports is
      procedure Mark_If_New (Directory : String; New_Report : out Boolean);
   private
      Reported : Reported_Path_Sets.Set;
   end Terminal_Reports;

   protected body Terminal_Reports is
      procedure Mark_If_New (Directory : String; New_Report : out Boolean) is
      begin
         New_Report := not Reported.Contains (Directory);
         if New_Report then
            Reported.Insert (Directory);
         end if;
      end Mark_If_New;
   end Terminal_Reports;

   --  The localized report label, rendered on the main thread by Scavenge.
   --  Report_Unrecoverable also runs on the Coordinator_Monitor task, and
   --  Files.Localization keeps unsynchronized state the UI reads every frame,
   --  so the task must not look the text up itself.
   protected Report_Label is
      procedure Set (Text : String);
      function Get return String;
   private
      Value : Unbounded_String;
   end Report_Label;

   protected body Report_Label is
      procedure Set (Text : String) is
      begin
         Value := To_Unbounded_String (Text);
      end Set;

      function Get return String is (To_String (Value));
   end Report_Label;

   procedure Report_Unrecoverable (Directory : String) is
      New_Report : Boolean;
      Report : Hostkit.Lease_Files.Lease;
      Label  : constant String := Report_Label.Get;
   begin
      Terminal_Reports.Mark_If_New (Directory, New_Report);
      if New_Report then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            (if Label /= "" then Label else "recovery.unsafe_transport") & ": " & Directory);
         declare
            Target_Directory : constant String :=
              Ada.Environment_Variables.Value (Report_Environment, "");
         begin
            if Target_Directory /= ""
              and then Ada.Directories.Exists (Target_Directory)
              and then not Hostkit.Fs.Is_Link (Target_Directory)
            then
               declare
                  Target : constant String :=
                    Hostkit.Fs.Join (Target_Directory, Report_Name);
                  Written : Boolean;
               begin
                  if Hostkit.Lease_Files.Create (Target, Report) =
                    Hostkit.Lease_Files.Opened
                  then
                     Written := Hostkit.Lease_Files.Write_At
                       (Report, Report_Marker);
                     pragma Unreferenced (Written);
                     Hostkit.Lease_Files.Release (Report);
                  end if;
               end;
            end if;
         end;
      end if;
   exception
      when others =>
         Hostkit.Lease_Files.Release (Report);
   end Report_Unrecoverable;

   protected body Scan_Requests is
      procedure Submit (Program : Files.Types.UString) is
      begin
         Pending_Program := Program;
         Pending := True;
      end Submit;

      procedure Take (Requested : out Boolean; Program : out Files.Types.UString) is
      begin
         Requested := Pending;
         Program := Pending_Program;
         Busy := Busy or else Pending;
         Pending := False;
         Pending_Program := Null_Unbounded_String;
      end Take;

      procedure Settle (Still_Busy : Boolean) is
      begin
         Busy := Still_Busy;
      end Settle;

      function Quiet return Boolean is (not Pending and then not Busy);
   end Scan_Requests;

   function Idle return Boolean is (Scan_Requests.Quiet);

   task Coordinator_Monitor is
      entry Stop;
   end Coordinator_Monitor;

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
         else
            Schedule_Retry (Program);
         end if;
      end Scan_After_Launch_Failure;

      procedure Start_Coordinator (Program : Files.Types.UString) is
         Arguments : Hostkit.String_Vectors.Vector;
      begin
         Retry_Pending := False;
         Arguments.Append (To_Unbounded_String ("--files-scavenge"));
         Active := Length (Program) > 0
           and then Hostkit.Spawn.Start
             (To_String (Program), Arguments, (others => <>),
              Monitored_Child) = Hostkit.Spawn.Spawn_Ok;
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
         Status : Hostkit.Spawn.Status;
         Found  : Boolean;
         Sent   : Boolean;
      begin
         for Poll in 1 .. Reap_Poll_Limit loop
            exit when not Active;
            Found := Hostkit.Spawn.Wait (Monitored_Child, Hostkit.Spawn.Wait_Poll, Status);
            if not Found
              or else Status.State in Hostkit.Spawn.Wait_Exited
                | Hostkit.Spawn.Wait_Signalled | Hostkit.Spawn.Wait_Lost
            then
               Hostkit.Spawn.Release (Monitored_Child);
               Active := False;
            else
               Sent := Hostkit.Signals.Send_To_Process
                 (Hostkit.Spawn.Process_Id (Monitored_Child), Hostkit.Signals.Signal_Kill);
               if not Sent then
                  Sent := Hostkit.Process.Request_Stop
                    (Hostkit.Spawn.Process_Id (Monitored_Child));
               end if;
               delay Reap_Poll_Interval;
            end if;
         end loop;
         Active := False;
      end Stop_And_Reap;
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
            declare
               Status : Hostkit.Spawn.Status;
               Found  : constant Boolean :=
                 Hostkit.Spawn.Wait (Monitored_Child, Hostkit.Spawn.Wait_Poll, Status);
            begin
               if Found and then Status.State in Hostkit.Spawn.Wait_Exited
                 | Hostkit.Spawn.Wait_Signalled | Hostkit.Spawn.Wait_Lost
               then
                  declare
                     Success : constant Boolean :=
                       Status.State = Hostkit.Spawn.Wait_Exited
                       and then Status.Exit_Code = 0;
                  begin
                     Hostkit.Spawn.Release (Monitored_Child);
                     Active := False;
                     if not Success and then Attempts < 2 then
                        declare
                           Arguments : Hostkit.String_Vectors.Vector;
                        begin
                           Arguments.Append (To_Unbounded_String ("--files-scavenge"));
                           Attempts := Attempts + 1;
                           Active := Hostkit.Spawn.Start
                             (To_String (Monitored_Program), Arguments, (others => <>),
                              Monitored_Child) =
                               Hostkit.Spawn.Spawn_Ok;
                           if not Active then
                              Scan_After_Launch_Failure (Monitored_Program);
                           end if;
                        end;
                     elsif not Success then
                        Schedule_Retry (Monitored_Program);
                     else
                        Retry_Pending := False;
                        Retry_Seconds := 1;
                     end if;
                  end;
               elsif not Found then
                  --  The handle is invalid or the host refused the question,
                  --  and it will not start answering. Staying Active would
                  --  poll it forever and never take another scan request, so
                  --  drop the handle as Stop_And_Reap does and go back to
                  --  accepting requests. Whether the scan finished is
                  --  unknown, so count it as failed: a scan is safe to
                  --  repeat, and the retry backs off.
                  Hostkit.Spawn.Release (Monitored_Child);
                  Active := False;
                  Schedule_Retry (Monitored_Program);
               end if;
            end;
         end if;
         if not Active then
            Scan_Requests.Take (Requested, Requested_Program);
            if Requested then
               Start_Coordinator (Requested_Program);
            elsif Retry_Pending and then Ada.Real_Time.Clock >= Retry_At then
               Start_Coordinator (Monitored_Program);
            end if;
         end if;
         Scan_Requests.Settle (Active or else Retry_Pending);
      end loop Main_Loop;
      Scan_Requests.Settle (False);
      Monitor_Result.Mark_Complete;
   exception
      --  Without this an exception would end recovery scans silently and leave
      --  Monitor_Result incomplete, so Shutdown would never clean the report.
      when E : others =>
         Files.Diagnostics.Note (E, "Files.Job_Scavenger.Coordinator_Monitor");
         Scan_Requests.Settle (False);
         Monitor_Result.Mark_Complete;
   end Coordinator_Monitor;

   procedure Scavenge (Coordinator : String := "") is
      Program   : constant String :=
        (if Coordinator = "" then Hostkit.Fs.Own_Executable else Coordinator);
      Resolved  : constant String := Hostkit.Process.Locate (Program);
   begin
      Report_Label.Set (Files.Localization.Text ("recovery.unsafe_transport"));
      --  One coordinator bounds recovery to a single process regardless of
      --  how many abandoned transports exist. It performs the scan outside
      --  application startup and serializes each transport through its lease.
      if Length (Report_Directory) = 0 then
         Previous_Report_Existed :=
           Ada.Environment_Variables.Exists (Report_Environment);
         if Previous_Report_Existed then
            Previous_Report_Directory := To_Unbounded_String
              (Ada.Environment_Variables.Value (Report_Environment));
         end if;
         Report_Directory := To_Unbounded_String
           (Hostkit.Fs.Create_Temporary_Directory ("files-recovery-report-"));
         if Length (Report_Directory) > 0 then
            Ada.Environment_Variables.Set
              (Report_Environment, To_String (Report_Directory));
         end if;
      end if;
      Scan_Requests.Submit (To_Unbounded_String (Resolved));
   end Scavenge;

   procedure Shutdown (Reaped : out Boolean) is
   begin
      Reaped := Monitor_Result.Complete;
      if Reaped then
         Clean_Report;
         return;
      end if;
      Monitor_Control.Request_Stop;
      if Coordinator_Monitor'Terminated then
         Reaped := Monitor_Result.Complete;
         if Reaped then
            Clean_Report;
         end if;
         return;
      end if;
      --  Acceptance only requests a stop. The monitor retains the child and
      --  reaps it outside the rendezvous, so a stuck child cannot hold this
      --  caller forever.
      select
         Coordinator_Monitor.Stop;
      or
         delay 0.2;
      end select;
      for Poll in 1 .. 180 loop
         exit when Monitor_Result.Complete or else Coordinator_Monitor'Terminated;
         delay 0.01;
      end loop;
      Reaped := Monitor_Result.Complete;
      if Reaped then
         Clean_Report;
      end if;
   exception
      when Tasking_Error =>
         Reaped := Monitor_Result.Complete;
         if Reaped then
            Clean_Report;
         end if;
   end Shutdown;

   procedure Shutdown is
      Reaped : Boolean;
   begin
      Shutdown (Reaped);
   end Shutdown;

   function Run
     (Minimum_Unmarked_Age : Duration := 1.0;
      Wait_For_Grace       : Boolean := True;
      Interruptible        : Boolean := False) return Boolean
   is
      Prefix : constant String := "files-job-";

      function Is_Current_Name (Directory : String) return Boolean is
         Name : constant String := Ada.Directories.Simple_Name (Directory);
         First_Hex : constant Positive := Name'First + Prefix'Length;
      begin
         return Name'Length = Prefix'Length + 32
           and then Name (Name'First .. First_Hex - 1) = Prefix
           and then (for all Position in First_Hex .. Name'Last =>
             Name (Position) in '0' .. '9' | 'a' .. 'f');
      exception
         when others => return False;
      end Is_Current_Name;

      procedure Scan (Retry_Needed : out Boolean) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Open   : Boolean := False;
         Filter : constant Ada.Directories.Filter_Type :=
           [Ada.Directories.Directory => True, others => False];
      begin
         Retry_Needed := False;
         Ada.Directories.Start_Search
           (Search, Hostkit.Fs.Temp_Directory, "files-job-*", Filter);
         Open := True;
         while Ada.Directories.More_Entries (Search) loop
            if Interruptible and then Monitor_Control.Stop_Requested then
               Retry_Needed := True;
               exit;
            end if;
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Directory : constant String := Ada.Directories.Full_Name (Item);
               Identity  : Files.Types.UString;
               Read_Error : Boolean;
               Claim     : Files.Job_Transports.Lease;
            begin
               Files.Job_Transports.Inspect_Marker (Directory, Identity, Read_Error);
               if Read_Error then
                  Retry_Needed := True;
               elsif Length (Identity) > 0 then
                  declare
                     Outcome : constant Files.Job_Cleanup.Cleanup_Outcome :=
                       Files.Job_Cleanup.Run
                         (Directory, To_String (Identity),
                          Attempt_Limit => (if Interruptible then 1 else 8),
                          Discard_Unreadable_On_Last_Attempt => not Interruptible);
                  begin
                     if Outcome = Files.Job_Cleanup.Cleanup_Failed then
                        Retry_Needed := True;
                     elsif Outcome in Files.Job_Cleanup.Cleanup_Unrecoverable
                       | Files.Job_Cleanup.Cleanup_Refused
                     then
                        Report_Unrecoverable (Directory);
                     end if;
                  end;
               elsif Is_Current_Name (Directory) then
                  if Ada.Directories.Exists
                    (Hostkit.Fs.Join (Directory, ".files-job-transport"))
                    or else Hostkit.Fs.Is_Link
                      (Hostkit.Fs.Join (Directory, ".files-job-transport"))
                  then
                     --  The marker may have been published after the first
                     --  inspection. Re-read before classifying it as invalid.
                     Files.Job_Transports.Inspect_Marker (Directory, Identity, Read_Error);
                     if Read_Error or else Length (Identity) > 0 then
                        Retry_Needed := True;
                     else
                        Report_Unrecoverable (Directory);
                     end if;
                  else
                     declare
                        Incomplete_Identity : Files.Types.UString;
                        Outcome : constant Files.Job_Transports.Claim_Outcome :=
                          Files.Job_Transports.Claim_Incomplete
                            (Directory, Incomplete_Identity, Claim, Minimum_Unmarked_Age);
                     begin
                        if Outcome = Files.Job_Transports.Claim_Acquired then
                           declare
                              Removed : constant Boolean :=
                                Files.File_System.Delete_Staging_Entry
                                  (Directory, To_String (Incomplete_Identity)).Success;
                           begin
                              if not Removed
                                or else Ada.Directories.Exists (Directory)
                                or else Hostkit.Fs.Is_Link (Directory)
                              then
                                 Retry_Needed := True;
                              else
                                 Files.Job_Transports.Forget_Witness (Directory, Claim);
                              end if;
                           end;
                        elsif Outcome = Files.Job_Transports.Claim_Deferred
                          or else Outcome = Files.Job_Transports.Claim_Error
                        then
                           Retry_Needed := True;
                        elsif Outcome in Files.Job_Transports.Claim_Unrecoverable
                          | Files.Job_Transports.Claim_Refused
                        then
                           Report_Unrecoverable (Directory);
                        end if;
                     end;
                  end if;
               end if;
            exception
               when others => Retry_Needed := True;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         Open := False;
         Files.Job_Transports.Scavenge_Witnesses;
      exception
         when others =>
            Retry_Needed := True;
            if Open then
               begin
                  Ada.Directories.End_Search (Search);
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.Job_Scavenger");
               end;
            end if;
      end Scan;

      Retry_Needed : Boolean;
      Grace            : constant Duration := Duration'Max (0.0, Minimum_Unmarked_Age);
   begin
      --  Called non-interruptibly only on a main thread (a helper process
      --  runs it directly), where looking the label up is safe.
      if not Interruptible and then Report_Label.Get = "" then
         Report_Label.Set (Files.Localization.Text ("recovery.unsafe_transport"));
      end if;
      Scan (Retry_Needed);
      if Wait_For_Grace and then Retry_Needed and then Grace > 0.0 then
         delay Grace;
         Scan (Retry_Needed);
      end if;
      return not Retry_Needed;
   end Run;
end Files.Job_Scavenger;

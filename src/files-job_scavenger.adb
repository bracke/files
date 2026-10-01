with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.File_System;
with Files.Job_Cleanup;
with Files.Job_Transports;
with Files.Localization;
with Files.Types;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

package body Files.Job_Scavenger is
   use Ada.Strings.Unbounded;
   use type Files.Job_Cleanup.Cleanup_Outcome;
   use type Files.Job_Transports.Claim_Outcome;
   use type Hostkit.Spawn.Spawn_Outcome;
   use type Hostkit.Spawn.Wait_State;
   use type Ada.Real_Time.Time;

   Report_Directory : Files.Types.UString;
   Report_Environment : constant String := "FILES_RECOVERY_REPORT_DIR";
   Report_Name : constant String := "unsafe";
   Previous_Report_Directory : Files.Types.UString;
   Previous_Report_Existed : Boolean := False;

   function Has_Unrecoverable return Boolean is
     (Length (Report_Directory) > 0
      and then Ada.Directories.Exists
        (Hostkit.Fs.Join (To_String (Report_Directory), Report_Name)));

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
      when others => null;
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

   protected Scan_Requests is
      procedure Submit (Program : Files.Types.UString);
      procedure Take (Requested : out Boolean; Program : out Files.Types.UString);
   private
      Pending : Boolean := False;
      Pending_Program : Files.Types.UString;
   end Scan_Requests;

   protected Terminal_Reports is
      procedure Mark_If_New (Directory : String; New_Report : out Boolean);
   private
      Reported : Files.Types.String_Vectors.Vector;
   end Terminal_Reports;

   protected body Terminal_Reports is
      procedure Mark_If_New (Directory : String; New_Report : out Boolean) is
         Value : constant Files.Types.UString := To_Unbounded_String (Directory);
      begin
         New_Report := not Reported.Contains (Value);
         if New_Report then
            Reported.Append (Value);
         end if;
      end Mark_If_New;
   end Terminal_Reports;

   procedure Report_Unrecoverable (Directory : String) is
      New_Report : Boolean;
      Report : Ada.Text_IO.File_Type;
   begin
      Terminal_Reports.Mark_If_New (Directory, New_Report);
      if New_Report then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Files.Localization.Text ("recovery.unsafe_transport") & ": " & Directory);
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
               begin
                  if Ada.Directories.Exists (Target) then
                     Ada.Text_IO.Open (Report, Ada.Text_IO.Append_File, Target);
                  else
                     Ada.Text_IO.Create (Report, Ada.Text_IO.Out_File, Target);
                  end if;
                  Ada.Text_IO.Put_Line (Report, Directory);
                  Ada.Text_IO.Close (Report);
               end;
            end if;
         end;
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Report) then
            Ada.Text_IO.Close (Report);
         end if;
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
         Pending := False;
         Pending_Program := Null_Unbounded_String;
      end Take;
   end Scan_Requests;

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

      procedure Stop_And_Reap is
         Status : Hostkit.Spawn.Status;
         Found  : Boolean;
         Sent   : Boolean;
      begin
         while Active loop
            Found := Hostkit.Spawn.Wait (Monitored_Child, Hostkit.Spawn.Wait_Poll, Status);
            if Found and then Status.State in Hostkit.Spawn.Wait_Exited
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
               delay 0.05;
            end if;
         end loop;
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
      end loop Main_Loop;
      Monitor_Result.Mark_Complete;
   end Coordinator_Monitor;

   procedure Scavenge (Coordinator : String := "") is
      Program   : constant String :=
        (if Coordinator = "" then Hostkit.Fs.Own_Executable else Coordinator);
      Resolved  : constant String := Hostkit.Process.Locate (Program);
   begin
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
                                (if Length (Incomplete_Identity) = 0
                                 then Files.Job_Transports.Remove_Empty_Incomplete (Directory, Claim)
                                 else Files.File_System.Delete_Staging_Entry
                                   (Directory, To_String (Incomplete_Identity)).Success);
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
                  when others => null;
               end;
            end if;
      end Scan;

      Retry_Needed : Boolean;
      Grace            : constant Duration := Duration'Max (0.0, Minimum_Unmarked_Age);
   begin
      Scan (Retry_Needed);
      if Wait_For_Grace and then Retry_Needed and then Grace > 0.0 then
         delay Grace;
         Scan (Retry_Needed);
      end if;
      return not Retry_Needed;
   end Run;
end Files.Job_Scavenger;

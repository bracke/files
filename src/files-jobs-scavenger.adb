with Files.Protocol_Names;
with Files.Timing;
with Files.IO.Fs_Primitives;
with Files.Jobs.Helper_Modes;
with Files.Diagnostics;
with Files.Environment;
with Ada.Real_Time;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.Jobs.Cleanup;
with Files.Jobs.Storage;
with Files.Jobs.Transports;
with Files.Types;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.IO.Lease_Streams;
with Hostkit.Process;
with Hostkit.Spawn;
with Hostkit.Spawn.Supervision;
with Files.Name_Parts;
with Files.Text_Basics;

package body Files.Jobs.Scavenger is
   use Files.Jobs.Helper_Modes;
   use Ada.Strings.Unbounded;
   use type Files.Jobs.Cleanup.Cleanup_Outcome;
   use type Files.Jobs.Transports.Claim_Outcome;
   use type Hostkit.Spawn.Wait_State;
   use type Ada.Real_Time.Time;

   package Reported_Path_Sets renames Files.Types.String_Sets;

   Report_Directory : Files.Types.UString;
   Report_Environment : constant String := "FILES_RECOVERY_REPORT_DIR";
   Report_Name : constant String := "unsafe";
   Report_Marker : constant Ada.Streams.Stream_Element_Array :=
     [Character'Pos ('u'), Character'Pos ('n'), Character'Pos ('s'),
      Character'Pos ('a'), Character'Pos ('f'), Character'Pos ('e'),
      Character'Pos (ASCII.LF)];
   Previous_Report_Directory : Files.Types.UString;
   Previous_Report_Existed : Boolean := False;

   --  The folder a report goes to, as FILES_RECOVERY_REPORT_DIR names it.
   --  The variable is read and changed on the main thread only (Scavenge,
   --  Clean_Report, a helper's non-interruptible Run), which copies it here:
   --  the Coordinator_Monitor task reads this copy, never the environment,
   --  which the host does not guard against a concurrent change. The
   --  variable itself stays, so a helper process inherits the folder.
   protected Report_Target is
      procedure Set (Directory : String);
      function Get return String;
   private
      Value : Unbounded_String;
   end Report_Target;

   protected body Report_Target is
      procedure Set (Directory : String) is
      begin
         Value := To_Unbounded_String (Directory);
      end Set;

      function Get return String is (To_String (Value));
   end Report_Target;

   --  Copy the variable into Report_Target. Main thread only.
   procedure Take_Report_Target is
   begin
      Report_Target.Set (Files.Environment.Value (Report_Environment));
   end Take_Report_Target;

   function Has_Unrecoverable return Boolean is
     (Length (Report_Directory) /= 0
      and then Files.IO.Lease_Streams.Holds_Exactly
        (Hostkit.Fs.Join (To_String (Report_Directory), Report_Name), Report_Marker));

   procedure Clean_Report is
   begin
      if Length (Report_Directory) = 0 then
         return;
      end if;
      declare
         Directory : constant String := To_String (Report_Directory);
         Target : constant String := Hostkit.Fs.Join (Directory, Report_Name);
      begin
         if Files.Environment.Value (Report_Environment) = Directory then
            if Previous_Report_Existed then
               Files.Environment.Set
                 (Report_Environment, To_String (Previous_Report_Directory));
            else
               Files.Environment.Clear (Report_Environment);
            end if;
         end if;
         Take_Report_Target;
         --  refusal-safe: a refused report folder is left, not removed
         if Files.IO.Fs_Primitives.Exists (Directory)
           and then not Hostkit.Fs.Is_Link (Directory)
         then
            --  refusal-safe: a refused report is left, not removed
            if Files.IO.Fs_Primitives.Exists (Target) then
               Files.IO.Fs_Primitives.Delete_File (Target);
            end if;
            Files.IO.Fs_Primitives.Delete_Directory (Directory);
         end if;
      end;
      Report_Directory := Null_Unbounded_String;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Scavenger");
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
      procedure Settle (Still_Busy : Boolean; Why : String := "");
      function Quiet return Boolean;
      function Reason return String;
   private
      Pending : Boolean := False;
      Pending_Program : Files.Types.UString;
      Busy : Boolean := False;
      Busy_Why : Files.Types.UString;
   end Scan_Requests;

   protected Terminal_Reports is
      procedure Mark_If_New (Directory : String; New_Report : out Boolean);
      function Contains (Directory : String) return Boolean;
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

      function Contains (Directory : String) return Boolean is
      begin
         return Reported.Contains (Directory);
      end Contains;
   end Terminal_Reports;

   --  The localized report label, set by the caller (Set_Report_Label) on
   --  its own thread. Report_Unrecoverable also runs on the
   --  Coordinator_Monitor task, so the text is held in a protected object.
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

   procedure Set_Report_Label (Text : String) is
   begin
      Report_Label.Set (Text);
   end Set_Report_Label;

   procedure Report_Unrecoverable (Directory : String) is
      New_Report : Boolean;
      Label      : constant String := Report_Label.Get;
      --  Best effort: a report already there, or one that cannot be written,
      --  leaves the standard error line alone to say it.
      Written    : Files.IO.Lease_Streams.Marker_Write;
      pragma Unreferenced (Written);
   begin
      Terminal_Reports.Mark_If_New (Directory, New_Report);
      if New_Report then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            (if Label /= "" then Label else Report_Label_Key) & ": " & Directory);
         declare
            Target_Directory : constant String := Report_Target.Get;
         begin
            if Target_Directory /= ""
              --  refusal-safe: a refused report folder gets no report
              and then Files.IO.Fs_Primitives.Exists (Target_Directory)
              and then not Hostkit.Fs.Is_Link (Target_Directory)
            then
               Written := Files.IO.Lease_Streams.Write_Marker
                 (Hostkit.Fs.Join (Target_Directory, Report_Name), Report_Marker);
            end if;
         end;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Scavenger");
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

      procedure Settle (Still_Busy : Boolean; Why : String := "") is
      begin
         Busy := Still_Busy;
         Busy_Why := To_Unbounded_String (Why);
      end Settle;

      function Quiet return Boolean is (not Pending and then not Busy);

      function Reason return String is
        ((if Pending then "scan-queued;" else "")
         & (if Busy then To_String (Busy_Why) else ""));
   end Scan_Requests;

   function Idle return Boolean is (Scan_Requests.Quiet);

   function Busy_Reason return String is (Scan_Requests.Reason);

   function Was_Reported (Directory : String) return Boolean is (Terminal_Reports.Contains (Directory));

   task Coordinator_Monitor is
      entry Stop;
   end Coordinator_Monitor;

   task body Coordinator_Monitor is separate;

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
           Files.Environment.Is_Set (Report_Environment);
         if Previous_Report_Existed then
            Previous_Report_Directory := To_Unbounded_String
              (Files.Environment.Value (Report_Environment));
         end if;
         Report_Directory := To_Unbounded_String
           (Hostkit.Fs.Create_Temporary_Directory ("files-recovery-report-"));
         if Length (Report_Directory) > 0 then
            Files.Environment.Set
              (Report_Environment, To_String (Report_Directory));
         end if;
      end if;
      Take_Report_Target;
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
         delay Files.Timing.Stop_Request_Wait;
      end select;
      for Poll in 1 .. Files.Timing.Stop_Polls loop
         exit when Monitor_Result.Complete or else Coordinator_Monitor'Terminated;
         delay Files.Timing.Stop_Poll_Interval;
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

   function Run
     (Minimum_Unmarked_Age : Duration := 1.0;
      Wait_For_Grace       : Boolean := True;
      Interruptible        : Boolean := False) return Boolean
   is
      --  Whether Directory's own name is a current transport's.
      function Is_Current_Name (Directory : String) return Boolean is
      begin
         return Files.Jobs.Transports.Is_Transport_Name (Files.Name_Parts.Leaf_Of (Directory));
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Jobs.Scavenger");
            return False;
      end Is_Current_Name;

      procedure Scan (Retry_Needed : out Boolean) is
         Temp        : constant String := Hostkit.Fs.Temp_Directory;
         Directories : Files.Types.String_Vectors.Vector;

         --  This user's job folders. The temporary folder is shared on a
         --  POSIX host: another user's transport (or a planted name, a link
         --  included) is not this process's to judge, so only a real folder
         --  private to the current user -- what Transports.Create makes -- is
         --  taken. Anything else is left alone and never reported.
         procedure Collect (Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Stop);
            Prefix : String renames Files.Protocol_Names.Transport_Prefix;
            Path   : constant String := Hostkit.Fs.Join (Temp, Name);
         begin
            if Files.Text_Basics.Starts_With (Name, Prefix)
              and then not Hostkit.Fs.Is_Link (Path)
              and then Files.IO.Fs_Primitives.Directory_Exists (Path)
              and then Hostkit.Metadata.Private_To_Current_User (Path)
            then
               Directories.Append (To_Unbounded_String (Path));
            end if;
         end Collect;
      begin
         Retry_Needed := False;
         Files.IO.Fs_Primitives.For_Each_Name (Temp, Collect'Access);
         for Listed of Directories loop
            if Interruptible and then Monitor_Control.Stop_Requested then
               Retry_Needed := True;
               exit;
            end if;
            declare
               Directory : constant String := To_String (Listed);
               Identity  : Files.Types.UString;
               Read_Error : Boolean;
               Claim     : Files.Jobs.Transports.Lease;
            begin
               Files.Jobs.Transports.Inspect_Marker (Directory, Identity, Read_Error);
               if Read_Error then
                  Retry_Needed := True;
               elsif Length (Identity) > 0 then
                  declare
                     Outcome : constant Files.Jobs.Cleanup.Cleanup_Outcome :=
                       Files.Jobs.Cleanup.Run
                         (Directory, To_String (Identity),
                          Attempt_Limit => (if Interruptible then 1 else 8),
                          Unreadable    =>
                            (if Interruptible then Files.Jobs.Cleanup.Keep_Unreadable
                             else Files.Jobs.Cleanup.Discard_On_Last_Attempt));
                  begin
                     if Outcome = Files.Jobs.Cleanup.Cleanup_Failed then
                        Retry_Needed := True;
                     elsif Outcome in Files.Jobs.Cleanup.Cleanup_Unrecoverable
                       | Files.Jobs.Cleanup.Cleanup_Refused
                     then
                        Report_Unrecoverable (Directory);
                     end if;
                  end;
               elsif Is_Current_Name (Directory) then
                  --  A marker the host will not answer for may be there: it is
                  --  re-read like a present one, never taken for an
                  --  unmarked (incomplete, removable) transport.
                  if not Files.IO.Fs_Primitives.Entry_Is_Absent
                    (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Transport_Marker))
                  then
                     --  The marker may have been published after the first
                     --  inspection. Re-read before classifying it as invalid.
                     Files.Jobs.Transports.Inspect_Marker (Directory, Identity, Read_Error);
                     if Read_Error or else Length (Identity) > 0 then
                        Retry_Needed := True;
                     else
                        Report_Unrecoverable (Directory);
                     end if;
                  else
                     declare
                        Incomplete_Identity : Files.Types.UString;
                        Outcome : constant Files.Jobs.Transports.Claim_Outcome :=
                          Files.Jobs.Transports.Claim_Incomplete
                            (Directory, Incomplete_Identity, Claim, Minimum_Unmarked_Age);
                     begin
                        if Outcome = Files.Jobs.Transports.Claim_Acquired then
                           declare
                              Removed : constant Boolean :=
                                Files.Jobs.Storage.Delete_Transport_Entry
                                  (Directory, To_String (Incomplete_Identity));
                           begin
                              if not Removed
                                or else not Files.IO.Fs_Primitives.Entry_Is_Absent (Directory)
                              then
                                 Retry_Needed := True;
                              else
                                 Files.Jobs.Transports.Forget_Witness (Directory, Claim);
                              end if;
                           end;
                        elsif Outcome = Files.Jobs.Transports.Claim_Deferred
                          or else Outcome = Files.Jobs.Transports.Claim_Error
                        then
                           Retry_Needed := True;
                        elsif Outcome in Files.Jobs.Transports.Claim_Unrecoverable
                          | Files.Jobs.Transports.Claim_Refused
                        then
                           Report_Unrecoverable (Directory);
                        end if;
                     end;
                  end if;
               end if;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Jobs.Scavenger");
                  Retry_Needed := True;
            end;
         end loop;
         Files.Jobs.Transports.Scavenge_Witnesses;
      exception
         when Failure : others =>
            Files.Diagnostics.Note (Failure, "Files.Jobs.Scavenger");
            Retry_Needed := True;
      end Scan;

      Retry_Needed : Boolean;
      Grace            : constant Duration := Duration'Max (0.0, Minimum_Unmarked_Age);
   begin
      --  Called non-interruptibly only on a main thread (a helper process
      --  runs it directly).
      if not Interruptible then
         Take_Report_Target;
      end if;
      Scan (Retry_Needed);
      if Wait_For_Grace and then Retry_Needed and then Grace > 0.0 then
         delay Grace;
         Scan (Retry_Needed);
      end if;
      return not Retry_Needed;
   end Run;
end Files.Jobs.Scavenger;

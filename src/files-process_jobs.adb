with Files.Protocol_Names;
with Files.Diagnostics;
with Files.Timing;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with Files.Exclusive_Streams;
with Files.File_System;
with Files.Fs_Primitives;
with Files.Job_Context;
with Files.Job_Records;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Hostkit.Spawn.Supervision;

package body Files.Process_Jobs is
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Ada.Streams.Stream_Element_Array;
   use type Hostkit.Lease_Files.Open_Outcome;
   use type Hostkit.Spawn.Wait_State;

   --  Each worker already performs its own bounded retry sequence. One
   --  parent retry covers launch and false-success races; a second failure
   --  leaves the transport on disk for the next startup recovery pass.
   Cleanup_Failure_Limit : constant Positive := 2;

   --  A refused stop signal is retried this soon: long enough not to spin on
   --  a process that is still being torn down, short enough that a cancel
   --  feels immediate.
   Stop_Retry_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (100);

   --  A cancelled worker gets this long to notice its cancellation marker and
   --  exit cleanly (publishing nothing more) before it is killed.
   Cancel_Grace_Period : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (2);

   --  After a cleanup worker fails, the next attempt waits this long so a
   --  transient refusal (a sharing violation, a busy volume) can clear
   --  instead of being retried at reaper-poll rate.
   Cleanup_Retry_Delay : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (2);

   --  A cleanup worker only deletes a staging transport; one still running
   --  after this long is assumed stuck and is killed so the retry sequence
   --  can move on.
   Cleanup_Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (30);

   --  How often the orphan reaper polls its queue: frequent enough that a
   --  finished worker is reaped promptly, rare enough to cost no idle CPU.
   Reaper_Poll_Interval : constant Duration := 0.05;
   Cancellation_Marker : constant Ada.Streams.Stream_Element_Array :=
     [Character'Pos ('c'), Character'Pos ('a'), Character'Pos ('n'),
      Character'Pos ('c'), Character'Pos ('e'), Character'Pos ('l'),
      Character'Pos (ASCII.LF)];

   function Valid_Cancellation_Marker (Path : String) return Boolean is
      Handle : Hostkit.Lease_Files.Lease;
      Read_Back : Ada.Streams.Stream_Element_Array (Cancellation_Marker'Range);
      Valid : Boolean := False;
   begin
      if Hostkit.Lease_Files.Open
        (Path, Hostkit.Lease_Files.Shared, Writable => False, Item => Handle) /=
          Hostkit.Lease_Files.Opened
      then
         return False;
      end if;
      Valid := Hostkit.Lease_Files.Size (Handle) = Cancellation_Marker'Length
        and then Hostkit.Lease_Files.Read_At (Handle, Read_Back)
        and then Read_Back = Cancellation_Marker;
      Hostkit.Lease_Files.Release (Handle);
      return Valid;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs");
         Hostkit.Lease_Files.Release (Handle);
         return False;
   end Valid_Cancellation_Marker;

   procedure Free is new Ada.Unchecked_Deallocation (State, State_Access);

   --  Start this program as the helper for Mode, on Arguments after the flag.
   function Start_Helper
     (Mode      : Files.Helper_Modes.Helper_Mode;
      Arguments : Hostkit.String_Vectors.Vector;
      Process   : in out Supervised_Process) return Boolean
   is
      Flag_First : Hostkit.String_Vectors.Vector;
   begin
      Flag_First.Append (To_Unbounded_String (Files.Helper_Modes.Flag (Mode)));
      Flag_First.Append (Arguments);
      return Files.Helper_Modes.Start_Helper (Flag_First, Process.Handle);
   end Start_Helper;

   --  Mark Process as running from now on.
   procedure Note_Started (Process : in out Supervised_Process) is
   begin
      Process := (Handle => Process.Handle, Started => True, Started_At => Ada.Real_Time.Clock, others => <>);
   end Note_Started;

   --  Ask a running Process to end now. A refused request is retried by
   --  Inspect once Stop_Retry_Interval has passed.
   procedure Stop (Process : in out Supervised_Process) is
   begin
      if Process.Started and then not Process.Finished then
         Process.Stop_Requested := True;
         Process.Terminated := Process.Terminated or else Hostkit.Spawn.Supervision.Stop_Now (Process.Handle);
         if not Process.Terminated then
            Process.Stop_Retry_At := Ada.Real_Time.Clock + Stop_Retry_Interval;
         end if;
      end if;
   end Stop;

   --  Whether a started Process has ended; an ended one is released and
   --  marked Finished, with what the host said in Status.
   function Collect (Process : in out Supervised_Process; Status : out Hostkit.Spawn.Status) return Boolean is
   begin
      if Hostkit.Spawn.Supervision.Has_Ended (Process.Handle, Status) then
         Hostkit.Spawn.Release (Process.Handle);
         Process.Finished := True;
         return True;
      end if;
      return False;
   end Collect;

   procedure Stop (Item : State_Access) is
   begin
      Stop (Item.Helper);
   end Stop;

   procedure Inspect (Item : State_Access) is
      Status : Hostkit.Spawn.Status;
   begin
      if Item.Helper.Started and then not Item.Helper.Finished then
         if Collect (Item.Helper, Status) then
            null;
         elsif Item.Helper.Stop_Requested and then not Item.Helper.Terminated
           and then Ada.Real_Time.Clock >= Item.Helper.Stop_Retry_At
         then
            Stop (Item);
            if Item.Cancelled then
               Item.Detached := Item.Helper.Terminated;
            end if;
         elsif Item.Cancelled and then not Item.Helper.Stop_Requested
           and then Files.Timing.Elapsed (Ada.Real_Time.Clock, Item.Cancel_At, Cancel_Grace_Period)
         then
            Stop (Item);
            --  A process stuck in kernel I/O may not become reapable immediately.
            --  Its pending termination prevents further user-code publication;
            --  detach the UI while retaining its handle and staging journal.
            Item.Detached := Item.Helper.Terminated;
         end if;
      end if;
   end Inspect;

   --  Neither the transport nor a link in its place is there any more.
   function Transport_Gone (Item : State_Access) return Boolean is
   begin
      return Files.Fs_Primitives.Entry_Is_Absent (To_String (Item.Directory));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs");
         return False;
   end Transport_Gone;

   protected Orphan_Queue is
      procedure Register (Accepted : out Boolean);
      procedure Unregister (Underflowed : out Boolean);
      procedure Add (Item : State_Access; Accepted : out Boolean);
      procedure Take_All (Items : out State_Access);
      procedure Close_If_Drained (Closed_Now : out Boolean);
      function Closed return Boolean;
   private
      Head : State_Access;
      Live_States : Natural := 0;
      Sealed : Boolean := False;
   end Orphan_Queue;

   protected body Orphan_Queue is
      procedure Register (Accepted : out Boolean) is
      begin
         Accepted := not Sealed;
         if Accepted then
            Live_States := Live_States + 1;
         end if;
      end Register;

      --  Underflowed reports an Unregister without a matching Register; the
      --  count stays at zero rather than raising inside a hand-off.
      procedure Unregister (Underflowed : out Boolean) is
      begin
         Underflowed := Live_States = 0;
         if not Underflowed then
            Live_States := Live_States - 1;
         end if;
      end Unregister;

      procedure Add (Item : State_Access; Accepted : out Boolean) is
      begin
         Accepted := not Sealed;
         if Accepted then
            Item.Next := Head;
            Head := Item;
         end if;
      end Add;

      procedure Take_All (Items : out State_Access) is
      begin
         Items := Head;
         Head := null;
      end Take_All;

      procedure Close_If_Drained (Closed_Now : out Boolean) is
      begin
         Closed_Now := Head = null and then Live_States = 0;
         if Closed_Now then
            Sealed := True;
         end if;
      end Close_If_Drained;

      function Closed return Boolean is (Sealed);
   end Orphan_Queue;

   protected Reaper_Result is
      procedure Mark_Complete;
      function Complete return Boolean;
   private
      Done : Boolean := False;
   end Reaper_Result;

   protected body Reaper_Result is
      procedure Mark_Complete is
      begin
         Done := True;
      end Mark_Complete;

      function Complete return Boolean is (Done);
   end Reaper_Result;

   procedure Ensure_Reaper;

   --  Ownership hand-off contract shared by Destroy, Submit_Or_Abandon and
   --  Dispose. An in out access parameter is passed by copy, so the caller's
   --  variable is only updated on a normal return. Each of them therefore
   --  either propagates while the caller still owns a live, unqueued Item, or
   --  takes ownership (frees or queues it) and then returns normally with
   --  Item = null: nothing that can raise runs after ownership has moved.
   --  The callers' handlers rely on this to retry with their own pointer.

   procedure Destroy (Item : in out State_Access) is
      Doomed      : State_Access := Item;
      Underflowed : Boolean := False;
   begin
      Item := null;
      begin
         Free (Doomed);
      exception
         when Swallowed : others =>
            --  Finalizing a component failed; the state is gone either way.
            Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs.Destroy");
      end;
      begin
         Orphan_Queue.Unregister (Underflowed);
         if Underflowed then
            --  Raised only so the trace records it; the count stays at zero.
            raise Program_Error;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs.Destroy.Unregister_Underflow");
      end;
   end Destroy;

   procedure Submit_Or_Abandon (Item : in out State_Access) is
      Accepted : Boolean;
   begin
      --  Add raises only before it links Item, which the caller then still owns.
      Orphan_Queue.Add (Item, Accepted);
      if Accepted then
         Item := null;
         return;
      end if;
      --  Shutdown sealed the queue. Preserve the marker for the next startup
      --  instead of adding work to a reaper that has already terminated.
      --  Abandoning is the last resort, so a failure to stop the processes
      --  or release the lease must not keep the state alive (or propagate
      --  into a caller that would retry with it): note it and carry on.
      begin
         Stop (Item.Helper);
         Stop (Item.Cleanup);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs.Submit_Or_Abandon");
      end;
      begin
         Files.Job_Transports.Release (Item.Owner);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs.Submit_Or_Abandon");
      end;
      Destroy (Item);
   end Submit_Or_Abandon;

   --  Stopping: shutdown has begun, and the queue must drain within its
   --  bound. Then nothing is handed to a cleanup worker or queued again: the
   --  direct removal is tried once and the in-memory owner dropped; a
   --  running worker finishes on its own, and the durable marker leaves the
   --  rest to startup recovery.
   procedure Dispose (Item : in out State_Access; Stopping : Boolean := False) is
      Stages : constant String := Hostkit.Fs.Join (To_String (Item.Directory), Files.Protocol_Names.Stages_Directory);

      function Launch_Cleanup return Boolean is
         Arguments : Hostkit.String_Vectors.Vector;
      begin
         if Stopping then
            return False;
         end if;
         Arguments.Append (Item.Directory);
         Arguments.Append (Item.Identity);
         Item.Cleanup := (others => <>);
         if not Start_Helper (Files.Helper_Modes.Cleanup, Arguments, Item.Cleanup) then
            return False;
         end if;
         Test_Cleanup_Launches :=
           (if Test_Cleanup_Launches = Natural'Last then 0 else Test_Cleanup_Launches + 1);
         Note_Started (Item.Cleanup);
         return True;
      end Launch_Cleanup;

      procedure Retain_For_Cleanup (Delay_Retry : Boolean) is
      begin
         if Stopping then
            Destroy (Item);
            return;
         end if;
         --  The helper is gone; only the cleanup worker is watched from here.
         Item.Helper := (others => <>);
         Item.Cancelled := False;
         Item.Detached := False;
         if Delay_Retry then
            Item.Cleanup_Retry_At := Ada.Real_Time.Clock + Cleanup_Retry_Delay;
         end if;
         Ensure_Reaper;
         Submit_Or_Abandon (Item);
      end Retain_For_Cleanup;

      procedure Defer_After_Cleanup_Failure is
      begin
         Item.Cleanup_Failures := Item.Cleanup_Failures + 1;
         if Item.Cleanup_Failures >= Cleanup_Failure_Limit then
            --  The marker and staging journal are the durable retry state.
            --  Drop only the in-memory owner so a permanent refusal cannot
            --  create an endless stream of cleanup workers in this process.
            Destroy (Item);
         else
            Retain_For_Cleanup (Delay_Retry => True);
         end if;
      end Defer_After_Cleanup_Failure;
   begin
      --  From here onward the job no longer has a live owner. Releasing the
      --  lease lets this process or a later startup recover the transport if
      --  the immediate guarded cleanup cannot finish.
      Files.Job_Transports.Release (Item.Owner);
      if Orphan_Queue.Closed then
         Destroy (Item);
         return;
      end if;
      if Item.Cleanup.Started and then not Item.Cleanup.Finished then
         declare
            Status : Hostkit.Spawn.Status;
         begin
            if not Collect (Item.Cleanup, Status) then
               if Stopping then
                  Destroy (Item);
                  return;
               end if;
               if Files.Timing.Elapsed (Ada.Real_Time.Clock, Item.Cleanup.Started_At, Cleanup_Timeout) then
                  Stop (Item.Cleanup);
               end if;
               Retain_For_Cleanup (Delay_Retry => False);
               return;
            end if;
            if Status.State = Hostkit.Spawn.Wait_Exited
              and then Status.Exit_Code = 0 and then Transport_Gone (Item)
            then
               --  A successful exit is only authoritative once the transport
               --  has actually disappeared.
               Destroy (Item);
            else
               Defer_After_Cleanup_Failure;
            end if;
            return;
         end;
      end if;
      --  Stage records that may be there (the host will not say) are kept
      --  as surely as present ones: the transport is the only pointer to
      --  the staged entries they name.
      if not Files.Fs_Primitives.Entry_Is_Absent (Stages) then
         if Stopping then
            Destroy (Item);
            return;
         elsif Ada.Real_Time.Clock < Item.Cleanup_Retry_At then
            Retain_For_Cleanup (Delay_Retry => False);
            return;
         end if;
         if Launch_Cleanup then
            Retain_For_Cleanup (Delay_Retry => False);
         else
            Defer_After_Cleanup_Failure;
         end if;
         return;
      end if;
      begin
         Test_Removal_Attempts :=
           (if Test_Removal_Attempts = Natural'Last then 0 else Test_Removal_Attempts + 1);
         if Files.Job_Transports.Matches
           (To_String (Item.Directory), To_String (Item.Identity))
           and then Files.File_System.Delete_Transport_Entry
             (To_String (Item.Directory), To_String (Item.Identity)).Success
         then
            Destroy (Item);
            return;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs");
      end;

      --  A transport without staging records can still resist removal: an
      --  unreadable child, a sharing violation, or a transient filesystem
      --  error is enough.  Hand it to the same independent cleanup worker so
      --  the failure is retried during application idleness instead of being
      --  forgotten when this state is freed.
      if Transport_Gone (Item) or else Stopping then
         Destroy (Item);
      elsif Launch_Cleanup then
         Retain_For_Cleanup (Delay_Retry => False);
      else
         Defer_After_Cleanup_Failure;
      end if;
   end Dispose;

   --  Once a session gives up its last reference, this task becomes the sole
   --  owner of its process handles.
   task type Orphan_Reaper_Task is
      entry Stop;
   end Orphan_Reaper_Task;

   task body Orphan_Reaper_Task is
      Current : State_Access;
      Next    : State_Access;
      Stopping : Boolean := False;
      Closed_Now : Boolean;
   begin
      loop
         if not Stopping then
            select
               accept Stop do
                  Stopping := True;
               end Stop;
            or
               delay Reaper_Poll_Interval;
            end select;
         else
            delay Reaper_Poll_Interval;
         end if;

         Orphan_Queue.Take_All (Current);
         while Current /= null loop
            Next := Current.Next;
            begin
               Inspect (Current);
               if Current.Helper.Finished or else not Current.Helper.Started then
                  Dispose (Current, Stopping);
               else
                  Submit_Or_Abandon (Current);
               end if;
            exception
               when Swallowed : others =>
                  --  One damaged state must not terminate cleanup for every
                  --  later orphan. Retain it for another bounded poll. By the
                  --  hand-off contract an exception means Current is still
                  --  owned here, live and unqueued. Next was read before any
                  --  hand-off, so a re-queued Current cannot redirect the walk.
                  Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs.Orphan_Reaper_Task");
                  if Current /= null then
                     begin
                        Submit_Or_Abandon (Current);
                     exception
                        when Requeue_Failure : others =>
                           --  Add itself failed, so Current is still ours. As in
                           --  Finalize's last resort, drop the in-memory lease and
                           --  state: the durable marker suffices for startup
                           --  recovery, and this task stays alive for the others.
                           Files.Diagnostics.Note (Requeue_Failure, "Files.Process_Jobs.Orphan_Reaper_Task");
                           begin
                              Files.Job_Transports.Release (Current.Owner);
                           exception
                              when Release_Failure : others =>
                                 Files.Diagnostics.Note (Release_Failure, "Files.Process_Jobs.Orphan_Reaper_Task");
                           end;
                           Destroy (Current);
                     end;
                  end if;
            end;
            Current := Next;
         end loop;
         if Stopping then
            Orphan_Queue.Close_If_Drained (Closed_Now);
            exit when Closed_Now;
         end if;
      end loop;
      Reaper_Result.Mark_Complete;
   end Orphan_Reaper_Task;

   type Orphan_Reaper_Access is access Orphan_Reaper_Task;
   Reaper         : Orphan_Reaper_Access;
   Reaper_Stopped : Boolean := False;

   procedure Ensure_Reaper is
   begin
      if Reaper = null then
         --  Dynamic creation occurs only after package elaboration, avoiding
         --  a library task that invokes this package while it is elaborating.
         Reaper := new Orphan_Reaper_Task;
         Reaper_Stopped := False;
      end if;
   end Ensure_Reaper;

   overriding procedure Adjust (Job : in out Session) is
   begin
      if Job.Shared /= null then
         Job.Shared.References := Job.Shared.References + 1;
      end if;
   end Adjust;

   overriding procedure Finalize (Job : in out Session) is
   begin
      if Job.Shared /= null then
         if Job.Shared.References > 1 then
            Job.Shared.References := Job.Shared.References - 1;
         else
            --  The reaper stops a running helper and removes the transport:
            --  releasing a session does no filesystem work on this task.
            Inspect (Job.Shared);
            Stop (Job.Shared);
            Ensure_Reaper;
            Submit_Or_Abandon (Job.Shared);
         end if;
         Job.Shared := null;
      end if;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Process_Jobs");
         --  Controlled finalization must not replace an active exception with
         --  a cleanup failure. Preserve the durable transport and let the
         --  orphan reaper retry whenever possible.
         if Job.Shared /= null then
            begin
               Stop (Job.Shared);
               Ensure_Reaper;
               Submit_Or_Abandon (Job.Shared);
            exception
               when Failure : others =>
                  Files.Diagnostics.Note (Failure, "Files.Process_Jobs");
                  --  The durable marker is sufficient for startup recovery.
                  --  Drop the in-memory lease and registration as a last
                  --  resort so finalization itself remains exception-safe.
                  if Job.Shared /= null then
                     begin
                        Files.Job_Transports.Release (Job.Shared.Owner);
                        Destroy (Job.Shared);
                     exception
                        when Swallowed : others =>
                           Files.Diagnostics.Note (Swallowed, "Files.Process_Jobs");
                     end;
                  end if;
            end;
         end if;
         Job.Shared := null;
   end Finalize;

   procedure Reserve (Job : in out Session) is
      Registered : Boolean;
   begin
      Reset (Job);
      Ensure_Reaper;
      Job.Shared := new State;
      Orphan_Queue.Register (Registered);
      if not Registered then
         Free (Job.Shared);
         raise Program_Error;
      end if;
      begin
         Files.Job_Transports.Create
           (Job.Shared.Directory, Job.Shared.Identity, Job.Shared.Owner);
      exception
         when others =>
            Destroy (Job.Shared);
            raise;
      end;
   end Reserve;

   function Path (Job : Session; Name : String) return String is
     (if Job.Shared = null then "" else Hostkit.Fs.Join (To_String (Job.Shared.Directory), Name));

   procedure Clean_Stages (Job : Session) is
   begin
      if Job.Shared /= null then
         Files.Job_Context.Clean_Stages
           (To_String (Job.Shared.Directory), Job.Shared.Owner);
      end if;
   end Clean_Stages;

   procedure Launch (Job : in out Session; Mode : String) is
      Arguments : Hostkit.String_Vectors.Vector;
   begin
      if Job.Shared = null or else Job.Shared.Helper.Started then
         raise Ada.Directories.Use_Error;
      end if;
      Arguments.Append (To_Unbounded_String (Mode));
      Arguments.Append (Job.Shared.Directory);
      if Test_Refuse_Next_Launch then
         Test_Refuse_Next_Launch := False;
         raise Ada.Directories.Use_Error;
      end if;
      if not Files.Helper_Modes.Start_Helper (Arguments, Job.Shared.Helper.Handle) then
         raise Ada.Directories.Use_Error;
      end if;
      Note_Started (Job.Shared.Helper);
   end Launch;

   procedure Launch_With_Request
     (Job   : in out Session;
      Mode  : Files.Helper_Modes.Helper_Mode;
      Write : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
   is
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      Files.Exclusive_Streams.Create (File, Path (Job, Request_File));
      Write (File'Access);
      Files.Job_Records.Validate_Size (Files.Exclusive_Streams.Size (File));
      Files.Exclusive_Streams.Close (File);
      Launch (Job, Files.Helper_Modes.Flag (Mode));
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         raise;
   end Launch_With_Request;

   procedure Poll (Job : Session; Finished : out Boolean; Cancelled : out Boolean) is
   begin
      Finished := False;
      Cancelled := False;
      if Job.Shared /= null then
         Inspect (Job.Shared);
         Finished := Job.Shared.Helper.Finished or else Job.Shared.Detached;
         Cancelled := Job.Shared.Cancelled;
      end if;
   end Poll;

   procedure Cancel (Job : Session) is
      Marker : Hostkit.Lease_Files.Lease;
      Marker_Path : constant String := Path (Job, Files.Protocol_Names.Cancel_File);
      Outcome : Hostkit.Lease_Files.Open_Outcome;
   begin
      if Job.Shared /= null and then not Job.Shared.Cancelled then
         Outcome := Hostkit.Lease_Files.Create (Marker_Path, Marker);
         if Outcome = Hostkit.Lease_Files.Opened then
            if not Hostkit.Lease_Files.Write_At (Marker, Cancellation_Marker) then
               Hostkit.Lease_Files.Release (Marker);
               raise Ada.Directories.Use_Error;
            end if;
            Hostkit.Lease_Files.Release (Marker);
         elsif Outcome /= Hostkit.Lease_Files.Refused
           or else not Valid_Cancellation_Marker (Marker_Path)
         then
            raise Ada.Directories.Use_Error;
         end if;
         Job.Shared.Cancel_At := Ada.Real_Time.Clock;
         Job.Shared.Cancelled := True;
      end if;
   exception
      when others =>
         Hostkit.Lease_Files.Release (Marker);
         raise;
   end Cancel;

   function Active (Job : Session) return Boolean is (Job.Shared /= null);

   procedure Reset (Job : in out Session) is
   begin
      Finalize (Job);
   end Reset;

   procedure Shutdown (Stopped : out Boolean) is
   begin
      Stopped := Reaper = null or else
        (Reaper.all'Terminated and then Reaper_Result.Complete);
      if Stopped then
         return;
      end if;
      if not Reaper_Stopped then
         --  The reaper can be busy in a filesystem operation. A timed entry
         --  call keeps executable shutdown bounded even in that case.
         select
            Reaper.Stop;
            Reaper_Stopped := True;
         or
            delay Files.Timing.Stop_Request_Wait;
         end select;
      end if;
      for Poll in 1 .. Files.Timing.Stop_Polls loop
         exit when Reaper.all'Terminated;
         delay Files.Timing.Stop_Poll_Interval;
      end loop;
      Stopped := Reaper.all'Terminated and then Reaper_Result.Complete;
   exception
      when Tasking_Error =>
         Stopped := Reaper = null or else
           (Reaper.all'Terminated and then Reaper_Result.Complete);
   end Shutdown;

   function Cancellation_Requested (Directory : String) return Boolean is
     (Directory /= ""
      and then Valid_Cancellation_Marker (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Cancel_File)));
end Files.Process_Jobs;

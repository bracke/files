with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with Files.File_System;
with Files.Job_Context;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Signals;

package body Files.Process_Jobs is
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Hostkit.Spawn.Spawn_Outcome;
   use type Hostkit.Spawn.Wait_State;

   --  Each worker already performs its own bounded retry sequence. One
   --  parent retry covers launch and false-success races; a second failure
   --  leaves the transport on disk for the next startup recovery pass.
   Cleanup_Failure_Limit : constant Positive := 2;

   procedure Free is new Ada.Unchecked_Deallocation (State, State_Access);

   procedure Stop (Item : State_Access) is
      Sent : Boolean;
   begin
      if Item.Started and then not Item.Finished then
         Item.Stop_Requested := True;
         Sent := Hostkit.Signals.Send_To_Process
           (Hostkit.Spawn.Process_Id (Item.Process), Hostkit.Signals.Signal_Kill);
         if not Sent then
            Sent := Hostkit.Process.Request_Stop (Hostkit.Spawn.Process_Id (Item.Process));
         end if;
         Item.Terminated := Item.Terminated or else Sent;
         if not Item.Terminated then
            Item.Stop_Retry_At := Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (100);
         end if;
      end if;
   end Stop;

   procedure Inspect (Item : State_Access) is
      Status : Hostkit.Spawn.Status;
      Found  : Boolean;
   begin
      if Item.Started and then not Item.Finished then
         Found := Hostkit.Spawn.Wait (Item.Process, Hostkit.Spawn.Wait_Poll, Status);
         if Found and then Status.State in Hostkit.Spawn.Wait_Exited
           | Hostkit.Spawn.Wait_Signalled | Hostkit.Spawn.Wait_Lost
         then
            Item.Finished := True;
            Hostkit.Spawn.Release (Item.Process);
         elsif Item.Stop_Requested and then not Item.Terminated
           and then Ada.Real_Time.Clock >= Item.Stop_Retry_At
         then
            Stop (Item);
            if Item.Cancelled then
               Item.Detached := Item.Terminated;
            end if;
         elsif Item.Cancelled and then not Item.Stop_Requested
           and then Ada.Real_Time.Clock - Item.Cancel_At >= Ada.Real_Time.Seconds (2)
         then
            Stop (Item);
            --  A process stuck in kernel I/O may not become reapable immediately.
            --  Its pending termination prevents further user-code publication;
            --  detach the UI while retaining its handle and staging journal.
            Item.Detached := Item.Terminated;
         end if;
      end if;
   end Inspect;

   protected Orphan_Queue is
      procedure Register (Accepted : out Boolean);
      procedure Unregister;
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

      procedure Unregister is
      begin
         Live_States := Live_States - 1;
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

   procedure Destroy (Item : in out State_Access) is
   begin
      Free (Item);
      Orphan_Queue.Unregister;
   end Destroy;

   procedure Submit_Or_Abandon (Item : in out State_Access) is
      Accepted : Boolean;
      Sent : Boolean;
   begin
      Orphan_Queue.Add (Item, Accepted);
      if Accepted then
         Item := null;
         return;
      end if;
      --  Shutdown sealed the queue. Preserve the marker for the next startup
      --  instead of adding work to a reaper that has already terminated.
      if Item.Started and then not Item.Finished then
         Stop (Item);
      end if;
      if Item.Cleanup_Started then
         Sent := Hostkit.Signals.Send_To_Process
           (Hostkit.Spawn.Process_Id (Item.Cleanup_Process), Hostkit.Signals.Signal_Kill);
         if not Sent then
            Sent := Hostkit.Process.Request_Stop
              (Hostkit.Spawn.Process_Id (Item.Cleanup_Process));
         end if;
      end if;
      Files.Job_Transports.Release (Item.Owner);
      Destroy (Item);
      Item := null;
   end Submit_Or_Abandon;

   procedure Dispose (Item : in out State_Access) is
      Arguments : Hostkit.String_Vectors.Vector;
      Stages : constant String := Hostkit.Fs.Join (To_String (Item.Directory), "stages");

      function Transport_Gone return Boolean is
      begin
         return not Ada.Directories.Exists (To_String (Item.Directory))
           and then not Hostkit.Fs.Is_Link (To_String (Item.Directory));
      exception
         when others => return False;
      end Transport_Gone;

      function Launch_Cleanup return Boolean is
      begin
         Arguments.Append (To_Unbounded_String ("--files-cleanup"));
         Arguments.Append (Item.Directory);
         Arguments.Append (Item.Identity);
         if Hostkit.Spawn.Start
           (Hostkit.Fs.Own_Executable, Arguments, (others => <>), Item.Cleanup_Process) /=
             Hostkit.Spawn.Spawn_Ok
         then
            return False;
         end if;
         Item.Cleanup_Started := True;
         Item.Cleanup_Started_At := Ada.Real_Time.Clock;
         return True;
      end Launch_Cleanup;

      procedure Retain_For_Cleanup (Delay_Retry : Boolean) is
      begin
         Item.Started := False;
         Item.Finished := False;
         Item.Cancelled := False;
         Item.Detached := False;
         Item.Terminated := False;
         Item.Stop_Requested := False;
         Item.Stop_Retry_At := Ada.Real_Time.Clock;
         if Delay_Retry then
            Item.Cleanup_Retry_At := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (2);
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
      if Item.Cleanup_Started then
         declare
            Status : Hostkit.Spawn.Status;
            Found  : constant Boolean :=
              Hostkit.Spawn.Wait (Item.Cleanup_Process, Hostkit.Spawn.Wait_Poll, Status);
         begin
            if Found and then Status.State in Hostkit.Spawn.Wait_Running
              | Hostkit.Spawn.Wait_Stopped | Hostkit.Spawn.Wait_Continued
            then
               if Ada.Real_Time.Clock - Item.Cleanup_Started_At >= Ada.Real_Time.Seconds (30) then
                  declare
                     Sent : constant Boolean := Hostkit.Signals.Send_To_Process
                       (Hostkit.Spawn.Process_Id (Item.Cleanup_Process), Hostkit.Signals.Signal_Kill);
                  begin
                     if not Sent then
                        declare
                           Requested : constant Boolean := Hostkit.Process.Request_Stop
                             (Hostkit.Spawn.Process_Id (Item.Cleanup_Process));
                           pragma Unreferenced (Requested);
                        begin
                           null;
                        end;
                     end if;
                  end;
               end if;
               Retain_For_Cleanup (Delay_Retry => False);
               return;
            end if;

            Hostkit.Spawn.Release (Item.Cleanup_Process);
            Item.Cleanup_Started := False;
            if Found and then Status.State = Hostkit.Spawn.Wait_Exited
              and then Status.Exit_Code = 0 and then Transport_Gone
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
      if Ada.Directories.Exists (Stages) then
         if Ada.Real_Time.Clock < Item.Cleanup_Retry_At then
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
         if Files.Job_Transports.Matches
           (To_String (Item.Directory), To_String (Item.Identity))
           and then Files.File_System.Delete_Staging_Entry
             (To_String (Item.Directory), To_String (Item.Identity)).Success
         then
            Destroy (Item);
            return;
         end if;
      exception
         when others => null;
      end;

      --  A transport without staging records can still resist removal: an
      --  unreadable child, a sharing violation, or a transient filesystem
      --  error is enough.  Hand it to the same independent cleanup worker so
      --  the failure is retried during application idleness instead of being
      --  forgotten when this state is freed.
      if not Ada.Directories.Exists (To_String (Item.Directory))
        and then not Hostkit.Fs.Is_Link (To_String (Item.Directory))
      then
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
               delay 0.05;
            end select;
         else
            delay 0.05;
         end if;

         Orphan_Queue.Take_All (Current);
         while Current /= null loop
            Next := Current.Next;
            begin
               Inspect (Current);
               if Current.Finished or else not Current.Started then
                  Dispose (Current);
               else
                  Submit_Or_Abandon (Current);
               end if;
            exception
               when others =>
                  --  One damaged state must not terminate cleanup for every
                  --  later orphan. Retain it for another bounded poll.
                  if Current /= null then
                     Submit_Or_Abandon (Current);
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
            Inspect (Job.Shared);
            if Job.Shared.Started and then not Job.Shared.Finished then
               Stop (Job.Shared);
               Ensure_Reaper;
               Submit_Or_Abandon (Job.Shared);
            else
               Dispose (Job.Shared);
            end if;
         end if;
         Job.Shared := null;
      end if;
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
      if Job.Shared = null or else Job.Shared.Started then
         raise Ada.Directories.Use_Error;
      end if;
      Arguments.Append (To_Unbounded_String (Mode));
      Arguments.Append (Job.Shared.Directory);
      if Hostkit.Spawn.Start
        (Hostkit.Fs.Own_Executable, Arguments, (others => <>), Job.Shared.Process) /= Hostkit.Spawn.Spawn_Ok
      then
         raise Ada.Directories.Use_Error;
      end if;
      Job.Shared.Started := True;
   end Launch;

   procedure Poll (Job : Session; Finished : out Boolean; Cancelled : out Boolean) is
   begin
      Finished := False;
      Cancelled := False;
      if Job.Shared /= null then
         Inspect (Job.Shared);
         Finished := Job.Shared.Finished or else Job.Shared.Detached;
         Cancelled := Job.Shared.Cancelled;
      end if;
   end Poll;

   procedure Cancel (Job : Session) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if Job.Shared /= null and then not Job.Shared.Cancelled then
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path (Job, "cancel"));
         Ada.Streams.Stream_IO.Close (File);
         Job.Shared.Cancel_At := Ada.Real_Time.Clock;
         Job.Shared.Cancelled := True;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         raise;
   end Cancel;

   function Active (Job : Session) return Boolean is (Job.Shared /= null);

   procedure Reset (Job : in out Session) is
   begin
      Finalize (Job);
   end Reset;

   procedure Release_For_Shutdown (Job : in out Session) is
   begin
      if Job.Shared = null then
         return;
      end if;
      if Job.Shared.References > 1 then
         Job.Shared.References := Job.Shared.References - 1;
      else
         if Job.Shared.Started and then not Job.Shared.Finished then
            Stop (Job.Shared);
         end if;
         Ensure_Reaper;
         Submit_Or_Abandon (Job.Shared);
      end if;
      Job.Shared := null;
   end Release_For_Shutdown;

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
            delay 0.2;
         end select;
      end if;
      for Poll in 1 .. 180 loop
         exit when Reaper.all'Terminated;
         delay 0.01;
      end loop;
      Stopped := Reaper.all'Terminated and then Reaper_Result.Complete;
   exception
      when Tasking_Error =>
         Stopped := Reaper = null or else
           (Reaper.all'Terminated and then Reaper_Result.Complete);
   end Shutdown;

   procedure Shutdown is
      Stopped : Boolean;
   begin
      Shutdown (Stopped);
   end Shutdown;

   function Cancellation_Requested (Directory : String) return Boolean is
     (Directory /= "" and then Ada.Directories.Exists (Hostkit.Fs.Join (Directory, "cancel")));
end Files.Process_Jobs;

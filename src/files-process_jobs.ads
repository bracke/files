with Ada.Finalization;
with Ada.Real_Time;
with Ada.Streams;
with Files.Helper_Modes;
with Files.Types;
with Files.Job_Transports;
with Hostkit.Spawn;

--  Reference-counted helper processes; releasing a window never waits for I/O.
package Files.Process_Jobs is
   type Session is new Ada.Finalization.Controlled with private;

   --  The files of a job's private directory: the window's request, and the
   --  helper's result, written under its staged name (Staged_Name) and
   --  published whole.
   Request_File : constant String := "request";
   Result_File  : constant String := "result";

   --  @param Name A result's published name.
   --  @return The name it is written under before it is published.
   function Staged_Name (Name : String) return String is (Name & ".tmp");

   --  @param Job Session to reserve a private transport directory for.
   procedure Reserve (Job : in out Session);

   --  @param Job Reserved session.
   --  @param Name Transport file basename.
   --  @return Full path inside the private job directory, or empty for no job.
   function Path (Job : Session; Name : String) return String;

   --  @param Job Reserved session to launch.
   --  @param Mode Internal helper command identifying its request format.
   procedure Launch (Job : in out Session; Mode : String);

   --  Start a reserved job the one way every job starts: Write fills its
   --  request file, which is checked against the transport bound
   --  (Files.Job_Records.Max_Transport_Bytes) and closed, then the helper for
   --  Mode is started on it. On a failure the request file is closed and the
   --  exception propagates; the job stays reserved for the caller to reset.
   --  @param Job Reserved session to launch.
   --  @param Mode The helper to start.
   --  @param Write Writes the request's records, header first.
   procedure Launch_With_Request
     (Job   : in out Session;
      Mode  : Files.Helper_Modes.Helper_Mode;
      Write : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class));

   --  @param Job Session to inspect without waiting.
   --  @param Finished True when its helper has stopped.
   --  @param Cancelled True when cancellation was requested.
   procedure Poll (Job : Session; Finished : out Boolean; Cancelled : out Boolean);

   --  @param Job Session whose helper should stop cooperatively, then forcibly.
   procedure Cancel (Job : Session);

   --  @param Job Session to inspect.
   --  @return True when a transport directory is reserved.
   function Active (Job : Session) return Boolean;

   --  Clean this reserved session's stage records while it still owns the lease.
   --  @param Job Reserved session holding the matching transport lease.
   procedure Clean_Stages (Job : Session);

   --  Release a reference. The last one stops the helper without waiting and
   --  hands the transport to the orphan reaper, which removes it: releasing a
   --  session does no filesystem work on the caller's task.
   --  @param Job Session to release.
   procedure Reset (Job : in out Session);

   --  Request poller shutdown and wait at most about two seconds for its task
   --  to terminate. The caller must exit explicitly if Stopped is False,
   --  because Ada task finalization would otherwise wait without a bound.
   --  @param Stopped True only when the reaper task completed normally.
   procedure Shutdown (Stopped : out Boolean);

   --  @param Directory Transport directory passed to a helper.
   --  @return True when the parent requested cooperative cancellation.
   function Cancellation_Requested (Directory : String) return Boolean;

private
   --  Test seam: the next Launch is refused as a failed spawn is.
   Test_Refuse_Next_Launch : Boolean := False;
   pragma Atomic (Test_Refuse_Next_Launch);
   --  Test seam: how many times the orphan reaper has tried to remove a
   --  released transport itself. Written by the reaper task alone.
   Test_Removal_Attempts : Natural := 0;
   pragma Atomic (Test_Removal_Attempts);
   --  Test seam: how many cleanup workers the orphan reaper has launched.
   --  Written by the reaper task alone.
   Test_Cleanup_Launches : Natural := 0;
   pragma Atomic (Test_Cleanup_Launches);

   --  One process this package started and watches: the job's helper, or the
   --  cleanup worker that removes a transport the reaper could not.
   type Supervised_Process is record
      Handle         : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Started        : Boolean := False;
      Started_At     : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  It has ended and its handle is released.
      Finished       : Boolean := False;
      --  A stop was asked for, and whether it reached the process.
      Stop_Requested : Boolean := False;
      Terminated     : Boolean := False;
      Stop_Retry_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

   type State;
   type State_Access is access State;
   type State is record
      References : Positive := 1;
      Directory  : Files.Types.UString;
      Identity   : Files.Types.UString;
      Owner      : Files.Job_Transports.Lease;
      Helper     : Supervised_Process;
      Detached   : Boolean := False;
      Cancelled  : Boolean := False;
      Cancel_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Cleanup    : Supervised_Process;
      Cleanup_Retry_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Cleanup_Failures : Natural := 0;
      Next       : State_Access;
   end record;

   type Session is new Ada.Finalization.Controlled with record
      Shared : State_Access;
   end record;
   overriding procedure Adjust (Job : in out Session);
   overriding procedure Finalize (Job : in out Session);
end Files.Process_Jobs;

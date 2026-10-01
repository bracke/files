with Ada.Finalization;
with Ada.Real_Time;
with Files.Types;
with Files.Job_Transports;
with Hostkit.Spawn;

--  Reference-counted helper processes; releasing a window never waits for I/O.
package Files.Process_Jobs is
   type Session is new Ada.Finalization.Controlled with private;

   --  @param Job Session to reserve a private transport directory for.
   procedure Reserve (Job : in out Session);

   --  @param Job Reserved session.
   --  @param Name Transport file basename.
   --  @return Full path inside the private job directory, or empty for no job.
   function Path (Job : Session; Name : String) return String;

   --  @param Job Reserved session to launch.
   --  @param Mode Internal helper command identifying its request format.
   procedure Launch (Job : in out Session; Mode : String);

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

   --  @param Job Session to release; the last owner stops the helper without waiting.
   procedure Reset (Job : in out Session);

   --  Hand the last session reference to the orphan reaper during executable
   --  shutdown, including sessions that only own a staging transport.
   --  @param Job Session to release without doing filesystem cleanup here.
   procedure Release_For_Shutdown (Job : in out Session);

   --  Request poller shutdown and wait at most about two seconds for its task
   --  to terminate. The caller must exit explicitly if Stopped is False,
   --  because Ada task finalization would otherwise wait without a bound.
   --  @param Stopped True only when the reaper task completed normally.
   procedure Shutdown (Stopped : out Boolean);

   --  Compatibility wrapper for callers that do not need the outcome.
   procedure Shutdown;

   --  @param Directory Transport directory passed to a helper.
   --  @return True when the parent requested cooperative cancellation.
   function Cancellation_Requested (Directory : String) return Boolean;

private
   type State;
   type State_Access is access State;
   type State is record
      References : Positive := 1;
      Directory  : Files.Types.UString;
      Identity   : Files.Types.UString;
      Owner      : Files.Job_Transports.Lease;
      Process    : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Started    : Boolean := False;
      Finished   : Boolean := False;
      Detached   : Boolean := False;
      Terminated : Boolean := False;
      Stop_Requested : Boolean := False;
      Stop_Retry_At  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Cancelled  : Boolean := False;
      Cancel_At  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Cleanup_Retry_At : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Cleanup_Process : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Cleanup_Started : Boolean := False;
      Cleanup_Started_At : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Cleanup_Failures : Natural := 0;
      Next       : State_Access;
   end record;

   type Session is new Ada.Finalization.Controlled with record
      Shared : State_Access;
   end record;
   overriding procedure Adjust (Job : in out Session);
   overriding procedure Finalize (Job : in out Session);
end Files.Process_Jobs;

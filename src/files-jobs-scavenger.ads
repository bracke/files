--  Startup recovery for helper transports left behind by abnormal termination.
package Files.Jobs.Scavenger is
   --  The message key of the line naming a transport recovery could not
   --  safely reclaim. The job layer translates nothing: the caller looks it
   --  up and hands the text to Set_Report_Label.
   Report_Label_Key : constant String := "error.recovery.unsafe_entry";

   --  Set the localized text that prefixes each unrecoverable-transport
   --  line, before Scavenge or Run. Until it is set the line starts with
   --  Report_Label_Key itself.
   --  @param Text The localized text of Report_Label_Key.
   procedure Set_Report_Label (Text : String);

   --  Start one independent recovery coordinator and return immediately. If
   --  it cannot be launched, perform the scan in the monitor task so startup
   --  remains responsive. Coordinator is injectable for the
   --  process-launch regression; an empty value selects this executable.
   --  Repeated calls while a coordinator is active coalesce into one follow-up
   --  scan after that child exits; no second child runs concurrently. A
   --  retryable scan failure is retried with bounded exponential backoff
   --  while the application remains open.
   --  @param Coordinator Executable to start, or empty for this executable.
   procedure Scavenge (Coordinator : String := "");

   --  True once a recovery worker has reported a transport it could not
   --  safely reclaim during this application session.
   --  @return Whether the desktop should show a recovery warning.
   function Has_Unrecoverable return Boolean;

   --  True when no scan is queued, none is running (as a child or in the
   --  monitor) and no retry is scheduled. A caller that must not race a
   --  scan it did not start, such as a test creating recovery fixtures,
   --  waits for this first.
   --  @return Whether recovery is quiet.
   function Idle return Boolean;

   --  Request coordinator shutdown and wait up to about two seconds for it
   --  to be reaped. An unfinished child remains owned by the monitor task.
   --  @param Reaped True when the monitor has terminated after reaping its child.
   procedure Shutdown (Reaped : out Boolean);

   --  Sequentially clean validated abandoned transports while retaining one
   --  exclusive claim at a time. Used only by the internal helper mode.
   --  @param Minimum_Unmarked_Age Grace period before claiming a directory
   --  whose creator stopped before it could publish a lease.
   --  @param Wait_For_Grace Rescan once after the grace period when an exact
   --  unmarked candidate could not yet be claimed.
   --  @param Interruptible Check monitor shutdown between entries and use one
   --  cleanup attempt per entry when running the in-process fallback.
   --  @return True when no recoverable transport remains unresolved.
   function Run
     (Minimum_Unmarked_Age : Duration := 1.0;
      Wait_For_Grace       : Boolean := True;
      Interruptible        : Boolean := False) return Boolean;

private

   --  Why recovery is not Idle -- a scan queued, a coordinator running, a
   --  retry due -- with how the last coordinator ended, for a diagnostic.
   --  @return The reason, or "" when Idle.
   function Busy_Reason return String;

   --  Whether this process has reported Directory as unrecoverable.
   --  @param Directory The transport path as the scan listed it.
   --  @return True once a report for it was made.
   function Was_Reported (Directory : String) return Boolean;

end Files.Jobs.Scavenger;

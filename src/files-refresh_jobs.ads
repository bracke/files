with Files.Model;
with Files.Operations;
with Files.Settings;
with Files.Process_Jobs;
with Files.Types;

with Ada.Real_Time;

--  Nonmodal directory reads and native watches execute outside the UI process.
package Files.Refresh_Jobs is
   --  @param Model Window to refresh without waiting for storage.
   --  @param Settings Immutable directory settings snapshot.
   --  @param Force Read the listing even when its directory signature is unchanged.
   --  @param Select_Name Preferred selection, or empty to retain the current selection.
   --  @return Immediate launch result; Advance later applies a matching snapshot.
   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "") return Files.Operations.Operation_Result;

   --  @param Model Window owning a pending read.
   --  @param Settings Current settings used to reject stale results.
   --  @return True when a new listing was applied.
   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean;

   --  Relaunch a reload that Advance had to discard because the listing
   --  context moved while it ran (see Files.Model.Note_Owed_Refresh). Call it
   --  from the window's poll; it does nothing while a read is in flight, and
   --  Start's usual policy decides when an owed unforced reload may run.
   --
   --  @param Model Window that may owe a reload of its current view.
   --  @param Settings Current directory settings.
   procedure Resume_Owed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  @param Model Window whose pending read to stop without waiting.
   procedure Cancel (Model : in out Files.Model.Window_Model);

   type Watch_Session is private;

   --  @param Job Native notification helper; unchanged paths retain the existing helper.
   --  @param Path Directory to watch, or empty to release the helper.
   procedure Watch_Path (Job : in out Watch_Session; Path : String);

   --  @param Job Native notification helper to poll without touching the watched directory.
   --  @return True when its helper posted a change notification.
   function Poll_Watch (Job : in out Watch_Session) return Boolean;

   --  Whether the helper is up and reporting changes, so a timed re-read is
   --  only a safety net: from the host's watch where it hears files being
   --  written, otherwise from the helper's own re-reads of the folder's
   --  signature. False while the helper is starting.
   --
   --  @param Job Native notification helper.
   --  @return True when the helper reported a native watch for its path.
   function Watch_Is_Native (Job : in out Watch_Session) return Boolean;

   --  @param Job Watch helper to stop without waiting for storage.
   procedure Release_Watch (Job : in out Watch_Session);

   --  How often a window may re-read its folder on its own. A file being
   --  written posts a change every 50 ms, and each one used to start a full
   --  reload of the folder as soon as the last ended; a listing that cannot
   --  be read was re-read, forced, on every poll.
   type Watch_Pacer is private;

   --  The shortest gap between two refreshes a watch asked for.
   Watch_Refresh_Gap : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (2);

   --  How long a listing that failed to load waits before the next try.
   Load_Retry_Gap : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (30);

   --  Whether to refresh now for the watch. A change seen while the last
   --  refresh is too recent is owed, and a later call pays it, so the last
   --  write of a burst is always shown.
   --
   --  @param Pacer This window's pacing.
   --  @param Now The current time.
   --  @param Changed The watch reported a change since the last call.
   --  @return True when the caller should refresh now.
   function Watch_Refresh_Due
     (Pacer   : in out Watch_Pacer;
      Now     : Ada.Real_Time.Time;
      Changed : Boolean) return Boolean;

   --  Note a change the watch reported while a refresh is still running: it
   --  stays owed, and Watch_Refresh_Due pays it once that refresh is done
   --  (a read already under way may have listed the folder before it).
   --
   --  @param Pacer This window's pacing.
   --  @param Changed The watch reported a change.
   procedure Owe_Watch_Refresh (Pacer : in out Watch_Pacer; Changed : Boolean);

   --  Whether a timed re-read may run. After a failed load it may, once per
   --  Load_Retry_Gap; otherwise always.
   --
   --  @param Pacer This window's pacing.
   --  @param Now The current time.
   --  @param Load_Failed The listing on screen failed to load.
   --  @return True when the caller may re-read.
   function Retry_Due
     (Pacer       : in out Watch_Pacer;
      Now         : Ada.Real_Time.Time;
      Load_Failed : Boolean) return Boolean;

   --  @param Directory Private refresh request/result directory.
   procedure Run_Helper (Directory : String);

   --  @param Directory Private native-watch request/notification directory.
   procedure Run_Watch_Helper (Directory : String);
private
   --  A real directory request carries absolute filesystem paths. The Recent
   --  view is synthetic, so both path fields are deliberately empty there.
   function Request_Paths_Are_Consistent
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean;

   --  Watch helpers pass this value directly to the native watcher.
   function Watch_Path_Is_Consistent (Path : String) return Boolean;

   --  Move a posted watch marker away from the helper's publication name in
   --  one atomic step.  A helper can then publish a later event without the
   --  consumer deleting that new marker while acknowledging the old one.
   function Claim_Watch_Notification (Directory : String) return Boolean;

   --  Publish one idempotent watch marker. False leaves the caller responsible
   --  for retrying because the native event has already been consumed.
   function Post_Watch_Notification (Directory : String) return Boolean;

   type Watch_Pacer is record
      Last_Refresh : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Refreshed    : Boolean := False;
      Owed         : Boolean := False;
      Retry_At     : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

   type Watch_Session is record
      Process : Files.Process_Jobs.Session;
      Path : Files.Types.UString;
      --  A helper for Failed_Path failed to start or exited on its own; do
      --  not relaunch it for that path before Retry_At (polling covers it).
      Failed_Path : Files.Types.UString;
      Retry_At    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  A claimed notification could not be removed; retry before the next
      --  claim. Otherwise a poll is only the claiming rename.
      Claim_Left  : Boolean := False;
      --  The helper reported a native watch (Watch_Is_Native).
      Native      : Boolean := False;
   end record;
end Files.Refresh_Jobs;

with Files.Model;
with Files.Operations;
with Files.Settings;
with Files.Process_Jobs;
with Files.Types;

private with Ada.Real_Time;

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

   --  @param Job Watch helper to stop without waiting for storage.
   procedure Release_Watch (Job : in out Watch_Session);

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

   type Watch_Session is record
      Process : Files.Process_Jobs.Session;
      Path : Files.Types.UString;
      --  A helper for Failed_Path failed to start or exited on its own; do
      --  not relaunch it for that path before Retry_At (polling covers it).
      Failed_Path : Files.Types.UString;
      Retry_At    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;
end Files.Refresh_Jobs;

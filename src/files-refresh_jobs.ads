with Files.Model;
with Files.Operations;
with Files.Settings;
with Files.Process_Jobs;
with Files.Types;

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
   type Watch_Session is record
      Process : Files.Process_Jobs.Session;
      Path : Files.Types.UString;
   end record;
end Files.Refresh_Jobs;

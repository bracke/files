with Files.Operation_Results;
with Files.Model;
with Files.Settings;
with Files.Items;

--  Nonmodal directory reads execute outside the UI process; the folder
--  watch that asks for them is the child Files.Refresh.Watch.
package Files.Refresh is
   --  @param Model Window to refresh without waiting for storage.
   --  @param Settings Immutable directory settings snapshot.
   --  @param Force Read the listing even when its directory signature is unchanged.
   --  @param Select_Name Preferred selection, or empty to retain the current selection.
   --  @return Immediate launch result; Advance later applies a matching snapshot.
   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "") return Files.Operation_Results.Operation_Result;

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

   --  @param Directory Private refresh request/result directory.
   procedure Run_Helper (Directory : String);

   --  Compute and cache the selected item's "extra info" (folder child count,
   --  document counts, symlink target) when the info pane wants it and it has
   --  not been computed yet. Called after input so the info pane can show the
   --  detail without every item paying for it on load. A no-op when the info
   --  pane is closed, nothing is selected, or the value is already cached --
   --  and in a window (Background_Transfers), whose loop reads it off the UI
   --  thread through Files.Application.Window_Polls.Poll_Selected_Item_Extra
   --  instead.
   --
   --  @param Model Window model whose selected item is updated in place.
   --  @param Show_Hidden Whether the listing shows hidden entries
   --    (Settings.Show_Hidden_Files): a folder's count includes them only then.
   procedure Ensure_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Show_Hidden : Boolean);

   --  The Recent view's items: each recorded recent path loaded
   --  (Files.File_System.Load_Item) in most-recent-first order, one that no
   --  longer resolves left out. The one way the view is built, whether
   --  navigated to, refreshed after a change, or reloaded by a background
   --  refresh.
   --
   --  @param Settings Settings holding the recent paths and used to classify.
   --  @return The loaded items.
   function Load_Recent_Items (Settings : Files.Settings.Settings_Model) return Files.Items.Item_Vectors.Vector;

private

   --  A real directory request carries absolute filesystem paths. The Recent
   --  view is synthetic, so both path fields are deliberately empty there.
   function Request_Paths_Are_Consistent
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean;

end Files.Refresh;

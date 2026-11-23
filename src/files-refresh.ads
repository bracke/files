with Files.Operation_Results;
with Files.Model;
with Files.Settings;
with Files.Items;
with Files.File_System_Types;
with Files.UI_Types;

--  Nonmodal directory reads execute outside the UI process; the folder
--  watch that asks for them is the child Files.Refresh.Watch.
package Files.Refresh is
   --  @param Model Window to refresh without waiting for storage.
   --  @param Settings Immutable directory settings snapshot.
   --  @param Force Read the listing even when its directory signature is unchanged.
   --  @param Select_Name Preferred selection, or empty to retain the current selection.
   --  @param Select_Path Full path to select, winning over Select_Name.
   --  @param Search_Again While the window shows search results, search
   --    again for its query in its scope (a forced read) rather than list
   --    the folder in their place, which ends the search (as the Refresh
   --    command does). The search's notice shows unless an error set
   --    before the read is kept.
   --  @return Immediate launch result; Advance later applies a matching snapshot.
   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "";
      Select_Path : String := "";
      Search_Again : Boolean := False) return Files.Operation_Results.Operation_Result;

   --  Put a fresh listing of the view in place of the items shown -- the
   --  one way a view read again is installed: a folder, the Recent view or
   --  search results, read again here after an operation, by the
   --  background refresh or by an operation's helper, or a new search's
   --  results -- keeping where the user was:
   --  the selection (or the item asked for), the scroll, the info pane on
   --  the same item and a Quick Look whose item is still there; and noting
   --  the signature the watch compares with, and the images still lacking a
   --  thumbnail as a forced background listing owed
   --  (Files.Model.Note_Owed_Refresh) when the listing deferred them. It
   --  ends as every view shown anew does: the error line set to Error_Line
   --  and the selected item's details read (Ensure_Selected_Item_Extra).
   --
   --  @param Model Window whose view is read again.
   --  @param Items The fresh listing.
   --  @param Signature The listed folder's signature.
   --  @param Recent The items are the Recent view's.
   --  @param Searched Filter_Here for a folder listing; else the scope the
   --    items answer Query in, as search results.
   --  @param Query The query search results answer (noted with them).
   --  @param New_Results The items answer a new search: noted as results
   --    afresh, with no place in them to keep.
   --  @param Select_Path Full path to select, winning over the rest.
   --  @param Select_Name Leaf name to select, winning over Keep_Selection.
   --  @param Keep_Selection Select again what was selected.
   --  @param Fresh_Details The info pane reads the item's details again (a
   --    forced reload: a settings change, an explicit refresh).
   --  @param Owe_Thumbnails The listing deferred thumbnails: missing ones
   --    are owed to a background listing.
   --  @param Show_Hidden Settings.Show_Hidden_Files, for the details read.
   --  @param Error_Line The error line the view is shown with: "", a
   --    search's notice, or an error kept from before the read.
   procedure Reinstall_Listing
     (Model          : in out Files.Model.Window_Model;
      Items          : Files.Items.Item_Vectors.Vector;
      Signature      : Files.File_System_Types.Directory_Signature;
      Recent         : Boolean := False;
      Searched       : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Query          : String := "";
      New_Results    : Boolean := False;
      Select_Path    : String := "";
      Select_Name    : String := "";
      Keep_Selection : Boolean := True;
      Fresh_Details  : Boolean := False;
      Owe_Thumbnails : Boolean := False;
      Show_Hidden    : Boolean;
      Error_Line     : String := "");

   --  How every listing shown in a view ends -- a folder a view moved to
   --  (Files.Operations.Support.Load_And_Show) or a view read again
   --  (Reinstall_Listing): the signature the watch compares with stored,
   --  the images still lacking a thumbnail owed to a forced background
   --  listing (Files.Model.Note_Owed_Refresh) when the listing deferred
   --  them, the error line set to Error_Line (only when it differs) and the
   --  selected item's details read (Ensure_Selected_Item_Extra).
   --
   --  @param Model Window whose view shows Items.
   --  @param Items The listing shown.
   --  @param Signature The listed folder's signature.
   --  @param Owe_Thumbnails The listing deferred thumbnails.
   --  @param Error_Line The error line the view is shown with.
   --  @param Show_Hidden Settings.Show_Hidden_Files, for the details read.
   procedure Settle_Listed
     (Model          : in out Files.Model.Window_Model;
      Items          : Files.Items.Item_Vectors.Vector;
      Signature      : Files.File_System_Types.Directory_Signature;
      Owe_Thumbnails : Boolean;
      Error_Line     : String;
      Show_Hidden    : Boolean);

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

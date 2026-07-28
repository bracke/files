with Files.Model;
with Files.Settings;

--  The directory-navigation operations of Files.Operations (view/sort apply,
--  refresh, path input, back/forward/home/parent/trash/recent, roots), extracted
--  into a group child. A private child; the parent renames these.
private package Files.Operations.Navigation is

   --  Apply the persisted global UI state -- view mode and sort field/direction --
   --  from Settings to the model, deterministically (an absolute set, not a
   --  toggle). Used at startup and after a settings save so the model matches the
   --  settings exactly regardless of its prior sort state. Info-pane visibility is
   --  handled separately by the caller.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model providing the view mode and sort state.
   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Refresh the current directory and replace loaded items.
   --
   --  @param Model Window model to refresh.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Poll the current directory and refresh only when its signature changed.
   --
   --  @param Model Window model containing the last loaded directory signature.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Commit the current path-input text by validating and loading the destination.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate home and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate backward and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate forward and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate to the parent of the current directory and load it, recording
   --  history so Back returns to the origin. A no-op at a filesystem root.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate to the current backend's trash payload directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Enter the virtual recent-items view, materializing a listing from the
   --  stored recent paths. Each path is stat-ed through Load_Item; paths that no
   --  longer resolve are skipped so a stale entry never blocks the view. Also
   --  used to rebuild the view in place after the recent list changes.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model providing the recent paths and classification.
   --  @return Structured operation result (always navigated).
   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Select a root location and load it in the current window.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Root_Path Root path selected by the user.
   --  @return Structured operation result.
   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result;

   --  Preflight eject/unmount for the selected root without forcing permanent state changes.
   --
   --  The first implementation exposes the command flow and reports a
   --  localized unavailable error until a native backend is available.
   --
   --  @param Model Window model containing the open root selector.
   --  @return Structured operation result.
   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result;

end Files.Operations.Navigation;

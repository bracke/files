with Files.UI_Types;
with Files.Model;
with Files.Settings;

--  Moving the window between folders: the path field, home, parent, back and
--  forward, the trash and recent views, the roots, and search results.
package Files.Operations.Navigation is

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

   --  Navigate backward: the destination is read first, and the window moves
   --  to it only when the read works; one that fails sets the error line
   --  and changes nothing else.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Navigated, or the failed read.
   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate forward: the destination is read first, and the window moves
   --  to it only when the read works; one that fails sets the error line
   --  and changes nothing else.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Navigated, or the failed read.
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

   --  Go to the folder that holds Path and select Path's item there: a file
   --  favorite's click and Open Containing Folder.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Path The item to show.
   --  @return The navigation's result (Navigated when the folder loaded);
   --    Disabled with no error when Path has no parent.
   function Navigate_And_Select
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Operation_Result;

   --  Replace the current view with the recursive search results for the
   --  filter text below the current folder: by name (Search_Names), or by
   --  content (Search_Contents) -- files whose bounded leading bytes contain
   --  the query, case-insensitively, skipping binary files and not descending
   --  symlinked directories. An empty query is refused (Disabled, with
   --  "error.filter.empty"). A partial answer is shown with a notice:
   --  "search.truncated" when a limit cut it short, "search.incomplete" when
   --  a folder below the root could not be read (or, by content, a file, or
   --  a text file longer than is read with no match in what was); no match
   --  shows the "search.no_matches" notice. Only a root that cannot be
   --  searched fails, keeping the listing. This runs the search in process;
   --  Files.Controller.Operation_Commands.Run_Search runs it in a helper instead when
   --  the window has background transfers on, applied the same way.
   --
   --  @param Model Window model containing the current path and filter query.
   --  @param Settings Settings model used for directory classification.
   --  @param Scope Search by name or by content.
   --  @return Structured operation result.
   function Run_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope)
      return Operation_Result;

end Files.Operations.Navigation;

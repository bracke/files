with Files.Commands;
with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Operations;
with Files.Settings;
with Guikit.Input;
with Files.Types;

--  Focus-aware input controller for command, text, palette, and filesystem operations.
package Files.Controller is

   type Controller_Status is
     (Controller_Ignored,
      Controller_Command_Executed,
      Controller_Selection_Moved,
      Controller_Text_Updated,
      Controller_Palette_Updated);

   type Controller_Result is record
      Status    : Controller_Status := Controller_Ignored;
      Command   : Files.Commands.Command_Id := Files.Commands.No_Command;
      Operation : Files.Operations.Operation_Result;
   end record;

   --  Replace the text of the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text New text for the focused input.
   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String);

   --  Append text to the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text Text to append to the focused input.
   --  @return Controller result indicating whether text changed.
   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result;

   --  Remove the final character from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the character at the cursor from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the previous word from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Word_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the next word from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Word_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Execute a command through the controller's filesystem-aware routing.
   --
   --  @param Id Command identifier.
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with any operation details.
   function Execute_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

   --  Validate, save, apply, and refresh edited settings.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model to replace on success.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Toggle hidden-file visibility, persist it, and reload the directory.
   --
   --  Flips Settings.Show_Hidden_Files, writes the updated settings model to the
   --  central settings file, and refreshes the current directory so it reloads
   --  with the new visibility. On a save failure the model error is set and a
   --  failed result is returned without leaving the toggle half-applied.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose visibility flag is flipped.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Hidden_Files
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Execute a command produced by a toolbar or bottom-bar hit test.
   --
   --  @param Id Command identifier from the clicked UI control.
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with command or operation details.
   function Handle_Command_Click
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

   --  Cycle the filter-bar search scope one step forward and re-run the shared
   --  query in the new scope. Filter_Here restores the live-filtered directory,
   --  Search_Names runs a recursive name search, and Search_Contents runs a
   --  recursive content search. With an empty query the scope still advances but
   --  no search runs; any prior search results are cleared and the directory is
   --  reloaded when returning to Filter_Here.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @return Controller result with the executed operation, when any.
   function Handle_Search_Scope_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result;

   --  Select a root path from the root selector.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Root_Path Root path selected by the user.
   --  @return Controller result with navigation details.
   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Controller_Result;

   --  Select a root-selector row by index.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Root_Index One-based root selector index, or zero for no row.
   --  @return Controller result with navigation details.
   function Handle_Root_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Natural)
      return Controller_Result;

   --  Navigate to a breadcrumb segment's ancestor directory.
   --
   --  The segment index refers to the segmentation of the current path produced
   --  by Files.Breadcrumbs; the matching ancestor directory is loaded and made
   --  current. A zero or out-of-range index, or the non-navigable elision
   --  marker, is ignored.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Segment_Index One-based breadcrumb segment index, or zero.
   --  @return Controller result with navigation details.
   function Handle_Breadcrumb_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Segment_Index : Natural)
      return Controller_Result;

   --  Toggle a folder-tree node's expansion or navigate to it.
   --
   --  When Toggle is true the node's children are loaded on first expand and its
   --  expanded flag is flipped. When Toggle is false the node's directory is
   --  loaded and made current and the node is expanded. A zero or out-of-range
   --  index is ignored.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Node_Index One-based tree node index, or zero.
   --  @param Toggle True to expand/collapse, false to navigate.
   --  @return Controller result describing the tree change or navigation.
   function Handle_Tree_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural;
      Toggle     : Boolean)
      return Controller_Result;

   --  Execute a command-palette result by index.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Result_Index One-based command-palette result index, or zero for no row.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with command or operation details.
   function Handle_Command_Result_Click
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Result_Index : Natural;
      Modifiers    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

   --  Select or activate a visible item.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Visible_Index One-based visible item index, or zero for no item.
   --  @param Activate True to open the item after selecting it.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with selection or open details.
   function Handle_Item_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Visible_Index : Natural;
      Activate      : Boolean := False;
      Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

   --  Import paths dropped into the current window through the paste engine, so
   --  a drop gets the same conflict dialog and resumable progress/cancel overlay
   --  as clipboard paste (a name collision arms the dialog instead of silently
   --  auto-renaming).
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Source_Paths Dropped filesystem paths.
   --  @param Mode Copy or move mode.
   --  @return Controller result with drop-import operation details.
   function Handle_Drop_Import
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Controller_Result;

   --  Handle a scroll-wheel action for overlays that accept vertical movement.
   --
   --  @param Model Window model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   --  @return Controller result describing whether visible state changed.
   function Handle_Scroll
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result;

   --  Handle a scroll action for a specific scrollable area.
   --
   --  @param Model Window model to update.
   --  @param Target Scrollable area that should consume the movement.
   --  @param Lines Positive values scroll down; negative values scroll up.
   --  @return Controller result describing whether visible state changed.
   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Events.Scroll_Target;
      Lines  : Integer)
      return Controller_Result;

   --  Focus a text field from a mouse click and place its cursor.
   --
   --  @param Model Window model to update.
   --  @param Target Text input target to focus.
   --  @param Cursor_Position Zero-based cursor position to set after focus.
   --  @param Item_Index Visible row index of a clicked rename field (0 otherwise).
   --  @return Controller result describing whether text focus changed.
   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result;

   --  Handle a click inside the settings pane.
   --
   --  @param Model Window model to update.
   --  @param Field Settings field selected by the click.
   --  @param Option Optional clicked option or action code.
   --  @return Controller result describing whether settings state changed.
   function Handle_Settings_Click
     (Model  : in out Files.Model.Window_Model;
      Field  : Natural;
      Option : Natural := 0)
      return Controller_Result;

   --  Handle one key press using focus-aware command routing.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Key Key code.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with any operation details.
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

end Files.Controller;

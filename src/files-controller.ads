with Files.Operation_Results;
with Files.Commands;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Operations;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files.UI_Types;

--  Focus-aware input controller for command, text, palette, and filesystem operations.
package Files.Controller is

   --  What a controller entry did. Two answers ask the caller to finish the
   --  work: Controller_Needs_Settings_Path, for a settings command (Command)
   --  reached without the settings file's path, which
   --  Complete_Settings_Command then applies; Controller_Activation_Requested,
   --  for an overlay's Enter (Activation says which), which the interaction
   --  layer completes as a click on the same control does.
   type Controller_Status is
     (Controller_Ignored,
      Controller_Command_Executed,
      Controller_Selection_Moved,
      Controller_Text_Updated,
      Controller_Palette_Updated,
      Controller_Needs_Settings_Path,
      Controller_Activation_Requested);

   --  An overlay's Enter, for the caller to complete: Choose_Label gives the
   --  selection the label picker's highlighted Label; Run_Menu_Row runs the
   --  context menu's highlighted row (Command).
   type Overlay_Activation is (No_Activation, Choose_Label, Run_Menu_Row);

   type Controller_Result is record
      Status     : Controller_Status := Controller_Ignored;
      Command    : Files.Commands.Command_Id := Files.Commands.No_Command;
      Operation  : Files.Operation_Results.Operation_Result;
      Activation : Overlay_Activation := No_Activation;
      Label      : Files.Types.Color_Label := Files.Types.No_Label;
   end record;

   --  Append text to the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text Text to append to the focused input.
   --  @return Controller result indicating whether text changed.
   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result;

   --  Execute a command through the controller's filesystem-aware routing,
   --  without the settings file: a disabled command is refused (with its
   --  reason on the error line), and a command that changes settings
   --  (Files.Commands.Requires_Settings_Path) is not applied but answered
   --  with Controller_Needs_Settings_Path, for Complete_Settings_Command.
   --
   --  @param Id Command identifier.
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with any operation details.
   function Execute_Non_Settings_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

   --  Finish what a controller entry without the settings path left to its
   --  caller: a Controller_Needs_Settings_Path result's settings command is
   --  applied and persisted (its enablement was checked when it was
   --  reported); any other result is returned as it is.
   --
   --  @param Reported The result an entry returned.
   --  @param Model Window model to update.
   --  @param Settings Live settings model, replaced by a settings command.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @return The applied command's result, or Reported.
   function Complete_Settings_Command
     (Reported      : Controller_Result;
      Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Favorites are folder tree roots: a tree already seeded is seeded again
   --  when the favorites list differs between Before and Settings. Every
   --  settings commit does this; a caller that replaces the settings another
   --  way (adopting another window's) calls it.
   --
   --  @param Model Window whose folder tree follows.
   --  @param Before The settings before the change.
   --  @param Settings The settings now live.
   procedure Follow_Favorites
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model);

   --  Persist the already-applied settings model to the central settings file:
   --  for a scalar applied as the user drags or scrolls (a column width, the
   --  zoom by wheel, the window's size), which cannot make the file too big.
   --  A change that can (a list, a path) goes through Commit_Settings.
   --  A no-op when the path is empty; a write that fails, or is not durable, or
   --  is refused because the settings file could not be loaded, is reported in
   --  the window's error line while the change stays applied for the session.
   --
   --  @param Model Window whose error line reports a failed write.
   --  @param Settings Settings model to serialize.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   procedure Persist_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String);

   --  The one policy for a settings change, wherever it comes from: Updated
   --  replaces Settings and is saved -- a write that fails or is not durable
   --  is reported in the window's error line and the result, never by
   --  dropping the change -- unless the file could not hold it (it would not
   --  load again): then the change is refused whole, Settings stays as it
   --  was, and the error line says the settings are full. (Settings that
   --  already would not load take the change in memory, unsaved.) An
   --  Updated equal to Settings writes nothing.
   --
   --  @param Model Window whose error line reports a refused change or a failed write.
   --  @param Settings Live settings model, replaced by Updated when it is accepted.
   --  @param Updated The settings with the change made.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @return The write's result; Success is False for a refused change.
   function Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result;

   --  Commit_Settings, saying whether the change took.
   --
   --  @param Model Window whose error line reports a refused change or a failed write.
   --  @param Settings Live settings model, replaced by Updated when it is accepted.
   --  @param Updated The settings with the change made.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Accepted True when Updated differed from Settings and is now the
   --    live settings (written, or with the write's failure on the error line);
   --    False when it changed nothing or was refused.
   procedure Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean);

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

   --  Toggle one permission bit of the selection from the info pane, while it
   --  is open and no overlay owns the input.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the operation.
   --  @param Bit Permission bit, 0 (others execute) .. 8 (owner read).
   --  @return Controller result with the operation's outcome.
   function Handle_Permission_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Bit      : Natural)
      return Controller_Result;

   --  Open the info pane's owner or group editor, prefilled with the id.
   --
   --  @param Model Window model to update.
   --  @param Group True for the group, False for the owner.
   --  @return Controller result.
   function Handle_Ownership_Edit
     (Model : in out Files.Model.Window_Model;
      Group : Boolean)
      return Controller_Result;

   --  Answer the open paste conflict.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the paste.
   --  @param Choice What to do with the conflicting item.
   --  @return Controller result with the paste's outcome.
   function Handle_Conflict_Choice
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Choice   : Files.Operations.Conflict_Choice)
      return Controller_Result;

   --  Flip whether the open paste conflict's answer applies to the rest.
   --
   --  @param Model Window model to update.
   --  @return Controller result.
   function Handle_Conflict_Apply_All_Toggle
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Cancel the running foreground job (a paste or an operation,
   --  Files.Foreground_Jobs) and finish over what is done (copies kept).
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the job.
   --  @return Controller result with the job's outcome.
   function Handle_Foreground_Job_Cancel
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
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

   --  Confirm the modal Copy to.../Move to... destination picker: copy or
   --  move the captured sources into the highlighted directory, and end the
   --  pick once that has started. Enter and the picker's Choose button both
   --  come here. A pick with no target yet (a newly seeded tree with no
   --  visible rows) or a paste that does not start (its error on the error
   --  line) leaves the picker open for another choice.
   --
   --  @param Model Window model whose pick is confirmed.
   --  @param Settings Settings model the paste reads.
   --  @return Executed (Copy_To_Command or Move_To_Command, with the paste's
   --    result) when the copy or move started; Ignored, with the paste's
   --    result when there was one, otherwise.
   function Confirm_Tree_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result;

   --  Expand or collapse a folder-tree node, loading its children on first
   --  expand. It reports no command: the tree's own open/close command is
   --  Toggle_Folder_Tree_Command. A zero or out-of-range index is ignored.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Node_Index One-based tree node index, or zero.
   --  @return Controller result describing the tree change.
   function Toggle_Tree_Node
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural)
      return Controller_Result;

   --  Activate a folder-tree node: in a Copy to/Move to pick it becomes the
   --  destination; otherwise its folder is opened and the node expanded. A
   --  zero or out-of-range index is ignored.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Node_Index One-based tree node index, or zero.
   --  @return Controller result describing the pick or the navigation.
   function Activate_Tree_Node
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural)
      return Controller_Result;

   --  Act on the command palette's highlighted command (from Command_Palette.Selected_Id),
   --  the one activation a click on a row and Enter share: launch the chosen
   --  application in Open-With mode, otherwise execute the command
   --  (Execute_Non_Settings_Command, so a settings command comes back for
   --  Complete_Settings_Command). Application preflight and spawn failures
   --  are returned as failed operations; handled selections close the palette.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with command or operation details.
   function Activate_Palette_Command
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
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

   --  Drop the selection, dragged within the window, on a visible item: a
   --  folder there receives it through the paste engine (its conflict dialog
   --  and progress overlay), copied with Ctrl and moved otherwise. A drop on
   --  a file, on no item, or with nothing selected does nothing.
   --
   --  @param Model Window model whose selection is dropped.
   --  @param Settings Settings model the paste reads.
   --  @param Target_Index One-based visible index of the item dropped on, or zero.
   --  @param Modifiers Modifier keys held at the release (Ctrl copies).
   --  @return Executed (Copy_To_Command or Move_To_Command, with the paste's
   --    result) when the paste started; Ignored, with the paste's result when
   --    there was one, otherwise.
   function Handle_Item_Drop
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Target_Index : Natural;
      Modifiers    : Guikit.Input.Modifier_Set)
      return Controller_Result;

   --  Whether dropped paths may be imported now: not while an overlay owns
   --  the input (a dialog, the palette, a paste's progress), which would turn
   --  the import away. Until it closes the drop stays queued, not lost.
   --
   --  @param Model Window model to inspect.
   --  @return True when Handle_Drop_Import would import a drop.
   function Accepts_Drop_Import (Model : Files.Model.Window_Model) return Boolean;

   --  Import the drop Source holds (Handle_Drop_Import), once the window
   --  accepts one (Accepts_Drop_Import): while an overlay owns the input the
   --  drop stays queued in Source, to be imported when the overlay closes.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Source The window's queue of dropped paths.
   procedure Import_Pending_Drops
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Source   : in out Files.Drop_Events.Drop_Event_Source);

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
      Target          : Files.UI_Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result;

   --  Handle a click inside the settings pane at a window coordinate: the panel
   --  hit-tests it (focusing/toggling/choosing/stepping/pressing), then the
   --  emitted change is applied to the draft.
   --
   --  @param Model Window model to update.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return Controller result describing whether settings state changed.
   function Handle_Settings_Click
     (Model : in out Files.Model.Window_Model;
      X     : Integer;
      Y     : Integer)
      return Controller_Result;

   --  Handle one key press using focus-aware command routing. The overlay on
   --  top (Files.Model.Topmost_Overlay) alone owns the keyboard, and Escape
   --  closes it. A settings command the key resolves to is answered with
   --  Controller_Needs_Settings_Path, and Enter on the label picker or the
   --  context menu with Controller_Activation_Requested.
   --
   --  The key arrives translated (Files.Interaction.Handle_Key asks
   --  Files.Events.Translate_Key, as the window layer translates pointer
   --  input), and raw, which text editing and the overlays read.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Key Key code.
   --  @param Action The input action Key and Modifiers translate to.
   --  @param Modifiers Active modifier keys.
   --  @param Tree_Page_Rows Folder-tree rows visible in the live viewport, or
   --    zero when geometry is unavailable.
   --  @return Controller result with any operation details.
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Action    : Files.Events.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result;

private

   --  Validate, apply, refresh, and save edited settings (Commit_Settings): a
   --  valid draft is applied even when the save then fails, and the failure
   --  is reported; one the file could not hold is refused. An unchanged draft
   --  is written again, so Save retries a save that failed.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, replaced when the draft is valid.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Replace the text of the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text New text for the focused input.
   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String);

   --  Toggle hidden-file visibility, persist it, and reload the directory.
   --
   --  Flips Settings.Show_Hidden_Files, refreshes the current directory so it
   --  reloads with the new visibility, and writes the settings file. Like every
   --  settings change, a save failure keeps the change for the session: the
   --  model error is set and the result's operation reports the failure.
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

   --  Cycle the status bar's disk-space field through free space, used space
   --  and a bar (Show_Used_Space, Show_Space_Bar) and persist it. Display
   --  only: the item list is unchanged and the directory is not reloaded.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose space-display flags change.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

end Files.Controller;

with Files.File_System_Types;
with Files.Preference_Types;
with Files.Operation_Results;
with Files.Commands;
with Files.Drop_Events;
with Files.Input_Actions;
with Files.Model;
with Files.Model.Selection;
with Files.Operations;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files.UI_Types;
private with Files.Operations.Paste;

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
      Label      : Files.Preference_Types.Color_Label := Files.Preference_Types.No_Label;
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

   --  After a change to settings the open settings pane edits (a command
   --  from a click, a shortcut or the palette, another window's or another
   --  process's change): the pane shows the new values, its next save
   --  cannot write the old ones back, and it takes the file to hold
   --  Settings now (Files.Overlays.Settings_Form.Mark_Saved). Nothing when the pane
   --  is closed.
   --
   --  @param Model Window whose pane follows.
   --  @param Before The settings before the change.
   --  @param Settings The settings now live.
   procedure Refresh_Open_Pane
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
   --  @param Settings Settings model to serialize; takes what another
   --    process wrote to the file since (Files.Settings.Storage.Merge_From_File).
   --  @param Settings_Path Central settings file path (empty disables persistence).
   procedure Persist_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String);

   --  Write the settings a held key stepped, once it is let go: what is in
   --  force, every accepted step, not the pane's draft again (a step the
   --  file could not hold was refused and is in force nowhere). An open
   --  pane then shows the written settings and counts them saved.
   --
   --  @param Model Window whose error line reports a failed write and whose
   --    settings pane, when open, is brought up to date.
   --  @param Settings Settings in force; takes what another process wrote.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   procedure Persist_Held_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String);

   --  Star or unstar the current folder, whatever is selected (the path
   --  bar's star), under Commit_Settings' policy. Nothing happens in a view
   --  of no folder (Recent) or while an overlay owns the input.
   --
   --  @param Model Window whose folder is starred.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Accepted True when the change took (Commit_Settings).
   procedure Toggle_Folder_Favorite
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean);

   --  Give every selected item Label (No_Label clears it) and close the
   --  label picker, under Commit_Settings' policy: an edit that would make
   --  the settings file too big to load again is refused whole.
   --
   --  @param Model Window whose selection is labelled.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Label The label to give.
   --  @param Accepted True when the change took.
   procedure Label_Selection
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Label         : Files.Preference_Types.Color_Label;
      Accepted      : out Boolean);

   --  Set the font size (zoom), under Commit_Settings' policy; the window's
   --  next frame takes it up.
   --
   --  @param Model Window that zoomed.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Size The new font pixel size (already clamped).
   --  @param Save_Now Write the file now; False puts the size in force only
   --    (a wheel zoom, whose window writes it with Persist_Settings once the
   --    wheel rests).
   --  @param Accepted True when the size changed and took.
   procedure Set_Font_Size
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Size          : Positive;
      Save_Now      : Boolean;
      Accepted      : out Boolean);

   --  Put a colour theme in force for this session without writing the
   --  file (a smoke scenario shows it), through the one settings decision.
   --
   --  @param Model Window whose settings change.
   --  @param Settings Live settings model.
   --  @param Theme The theme to show.
   procedure Show_Theme
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Theme    : Files.Settings.Theme_Choice);

   --  Give a details column Width (in reference units) while it is dragged:
   --  in memory only -- Persist_Settings writes it once the drag ends -- but
   --  the window's settings moved, so other windows take them from here.
   --
   --  @param Model Window whose column is resized.
   --  @param Settings Live settings model.
   --  @param Column The column resized.
   --  @param Width Its new width in reference units.
   --  @param Changed True when the width moved.
   procedure Resize_Column
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Column   : Files.Preference_Types.Detail_Column;
      Width    : Natural;
      Changed  : out Boolean);

   --  Move a details column to To_Index, under Commit_Settings' policy.
   --
   --  @param Model Window whose columns are reordered.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Column The column moved.
   --  @param To_Index Where it goes.
   --  @param Accepted True when the order changed and took.
   procedure Reorder_Column
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Preference_Types.Detail_Column;
      To_Index      : Files.Preference_Types.Detail_Column_Index;
      Accepted      : out Boolean);

   --  The window's own view of the persisted UI state (view mode, sort,
   --  info pane), captured before a command runs so what it changed, and only
   --  that, is written back: a value the window never adopted from another
   --  window (its view mode, its info pane) must not overwrite the shared one.
   type UI_State is record
      View      : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons;
      Sort      : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Ascending : Boolean := True;
      Info      : Boolean := False;
   end record;

   --  The model's UI state now.
   --  @param Model The window.
   --  @return Its view mode, sort and info-pane state.
   function UI_State_Of (Model : Files.Model.Window_Model) return UI_State;

   --  Write the UI state a command changed in the model (against Before, the
   --  model's state before it ran) into the settings and persist it.
   --  @param Model Window model the command ran on.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Before The model's UI state before the command ran.
   --  @param Accepted True when a change was written and took.
   procedure Persist_UI_State
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Before        : UI_State;
      Accepted      : out Boolean);

   --  Carry the stored favorites, labels and recent paths along the moves,
   --  renames and removals the model queued (Files.Model.Recent), under
   --  Commit_Settings' policy: longer paths that would make the file too big
   --  to load again leave the references where they were, said in the error
   --  line. A background job's finish calls this; an input's dispatch calls
   --  Note_Recent_Opens, which takes both queues.
   --
   --  @param Model Model whose queued moves are drained.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @return True when a stored path changed and the change took.
   function Follow_Path_Moves
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean;

   --  Keep a closing window's size for the next window, under
   --  Commit_Settings' policy; nothing when it is the stored size.
   --
   --  @param Model The closing window's model.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Width Window width in screen units.
   --  @param Height Window height in screen units.
   procedure Remember_Window_Size
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Width         : Positive;
      Height        : Positive);

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

   --  Take settings another window changed (Shared) as this window's own,
   --  put in force as Take_In_Settings does: an open settings pane is
   --  refreshed (Files.Settings.Drafts.Refresh_Draft), so its next save
   --  cannot write the old values back; the listing is reloaded when what it
   --  lists or how it names entries' types changed; an open command palette
   --  lists its commands again (a shortcut the other window rebound).
   --
   --  @param Model This window's model.
   --  @param Settings This window's live settings, replaced by Shared.
   --  @param Shared The settings another window committed.
   procedure Adopt_Shared_Settings
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Shared   : Files.Settings.Settings_Model);

   --  What every key and action dispatch ends with: any item opened folded
   --  into the recent list with the queued path moves (Note_Recent_Opens),
   --  and the selected item's lazily computed extra info
   --  (Files.Refresh.Ensure_Selected_Item_Extra).
   --
   --  @param Model Model whose queues are drained.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Accepted True when a settings change took.
   procedure Finish_Dispatch
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean);

   --  Answer a button of the open paste-conflict dialog: Replace, Skip,
   --  Rename or Cancel answer it, Apply All flips whether the answer applies
   --  to the rest.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the paste.
   --  @param Button The button clicked.
   --  @return Controller result with the paste's outcome; ignored with no
   --    conflict open or no button.
   function Handle_Conflict_Button
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Button   : Files.Input_Actions.Conflict_Button_Kind)
      return Controller_Result;

   --  Cancel the running foreground job (a paste or an operation,
   --  Files.Job_Drivers.Foreground) and finish over what is done (copies kept).
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

   --  A click on the command palette: the row under (X, Y) selected and
   --  activated as Enter activates it (Activate_Palette_Command); ignored
   --  when the palette is closed or the click hits no row.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param X Click column, in window pixels.
   --  @param Y Click row, in window pixels.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result; Controller_Ignored when nothing ran.
   function Click_Palette_Row
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      X         : Integer;
      Y         : Integer;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result;

   --  A right-click: the context menu for what it hit opened at (X, Y) --
   --  the details header's column menu, an item's (selecting the item
   --  first when it was not selected, so the menu's commands act on what
   --  the user sees), or the empty view's -- or the open menu closed.
   --  Swallowed behind an overlay that owns the input, as a left-click is;
   --  a click on the open menu itself is left to it.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Target What the click hit.
   --  @param Item_Index One-based visible item index, or zero for none.
   --  @param X Click column, in window pixels.
   --  @param Y Click row, in window pixels.
   --  @return Controller result of the item selection, if any.
   function Handle_Right_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Target     : Files.Input_Actions.Right_Click_Target;
      Item_Index : Natural;
      X          : Natural;
      Y          : Natural)
      return Controller_Result;

   --  The context menu closed for a row of it that was chosen (the caller
   --  then runs the row's command).
   --
   --  @param Model Window model to update.
   procedure Close_Context_Menu (Model : in out Files.Model.Window_Model);

   --  A marquee drag's selection: exactly the visible rows Rows (one-based,
   --  repeats ignored).
   --
   --  @param Model Window model to update.
   --  @param Rows The rows the marquee selects.
   procedure Select_Marquee_Rows
     (Model : in out Files.Model.Window_Model;
      Rows  : Files.Model.Selection.Visible_Index_List);

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

   --  Handle a scroll action for a specific scrollable area.
   --
   --  @param Model Window model to update.
   --  @param Target Scrollable area that should consume the movement.
   --  @param Lines Positive values scroll down; negative values scroll up.
   --  @return Controller result describing whether visible state changed.
   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Input_Actions.Scroll_Target;
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
      Action    : Files.Input_Actions.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result;

private

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

   --  Make settings that replaced Before -- another window's, or another
   --  process's taken in by a save -- in force in this window: the open
   --  pane follows (Refresh_Open_Pane), an open palette lists its commands
   --  again (a shortcut rebound elsewhere), the folder tree follows the
   --  favorites, the sort is applied, and the listing is read again (or
   --  search results reclassified in place) when what it lists or how it
   --  names types changed (hidden files, filetype or icon mappings).
   --
   --  @param Model This window's model.
   --  @param Before The settings before.
   --  @param Settings The settings now live.
   procedure Take_In_Settings
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model);

   --  Fold the paths the model queued while opening items into the recent
   --  list, with the queued path moves, as one settings edit and one write.
   --  A no-op when both queues are empty, so it is safe after every dispatch.
   --  Should the recent list make the file too big, the moves alone go in.
   --
   --  @param Model Model whose queues are drained.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Accepted True when a change took.
   procedure Note_Recent_Opens
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean);

   --  Answer the open paste conflict.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the paste.
   --  @param Choice What to do with the conflicting item.
   --  @return Controller result with the paste's outcome.
   function Handle_Conflict_Choice
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Choice   : Files.Operations.Paste.Conflict_Choice)
      return Controller_Result;

   --  Flip whether the open paste conflict's answer applies to the rest.
   --
   --  @param Model Window model to update.
   --  @return Controller result.
   function Handle_Conflict_Apply_All_Toggle
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

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

   --  Whether dropped paths may be imported now: not while an overlay owns
   --  the input (a dialog, the palette, a paste's progress), which would turn
   --  the import away. Until it closes the drop stays queued, not lost.
   --
   --  @param Model Window model to inspect.
   --  @return True when Handle_Drop_Import would import a drop.
   function Accepts_Drop_Import (Model : Files.Model.Window_Model) return Boolean;

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
      Mode         : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy)
      return Controller_Result;

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

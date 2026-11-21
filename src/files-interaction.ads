with Files.Preference_Types;
with Files.Input_Actions;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Model;
with Files.Model.Selection;
with Files.Settings;
with Guikit.Input;
with Files.Types;

--  GLFW-free interaction reducer. Peer to Files.Events (which translates raw
--  GLFW input into an Input_Action) and Files.Controller (the focus-aware leaf
--  operations): this package owns the orchestration that *applies* an
--  Input_Action or a Command to the window model and settings and *sequences*
--  multi-step interactions (right-click -> menu open -> row click -> command).
--
--  It touches nothing GLFW, Vulkan, timing, or GPU related. The desktop shell
--  (Files.Application.Windows) calls one of these entry points and then performs
--  its own follow-up (font-size sync, glyph-cache invalidation, pending-text
--  clearing) by inspecting the returned Interaction_Result flags.
package Files.Interaction is

   --  Follow-up flags produced by an interaction. Every flag is an *observation*
   --  about what the reducer did; acting on the GPU/GLFW/timing consequences is
   --  the shell's responsibility (or the test's assertion target).
   type Interaction_Result is record
      Command              : Files.Commands.Command_Id := Files.Commands.No_Command;
      --  Command that was dispatched (No_Command when none).
      Status               : Files.Controller.Controller_Status :=
        Files.Controller.Controller_Ignored;
      --  Status reported by the underlying controller leaf operation.
      Settings_Changed     : Boolean := False;
      --  True when the action changed what the settings hold
      --  (Files.Settings.Same_Content), not merely ran a settings command:
      --  written now, or, for a column-resize or wheel-zoom step, held in
      --  memory for one write when the gesture ends.
      Clear_Pending_Text   : Boolean := False;
      --  True when the shell must drop any buffered character input.
   end record;

   --  Execute a single command with the follow-ups a settings change needs:
   --  a settings command's own (font size, glyphs), the UI state it changed
   --  written back to the settings, and an open settings pane refreshed.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the command persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Command Command identifier to execute.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the command did.
   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result);

   --  Take settings another window changed (Shared) as this window's own.
   --  An open settings pane is refreshed as after a command run here
   --  (Files.Settings.Refresh_Draft), so its draft shows the change and its
   --  next save cannot write the old values back; the listing is reloaded
   --  when what it lists or how it names entries' types changed (the listing
   --  options, the filetype or icon mappings). An open command palette lists
   --  its commands again: a shortcut the other window rebound shows its new
   --  keys.
   --
   --  @param Model This window's model.
   --  @param Settings This window's live settings, replaced by Shared.
   --  @param Shared The settings the other window changed.
   procedure Adopt_Shared_Settings
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Shared   : Files.Settings.Settings_Model);

   --  Dispatch one keyboard press through the focus-aware controller. A key
   --  that ran a settings command gets the same follow-ups as Execute_Command
   --  gives one, and Clear_Pending_Text; any other key keeps the controller's
   --  own result. This is the live key dispatch seam, distinct from
   --  translating a raw input action.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the key persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Key Key code that was pressed.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the key dispatch did.
   --  @param Tree_Page_Rows Folder-tree rows visible in the live viewport, or
   --    zero when geometry is unavailable.
   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result;
      Tree_Page_Rows    : Natural := 0);

   --  Type Text into the window: the focused field edits it, or the grid's
   --  type-ahead moves the selection (Files.Controller.Append_Focused_Text),
   --  as a key press reaches the window through Handle_Key.
   --
   --  @param Model Window model to update.
   --  @param Text UTF-8 text typed, in the order it arrived.
   --  @param Result Follow-up flags describing what the text did.
   procedure Append_Text
     (Model  : in out Files.Model.Window_Model;
      Text   : String;
      Result : out Interaction_Result);

   --  Import the paths dropped on the window (Files.Controller.
   --  Import_Pending_Drops), which stay queued in Source while an overlay owns
   --  the input. A drop too big to take whole is refused with an error line.
   --  A move the import made carries its labels, favourites and recent
   --  entries along, as a move from a command does.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated when stored paths follow.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Source The window's queue of dropped paths.
   --  @param Result Follow-up flags describing what the drop did.
   procedure Import_Drops
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Source        : in out Files.Drop_Events.Drop_Event_Source;
      Result        : out Interaction_Result);

   --  Apply a translated input action to the model and settings. The drag
   --  begins (scrollbar, column resize and reorder, marquee) are ignored here:
   --  the shell owns their runtime state and applies them on drop or per
   --  frame. A Selection_Input_Action (the arrow keys) arrives through
   --  Handle_Key instead, and the no-op is ignored.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when an action persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Action Translated input action to apply.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the action did.
   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Input_Actions.Input_Action;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result);

   --  Apply one step of a details-header column-resize drag. Sets Column's
   --  width to its width at drag start adjusted by how far the pointer has moved
   --  from the separator's origin, clamped through With_Column_Width. The step
   --  changes the settings in memory only: a drag moves many times a second, so
   --  End_Column_Resize writes the settings file once when the drag ends.
   --  Because the flexible name column absorbs the slack on the left, dragging
   --  a separator left widens its column and dragging right narrows it, so the
   --  applied delta is Origin_X minus Current_X. The details layout reflows the
   --  name column to honour its minimum on the next frame.
   --  Result.Settings_Changed is set, and the window's settings revision
   --  bumped (Files.Model.Note_Settings_Changed), when the width actually
   --  changed. The pointer works in framebuffer pixels, but the width is stored in
   --  reference units (pixels at Guikit.Layout.Reference_Line_Height, rounded),
   --  which Compute_Detail_Columns scales back up: a width set on a 1x display
   --  shows the same characters on a 2x one, and at the reference line height
   --  the two units coincide, so existing settings files keep their meaning.
   --
   --  @param Model Window whose settings revision notes a width change.
   --  @param Settings Live settings model, updated in place when the width changes.
   --  @param Column Optional detail column being resized.
   --  @param Origin_X Separator x edge captured when the drag began.
   --  @param Origin_Width Column's effective width in pixels when the drag began.
   --  @param Current_X Current pointer x coordinate in window pixels.
   --  @param Result Follow-up flags; Settings_Changed reports a width change.
   --  @param Line_Height Text line height the columns are drawn at.
   procedure Apply_Column_Resize
     (Model        : in out Files.Model.Window_Model;
      Settings     : in out Files.Settings.Settings_Model;
      Column       : Files.Preference_Types.Detail_Column;
      Origin_X     : Integer;
      Origin_Width : Natural;
      Current_X    : Integer;
      Result       : out Interaction_Result;
      Line_Height  : Positive);

   --  End a details-header column-resize drag: when any of its steps changed a
   --  width, write the settings once. A failed write is reported in the
   --  window's error line.
   --
   --  @param Model Window whose error line reports a failed write.
   --  @param Settings Live settings model holding the drag's final width.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Changed Whether any step of the drag reported Settings_Changed.
   procedure End_Column_Resize
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Changed       : Boolean);

   --  Apply a details-header column-reorder drop. Moves Column so it occupies
   --  slot To_Index in the persisted column order (through With_Column_Order,
   --  which pins the name column first and treats a no-op move as a no-op), then
   --  persists the settings. Per-column widths and visibility follow their
   --  column, not its position. Result.Settings_Changed is set when the order
   --  actually changed. A failed write is reported in the window's error line.
   --
   --  @param Model Window whose error line reports a failed write.
   --  @param Settings Live settings model, updated in place when the order changes.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Column Detail column being moved.
   --  @param To_Index Target one-based slot for Column.
   --  @param Result Follow-up flags; Settings_Changed reports an order change.
   procedure Apply_Column_Reorder
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Preference_Types.Detail_Column;
      To_Index      : Files.Preference_Types.Detail_Column_Index;
      Result        : out Interaction_Result);

   --  Make labels, favorites and recent entries follow the renames and moves
   --  the model recorded (Files.Model.Note_Path_Move), and persist them.
   --
   --  @param Model Model whose recorded moves are drained.
   --  @param Settings Live settings model updated in place.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @return True when any stored path changed.
   function Follow_Path_Moves
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean;

   --  Zoom to New_Size, from the keyboard or the wheel alike: the change goes
   --  through the one settings policy (Controller.Commit_Settings); the
   --  window's next frame takes up the new size.
   --
   --  @param Model Window whose error line reports a refused or failed save.
   --  @param Settings Live settings, replaced when the change is taken.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param New_Size The font pixel size asked for, already clamped.
   --  @param Result Settings_Changed is set; other fields are left alone.
   procedure Apply_Zoom
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      New_Size      : Positive;
      Result        : in out Interaction_Result);

   --  The selection a marquee starts from, by path: the shell captures it at
   --  the press so an additive (Ctrl/Shift) marquee can union against the
   --  prior selection without the per-frame reapply erasing it, and a
   --  refresh landing mid-drag (rows moving under their numbers) keeps the
   --  same items.
   --
   --  @param Model Window model to inspect.
   --  @return Full paths of the items selected now.
   function Marquee_Base
     (Model : Files.Model.Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Apply a rubber-band marquee's per-frame selection to the model. The
   --  selection is cleared and rebuilt from Hits (the items the marquee touches);
   --  when Additive the Base snapshot (the selection captured at the marquee's
   --  press, by path, so it names the same items whatever rows they are on
   --  now) is unioned in first so the drag extends rather than replaces it.
   --  Called live each frame while the marquee drags so the selection tracks it.
   --
   --  @param Model Window model to update.
   --  @param Hits Visible indices the current marquee rectangle intersects.
   --  @param Additive True to union Base with Hits (Ctrl/Shift marquee).
   --  @param Base Selection snapshot captured at the marquee's press (Marquee_Base).
   procedure Apply_Marquee_Selection
     (Model    : in out Files.Model.Window_Model;
      Hits     : Files.Model.Selection.Visible_Index_List;
      Additive : Boolean;
      Base     : Files.Types.String_Vectors.Vector);

private

   --  Apply a chosen context-menu row command: close the menu, then execute the
   --  command when it is not No_Command. Reached through Apply_Input_Action
   --  and Handle_Key (Enter on a highlighted row).
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the command persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Command Resolved menu-row command, or No_Command when the click missed a row.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the command did.
   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result);

   --  Apply a right-click: select the right-clicked item (matching desktop
   --  convention) and open the context menu, unless a modal overlay is open, in
   --  which case the menu is closed. Files.Events.Translate_Right_Click
   --  supplies In_Main and Item_Index from the snapshot; overlay state is read
   --  here. A right-click on the details-view column header
   --  (In_Details_Header) opens the column-configuration menu and takes
   --  precedence over the item/empty menus. Reached through Apply_Input_Action.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by item-click selection.
   --  @param Target What the click landed on. On the open context menu it
   --  is ignored, so the item drawn beneath cannot take the selection.
   --  @param Item_Index Visible item index under the cursor, or zero when none.
   --  @param X Window-space X coordinate of the click.
   --  @param Y Window-space Y coordinate of the click.
   --  @param Result Follow-up flags describing the context-menu change.
   procedure Apply_Right_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Target     : Files.Input_Actions.Right_Click_Target;
      Item_Index : Natural;
      X          : Natural;
      Y          : Natural;
      Result     : out Interaction_Result);

end Files.Interaction;

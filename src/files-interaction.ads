with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.Model;
with Files.Rendering;
with Files.Settings;
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
      Command_Executed     : Boolean := False;
      --  True when a command actually ran (controller reported execution).
      Settings_Changed     : Boolean := False;
      --  True when the persisted settings model changed and was written to disk.
      Font_Size_Changed    : Boolean := False;
      --  True when a saved settings change altered the live font pixel size.
      Needs_Glyph_Rebuild  : Boolean := False;
      --  True when the shell must invalidate its rasterized glyph cache.
      Directory_Reloaded   : Boolean := False;
      --  True when the current directory listing was reloaded.
      Clear_Pending_Text   : Boolean := False;
      --  True when the shell must drop any buffered character input.
      Context_Menu_Changed : Boolean := False;
      --  True when the right-click context menu was opened or closed.
   end record;

   --  Execute a single command, applying the settings-path-aware routing the
   --  desktop shell previously performed inline (save/toggle/bookmark, global
   --  UI-state sync, and the sort-change directory reload).
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the command persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Command Command identifier to execute.
   --  @param Current_Font_Size Live font pixel size, used to detect a saved font-size change.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the command did.
   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result            : out Interaction_Result);

   --  Dispatch one keyboard press through the focus-aware controller, applying
   --  the settings-path-aware routing the desktop shell previously performed
   --  inline: a key that resolves to a settings-path command (save or
   --  toggle-hidden) is re-run through Execute_Command so the in-out settings
   --  handling and follow-up flags apply (including Clear_Pending_Text); any
   --  other key keeps the controller's own result. This is the genuine live key
   --  dispatch seam, distinct from translating a raw input action.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the key persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Key Key code that was pressed.
   --  @param Modifiers Active modifier keys.
   --  @param Current_Font_Size Live font pixel size, used to detect a saved font-size change.
   --  @param Result Follow-up flags describing what the key dispatch did.
   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Files.Types.Key_Code;
      Modifiers         : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Current_Font_Size : Positive;
      Result            : out Interaction_Result);

   --  Apply a translated input action to the model and settings. Mirrors the
   --  former Dispatch_Click_Action ladder: command, item-click, root-click,
   --  command-palette result, text-click, settings-click (with save/toggle
   --  follow-up), and targeted scroll. Scrollbar-drag and no-op kinds are left
   --  for the shell, which owns the scrollbar-drag runtime state.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when an action persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Action Translated input action to apply.
   --  @param Current_Font_Size Live font pixel size, used to detect a saved font-size change.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the action did.
   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Events.Input_Action;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set;
      Result            : out Interaction_Result);

   --  Apply a chosen context-menu row command: close the menu, then execute the
   --  command when it is not No_Command.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the command persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Command Resolved menu-row command, or No_Command when the click missed a row.
   --  @param Current_Font_Size Live font pixel size, used to detect a saved font-size change.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the command did.
   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set;
      Result            : out Interaction_Result);

   --  Apply a right-click: select the right-clicked item (matching desktop
   --  convention) and open the context menu, unless a modal overlay is open, in
   --  which case the menu is closed. The shell supplies the geometry-derived
   --  In_Main flag and Item_Index (from Item_At); overlay state is read here. A
   --  right-click on the details-view column header (In_Details_Header) opens the
   --  column-configuration menu and takes precedence over the item/empty menus.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by item-click selection.
   --  @param In_Main True when the click landed inside the main grid region.
   --  @param Item_Index Visible item index under the cursor, or zero when none.
   --  @param X Window-space X coordinate of the click.
   --  @param Y Window-space Y coordinate of the click.
   --  @param In_Details_Header True when the click landed on the details header.
   --  @param Result Follow-up flags describing the context-menu change.
   procedure Apply_Right_Click
     (Model             : in out Files.Model.Window_Model;
      Settings          : Files.Settings.Settings_Model;
      In_Main           : Boolean;
      Item_Index        : Natural;
      X                 : Natural;
      Y                 : Natural;
      Result            : out Interaction_Result;
      In_Details_Header : Boolean := False);

   --  Apply one step of a details-header column-resize drag. Sets Column's
   --  persisted width to its width at drag start adjusted by how far the pointer
   --  has moved from the separator's origin, then clamps and persists it through
   --  With_Column_Width. Because the flexible name column absorbs the slack on
   --  the left, dragging a separator left widens its column and dragging right
   --  narrows it, so the applied delta is Origin_X minus Current_X. The details
   --  layout reflows the name column to honour its minimum on the next frame.
   --  Result.Settings_Changed is set when the width actually changed.
   --
   --  @param Settings Live settings model, updated in place when the width changes.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Column Optional detail column being resized.
   --  @param Origin_X Separator x edge captured when the drag began.
   --  @param Origin_Width Column's effective width when the drag began.
   --  @param Current_X Current pointer x coordinate in window pixels.
   --  @param Result Follow-up flags; Settings_Changed reports a width change.
   procedure Apply_Column_Resize
     (Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Types.Detail_Column;
      Origin_X      : Integer;
      Origin_Width  : Natural;
      Current_X     : Integer;
      Result        : out Interaction_Result);

   --  Apply a details-header column-reorder drop. Moves Column so it occupies
   --  slot To_Index in the persisted column order (through With_Column_Order,
   --  which pins the name column first and treats a no-op move as a no-op), then
   --  persists the settings. Per-column widths and visibility follow their
   --  column, not its position. Result.Settings_Changed is set when the order
   --  actually changed.
   --
   --  @param Settings Live settings model, updated in place when the order changes.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Column Detail column being moved.
   --  @param To_Index Target one-based slot for Column.
   --  @param Result Follow-up flags; Settings_Changed reports an order change.
   procedure Apply_Column_Reorder
     (Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Types.Detail_Column;
      To_Index      : Files.Types.Detail_Column_Index;
      Result        : out Interaction_Result);

   --  Persist the settings model to the central settings file. A no-op when the
   --  path is empty; write failures are intentionally ignored.
   --
   --  @param Settings Settings model to serialize.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   procedure Persist_Settings
     (Settings      : Files.Settings.Settings_Model;
      Settings_Path : String);

   --  Snapshot the currently selected visible items as an ascending set of
   --  one-based visible indices. The shell captures this at a marquee's press so
   --  an additive (Ctrl/Shift) marquee can union against the prior selection
   --  without the per-frame reapply erasing it.
   --
   --  @param Model Window model to inspect.
   --  @return Ascending visible indices currently selected.
   function Selected_Visible_Indices
     (Model : Files.Model.Window_Model)
      return Files.Rendering.Visible_Index_Vectors.Vector;

   --  Apply a rubber-band marquee's per-frame selection to the model. The
   --  selection is cleared and rebuilt from Hits (the items the marquee touches);
   --  when Additive the Base snapshot (the selection captured at the marquee's
   --  press) is unioned in first so the drag extends rather than replaces it.
   --  Called live each frame while the marquee drags so the selection tracks it.
   --
   --  @param Model Window model to update.
   --  @param Hits Visible indices the current marquee rectangle intersects.
   --  @param Additive True to union Base with Hits (Ctrl/Shift marquee).
   --  @param Base Selection snapshot captured at the marquee's press.
   procedure Apply_Marquee_Selection
     (Model    : in out Files.Model.Window_Model;
      Hits     : Files.Rendering.Visible_Index_Vectors.Vector;
      Additive : Boolean;
      Base     : Files.Rendering.Visible_Index_Vectors.Vector);

end Files.Interaction;

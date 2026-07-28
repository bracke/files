--  The panes state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Panes is

   --  Toggle info-pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Info_Pane
     (Model : in out Window_Model);

   --  Return whether the info pane is open.
   --
   --  @param Model Model to inspect.
   --  @return True when info pane is open.
   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Compute and cache the selected item's "extra info" (folder child count,
   --  document counts, symlink target) when the info pane is open and it has not
   --  been computed yet. Called after input so the info pane can show the detail
   --  without every item paying for it on load. A no-op when the info pane is
   --  closed, nothing is selected, or the value is already cached.
   --
   --  @param Model Model whose selected item is updated in place.
   procedure Ensure_Selected_Item_Extra
     (Model : in out Window_Model);

   --  Toggle settings pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Settings_Pane
     (Model : in out Window_Model);

   --  Return whether the settings pane is visible.
   --
   --  @param Model Model to inspect.
   --  @return True when the settings pane is open.
   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Begin editing settings values in the settings pane.
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to edit.
   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Return the current settings draft.
   --
   --  @param Model Model to inspect.
   --  @return Editable settings draft.
   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft;

   --  Replace the active settings draft.
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to store.
   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Move keyboard focus over the panel's fields (sections are skipped).
   --
   --  @param Model Model to update.
   --  @param Delta_Rows Signed number of fields to move focus.
   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer);

   --  Advance/retreat the focused toggle or choice, or step a focused number.
   --
   --  @param Model Model to update.
   --  @param Forward True to advance, False to retreat.
   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean);

   --  Replace the whole value of the focused text field.
   --
   --  @param Model Model to update.
   --  @param Text New text value.
   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String);

   --  Scroll the panel content by whole rows (positive scrolls down).
   --
   --  @param Model Model to update.
   --  @param Lines Rows to scroll.
   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer);

   --  Hit-test a window coordinate, focusing/editing the field under it.
   --
   --  @param Model Model to update.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return True when a field was hit.
   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

   --  The change emitted by the panel's most recent input (clears on read).
   --
   --  @param Model Model to update.
   --  @return The pending change.
   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change;

   --  The focused field's current value ("" when none).
   --
   --  @param Model Model to inspect.
   --  @return The focused field's value.
   function Settings_Focused_Value (Model : Window_Model) return String;

   --  Show the Ordinal-th settings section (clamped to the available range),
   --  moving focus to its first field. Used to drive the tab switcher
   --  programmatically (keyboard tab navigation and tests).
   --
   --  @param Model Model to update.
   --  @param Ordinal One-based section ordinal.
   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural);

   --  The number of settings sections (tabs) in the current field list.
   --
   --  @param Model Model to inspect.
   --  @return Section count (0 before the panel has been laid out).
   function Settings_Section_Count (Model : Window_Model) return Natural;

   --  The one-based ordinal of the currently shown settings section.
   --
   --  @param Model Model to inspect.
   --  @return Active section ordinal.
   function Settings_Active_Section (Model : Window_Model) return Natural;

   --  Arm the focused field for capture when it is an enabled Shortcut field.
   --
   --  @param Model Model to update.
   procedure Settings_Begin_Capture (Model : in out Window_Model);

   --  Whether a Shortcut field is armed for capture.
   --
   --  @param Model Model to inspect.
   --  @return True while a chord is being captured.
   function Settings_Is_Capturing (Model : Window_Model) return Boolean;

   --  The command identifier of the armed Shortcut field ("" when none). The
   --  field Key is "shortcut.<identifier>"; this returns that whole Key.
   --
   --  @param Model Model to inspect.
   --  @return The armed field's Key, or "".
   function Settings_Capturing_Key (Model : Window_Model) return String;

   --  Commit a captured chord (empty Text unbinds) to the armed field, disarm,
   --  and emit the panel's Value_Changed.
   --
   --  @param Model Model to update.
   --  @param Text The formatted chord text, or "" to unbind.
   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String);

   --  Disarm capture without changing any field.
   --
   --  @param Model Model to update.
   procedure Settings_Cancel_Capture (Model : in out Window_Model);

   --  Render the settings panel within a region, rebuilding its field list from
   --  the current draft first. Emits draw commands and accessibility nodes.
   --
   --  @param Model Model to render from (updates the panel's cached layout).
   --  @param Region_X Left edge of the panel region in pixels.
   --  @param Region_Y Top edge of the panel region in pixels.
   --  @param Region_Width Panel region width in pixels.
   --  @param Region_Height Panel region height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Line_Height Row height in pixels.
   --  @param Focused Whether the panel has keyboard focus.
   --  @param Hover_X Cursor X in pixels, or negative when off-window (drives the
   --    tab-switcher hover tooltip).
   --  @param Hover_Y Cursor Y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Settings_Build_Frame
     (Model         : in out Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

   --  Scroll the info pane by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current info-pane scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative info-pane scroll offset.
   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural;

   --  Scroll the main item view by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current main item-view scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative main-view scroll offset.
   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural;

   --  Set the main-view scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New main-view scroll offset in logical text lines.
   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

   --  Set the info-pane scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New info-pane scroll offset in logical text lines.
   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

end Files.Model.Panes;

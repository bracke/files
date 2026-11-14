with Files.Items;
private package Files.Model.Support is

   --  Sentinel item index marking the temporary create-item row.
   Temporary_Item_Index : constant Natural := Natural'Last;

   --  Clear the Quick Look overlay state. Declared early so the navigation and
   --  selection resets below can close a stale preview when the previewed item
   --  is no longer the single, current selection.
   --
   --  @param Model Model whose Quick Look state is cleared.
   procedure Reset_Quick_Look
     (Model : in out Window_Model);

   --  The magnitude of a signed scroll delta in lines (its absolute value,
   --  saturating Integer'First).
   --
   --  @param Lines Signed scroll delta.
   --  @return Number of lines to scroll by.
   function Scroll_Step (Lines : Integer) return Natural;

   --  Deactivate rename mode and discard every inline rename field.
   --
   --  @param Model Model whose rename state is reset.
   procedure Reset_Rename_State
     (Model : in out Window_Model);

   --  Return whether the active rename is the temporary create-item field.
   --
   --  @param Model Model to inspect.
   --  @return True when a rename is active on the temporary create row.
   function Is_Temporary_Rename
     (Model : Window_Model)
      return Boolean;

   --  Close the drive/root selector and forget its selection.
   --
   --  @param Model Model whose root-selector state is cleared.
   procedure Clear_Root_Selector_State
     (Model : in out Window_Model);

   --  Whether Item passes the current filter query (case-insensitive substring
   --  of its name); True when the filter is empty.
   --
   --  @param Model Model providing the filter query.
   --  @param Item Directory item to test.
   --  @return True when Item is shown under the current filter.
   function Item_Is_Visible
     (Model : Window_Model;
      Item  : Files.Items.Directory_Item)
      return Boolean;

   --  Whether the temporary create-item row is shown under the current filter.
   --
   --  @param Model Model to inspect.
   --  @return True when the temporary row passes the filter.
   function Temporary_Is_Visible (Model : Window_Model) return Boolean;

   --  The temporary create-item row's item: a folder, or a plain-text file,
   --  named as typed so far, in the current folder.
   --
   --  @param Model Model whose pending create to describe.
   --  @return The item the row shows.
   function Temporary_Item (Model : Window_Model) return Files.Items.Directory_Item;

   --  Map a 1-based visible-row index to its item-list index (accounting for
   --  the filter and the temporary row); zero when the row has no backing item.
   --
   --  @param Model Model providing the filtered view.
   --  @param Visible_Index 1-based row index in the visible list.
   --  @return Item-list index, or 0 for the temporary/absent row.
   function Visible_To_Item_Index
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural;

   --  Map an item-list index to its 1-based visible-row index, or zero when the
   --  item is hidden by the current filter.
   --
   --  @param Model Model providing the filtered view.
   --  @param Item_Index 1-based item-list index.
   --  @return Visible row index, or 0 when the item is filtered out.
   function Item_To_Visible_Index
     (Model      : Window_Model;
      Item_Index : Positive)
      return Natural;

   --  Whether Item_Index is part of the current multi-selection.
   --
   --  @param Model Model to inspect.
   --  @param Item_Index Item-list index to test.
   --  @return True when the index is selected.
   function Selection_Contains
     (Model      : Window_Model;
      Item_Index : Natural)
      return Boolean;

   --  One flag per loaded item, True when selected. Built in one pass over the
   --  selection, so a loop over the items can test membership in O(1) instead
   --  of rescanning the selection list per item (quadratic after Select All).
   type Selection_Flags is array (Positive range <>) of Boolean with Pack;

   --  @param Model Model to inspect.
   --  @return Selection flags for item indexes 1 .. item count.
   function Selected_Flags
     (Model : Window_Model)
      return Selection_Flags;

   --  Forget the visible-row map: call after any write of the items, their
   --  order, the filter or whether search results are shown.
   --
   --  @param Model Model whose rows changed.
   procedure Invalidate_Visible (Model : in out Window_Model);

   --  Fill the visible-row map if it was invalidated.
   --
   --  @param Model Model to inspect.
   procedure Ensure_Visible_Map (Model : Window_Model);

   --  How many items are visible (the pending create row not counted).
   --
   --  @param Model Model to inspect.
   --  @return The count.
   function Visible_Item_Count (Model : Window_Model) return Natural;

   --  Note a change: Revision and Rows_Revision move.
   --
   --  @param Model Model that changed.
   procedure Touch (Model : in out Window_Model);

   --  Note a change of the selection alone: Revision and Selection_Revision
   --  move, Rows_Revision does not. A mutator that changes anything else a
   --  row shows must Touch.
   --
   --  @param Model Model that changed.
   procedure Touch_Selection (Model : in out Window_Model);

   --  Note a change no row shows and that is not the selection (a folder
   --  size, the Quick Look preview, the type-ahead text): Revision moves.
   --
   --  @param Model Model that changed.
   procedure Touch_Header (Model : in out Window_Model);

   --  Add Item_Index to the multi-selection (no-op when already present).
   --
   --  @param Model Model to update.
   --  @param Item_Index Item-list index to select.
   procedure Add_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural);

   --  Remove Item_Index from the multi-selection (no-op when absent).
   --
   --  @param Model Model to update.
   --  @param Item_Index Item-list index to deselect.
   procedure Remove_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural);

   --  The single primary selected item index, falling back to the first entry
   --  of the multi-selection, or zero when nothing is selected.
   --
   --  @param Model Model to inspect.
   --  @return Effective selected item index, or 0.
   function Effective_Selected_Item_Index (Model : Window_Model) return Natural;

   --  Re-anchor the active rename onto the current selection after the item
   --  list or selection changed (dropping it if its target is gone).
   --
   --  @param Model Model to reconcile in place.
   procedure Reconcile_Rename_With_Selection (Model : in out Window_Model);

   --  Drop any selected indexes that are no longer visible or valid after the
   --  item list or filter changed.
   --
   --  @param Model Model whose selection is reconciled in place.
   procedure Reconcile_Selection (Model : in out Window_Model);

   --  Reorder the stored items to match the model's current sort field and
   --  direction. Keyboard navigation walks the stored item order, so it must be
   --  identical to the displayed order the renderer sorts with -- otherwise a
   --  descending sort makes Up/Down move against the visible order. Selection
   --  and rename targets are index-based, so they are re-established by item
   --  identity (full path) after the reorder.
   --
   --  Under a grouping (Sync_Grouping) the sorted items are then stably
   --  partitioned into bands, matching the drawn order.
   --
   --  @param Model Model whose items are re-sorted in place.
   --  @param Field_Sort False to keep the current order and only regroup it.
   procedure Resort_Items (Model : in out Window_Model; Field_Sort : Boolean := True);

   --  @param Model Model to inspect.
   --  @return True when the items are already in band order (or ungrouped).
   function Items_In_Group_Order (Model : Window_Model) return Boolean;

   --  Cancel every overlay and edit sub-mode (rename, palette, panes, pickers)
   --  before starting a new edit, so only one is ever active at a time.
   --
   --  @param Model Model whose overlay/edit state is cleared.
   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model);

   --  The currently focused text input (path, filter, rename, palette,
   --  settings or ownership field): its text and caret. The palette query
   --  and a settings value are edited whole, so their caret is at the end.
   --  The empty field when none is focused.
   --
   --  @param Model Model providing the focus target.
   --  @return The focused input's text and caret.
   function Focused_Field
     (Model : Window_Model)
      return Text_Field_State;

   --  The value of the currently focused text input (Focused_Field's text),
   --  or "" when none is focused.
   --
   --  @param Model Model providing the focus target.
   --  @return Text of the focused input.
   function Focused_Text_Value
     (Model : Window_Model)
      return String;

   --  Reset the panel component and rebuild its field list from the draft.
   --
   --  @param Model Model whose settings panel is rebuilt.
   procedure Reset_Settings_Panel (Model : in out Window_Model);

   --  Return the 1-based index into Rename_Fields for the field shown at
   --  Visible_Index, or zero when that row has no active rename field.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index 1-based visible row.
   --  @return Rename-field index, or 0 when the row has no rename field.
   function Find_Rename_Field
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural;

   --  Begin an inline create-file/create-folder edit: clear other overlays, add
   --  the temporary row, and open a rename field pre-filled with Name.
   --
   --  @param Model Model to update.
   --  @param Name Initial name for the new item.
   --  @param Is_Directory True to create a folder, False for a file.
   procedure Begin_Create_Temporary
      (Model        : in out Window_Model;
       Name         : String;
       Is_Directory : Boolean);

   --  Opening an overlay ends the grid's current type-to-select session.  Every
   --  caller already advances the model revision, so clear the private buffer
   --  directly rather than adding a second revision for Reset_Type_Ahead.
   --
   --  @param Model Model taking the keyboard for an overlay.
   procedure Claim_Overlay_Input
     (Model : in out Window_Model);

   --  Close the command palette.
   --
   --  @param Model Model to update.
   procedure Close_Command_Palette
     (Model : in out Window_Model);

   --  Close the root selector.
   --
   --  @param Model Model to update.
   procedure Close_Root_Selector
     (Model : in out Window_Model);

   --  Close the color-label swatch picker overlay.
   --
   --  @param Model Model to update.
   procedure Close_Label_Picker
     (Model : in out Window_Model);

   --  Close the bottom-bar sort menu.
   --
   --  @param Model Model to update.
   procedure Close_Sort_Menu
     (Model : in out Window_Model);

   --  Close the right-click context menu.
   --
   --  @param Model Model to update.
   procedure Close_Context_Menu
     (Model : in out Window_Model);

   --  Toggle settings pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Settings_Pane
     (Model : in out Window_Model);

   --  An idle process session, to release a held one by assignment.
   --
   --  @return A session holding no job.
   function Released_Process return Files.Process_Jobs.Session;

   --  Clear the pending grid type-ahead prefix.
   --
   --  @param Model Model to update.
   procedure Reset_Type_Ahead
     (Model : in out Window_Model);

   --  Return the selected visible index.
   --
   --  @param Model Model to inspect.
   --  @return One-based visible selected index, or zero when nothing is selected.
   function Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Return the number of selected items.
   --
   --  @param Model Model to inspect.
   --  @return Selected item count.
   function Selected_Count
     (Model : Window_Model)
      return Natural;

   --  Return the selected item.
   --
   --  @param Model Model to inspect.
   --  @return Selected item, or a default empty item when no selection exists.
   function Selected_Item
     (Model : Window_Model)
      return Files.Items.Directory_Item;

   --  Return the selected items in deterministic loaded-item order.
   --
   --  @param Model Model to inspect.
   --  @param Limit At most this many, the first in that order.
   --  @return Selected directory items, excluding transient create-file items.
   function Selected_Items
     (Model : Window_Model;
      Limit : Natural := Natural'Last)
      return Files.Items.Item_Vectors.Vector;

   --  Restore the loaded, visible items present in a previous selection. Item
   --  paths provide identity across sorting and reloads; Primary_Path restores
   --  the keyboard anchor when that item still exists.
   --
   --  @param Model Model whose selection is replaced.
   --  @param Items Previously selected items to match by full path.
   --  @param Primary_Path Full path of the previous primary item, or empty.
   procedure Restore_Selection
     (Model        : in out Window_Model;
      Items        : Files.Items.Item_Vectors.Vector;
      Primary_Path : String);

   --  Return whether any selected item is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the selection includes the pending create-file item.
   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean;

   --  Forget every cached folder-size measurement.
   --
   --  @param Model Model to update.
   procedure Clear_Folder_Size
     (Model : in out Window_Model);

end Files.Model.Support;

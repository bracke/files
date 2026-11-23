with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Finalization;
with Ada.Strings.Hash;
with Files.Preference_Types;
with Files.Items;
private package Files.Model.Support is

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

   --  Deactivate rename mode and discard every inline rename field; the
   --  keyboard leaves the rename field with them.
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

   --  Whether the loaded item at Item_Index is shown: it passes the current
   --  filter query (a case-insensitive substring of its name, or no query)
   --  or is a search result shown. Read from the visible-row map, so a loop
   --  over the items folds no name and no query.
   --
   --  @param Model Model to inspect.
   --  @param Item_Index Index into the loaded items.
   --  @return True when that item is shown.
   function Item_Visible_At
     (Model      : Window_Model;
      Item_Index : Positive)
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

   --  A path's colour label, by path, for banding by label.
   package Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Files.Preference_Types.Color_Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Files.Preference_Types."=");

   --  The labels the model's grouping bands by: each labelled path's label
   --  when grouping by label, else nothing.
   --
   --  @param Model Model to inspect.
   --  @return The labels by path.
   function Group_Labels_Map (Model : Window_Model) return Label_Maps.Map;

   --  The band Item falls in under the model's grouping (Files.Model's
   --  Resort_Items orders the items by it; Files.Model.Rename asks it of the
   --  pending create row).
   --
   --  @param Model Model whose grouping to apply.
   --  @param Labels Group_Labels_Map (Model), built once per pass.
   --  @param Item The item to place.
   --  @return Its band.
   function Group_Band
     (Model  : Window_Model;
      Labels : Label_Maps.Map;
      Item   : Files.Items.Directory_Item)
      return Positive;

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

   --  The selection index of a visible row: its item-list index, the
   --  Temporary_Item_Index sentinel for the temporary create-item row (the
   --  last visible row while it shows), or zero when the row is beyond the
   --  list.
   --
   --  @param Model Model providing the filtered view.
   --  @param Visible_Index 1-based row index in the visible list.
   --  @return Item-list index, Temporary_Item_Index, or 0.
   function Selection_Index_Of_Visible
     (Model         : Window_Model;
      Visible_Index : Positive)
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
   --  Kept on the heap and freed with the object: a folder's worth of flags
   --  on the stack could overflow a small one (Windows' main stack is about
   --  a megabyte). Read as Flags (Item_Index).
   type Selection_Flags is new Ada.Finalization.Limited_Controlled with private
     with Constant_Indexing => Is_Selected;

   --  @param Flags Flags to read.
   --  @param Item_Index Index into the loaded items.
   --  @return True when that item is selected; False for an index outside
   --    the loaded items (0, the pending create row).
   function Is_Selected (Flags : Selection_Flags; Item_Index : Natural) return Boolean;

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

   --  Note a change: Revision and Rows_Revision move.
   --
   --  @param Model Model that changed.
   procedure Touch (Model : in out Window_Model);

   --  Note a change of a rename field's text or caret alone: Revision and
   --  Rename_Revision move, Rows_Revision does not, so a view patches the
   --  renamed rows instead of building every row again. Starting or ending
   --  a rename (which rows edit) must Touch.
   --
   --  @param Model Model that changed.
   procedure Touch_Rename (Model : in out Window_Model);

   --  Note a change of the selection alone: Revision and Selection_Revision
   --  move, Rows_Revision does not. A mutator that changes anything else a
   --  row shows must Touch.
   --
   --  @param Model Model that changed.
   procedure Touch_Selection (Model : in out Window_Model);

   --  Note a change no row shows and that is not the selection (a folder
   --  size, the Quick Look preview, the type-ahead text, an overlay or pane
   --  and its highlight, a caret outside the rename field, the undo stacks):
   --  Revision moves. In a large folder a Touch rebuilds every row, so use
   --  this whenever the rows stand.
   --
   --  @param Model Model that changed.
   procedure Touch_Header (Model : in out Window_Model);

   --  Note a change the info pane shows that no other revision tracks
   --  (Info_Revision): a Touch_Header that also moves Info_Revision.
   --
   --  @param Model Model that changed.
   procedure Touch_Info (Model : in out Window_Model);

   --  Note a change only an overlay drawn from the model shows -- the
   --  command palette or the settings pane (Overlay_Revision): Revision,
   --  and with it the snapshot, stays.
   --
   --  @param Model Model that changed.
   procedure Touch_Overlay (Model : in out Window_Model);

   --  Note a change of the listing context a background read was asked
   --  under (Listing_Revision): a read started before it is stale. Moves
   --  nothing else; the change that calls it touches what it shows.
   --
   --  @param Model Model that changed.
   procedure Touch_Listing (Model : in out Window_Model);

   --  Note a scroll alone (Scroll_Revision): a view patches the scroll
   --  offsets instead of rebuilding.
   --
   --  @param Model Model that scrolled.
   procedure Touch_Scroll (Model : in out Window_Model);

   --  Note a change to the folder sizes measured: Folder_Sizes_Revision and
   --  Revision move.
   --
   --  @param Model Model that changed.
   procedure Note_Folder_Sizes (Model : in out Window_Model);

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

   --  Re-anchor the active rename onto the current selection after the item
   --  list or selection changed (dropping it if its target is gone).
   --
   --  @param Model Model to reconcile in place.
   procedure Reconcile_Rename_With_Selection (Model : in out Window_Model);

   --  Cancel every overlay and edit sub-mode (rename, palette, panes, pickers)
   --  before starting a new edit, so only one is ever active at a time.
   --
   --  @param Model Model whose overlay/edit state is cleared.
   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model);

   --  Opening an overlay ends the grid's current type-to-select session.  Every
   --  caller already advances the model revision, so clear the private buffer
   --  directly rather than adding a second revision for Reset_Type_Ahead.
   --
   --  @param Model Model taking the keyboard for an overlay.
   procedure Claim_Overlay_Input
     (Model : in out Window_Model);

   --  Hide the command palette and reset it (commands mode, no Open With
   --  targets), leaving focus to the caller: what an overlay or field that
   --  takes the palette's place does.
   --
   --  @param Model Model to update.
   procedure Hide_Command_Palette
     (Model : in out Window_Model);

   --  Close the command palette, handing focus back to what it covered.
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

   --  Close the Quick Look overlay and drop its previewed content.
   --
   --  @param Model Model to update.
   procedure Close_Quick_Look
     (Model : in out Window_Model);

   --  Close the folder-tree sidebar, abandoning any destination pick.
   --
   --  @param Model Model to update.
   procedure Close_Tree_Panel
     (Model : in out Window_Model);

   --  Finish the destination picker: close the folder tree when the picker
   --  opened it, or else leave the tree as the user had it.
   --
   --  @param Model Model to update.
   procedure End_Tree_Pick
     (Model : in out Window_Model);

   --  Close the settings pane, handing back its focus; the next open
   --  (Settings_Pane.Begin_Edit) starts from a fresh draft.
   --
   --  @param Model Model to update.
   procedure Close_Settings_Pane
     (Model : in out Window_Model);

   --  An idle process session, to release a held one by assignment.
   --
   --  @return A session holding no job.
   function Released_Process return Files.Jobs.Process.Session;

   --  End the modal job, whichever it is (Files.Model.Jobs.End_Foreground_Job,
   --  which renames this; Files.Model.Pasting ends one before it starts).
   --
   --  @param Model Window to update.
   procedure End_Foreground_Job (Model : in out Window_Model);

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

   --  Visit the selected items in deterministic loaded-item order, in place.
   --
   --  @param Model Model to inspect.
   --  @param Visit Called once per selected item, excluding transient
   --    create-file items.
   --  @param Limit At most this many, the first in that order.
   procedure For_Each_Selected_Item
     (Model : Window_Model;
      Visit : not null access procedure (Item : Files.Items.Directory_Item);
      Limit : Natural := Natural'Last);

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
   --  @param Paths Full paths of the previously selected items.
   --  @param Primary_Path Full path of the previous primary item, or empty.
   procedure Restore_Selection
     (Model        : in out Window_Model;
      Paths        : Files.Types.String_Vectors.Vector;
      Primary_Path : String);

   --  The selected loaded items' full paths, in item order: what a
   --  selection is restored from (Restore_Selection), without copying the
   --  items themselves.
   --
   --  @param Model Model to inspect.
   --  @return The selected loaded items' full paths.
   function Selected_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

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

   --  Record that the item at From now lives at To (a rename, a move, or Undo
   --  or Redo of one), so the interaction layer can make labels, favorites and
   --  recent entries follow it.
   --
   --  @param Model Model to update.
   --  @param From Old full path.
   --  @param To New full path.
   procedure Note_Path_Move
     (Model : in out Window_Model;
      From  : String;
      To    : String);

   --  Set the info-pane scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New info-pane scroll offset in logical text lines.
   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

private

   type Flag_Array is array (Positive range <>) of Boolean;
   type Flag_Array_Access is access Flag_Array;

   type Selection_Flags is new Ada.Finalization.Limited_Controlled with record
      Flags : Flag_Array_Access;
   end record;

   overriding procedure Finalize (Flags : in out Selection_Flags);

end Files.Model.Support;

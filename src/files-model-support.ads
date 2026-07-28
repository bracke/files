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

   --  Add Left and Right, clamping at Natural'Last instead of overflowing.
   --
   --  @param Left First addend.
   --  @param Right Second addend.
   --  @return Left + Right, or Natural'Last on overflow.
   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural;

   --  The magnitude of a signed scroll delta in lines (its absolute value,
   --  saturating Integer'First).
   --
   --  @param Lines Signed scroll delta.
   --  @return Number of lines to scroll by.
   function Scroll_Step (Lines : Integer) return Natural;

   --  The byte offset of the UTF-8 codepoint boundary immediately before Cursor
   --  (for a left-arrow / delete-backward step over a whole character).
   --
   --  @param Text Text being edited.
   --  @param Cursor Current byte offset of the caret.
   --  @return Byte offset of the previous codepoint boundary.
   function Previous_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  The byte offset of the UTF-8 codepoint boundary immediately after Cursor
   --  (for a right-arrow / delete-forward step over a whole character).
   --
   --  @param Text Text being edited.
   --  @param Cursor Current byte offset of the caret.
   --  @return Byte offset of the next codepoint boundary.
   function Next_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  The nearest UTF-8 codepoint boundary at or before Cursor, used to snap a
   --  clamped offset onto a valid character start.
   --
   --  @param Text Text being edited.
   --  @param Cursor Byte offset to snap.
   --  @return Byte offset of the boundary at or before Cursor.
   function Text_Boundary_At_Or_Before
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  Insert Text into Old at the byte offset Cursor (clamped into range).
   --
   --  @param Old Existing text.
   --  @param Cursor Byte offset to insert at.
   --  @param Text Text to insert.
   --  @return Old with Text spliced in at Cursor.
   function Insert_Text_At
     (Old    : String;
      Cursor : Natural;
      Text   : String)
      return String;

   --  Return the byte offset before a name's extension: the position of the
   --  last non-leading dot, or the name length when there is no extension.
   --
   --  @param Name File name.
   --  @return Byte offset before the extension (name-relative).
   function Caret_Before_Extension
     (Name : String)
      return Natural;

   --  Deactivate rename mode and discard every inline rename field.
   --
   --  @param Model Model whose rename state is reset.
   procedure Reset_Rename_State
     (Model : in out Window_Model);

   --  Return the first rename field's text, or an empty string when inactive.
   --
   --  @param Model Model to inspect.
   --  @return The active rename text, or "" when no rename is active.
   function First_Rename_Value
     (Model : Window_Model)
      return String;

   --  Return the first rename field's caret, or zero when inactive.
   --
   --  @param Model Model to inspect.
   --  @return The active rename caret offset, or 0 when inactive.
   function First_Rename_Cursor
     (Model : Window_Model)
      return Natural;

   --  Return whether the active rename is the temporary create-item field.
   --
   --  @param Model Model to inspect.
   --  @return True when a rename is active on the temporary create row.
   function Is_Temporary_Rename
     (Model : Window_Model)
      return Boolean;

   --  Update the temporary-item name buffer to track its rename field's value.
   --
   --  @param Model Model to update.
   --  @param Field The temporary item's rename field.
   procedure Sync_Temporary_From_Field
     (Model : in out Window_Model;
      Field : Rename_Field);

   --  Close the drive/root selector and forget its selection.
   --
   --  @param Model Model whose root-selector state is cleared.
   procedure Clear_Root_Selector_State
     (Model : in out Window_Model);

   --  The number of complete key/value pairs across two parallel lists (the
   --  shorter of the two lengths).
   --
   --  @param Keys Key list.
   --  @param Values Value list.
   --  @return Min of the two list lengths.
   function Pair_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural;

   --  Truncate Values to at most Count entries.
   --
   --  @param Values List to truncate in place.
   --  @param Count Maximum number of entries to keep.
   procedure Trim_To_Count
     (Values : in out Files.Types.String_Vectors.Vector;
      Count  : Natural);

   --  Bring a settings draft into a consistent state: pair up its parallel
   --  key/value mapping lists to equal length and clamp each selection index.
   --
   --  @param Draft Settings draft to normalize in place.
   procedure Normalize_Settings_Draft
     (Draft : in out Files.Settings.Settings_Draft);

   --  Whether Item passes the current filter query (case-insensitive substring
   --  of its name); True when the filter is empty.
   --
   --  @param Model Model providing the filter query.
   --  @param Item Directory item to test.
   --  @return True when Item is shown under the current filter.
   function Item_Is_Visible
     (Model : Window_Model;
      Item  : Files.File_System.Directory_Item)
      return Boolean;

   --  Whether the temporary create-item row is shown under the current filter.
   --
   --  @param Model Model to inspect.
   --  @return True when the temporary row passes the filter.
   function Temporary_Is_Visible (Model : Window_Model) return Boolean;

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

   --  Mark the settings draft as edited so a save is offered.
   --
   --  @param Model Model whose draft is flagged dirty.
   procedure Mark_Settings_Draft_Edited (Model : in out Window_Model);

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

   --  Build the directory polling signature (used to detect background changes)
   --  from a directory path and its loaded items.
   --
   --  @param Directory_Path Path the items were loaded from.
   --  @param Items Loaded directory items.
   --  @return Signature capturing the directory's current state.
   function Signature_From_Items
     (Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector)
      return Files.File_System.Directory_Signature;

   --  Map the model's sort field onto the persisted settings sort-field enum.
   --
   --  @param Field Model sort field.
   --  @return Equivalent Files.Settings sort field.
   function Settings_Sort_Field (Field : Sort_Field) return Files.Settings.Sort_Field;

   --  Reorder the stored items to match the model's current sort field and
   --  direction. Keyboard navigation walks the stored item order, so it must be
   --  identical to the displayed order the renderer sorts with -- otherwise a
   --  descending sort makes Up/Down move against the visible order. Selection
   --  and rename targets are index-based, so they are re-established by item
   --  identity (full path) after the reorder.
   --
   --  @param Model Model whose items are re-sorted in place.
   procedure Resort_Items (Model : in out Window_Model);

   --  Single-select a visible item without disturbing the type-ahead prefix.
   --  Type-ahead selection uses this so its own selection jumps do not clear the
   --  prefix it is accumulating; every other selection path goes through the
   --  public Select_Visible, which resets the prefix first.
   --
   --  @param Model Model to update.
   --  @param Visible_Index 1-based visible row to select.
   procedure Select_Visible_Internal
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Cancel every overlay and edit sub-mode (rename, palette, panes, pickers)
   --  before starting a new edit, so only one is ever active at a time.
   --
   --  @param Model Model whose overlay/edit state is cleared.
   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model);

   --  A run is only fed to type-ahead when every byte is a printable glyph.
   --  Control bytes below the space and the DEL byte never start a prefix.
   --
   --  @param Text Candidate input run.
   --  @return True when every byte is printable.
   function Is_Printable_Run (Text : String) return Boolean;

   --  Return True when Text is a single UTF-8 codepoint repeated one or more
   --  times (case-insensitively), e.g. "d", "DD", "www". Used to detect the
   --  repeated-letter cycling gesture.
   --
   --  @param Text Candidate input run.
   --  @return True when Text is one repeated codepoint.
   function Is_Repeated_Single_Codepoint (Text : String) return Boolean;

   --  Return the first UTF-8 codepoint of Text as a byte string.
   --
   --  @param Text Source text.
   --  @return The leading codepoint's bytes, or "" when Text is empty.
   function First_Codepoint (Text : String) return String;

   --  The byte length of the currently focused text input's value (path, filter,
   --  rename, palette, settings or ownership field), or zero when none is focused.
   --
   --  @param Model Model providing the focus target.
   --  @return Byte length of the focused input's text.
   function Focused_Text_Length
     (Model : Window_Model)
      return Natural;

   --  The value of the currently focused text input (path, filter, rename,
   --  palette, settings or ownership field), or "" when none is focused.
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

   --  The presentation config for the command palette (overlay with shortcuts,
   --  the component owns the filtering).
   --
   --  @param Line_Height Row height in pixels.
   --  @param Mode Which palette (commands or the alternate mode) to configure.
   --  @return Command-palette component configuration.
   function Palette_Config
     (Line_Height : Positive;
      Mode        : Palette_Mode) return Guikit.Command_Palette.Configuration;

   --  Return the loaded-item indexes of the current real (non-temporary)
   --  selection, in loaded order, for populating rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Loaded-item indexes of the real selection.
   function Selected_Loaded_Indexes
     (Model : Window_Model)
      return Natural_Vectors.Vector;

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

end Files.Model.Support;

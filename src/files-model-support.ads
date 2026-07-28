private package Files.Model.Support is

   --  Sentinel item index marking the temporary create-item row.
   Temporary_Item_Index : constant Natural := Natural'Last;

   --  Clear the Quick Look overlay state. Declared early so the navigation and
   --  selection resets below can close a stale preview when the previewed item
   --  is no longer the single, current selection.
   --
   --  @param Model model.
   procedure Reset_Quick_Look
     (Model : in out Window_Model);

   --  Internal helper: saturating add.
   --
   --  @param Left left.
   --  @param Right right.
   --  @return Result of saturating add.
   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural;

   --  Internal helper: scroll step.
   --
   --  @param Lines lines.
   --  @return Result of scroll step.
   function Scroll_Step (Lines : Integer) return Natural;

   --  Internal helper: previous text boundary.
   --
   --  @param Text text.
   --  @param Cursor cursor.
   --  @return Result of previous text boundary.
   function Previous_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  Internal helper: next text boundary.
   --
   --  @param Text text.
   --  @param Cursor cursor.
   --  @return Result of next text boundary.
   function Next_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  Internal helper: text boundary at or before.
   --
   --  @param Text text.
   --  @param Cursor cursor.
   --  @return Result of text boundary at or before.
   function Text_Boundary_At_Or_Before
     (Text   : String;
      Cursor : Natural)
      return Natural;

   --  Remove the byte range [First, Last) from Text (offsets are clamped).
   --  Insert Text into Old at the byte offset Cursor.
   --
   --  @param Old old.
   --  @param Cursor cursor.
   --  @param Text text.
   --  @return Result of insert text at.
   function Insert_Text_At
     (Old    : String;
      Cursor : Natural;
      Text   : String)
      return String;

   --  Return the byte offset before a name's extension: the position of the
   --  last non-leading dot, or the name length when there is no extension.
   --
   --  @param Name name.
   --  @return Result of caret before extension.
   function Caret_Before_Extension
     (Name : String)
      return Natural;

   --  Deactivate rename mode and discard every inline rename field.
   --
   --  @param Model model.
   procedure Reset_Rename_State
     (Model : in out Window_Model);

   --  Return the first rename field's text, or an empty string when inactive.
   --
   --  @param Model model.
   --  @return Result of first rename value.
   function First_Rename_Value
     (Model : Window_Model)
      return String;

   --  Return the first rename field's caret, or zero when inactive.
   --
   --  @param Model model.
   --  @return Result of first rename cursor.
   function First_Rename_Cursor
     (Model : Window_Model)
      return Natural;

   --  Return whether the active rename is the temporary create-item field.
   --
   --  @param Model model.
   --  @return Result of is temporary rename.
   function Is_Temporary_Rename
     (Model : Window_Model)
      return Boolean;

   --  Update the temporary-item name buffer to track its rename field's value.
   --
   --  @param Model model.
   --  @param Field field.
   procedure Sync_Temporary_From_Field
     (Model : in out Window_Model;
      Field : Rename_Field);

   --  Internal helper: clear root selector state.
   --
   --  @param Model model.
   procedure Clear_Root_Selector_State
     (Model : in out Window_Model);

   --  Internal helper: pair count.
   --
   --  @param Keys keys.
   --  @param Values values.
   --  @return Result of pair count.
   function Pair_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural;

   --  Internal helper: trim to count.
   --
   --  @param Values values.
   --  @param Count count.
   procedure Trim_To_Count
     (Values : in out Files.Types.String_Vectors.Vector;
      Count  : Natural);

   --  Internal helper: normalize settings draft.
   --
   --  @param Draft draft.
   procedure Normalize_Settings_Draft
     (Draft : in out Files.Settings.Settings_Draft);

   --  Internal helper: item is visible.
   --
   --  @param Model model.
   --  @param Item item.
   --  @return Result of item is visible.
   function Item_Is_Visible
     (Model : Window_Model;
      Item  : Files.File_System.Directory_Item)
      return Boolean;

   --  Internal helper: temporary is visible.
   --
   --  @param Model model.
   --  @return Result of temporary is visible.
   function Temporary_Is_Visible (Model : Window_Model) return Boolean;

   --  Internal helper: visible to item index.
   --
   --  @param Model model.
   --  @param Visible_Index visible index.
   --  @return Result of visible to item index.
   function Visible_To_Item_Index
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural;

   --  Internal helper: item to visible index.
   --
   --  @param Model model.
   --  @param Item_Index item index.
   --  @return Result of item to visible index.
   function Item_To_Visible_Index
     (Model      : Window_Model;
      Item_Index : Positive)
      return Natural;

   --  Internal helper: selection contains.
   --
   --  @param Model model.
   --  @param Item_Index item index.
   --  @return Result of selection contains.
   function Selection_Contains
     (Model      : Window_Model;
      Item_Index : Natural)
      return Boolean;

   --  Internal helper: add selected index.
   --
   --  @param Model model.
   --  @param Item_Index item index.
   procedure Add_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural);

   --  Internal helper: remove selected index.
   --
   --  @param Model model.
   --  @param Item_Index item index.
   procedure Remove_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural);

   --  Internal helper: mark settings draft edited.
   --
   --  @param Model model.
   procedure Mark_Settings_Draft_Edited (Model : in out Window_Model);

   --  Internal helper: effective selected item index.
   --
   --  @param Model model.
   --  @return Result of effective selected item index.
   function Effective_Selected_Item_Index (Model : Window_Model) return Natural;

   --  Internal helper: reconcile rename with selection.
   --
   --  @param Model model.
   procedure Reconcile_Rename_With_Selection (Model : in out Window_Model);

   --  Internal helper: reconcile selection.
   --
   --  @param Model model.
   procedure Reconcile_Selection (Model : in out Window_Model);

   --  Internal helper: signature from items.
   --
   --  @param Directory_Path directory path.
   --  @param Items items.
   --  @return Result of signature from items.
   function Signature_From_Items
     (Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector)
      return Files.File_System.Directory_Signature;

   --  Internal helper: settings sort field.
   --
   --  @param Field field.
   --  @return Result of settings sort field.
   function Settings_Sort_Field (Field : Sort_Field) return Files.Settings.Sort_Field;

   --  Reorder the stored items to match the model's current sort field and
   --  direction. Keyboard navigation walks the stored item order, so it must be
   --  identical to the displayed order the renderer sorts with -- otherwise a
   --  descending sort makes Up/Down move against the visible order. Selection
   --  and rename targets are index-based, so they are re-established by item
   --  identity (full path) after the reorder.
   --
   --  @param Model model.
   procedure Resort_Items (Model : in out Window_Model);

   --  Single-select a visible item without disturbing the type-ahead prefix.
   --  Type-ahead selection uses this so its own selection jumps do not clear the
   --  prefix it is accumulating; every other selection path goes through the
   --  public Select_Visible, which resets the prefix first.
   --
   --  @param Model model.
   --  @param Visible_Index visible index.
   procedure Select_Visible_Internal
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Internal helper: clear overlay state for edit.
   --
   --  @param Model model.
   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model);

   --  A run is only fed to type-ahead when every byte is a printable glyph.
   --  Control bytes below the space and the DEL byte never start a prefix.
   --
   --  @param Text text.
   --  @return Result of is printable run.
   function Is_Printable_Run (Text : String) return Boolean;

   --  Return True when Text is a single UTF-8 codepoint repeated one or more
   --  times (case-insensitively), e.g. "d", "DD", "www". Used to detect the
   --  repeated-letter cycling gesture.
   --
   --  @param Text text.
   --  @return Result of is repeated single codepoint.
   function Is_Repeated_Single_Codepoint (Text : String) return Boolean;

   --  Return the first UTF-8 codepoint of Text as a byte string.
   --
   --  @param Text text.
   --  @return Result of first codepoint.
   function First_Codepoint (Text : String) return String;

   --  Internal helper: focused text length.
   --
   --  @param Model model.
   --  @return Result of focused text length.
   function Focused_Text_Length
     (Model : Window_Model)
      return Natural;

   --  Internal helper: focused text value.
   --
   --  @param Model model.
   --  @return Result of focused text value.
   function Focused_Text_Value
     (Model : Window_Model)
      return String;

   --  Reset the panel component and rebuild its field list from the draft.
   --
   --  @param Model model.
   procedure Reset_Settings_Panel (Model : in out Window_Model);

   --  The presentation config for the command palette (overlay with shortcuts,
   --  the component owns the filtering).
   --
   --  @param Line_Height line height.
   --  @param Mode mode.
   --  @return Result of palette config.
   function Palette_Config
     (Line_Height : Positive;
      Mode        : Palette_Mode) return Guikit.Command_Palette.Configuration;

   --  Return the loaded-item indexes of the current real (non-temporary)
   --  selection, in loaded order, for populating rename fields.
   --
   --  @param Model model.
   --  @return Result of selected loaded indexes.
   function Selected_Loaded_Indexes
     (Model : Window_Model)
      return Natural_Vectors.Vector;

   --  Return the 1-based index into Rename_Fields for the field shown at
   --  Visible_Index, or zero when that row has no active rename field.
   --
   --  @param Model model.
   --  @param Visible_Index visible index.
   --  @return Result of find rename field.
   function Find_Rename_Field
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural;

   --  Internal helper: begin create temporary.
   --
   --  @param Model model.
   --  @param Name name.
   --  @param Is_Directory is directory.
   procedure Begin_Create_Temporary
      (Model        : in out Window_Model;
       Name         : String;
       Is_Directory : Boolean);

end Files.Model.Support;

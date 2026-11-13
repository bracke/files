with Files.Extra_Info;
with Files.Items;
with Ada.Calendar;
with Files.Copy_Context;
with Files.Desktop_Applications;
with Files.Process_Jobs;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Folder_Tree;
with Files.Folder_Size;
with Files.Paste;
with Files.Quick_Look;
with Files.Settings;
with Guikit.Command_Palette;
with Guikit.Input;
with Guikit.Settings_Panel;
with Files.Types;
with Files.Transfer_Jobs;

--  Directory state, selection, filtering, history, input state, and pane state.
package Files.Model is
   subtype UString is Files.Types.UString;

   type Window_Model is private;

   --  Initialize a window model for a loaded directory.
   --
   --  @param Model Model to initialize.
   --  @param Directory_Path Current directory path.
   --  @param Items Loaded directory items.
   --  @param Home_Path Current user's home directory path.
   --  @param Default_View_Mode Initial view mode.
   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.Items.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons);

   --  Return the model's change revision -- a counter bumped by every mutator.
   --  The render layer compares this against the revision it last built a
   --  snapshot at to decide whether the cached snapshot is still current.
   --
   --  @param Model Model to inspect.
   --  @return Current change revision.
   function Revision
     (Model : Window_Model)
      return Natural;

   --  Return the window's settings revision: a counter bumped by every change
   --  to the window's live settings (Note_Settings_Changed), so the window
   --  layer can tell a window changed its settings without comparing them.
   --
   --  @param Model Model to inspect.
   --  @return Current settings revision.
   function Settings_Revision
     (Model : Window_Model)
      return Natural;

   --  Record that the window's live settings changed. Every path that writes
   --  a window's settings calls it: the settings commit, and the in-memory
   --  changes (a column resize drag) that are persisted later.
   --
   --  @param Model Window whose settings changed.
   procedure Note_Settings_Changed
     (Model : in out Window_Model);

   --  Like Revision, but not moved by a change of the selection alone: the
   --  rows a view shows (names, metadata, rename fields, cut marks, order)
   --  are as they were while it holds, though which are selected may not be.
   --
   --  @param Model Model to inspect.
   --  @return The rows revision.
   function Rows_Revision
     (Model : Window_Model)
      return Natural;

   --  Moved by every change of the selection and by nothing else: with
   --  Rows_Revision, what the selected items are.
   --
   --  @param Model Model to inspect.
   --  @return The selection revision.
   function Selection_Revision
     (Model : Window_Model)
      return Natural;

   --  Moves when only a scroll offset changed (the main view, the info pane,
   --  the folder tree), which Revision does not: the snapshot's items stand,
   --  and a view refreshing its snapshot copies it with the new offsets
   --  rather than rebuilding it.
   --
   --  @param Model Model to inspect.
   --  @return The scroll revision.
   function Scroll_Revision (Model : Window_Model) return Natural;

   --  Return the generation of model state that a background listing depends
   --  on. Unlike Revision, ordinary interaction such as selection,
   --  scrolling, focus, and overlay changes does not advance this value.
   --
   --  @param Model Model to inspect.
   --  @return Current listing-context generation.
   function Listing_Revision
     (Model : Window_Model)
      return Natural;

   --  Return the generation of the displayed directory view. It advances only
   --  when the window navigates (even back to the same path), never on edits
   --  within a view, so a background result can tell "the view it started
   --  from is still on screen" apart from "nothing listing-visible changed".
   --
   --  @param Model Model to inspect.
   --  @return Current view incarnation.
   function View_Incarnation
     (Model : Window_Model)
      return Natural;

   --  Remember that a reload of the current view is still owed: a background
   --  read was discarded because the listing context moved while it ran, so
   --  its answer could not be applied. A later owed request merges with an
   --  earlier one (Force wins; a nonempty selection replaces the old one).
   --
   --  @param Model Model to update.
   --  @param Force Whether the discarded read was a forced reload.
   --  @param Select_Name Item name the discarded read was asked to select.
   procedure Note_Owed_Refresh
     (Model       : in out Window_Model;
      Force       : Boolean;
      Select_Name : String);

   --  Return whether a reload is owed for the view that is on screen now.
   --  Navigation makes an earlier debt moot, since it loads the new view.
   --
   --  @param Model Model to inspect.
   --  @return True while an owed reload is pending for this incarnation.
   function Refresh_Is_Owed
     (Model : Window_Model)
      return Boolean;

   --  @param Model Model to inspect.
   --  @return Whether the owed reload must be forced.
   function Owed_Refresh_Force
     (Model : Window_Model)
      return Boolean;

   --  @param Model Model to inspect.
   --  @return Item name the owed reload should select, or "".
   function Owed_Refresh_Selection
     (Model : Window_Model)
      return String;

   --  Settle any owed reload, typically because a new read was launched.
   --
   --  @param Model Model to update.
   procedure Clear_Owed_Refresh
     (Model : in out Window_Model);

   --  Return whether a transient surface currently owns window input.  Native
   --  callback paths and shell-owned continuous gestures use this common policy
   --  because they do not pass through the ordinary click/key translators.
   --
   --  @param Model Model to inspect.
   --  @return True while any menu, picker, preview, pane, palette, or paste
   --    overlay is open.
   function Input_Owning_Overlay_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  The transient surfaces that own window input while open. A new overlay
   --  is added here and to Overlay_Is_Open; every model query reads this
   --  list. The snapshot carries one flag per overlay, so the renderer's
   --  Files.Rendering.Any_Overlay_Open lists them again: its test walks this
   --  type and fails until a new overlay is listed there too.
   type Input_Overlay is
     (Settings_Pane_Overlay,
      Command_Palette_Overlay,
      Root_Selector_Overlay,
      Sort_Menu_Overlay,
      Context_Menu_Overlay,
      Label_Picker_Overlay,
      Quick_Look_Overlay,
      Tree_Pick_Overlay,
      Paste_Conflict_Overlay,
      Paste_Execution_Overlay);

   --  The overlays with their own text-entry surface.
   subtype Text_Input_Overlay is Input_Overlay range Settings_Pane_Overlay .. Command_Palette_Overlay;

   --  The overlays Escape (the close command) closes; the others have their
   --  own way out.
   subtype Escape_Closable_Overlay is Input_Overlay range Settings_Pane_Overlay .. Label_Picker_Overlay;

   --  The open overlay on top: the one whose own controls alone still act,
   --  and the one drawn on top (a paste in progress first, then the command
   --  palette, the settings pane, the context menu, the root selector, the
   --  sort menu, the label picker, Quick Look, a tree pick). Escape and the
   --  window's drawing follow the same order.
   --
   --  @param Model Model to inspect.
   --  @param Overlay Set to the top-most open overlay when one is open.
   --  @return True when any input-owning overlay is open.
   function Topmost_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean;

   --  Whether the window layer draws Overlay (the command palette or the
   --  settings pane, which it merges over the frame): it is open and nothing
   --  is above it in Topmost_Overlay's order. A paste dialog, drawn in the
   --  frame, is above both; the palette is above the pane.
   --
   --  @param Model Model to inspect.
   --  @param Overlay The palette or the pane.
   --  @return True when Overlay is to be drawn.
   function Window_Overlay_Shown (Model : Window_Model; Overlay : Text_Input_Overlay) return Boolean;

   --  The overlay Escape (the close command) closes: the top-most one
   --  (Topmost_Overlay), when it is one Escape closes -- the label picker,
   --  the context menu, the command palette, the root selector, the sort
   --  menu or the settings pane. The others have their own way out, and an
   --  overlay below one of them is not closed past it.
   --
   --  @param Model Model to inspect.
   --  @param Overlay Set to that overlay when one is open.
   --  @return True when an overlay Escape closes is open.
   function Escape_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean;

   --  Close one overlay, as Escape closes it.
   --
   --  @param Model Model to update.
   --  @param Overlay The overlay to close.
   procedure Close_Overlay (Model : in out Window_Model; Overlay : Escape_Closable_Overlay);

   --  Return whether an input-owning overlay other than Except is open: what
   --  an overlay's own click handler asks so it ignores clicks while another
   --  overlay is on top of it.
   --
   --  @param Model Model to inspect.
   --  @param Except The overlay that does not count.
   --  @return True while any other input-owning overlay is open.
   function Other_Input_Owning_Overlay_Is_Open
     (Model  : Window_Model;
      Except : Input_Overlay)
      return Boolean;

   --  Return whether an overlay without a text-entry surface owns input, so
   --  native character input and auto-targeted scrolling must be contained.
   --  The root selector does not count while the command palette is open
   --  over it: the palette's query field then owns the keyboard.
   --
   --  @param Model Model to inspect.
   --  @return True while a non-text input-owning overlay owns input.
   function Non_Text_Overlay_Owns_Input
     (Model : Window_Model)
      return Boolean;

   --  Whether the current directory is the trash's files directory, settled
   --  when the directory was entered (no disk access here). It is False after
   --  every directory change until Set_Current_Is_Trash settles it; see
   --  Files.Operations.Settle_Current_Is_Trash.
   --
   --  @param Model Model to inspect.
   --  @return True when the current directory is the trash.
   function Current_Is_Trash
     (Model : Window_Model)
      return Boolean;

   --  Record whether the current directory is the trash's files directory,
   --  as checked against the disk by the caller.
   --
   --  @param Model Model to update.
   --  @param Is_Trash True when the current directory is the trash.
   procedure Set_Current_Is_Trash
     (Model    : in out Window_Model;
      Is_Trash : Boolean);

   --  Return the model current path.
   --
   --  @param Model Model to inspect.
   --  @return Current directory path.
   function Current_Path
     (Model : Window_Model)
      return String;

   --  Return the last stored directory polling signature.
   --
   --  @param Model Model to inspect.
   --  @return Stored directory signature for the current path.
   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature;

   --  Replace the stored directory polling signature.
   --
   --  @param Model Model to update.
   --  @param Signature Signature captured after loading or polling a directory.
   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature);

   --  Return the model home path.
   --
   --  @param Model Model to inspect.
   --  @return Home directory path.
   function Home_Path
     (Model : Window_Model)
      return String;

   --  Return the active view mode.
   --
   --  @param Model Model to inspect.
   --  @return Active view mode.
   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode;

   --  Set the active view mode.
   --
   --  @param Model Model to update.
   --  @param Mode New view mode.
   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode);

   --  Return the active item sort field.
   --
   --  @param Model Model to inspect.
   --  @return Active sort field.
   function Sort_Field_Of
     (Model : Window_Model)
      return Files.Types.Sort_Field;

   --  Return whether item sorting is ascending.
   --
   --  @param Model Model to inspect.
   --  @return True when sorting ascends by the active field.
   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean;

   --  Select or toggle the active item sort field.
   --
   --  Selecting the current field toggles sort direction. Selecting a different
   --  field makes that field ascending.
   --
   --  @param Model Model to update.
   --  @param Field Sort field to select.
   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Files.Types.Sort_Field);

   --  Set the sort field and direction to absolute values and re-sort. Unlike
   --  Select_Sort_Field (which toggles direction when re-selecting the current
   --  field), this applies a known target state, for use when applying saved or
   --  persisted settings.
   --
   --  @param Model Model to update.
   --  @param Field Sort field to sort by.
   --  @param Ascending True to sort ascending, False for descending.
   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean);

   --  Keep the items in the Details view's group order (Settings.Group_By;
   --  no grouping in other views): by band, then by the sort within a band.
   --  Keyboard and range selection walk the stored order, so grouping only
   --  in the renderer drew rows in an order Up/Down did not follow. Call it
   --  before handling input or rendering a window; it returns at once when
   --  neither the model nor the grouping inputs changed since the last call.
   --
   --  @param Model Model whose items are regrouped in place.
   --  @param Settings Settings supplying the grouping mode and color labels.
   procedure Sync_Grouping
     (Model    : in out Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  The day Sync_Grouping last banded the items by (the start of today
   --  then), so band headers drawn later agree with the order across
   --  midnight; Unknown_Time before the first sync.
   --
   --  @param Model Model to query.
   --  @return The start of the day the bands are relative to.
   function Grouping_Day (Model : Window_Model) return Ada.Calendar.Time;

   --  A copy of Model in group order, for a one-off render of a model that is
   --  not updated in place.
   --
   --  @param Model Model to copy.
   --  @param Settings Settings supplying the grouping mode and color labels.
   --  @return Model after Sync_Grouping.
   function Grouped
     (Model    : Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Window_Model;

   --  Return the number of loaded directory items.
   --
   --  @param Model Model to inspect.
   --  @return Loaded item count.
   function Item_Count
     (Model : Window_Model)
      return Natural;

   --  Return the number of visible items after filtering.
   --
   --  @param Model Model to inspect.
   --  @return Visible item count.
   function Visible_Count
     (Model : Window_Model)
      return Natural;

   --  Return the number of loaded hidden items.
   --
   --  Hidden items are loaded directory items whose simple name begins with a
   --  dot. This lets the bottom bar report how many dot-files are present.
   --
   --  @param Model Model to inspect.
   --  @return Count of loaded items whose simple name begins with '.'.
   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural;

   --  Return a visible item by one-based visible index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return Directory item at Visible_Index.
   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.Items.Directory_Item;

   --  Find a visible item by its full path in one pass over the rows.
   --
   --  @param Model Model to inspect.
   --  @param Full_Path Full path of the item to find.
   --  @return Its one-based visible index, or zero when it is not visible.
   function Visible_Index_Of
     (Model     : Window_Model;
      Full_Path : String)
      return Natural;

   --  One visible row: the directory item plus whether it is selected.
   type Visible_Row is record
      Item       : Files.Items.Directory_Item;
      Selected   : Boolean := False;
      --  Index into the loaded items, or zero for the pending create row.
      --  Lets a caller walking the rows skip a per-row visible-to-item scan.
      Item_Index : Natural := 0;
   end record;

   package Visible_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Visible_Row);

   --  Return every visible row in display order in a single pass.
   --
   --  Equivalent to reading Visible_Item and Is_Selected over
   --  1 .. Visible_Count, but resolves the visible sequence and selection
   --  membership once (O(N)) instead of rescanning the item list per row.
   --  The sequence is the filtered items in order followed by the temporary
   --  placeholder item when one is active.
   --
   --  @param Model Model to inspect.
   --  @return Visible items in display order, each flagged selected or not.
   function Visible_Rows
     (Model : Window_Model)
      return Visible_Row_Vectors.Vector;

   --  Visit every visible row in display order, as Visible_Rows lists them,
   --  without copying the items: Item is the model's own, for the duration
   --  of the call. For a caller that reads each row once (the snapshot,
   --  type-ahead), where the copy cost more than the work.
   --
   --  @param Model Model to inspect.
   --  @param Visit Called once per row with the three below.
   --  @param Item The row's item, the model's own.
   --  @param Item_Index Its index into the loaded items; zero for the
   --    pending create row.
   --  @param Selected Whether it is selected.
   procedure For_Each_Visible_Row
     (Model : Window_Model;
      Visit : not null access procedure
        (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean));

   --  The fixed end a shift-extended selection grows from: the item last
   --  selected by a plain click, a Ctrl click or a cursor move
   --  (Select_Visible, Toggle_Visible_Selection), which a range
   --  (Select_Visible_Range) keeps. Successive shift-clicks or shift-arrows
   --  so grow the range from where it began, not from the moving cursor; a
   --  Ctrl click starts the next range at the item it clicked. When that item
   --  is no longer shown, the cursor itself.
   --
   --  @param Model Model to inspect.
   --  @return Anchor visible index, or zero when nothing is selected.
   function Range_Anchor
     (Model : Window_Model)
      return Natural;

   --  Whether Move_Selection in Direction would wrap past an edge of the
   --  listing (to the other end, or to the next column). Extending a range
   --  stops at the edge instead.
   --
   --  @param Model Model to inspect.
   --  @param Direction Arrow-key direction.
   --  @return True when the move would wrap.
   function Selection_Move_Would_Wrap
     (Model     : Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean;

   --  Set filter text and reconcile selection.
   --
   --  @param Model Model to update.
   --  @param Text New filter text.
   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String);

   --  Return the current filter text.
   --
   --  @param Model Model to inspect.
   --  @return Filter text.
   function Filter_Text
     (Model : Window_Model)
      return String;

   --  Clear the current filter text. Resets the search scope to Filter_Here and
   --  drops any recorded search-results state.
   --
   --  @param Model Model to update.
   procedure Clear_Filter
     (Model : in out Window_Model);

   --  Return the active scope of the shared filter-bar query.
   --
   --  @param Model Model to inspect.
   --  @return Current search scope.
   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope;

   --  Set the active scope of the shared filter-bar query. Does not itself run a
   --  search; callers run the matching operation and record results separately.
   --
   --  @param Model Model to update.
   --  @param Scope New search scope.
   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope);

   --  Return whether the current view holds recursive search results rather than
   --  a plain directory listing.
   --
   --  @param Model Model to inspect.
   --  @return True when search results are shown.
   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean;

   --  Record that the current view now holds recursive search results for the
   --  given scope. Used by the name and content search operations.
   --
   --  @param Model Model to update.
   --  @param Scope Scope that produced the results.
   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope);

   --  Drop any recorded search-results state and reset the scope to Filter_Here,
   --  leaving the loaded items untouched so the caller can restore the directory.
   --
   --  @param Model Model to update.
   procedure Clear_Search_Results
     (Model : in out Window_Model);

   --  Select a visible item by one-based visible index; it becomes the
   --  Range_Anchor a later shift-extended range grows from.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Visible indexes, in the order they are taken. On the heap: a marquee
   --  over a large folder names thousands, too many for a stack array.
   package Visible_Index_Lists is new Ada.Containers.Vectors (Positive, Positive);
   subtype Visible_Index_List is Visible_Index_Lists.Vector;

   --  Select exactly Indexes (out of range ones are skipped, repeats count
   --  once), the last one primary: what Clear_Selection and a
   --  Toggle_Visible_Selection per index do, in one pass over the items
   --  rather than one per index (a marquee drag does this on every move).
   --
   --  @param Model Model to update.
   --  @param Indexes One-based visible indexes to select.
   procedure Select_Visible_Set
     (Model   : in out Window_Model;
      Indexes : Visible_Index_List);

   --  Toggle a visible item in the deterministic multi-selection set; it
   --  becomes the Range_Anchor, selected or not, as in other file managers.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Select a deterministic inclusive visible range. The range keeps its
   --  anchor: Range_Anchor stays at Anchor_Index (normally Range_Anchor
   --  already), however the cursor moved to Target_Index.
   --
   --  @param Model Model to update.
   --  @param Anchor_Index One-based range anchor in the visible projection.
   --  @param Target_Index One-based range target in the visible projection.
   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive);

   --  Select all currently visible loaded directory items.
   --
   --  Temporary create-file items are excluded because they do not exist on
   --  disk until committed.
   --
   --  @param Model Model to update.
   procedure Select_All_Visible
     (Model : in out Window_Model);

   --  Clear the deterministic multi-selection set and primary selection.
   --
   --  @param Model Model to update.
   procedure Clear_Selection
     (Model : in out Window_Model);

   --  Invert the selection across the currently visible loaded items.
   --
   --  Every visible directory item that is currently selected becomes
   --  unselected and every visible unselected item becomes selected. The
   --  current directory and view stay intact. Temporary create-file items are
   --  excluded because they do not exist on disk until committed.
   --
   --  @param Model Model to update.
   procedure Invert_Selection
     (Model : in out Window_Model);

   --  Clear the entire selection (deselect all visible items).
   --
   --  @param Model Model to update.
   procedure Deselect_All
     (Model : in out Window_Model);

   --  Move selection in the visible projection with wraparound.
   --
   --  @param Model Model to update.
   --  @param Direction Direction requested by user input.
   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction);

   --  Select the first visible item (visible index one).
   --
   --  Clears the selection when nothing is visible. Intended for the keyboard
   --  Home shortcut while the file grid is focused.
   --
   --  @param Model Model to update.
   procedure Select_First_Visible
     (Model : in out Window_Model);

   --  Select the last visible item (the highest visible index).
   --
   --  Clears the selection when nothing is visible. Intended for the keyboard
   --  End shortcut while the file grid is focused.
   --
   --  @param Model Model to update.
   procedure Select_Last_Visible
     (Model : in out Window_Model);

   --  Move the single selection by whole pages within the visible projection.
   --
   --  A page spans Page_Rows grid rows, i.e. Page_Rows times the selection grid
   --  column stride items. Movement clamps at the first and last visible item
   --  (no wraparound). With nothing selected the first visible item is chosen.
   --  Intended for the keyboard Page Up / Page Down shortcuts while the file
   --  grid is focused.
   --
   --  @param Model Model to update.
   --  @param Page_Rows Number of grid rows spanned by one page.
   --  @param Down Move toward the last item when True, toward the first when False.
   procedure Move_Selection_By_Page
     (Model     : in out Window_Model;
      Page_Rows : Positive;
      Down      : Boolean);

   --  Feed a typed printable character run to the grid type-ahead buffer.
   --
   --  Appends Text to the pending type-ahead prefix and jumps the single
   --  selection to the first visible item whose name starts with the prefix,
   --  scanning from the current selection and wrapping around. Repeatedly
   --  typing the same single letter cycles through the items beginning with it.
   --  A run that matches nothing leaves the current selection untouched. Intended
   --  for use only when the file grid is focused (no text field active).
   --
   --  @param Model Model to update.
   --  @param Text Printable UTF-8 character run typed by the user.
   --  @param Matched Set True when a matching item was selected.
   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean);

   --  Clear the pending grid type-ahead prefix.
   --
   --  @param Model Model to update.
   procedure Reset_Type_Ahead
     (Model : in out Window_Model);

   --  Return the pending grid type-ahead prefix.
   --
   --  @param Model Model to inspect.
   --  @return Current type-ahead prefix, or an empty string when idle.
   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String;

   --  Set the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to update.
   --  @param Columns Number of visible item columns; values below one are ignored.
   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive);

   --  Record how many item rows the main view shows, for Page Up and Page
   --  Down. The shell measures it from the rendered layout before each key.
   --
   --  @param Model Model to update.
   --  @param Rows Whole item rows in view.
   procedure Set_Selection_Page_Rows
     (Model : in out Window_Model;
      Rows  : Positive);

   --  Return the rows Page Up and Page Down move by (ten until measured).
   --
   --  @param Model Model to inspect.
   --  @return Rows per page.
   function Selection_Page_Rows
     (Model : Window_Model)
      return Positive;

   --  Return whether a visible item is selected.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return True when the visible item is selected.
   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean;

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

   --  Return the selected item name.
   --
   --  @param Model Model to inspect.
   --  @return Selected item name or an empty string.
   function Selected_Name
     (Model : Window_Model)
      return String;

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

   --  Visit the selected items in the order Selected_Items lists them,
   --  without copying them: Item is the model's own, for the duration of the
   --  call. For a caller that reads each once (a total, a test for any
   --  archive), where copying a large selection cost more than the work.
   --
   --  @param Model Model to inspect.
   --  @param Visit Called once per selected loaded item.
   procedure For_Each_Selected_Item
     (Model : Window_Model;
      Visit : not null access procedure (Item : Files.Items.Directory_Item));

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

   --  Navigate to a directory and push the previous path onto back history.
   --
   --  @param Model Model to update.
   --  @param Directory_Path Destination directory path.
   --  @param Items Loaded directory items for the destination.
   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.Items.Item_Vectors.Vector);

   --  Enter the virtual recent-items view, showing Items in place of an ordinary
   --  directory listing. The first entry into the view pushes the current path
   --  onto back history so Back leaves the view; re-entering while already in the
   --  view (a refresh or clear) simply replaces the listing. The current path is
   --  cleared because the view is synthetic and has no backing directory.
   --
   --  @param Model Model to update.
   --  @param Items Recent items materialized from the stored recent paths.
   procedure Navigate_Recent
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector);

   --  Return whether the virtual recent-items view is currently shown.
   --
   --  @param Model Model to inspect.
   --  @return True while the recent-items view is active.
   function In_Recent_View
     (Model : Window_Model)
      return Boolean;

   --  Record Path as an item that was just opened, queued for the settings layer
   --  to fold into the persisted recent list. Both files and folders are
   --  recorded; the empty path is ignored.
   --
   --  @param Model Model to update.
   --  @param Path Full path of the opened item.
   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String);

   --  Return and clear the paths queued by Note_Recent_Open since the last drain.
   --  The interaction layer calls this after dispatching a user action to persist
   --  any newly opened items into the recent list.
   --
   --  @param Model Model to update.
   --  @return Opened paths in the order they were recorded.
   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector;

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

   --  Record that the item at Path is gone for good (deleted, or purged from
   --  the trash), so labels and favorites naming it are forgotten. Queued
   --  with Note_Path_Move as a Removed move.
   --
   --  @param Model Model to update.
   --  @param Path Full path of the removed item.
   procedure Note_Path_Removed
     (Model : in out Window_Model;
      Path  : String);

   --  Return and clear the moves and removals queued by Note_Path_Move and
   --  Note_Path_Removed, in order.
   --
   --  @param Model Model to update.
   --  @return The queued moves; a removal is Kind Removed with an empty To.
   function Take_Path_Moves
     (Model : in out Window_Model)
      return Files.Types.Path_Move_Vectors.Vector;

   --  Return whether back navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the back-history stack is not empty.
   function Can_Go_Back
     (Model : Window_Model)
      return Boolean;

   --  Return whether forward navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the forward-history stack is not empty.
   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean;

   --  Navigate backward if history is available.
   --
   --  @param Model Model to update.
   procedure Go_Back
     (Model : in out Window_Model);

   --  Navigate forward if history is available.
   --
   --  @param Model Model to update.
   procedure Go_Forward
     (Model : in out Window_Model);

   --  Where a window is in its history: its view, the recent view or not,
   --  and both history stacks.
   type Navigation_Mark is private;

   --  Mark where Model is, to return there when a move fails.
   --
   --  @param Model Model to inspect.
   --  @return Its view and history.
   function Mark_Navigation (Model : Window_Model) return Navigation_Mark;

   --  Return Model to Mark: the view, whether it is the recent view, and the
   --  history as it was -- not a move the other way, which from the recent
   --  view (never in history) lands somewhere else.
   --
   --  @param Model Model to update.
   --  @param Mark  Where it was, from Mark_Navigation.
   procedure Return_To (Model : in out Window_Model; Mark : Navigation_Mark);

   --  Focus the path input field.
   --
   --  @param Model Model to update.
   procedure Focus_Path_Input
     (Model : in out Window_Model);

   --  Focus the filter input field.
   --
   --  @param Model Model to update.
   procedure Focus_Filter_Input
     (Model : in out Window_Model);

   --  Focus the active rename input without changing its existing text.
   --
   --  @param Model Model to update.
   procedure Focus_Rename_Input
     (Model : in out Window_Model);

   --  Open the info-pane ownership editor for the single selected item.
   --
   --  The editor buffer is prefilled with Account_Name, the resolved name of
   --  the selected item's owner or group, or with its numeric id when the name
   --  is empty. Does nothing unless exactly one non-trash item is selected whose
   --  ownership was read. Files.Operations.Focus_Ownership_Input resolves the
   --  name and checks that the platform supports chown.
   --
   --  @param Model Model to update.
   --  @param Editing_Group True to edit the group id, False to edit the owner.
   --  @param Account_Name The owner's (or group's) name, or "" when unknown.
   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean;
      Account_Name  : String);

   --  Return the current text of the ownership editor buffer.
   --
   --  @param Model Model to inspect.
   --  @return The editor buffer contents (empty when not editing).
   function Ownership_Input_Text
     (Model : Window_Model)
      return String;

   --  Replace the ownership editor buffer with Text.
   --
   --  @param Model Model to update.
   --  @param Text New buffer contents.
   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return whether the ownership editor is currently editing the group id.
   --
   --  @param Model Model to inspect.
   --  @return True when editing the group, False when editing the owner.
   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean;

   --  Destination-picker mode driving the folder tree while the user chooses a
   --  Copy to.../Move to... target directory.
   type Tree_Pick_Mode is (Pick_None, Pick_Copy, Pick_Move);

   --  Return the current focus target.
   --
   --  @param Model Model to inspect.
   --  @return Focus target.
   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target;

   --  Return the cursor position of the currently focused text input.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based text cursor position, or zero when no text input is focused.
   function Text_Cursor_Position
     (Model : Window_Model)
      return Natural;

   --  Set the cursor position of the currently focused text input.
   --
   --  @param Model Model to update.
   --  @param Position Zero-based cursor position before clamping to text length.
   procedure Set_Text_Cursor_Position
     (Model    : in out Window_Model;
      Position : Natural);

   --  Move the cursor in the currently focused text input.
   --
   --  @param Model Model to update.
   --  @param Direction Left moves before the previous character; right moves after the next character.
   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction);

   --  Set path input text.
   --
   --  @param Model Model to update.
   --  @param Text New path input text.
   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return path input text.
   --
   --  @param Model Model to inspect.
   --  @return Current path input text.
   function Path_Input_Text
     (Model : Window_Model)
      return String;

   --  Commit path input using an externally validated path result.
   --
   --  @param Model Model to update.
   --  @param Result Validation result.
   --  @param Items Loaded destination items when Result is valid.
   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.Items.Item_Vectors.Vector);

   --  Return whether the path input is valid.
   --
   --  @param Model Model to inspect.
   --  @return True when no validation error is active.
   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean;

   --  Return path input validation error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Path_Input_Error_Key
     (Model : Window_Model)
      return String;

   --  Cancel focused text input and transient rename/create state as applicable.
   --
   --  @param Model Model to update.
   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model);

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

   --  Return whether the selected item's "extra info" (folder child count,
   --  document counts, symlink target) is wanted and not computed yet: the info
   --  pane is open, no paste or listing is in flight, and the value is not
   --  cached. Files.Operations.Ensure_Selected_Item_Extra computes it.
   --
   --  @param Model Model to inspect.
   --  @return True when the selected item's extra info should be computed.
   function Selected_Item_Needs_Extra
     (Model : Window_Model)
      return Boolean;

   --  Cache the selected item's computed extra info. A no-op unless
   --  Selected_Item_Needs_Extra holds.
   --
   --  @param Model Model whose selected item is updated in place.
   --  @param Extra The extra info (No_Info when there is nothing to show).
   procedure Set_Selected_Item_Extra
     (Model : in out Window_Model;
      Extra : Files.Extra_Info.Info);

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

   type Palette_Mode is (Palette_Commands, Palette_Open_With);

   --  Return whether rename can start for the current selection.
   --
   --  @param Model Model to inspect.
   --  @return True when at least one non-temporary item is selected.
   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean;

   --  Toggle synchronized multi-item rename mode.
   --
   --  When starting, one inline rename field is created per selected loaded
   --  item, each with its caret placed before the file extension.
   --
   --  @param Model Model to update.
   procedure Toggle_Rename
     (Model : in out Window_Model);

   --  Return whether rename mode is active.
   --
   --  @param Model Model to inspect.
   --  @return True when rename mode is active.
   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to inspect.
   --  @return First field's rename text, or an empty string.
   function Rename_Text
     (Model : Window_Model)
      return String;

   --  Set the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to update.
   --  @param Text New rename text for the first field.
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Insert Text at every rename field's caret, advancing each caret.
   --
   --  @param Model Model to update.
   --  @param Text UTF-8 text to insert.
   --  @return True when any field changed.
   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean;

   --  Delete, at every rename field's caret, the character or word before
   --  it (Backward) or after it.
   --
   --  @param Model Model to update.
   --  @param Backward Delete before the caret; otherwise at it.
   --  @param By_Word A word rather than one character.
   --  @return True when any field changed (the revision moves only then).
   function Rename_Delete
     (Model    : in out Window_Model;
      Backward : Boolean;
      By_Word  : Boolean := False)
      return Boolean;

   --  Move every rename field's caret one character or word in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @param By_Word To the next word boundary rather than the next character.
   --  @return True when any caret moved (the revision moves only then).
   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction;
      By_Word   : Boolean := False)
      return Boolean;

   --  Move every rename field's caret to the start of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret to the end of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean;

   --  Set the caret of the rename field shown at Visible_Index only.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible row index of the clicked field.
   --  @param Position Byte offset of the new caret (clamped to a boundary).
   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural);

   --  Visit each active rename field, so a caller rendering every row can
   --  index them once instead of searching the fields per row (a rename of
   --  a whole large folder made that quadratic). Nothing is visited when no
   --  rename is active.
   --
   --  @param Model Model to inspect.
   --  @param Visit Called once per field with the three below.
   --  @param Item_Index The field's item index; zero for the pending create row.
   --  @param Value Its text.
   --  @param Cursor Its caret byte offset.
   procedure For_Each_Rename_Field
     (Model : Window_Model;
      Visit : not null access procedure (Item_Index : Natural; Value : UString; Cursor : Natural));

   type Rename_Target is record
      Item_Index    : Natural := 0;
      Old_Full_Path : UString;
      Old_Name      : UString;
      New_Name      : UString;
   end record;

   package Rename_Target_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Target);

   --  Return the commit targets for the active real-item rename fields.
   --
   --  @param Model Model to inspect.
   --  @return One target per real rename field (temporary fields excluded).
   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector;

   --  Resume single-item rename mode for the currently selected item.
   --
   --  @param Model Model to update.
   --  @param Text Rename text to restore.
   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String);

   --  Begin temporary create-file state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary file name.
   procedure Begin_Create_File
     (Model : in out Window_Model;
      Name  : String);

   --  Begin temporary create-folder state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary folder name.
   procedure Begin_Create_Folder
     (Model : in out Window_Model;
      Name  : String);

   --  Return whether a temporary create-file item is active.
   --
   --  @param Model Model to inspect.
   --  @return True when temporary item exists.
   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return whether the active temporary item creates a directory.
   --
   --  @param Model Model to inspect.
   --  @return True when the temporary item is a directory.
   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean;

   --  Return temporary item name.
   --
   --  @param Model Model to inspect.
   --  @return Temporary item name or an empty string.
   function Temporary_Item_Name
     (Model : Window_Model)
      return String;

   --  Clear rename, temporary item, and edit focus state after a successful commit.
   --
   --  @param Model Model to update.
   procedure Clear_Edit_State
     (Model : in out Window_Model);

   --  Replace loaded items without changing path history.
   --
   --  @param Model Model to update.
   --  @param Items New loaded item list.
   procedure Replace_Items
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector);

   --  Select an item by name in the full loaded model.
   --
   --  @param Model Model to update.
   --  @param Name Loaded item name to select.
   --  @return True when a matching visible item was selected.
   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean;

   subtype Context_Menu_Target is Files.Types.Context_Menu_Target;

   type Clipboard_Mode is (Clipboard_None, Clipboard_Copy, Clipboard_Cut);

   --  Multi-level undo/redo history. Each entry stores enough to BOTH reverse
   --  (undo) and re-apply (redo) one action. Paths are parallel From/To
   --  vectors; Forward carries the redo payload and Create_Kind names the kind
   --  of creation to re-run for Undo_Delete_Created entries.
   type Undo_Action_Kind is
     (Undo_None,
      Undo_Rename,
      Undo_Move,
      Undo_Restore_Trash,
      Undo_Delete_Created,
      Undo_Set_Permissions,
      Undo_Set_Ownership);

   --  How an Undo_Delete_Created entry re-creates its paths on redo.
   type Undo_Create_Kind is
     (Create_None,
      Create_Copy,
      Create_Symbolic_Link,
      Create_Hard_Link);

   --  A single reversible/re-applicable action.
   --
   --  Undo runs the reverse direction, redo the forward direction:
   --    * Rename/Move: reverse moves From back to To, redo re-does the original
   --      To -> From transition.
   --    * Restore_Trash: reverse restores the trashed From paths; it is
   --      undo-only (Redoable is False), so redo never re-runs it.
   --    * Delete_Created: reverse deletes From; redo re-creates each From path
   --      from the parallel source path in Forward using Create_Kind.
   --    * Set_Permissions: To holds the old value (reverse) and Forward holds
   --      the new value (redo), both parallel to From.
   --    * Set_Ownership uses the same vectors, with each value encoded as
   --      "uid gid<NUL>user-name<NUL>group-name".  The names let a helper
   --      process reconstruct platform identities whose numeric token is only
   --      meaningful inside the process that obtained it.
   type Undo_Entry is record
      Kind        : Undo_Action_Kind := Undo_None;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      --  Trash locations of destinations a paste-replace overwrote. On undo, once
      --  the main reverse has vacated the destination, these are restored from the
      --  trash so the overwritten original comes back. Empty for every other
      --  action. Undo-only (a paste that replaced anything is not redoable).
      Restore_Trash : Files.Types.String_Vectors.Vector;
      --  Parallel snapshots of replacement originals, retained for retryable Undo.
      Restore_Identities : Files.Types.String_Vectors.Vector;
      Restore_Targets : Files.Types.String_Vectors.Vector;
      --  Successful reverse steps retained after a partial Undo. A retry must
      --  never delete or move an original that an earlier pass restored.
      Reverse_Completed : Files.Types.String_Vectors.Vector;
      Restores_Completed : Files.Types.String_Vectors.Vector;
      --  Successful creation/move steps retained after a partial Redo, so a
      --  retry skips committed items instead of treating them as collisions.
      Forward_Completed : Files.Types.String_Vectors.Vector;
      --  Verified hard-link families retained across partial copy Redo retries.
      Copy_Records : Files.Types.String_Vectors.Vector;
      --  Parallel to From for creations, moves, trash and metadata changes. Tracks the current entry at
      --  either end of a move, including a new identity after a copy-based move.
      --  Empty tokens never authorize deletion, history moves, trash restoration or metadata changes.
      Created_Identities : Files.Types.String_Vectors.Vector;
      --  Parallel recursive revision snapshots for created directories. Files
      --  and links use an empty value. Undo refuses a directory whose complete
      --  tree no longer matches the snapshot captured at publication.
      Created_Tree_Revisions : Files.Types.String_Vectors.Vector;
      --  Copies a failed move left beside their still present sources, set
      --  only on a non-redoable Undo_Move: reverse deletes each (verified by
      --  the parallel identity and tree revision) before it moves anything
      --  back or restores an original a replace preserved, so one paste is
      --  one Undo. Their completion markers join Reverse_Completed.
      Kept_Copies              : Files.Types.String_Vectors.Vector;
      Kept_Copy_Identities     : Files.Types.String_Vectors.Vector;
      Kept_Copy_Tree_Revisions : Files.Types.String_Vectors.Vector;
      --  Who the entry is across processes: a background helper's history
      --  journal names entries by it, so the window can tell an entry the
      --  helper left out of its journal from one it retired. Given by
      --  Commit_Undo_Record; 0 until then.
      Sequence : Natural := 0;
   end record;

   --  An Undo_Entry's parallel fields can be shorter than the vector they
   --  parallel: an entry recorded before a field existed, or one that never
   --  filled it. These read a field at an index as "" past its end, so no
   --  caller guards the index itself.

   --  @param Values A parallel field.
   --  @param Index Position in the vector Values parallels.
   --  @return Values (Index), or "" when Values is shorter.
   function Value_At (Values : Files.Types.String_Vectors.Vector; Index : Positive) return String is
     (if Index <= Values.Last_Index then Ada.Strings.Unbounded.To_String (Values (Index)) else "");

   --  @param Action Entry to read.
   --  @param Index Position in From.
   --  @return The identity the entry recorded at Index, or "".
   function Created_Identity (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.Created_Identities, Index));

   --  @param Action Entry to read.
   --  @param Index Position in From.
   --  @return The tree revision the entry recorded at Index, or "".
   function Created_Tree_Revision (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.Created_Tree_Revisions, Index));

   --  @param Action Entry to read.
   --  @param Index Position in Kept_Copies.
   --  @return The identity of the kept copy at Index, or "".
   function Kept_Copy_Identity (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.Kept_Copy_Identities, Index));

   --  @param Action Entry to read.
   --  @param Index Position in Kept_Copies.
   --  @return The tree revision of the kept copy at Index, or "".
   function Kept_Copy_Tree_Revision (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.Kept_Copy_Tree_Revisions, Index));

   --  @param Action Entry to read.
   --  @param Index Position in From.
   --  @return Forward (Index), or "".
   function Forward_Value (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.Forward, Index));

   --  @param Action Entry to read.
   --  @param Index Position in From.
   --  @return To (Index), or "".
   function To_Value (Action : Undo_Entry; Index : Positive) return String is
     (Value_At (Action.To, Index));

   --  Record what a creation at From (Index) published, growing the
   --  parallel fields with empty values up to Index first.
   --
   --  @param Action Entry to update.
   --  @param Index Position in From.
   --  @param Identity The created entry's identity.
   --  @param Tree_Revision Its tree revision, or "".
   procedure Set_Created
     (Action : in out Undo_Entry; Index : Positive; Identity, Tree_Revision : UString);

   --  The window's folder-size measurements: a handle the model holds as
   --  data, which Files.Operations drives (targets, steps, cancels) in place,
   --  since a copy is its queues' worth on every loop pass. The model only
   --  releases it, when the view it measures is left.
   --
   --  @param Model Window whose folder-size session is driven.
   --  @param Change Called once with the session, in place.
   procedure Update_Folder_Scan
     (Model  : in out Window_Model;
      Change : not null access procedure (Scan : in out Files.Folder_Size.Session));

   --  Record finished measurements, those of directories still selected;
   --  the selected directories are looked up once per batch.
   --
   --  @param Model Window to update.
   --  @param Measured The finished measurements.
   procedure Note_Folder_Sizes
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector);

   --  Stack of undo/redo entries; the last element is the top of the stack.
   package Undo_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Undo_Entry);

   --  Undo_Entry.Sequence values.
   package Sequence_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Positive);

   --  What a history journal holds besides its stacks.
   type History_Journal_State is record
      --  The Sequence the next recorded entry gets.
      Next_Sequence : Positive := 1;
      --  Sequences of entries still in the history but left out of the
      --  journal (too old, or too large, to fit it).
      Unjournaled   : Sequence_Vectors.Vector;
      --  Whether a new record retired the redo stack since the history was
      --  loaded: redo entries the loader never saw are retired with it.
      Redo_Retired  : Boolean := False;
   end record;

   --  @param Model Window whose history to snapshot.
   --  @return Undo stack, oldest first.
   function Undo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector;

   --  @param Model Window whose history to snapshot.
   --  @return Redo stack, oldest first.
   function Redo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector;

   --  Restore checkpointed history after filtering structurally unusable
   --  actions and completion markers. Identity snapshots are retained without
   --  consulting current pathnames so refused operations remain retryable.
   --  Entries without a Sequence (a journal from an older build) are given
   --  one, and the next Sequence is past every one the history holds.
   --  @param Model Window whose checkpointed history to restore.
   --  @param Undo Undo stack, oldest first.
   --  @param Redo Redo stack, oldest first.
   --  @param State The journal's state; Redo_Retired starts over as False.
   procedure Set_History
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State := (others => <>));

   --  @param Model Window whose journal state to read.
   --  @return The journal state to write beside its stacks.
   function History_State (Model : Window_Model) return History_Journal_State;

   --  Take back the history a background helper journaled, merging it into
   --  the window's own instead of replacing it: an entry the journal does
   --  not hold stays when the journal lists it as unjournaled (it left the
   --  journal only to fit it, or the helper never saw it) and goes when the
   --  helper retired it (the helper released its payloads). Redo entries the
   --  helper never saw are retired here when its new record retired its redo
   --  stack, and the merged undo stack keeps the depth cap; payloads of what
   --  is retired here are queued for Take_Retired_History.
   --
   --  @param Model Window whose history to merge into.
   --  @param Undo Journaled undo stack, oldest first.
   --  @param Redo Journaled redo stack, oldest first.
   --  @param State The journal's state.
   procedure Merge_History
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State);

   --  Start recording a performed action: advance the model revision and, for
   --  a completed rename or move, note each path move whether or not the
   --  action ends up undoable. Undo_None or an empty From only advances the
   --  revision. Touches no filesystem; Commit_Undo_Record finishes the record.
   --
   --  @param Model Model to update.
   --  @param Kind  Kind of the performed action.
   --  @param From  Current (new) locations of the action's items.
   --  @param To    Old locations, parallel to From.
   procedure Begin_Undo_Record
     (Model : in out Window_Model;
      Kind  : Undo_Action_Kind;
      From  : Files.Types.String_Vectors.Vector;
      To    : Files.Types.String_Vectors.Vector);

   --  Finish recording an action whose members the operations layer has
   --  already verified against the filesystem: the redo stack is retired (a
   --  new operation invalidates any pending redo) and, when Action keeps any
   --  From path, Action is pushed and the oldest entries past the depth cap
   --  are retired. Redo payloads are queued for deletion; payloads of entries
   --  past the cap, and of an Action that records nothing, are queued for
   --  release to the system trash. Both, and the journal save, wait for
   --  Take_Retired_History; nothing touches the filesystem here.
   --
   --  @param Model  Model whose history is updated.
   --  @param Action Verified entry; an empty From records nothing.
   --  @return True when Action was pushed onto the undo stack.
   function Commit_Undo_Record
     (Model  : in out Window_Model;
      Action : Undo_Entry) return Boolean;

   --  Hand over, and forget, what history mutations left for the operations
   --  layer: recovery payloads of retired entries to delete, payloads of an
   --  ended history to release to the system trash, and whether the history
   --  changed since the journal was last saved.
   --
   --  @param Model         Model whose pending history work to drain.
   --  @param Discarded     Restore_Trash payloads no entry references any more.
   --  @param Released      Restore_Trash payloads of a released history.
   --  @param Journal_Dirty True when the history journal must be saved.
   procedure Take_Retired_History
     (Model         : in out Window_Model;
      Discarded     : out Files.Types.String_Vectors.Vector;
      Released      : out Files.Types.String_Vectors.Vector;
      Journal_Dirty : out Boolean);

   --  End the history with its window: originals a paste replaced, kept in a
   --  hidden recovery folder only so Undo could put them back, are queued to
   --  go to the system trash under their own names (Take_Retired_History).
   --
   --  @param Model Model to update.
   procedure Release_History
     (Model : in out Window_Model);

   --  Forget the entire undo and redo history, queueing the retired recovery
   --  payloads and the journal save for Take_Retired_History.
   --
   --  @param Model Model to update.
   procedure Clear_Undo
     (Model : in out Window_Model);

   --  Return whether an undoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the undo stack is non-empty.
   function Undo_Available
     (Model : Window_Model)
      return Boolean;

   --  Return whether a redoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the redo stack is non-empty.
   function Redo_Available
     (Model : Window_Model)
      return Boolean;

   --  Pop the top entry off the undo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Pop the top entry off the redo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Push an action onto the redo stack (after a successful undo), queueing
   --  the journal save for Take_Retired_History.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Push an action back onto the undo stack (after a successful redo),
   --  leaving the redo stack untouched and queueing the journal save for
   --  Take_Retired_History.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Return the top undo entry's "from" (current) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of current locations, parallel to the entry's To paths.
   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The replace-or-skip prompt shown when a paste meets existing names.
   --  Every default is the closed state, as for Paste_Execution_State.
   type Paste_Conflict_State is record
      Active           : Boolean := False;
      Items            : Files.Paste.Work_Item_Vectors.Vector;
      Existing         : Files.Types.String_Vectors.Vector;
      Overrides        : Files.Paste.Item_Decision_Vectors.Vector;
      Policy           : Files.Paste.Conflict_Policy := Files.Paste.Policy_Ask;
      Mode             : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      Index            : Natural := 0;
      Apply_All        : Boolean := False;
      Clears_Clipboard : Boolean := True;
   end record;

   --  One paste (or drop) being carried out, action by action. Every field's
   --  default is the idle state, so a paste starts and ends by assigning a
   --  fresh aggregate rather than clearing each field by hand.
   type Paste_Execution_State is record
      Active                  : Boolean := False;
      Copy_Context            : Files.Copy_Context.Session;
      Actions                 : Files.Paste.Resolved_Action_Vectors.Vector;
      Cursor                  : Natural := 0;
      Done                    : Natural := 0;
      Total                   : Natural := 0;
      Mode                    : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      Cancelled               : Boolean := False;
      Clears_Clipboard        : Boolean := True;
      Current                 : UString;
      First_Dest              : UString;
      Undo_From               : Files.Types.String_Vectors.Vector;
      Undo_To                 : Files.Types.String_Vectors.Vector;
      Identities              : Files.Types.String_Vectors.Vector;
      Tree_Revisions          : Files.Types.String_Vectors.Vector;
      Verified_Created_Count  : Natural := 0;
      --  Trash locations of destinations overwritten by a Replace during this
      --  paste, so the undo entry can restore them (each is restored to its
      --  own recorded original path).
      Replaced_Trash          : Files.Types.String_Vectors.Vector;
      Replaced_Identities     : Files.Types.String_Vectors.Vector;
      Replaced_Targets        : Files.Types.String_Vectors.Vector;
      Verified_Replaced_Count : Natural := 0;
   end record;

   --  Select helper execution for a live window; headless callers can step synchronously.
   --  @param Model Window model to configure before starting a paste.
   --  @param Enabled Whether filesystem actions run on helper processes.
   procedure Set_Background_Transfers (Model : in out Window_Model; Enabled : Boolean);

   --  Return whether filesystem actions use helpers.
   --  @param Model Window model to inspect.
   --  @return True when background transfers are enabled.
   function Background_Transfers (Model : Window_Model) return Boolean;

   --  @param Model Window owning a general background operation.
   --  @param Job Helper session to attach while the progress overlay is open.
   --  @param Label_Key Localized command caption for the progress overlay.
   procedure Set_Background_Operation
     (Model : in out Window_Model; Job : Files.Process_Jobs.Session; Label_Key : String);

   --  @param Model Window to inspect.
   --  @return Progress caption key, or empty for a copy/move paste.
   function Background_Operation_Label (Model : Window_Model) return String;

   --  @param Model Window to inspect.
   --  @return Shared helper session, inactive during ordinary paste execution.
   function Background_Operation (Model : Window_Model) return Files.Process_Jobs.Session;

   --  @param Model Window whose nonmodal directory-read session to replace.
   --  @param Job Shared helper session, or empty to cancel the pending read.
   --  Transport changes do not change the visible model revision.
   procedure Set_Background_Refresh (Model : in out Window_Model; Job : Files.Process_Jobs.Session);

   --  @param Model Window owning a nonmodal directory-read helper.
   --  @return Shared refresh session, or an empty session.
   function Background_Refresh (Model : Window_Model) return Files.Process_Jobs.Session;

   --  Forget every cached folder-size measurement.
   --
   --  @param Model Model to update.
   procedure Clear_Folder_Size
     (Model : in out Window_Model);

   --  Drop cached folder-size measurements for directories that are no longer
   --  part of the current selection, keeping the cache bounded to the selection.
   --
   --  @param Model Model to update.
   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model);

   --  Return whether a folder-size measurement is cached for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up in the cache.
   --  @return True when a measurement for Path is cached.
   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean;

   --  Free and total space of the volume holding the current directory.
   type Volume_Space is record
      Known       : Boolean := False;
      Free_Bytes  : Long_Long_Integer := 0;
      Total_Bytes : Long_Long_Integer := 0;
   end record;

   --  How long a volume-space sample stays current before the window layer
   --  samples again, so the readout follows a delete, a paste or another
   --  process rather than sticking until the user navigates away.
   Volume_Space_Refresh_Interval : constant Duration := 3.0;

   --  Record a volume-space sample. The window layer takes it (a statvfs);
   --  Build_Snapshot only reads it, so building a snapshot touches no disk.
   --  Bumps the revision only when what would be shown changed.
   --
   --  @param Model Model to update.
   --  @param Path Directory the sample was taken for.
   --  @param Space The sampled free and total bytes.
   --  @param Sampled When it was taken.
   procedure Set_Volume_Space
     (Model   : in out Window_Model;
      Path    : String;
      Space   : Volume_Space;
      Sampled : Ada.Calendar.Time);

   --  @param Model Model to inspect.
   --  @param Now The current time.
   --  @return True when the sample is for the current directory and younger
   --    than Volume_Space_Refresh_Interval.
   function Volume_Space_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean;

   --  @param Model Model to inspect.
   --  @return The last sample, or an unknown space when it was taken for
   --    another directory.
   function Volume_Space_Of
     (Model : Window_Model)
      return Volume_Space;

   --  Which numeric account an owner name belongs to: a user id or a group id.
   type Account_Kind is (User_Account, Group_Account);

   --  Record the name of a user or group id. The window layer resolves it (an
   --  NSS lookup); Build_Snapshot only reads it, so building a snapshot asks
   --  the OS nothing. Bumps the revision only when the recorded name changed.
   --
   --  @param Model Model to update.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @param Name Resolved name, or "" when the id has none.
   procedure Set_Account_Name
     (Model : in out Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String);

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return True when a name (possibly "") was recorded for Id.
   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean;

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return The recorded name, or "" when none was recorded.
   function Account_Name
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return String;

   --  Note that the account names the info pane needs were sampled at the
   --  current revision, so the window layer can skip sampling until the model
   --  changes again. Does not bump the revision.
   --
   --  @param Model Model to update.
   procedure Note_Account_Names_Sampled
     (Model : in out Window_Model);

   --  @param Model Model to inspect.
   --  @return True when Note_Account_Names_Sampled ran at the current revision.
   function Account_Names_Current
     (Model : Window_Model)
      return Boolean;

   --  Return the cached folder-size measurement for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up.
   --  @return Cached totals for Path; Available is False when Path is not cached.
   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result;

   --  Record a recoverable error key, and the path its message names.
   --
   --  @param Model Model to update.
   --  @param Error_Key Localized error key.
   --  @param Path The value of the message's {path}, or "" when it has none.
   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String;
      Path      : String := "");

   --  Return the last recoverable error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Last_Error_Key
     (Model : Window_Model)
      return String;

   --  Return the path the last recoverable error's message names.
   --
   --  @param Model Model to inspect.
   --  @return The path given to Set_Error with the last error, or "".
   function Last_Error_Path
     (Model : Window_Model)
      return String;

private

   --  Cache a recursive folder-size measurement for a directory path.
   --
   --  The cache holds one measurement at a time, keyed by Path, so a repeated
   --  selection of the same directory reuses it instead of walking again.
   --
   --  @param Model Model to update.
   --  @param Path Directory the measurement describes.
   --  @param Value Recursive size totals for Path.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result);

   --  Clear the destination-picker sub-mode and its captured sources.
   --
   --  @param Model Model to update.
   procedure Clear_Tree_Pick
     (Model : in out Window_Model);

   --  Return whether one input-owning overlay is open.
   --
   --  @param Model Model to inspect.
   --  @param Overlay The overlay to ask about.
   --  @return True while Overlay is open (or, for a paste, active).
   function Overlay_Is_Open
     (Model   : Window_Model;
      Overlay : Input_Overlay)
      return Boolean;

   --  Cancel temporary create-file state.
   --
   --  @param Model Model to update.
   procedure Cancel_Create_File
     (Model : in out Window_Model);
   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Natural);

   --  One inline rename editor. Item_Index is a loaded-item index (1 .. last)
   --  for a real item, or 0 for the temporary create item. Value is the edited
   --  name and Cursor is the byte offset of that field's caret.
   type Rename_Field is record
      Item_Index : Natural := 0;
      Value      : UString;
      Cursor     : Natural := 0;
   end record;

   package Rename_Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Field);

   --  Cache of recursive folder-size measurements, keyed by absolute path. Holds
   --  one entry per measured selected directory so a multi-item selection can
   --  show each folder's size; pruned to the selection by
   --  Prune_Folder_Sizes_To_Selection.
   use type Files.File_System.Directory_Size_Result;
   package Folder_Size_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => UString,
      Element_Type => Files.File_System.Directory_Size_Result,
      "<"          => Ada.Strings.Unbounded."<");

   use type Files.Types.Account_Id;

   --  Resolved account names keyed by numeric id (Set_Account_Name).
   package Account_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Files.Types.Account_Id,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   type Account_Name_Tables is array (Account_Kind) of Account_Name_Maps.Map;

   --  The right-click menu: where it opened, what it was opened on, and the
   --  keyboard highlight (0 = none). Every default is the closed state.
   type Context_Menu_State is record
      Open       : Boolean := False;
      X          : Natural := 0;
      Y          : Natural := 0;
      Target     : Context_Menu_Target := Files.Types.Context_Menu_None;
      Item_Index : Natural := 0;
      Highlight  : Natural := 0;
   end record;

   --  The path bar's text field: what is typed, where the caret is (a byte
   --  offset), and whether the last commit failed and why. Every default is
   --  a fresh, valid field.
   type Path_Input_State is record
      Text   : UString;
      Cursor : Natural := 0;
      Valid  : Boolean := True;
      Error  : UString;
   end record;

   --  The Copy to.../Move to... destination picker over the folder tree: its
   --  mode, the paths it copies or moves, the highlighted destination, and
   --  whether the picker opened the folder tree, which it then closes. Every
   --  default is the idle state.
   type Tree_Pick_State is record
      Mode         : Tree_Pick_Mode := Pick_None;
      Sources      : Files.Types.String_Vectors.Vector;
      Target       : UString;
      Opened_Panel : Boolean := False;
   end record;

   --  The not-yet-created item New File or New Folder shows while its name
   --  is edited. Every default is the state with no such item.
   type Temporary_Item_State is record
      Active       : Boolean := False;
      Is_Directory : Boolean := False;
      Name         : UString;
   end record;

   --  A discarded background read whose reload is still owed, the view
   --  incarnation it is owed to, whether it must be forced, and the item it
   --  should select. Every default is the settled state.
   type Owed_Refresh_State is record
      Owed        : Boolean := False;
      Incarnation : Natural := 0;
      Forced      : Boolean := False;
      Selection   : UString;
   end record;

   --  The info pane's owner or group field: what is typed, where the caret
   --  is (a byte offset), and whether it edits the group rather than the
   --  owner. Every default is the idle field.
   type Ownership_Input_State is record
      Text          : UString;
      Cursor        : Natural := 0;
      Editing_Group : Boolean := False;
   end record;

   --  The Quick Look overlay: whether it is shown, the path it previews and
   --  the content prepared for it. Every default is the closed state.
   type Quick_Look_State is record
      Open    : Boolean := False;
      Path    : UString;
      Content : Files.Quick_Look.Quick_Look_Content;
   end record;

   --  The command palette overlay: whether it is shown, what it lists, the
   --  guikit component holding its query, scroll and selection, the paths
   --  and applications an Open With listing is for, and the model revision
   --  its command list was built at, so a frame rebuilds it (every command's
   --  enablement) only after a change. Every default is the closed state.
   type Command_Palette_State is record
      Open                   : Boolean := False;
      Mode                   : Palette_Mode := Palette_Commands;
      View                   : Guikit.Command_Palette.Palette;
      Open_With_Targets      : Files.Types.String_Vectors.Vector;
      Open_With_Applications : Files.Desktop_Applications.Application_Vectors.Vector;
      Listed_Revision        : Natural := Natural'Last;
   end record;

   --  The sort menu over the bottom bar: whether it is shown and its keyboard
   --  highlight (0 = none). Every default is the closed state.
   type Sort_Menu_State is record
      Open      : Boolean := False;
      Highlight : Natural := 0;
   end record;

   --  The folder-tree side panel: whether it is shown, its scroll in rows,
   --  the tree it shows, whether it holds the keyboard, and the path of its
   --  keyboard cursor. Every default is the closed, unseeded panel.
   type Tree_Panel_State is record
      Open     : Boolean := False;
      Scroll   : Natural := 0;
      Tree     : Files.Folder_Tree.Tree;
      Keyboard : Boolean := False;
      Cursor   : UString;
   end record;

   --  Inline rename: whether it is active and one field per renamed item.
   --  Every default is the idle state.
   type Rename_State is record
      Active : Boolean := False;
      Fields : Rename_Field_Vectors.Vector;
   end record;

   --  The undo history: the two stacks, the work owed to the operations
   --  layer (Take_Retired_History) -- payloads of retired entries to delete,
   --  payloads of a released history to send to the trash -- whether the
   --  history changed since it was last saved, and what its journal holds
   --  besides the stacks. Every default is the empty history.
   type Undo_History_State is record
      Undo_Stack       : Undo_Entry_Vectors.Vector;
      Redo_Stack       : Undo_Entry_Vectors.Vector;
      Retired_Discards : Files.Types.String_Vectors.Vector;
      Retired_Releases : Files.Types.String_Vectors.Vector;
      Journal_Dirty    : Boolean := False;
      Journal          : History_Journal_State;
   end record;

   --  The clipboard: the paths cut or copied in this window and how, and a
   --  text the window layer is asked to put on the system clipboard. Every
   --  default is the empty clipboard.
   type Clipboard_State is record
      Paths                  : Files.Types.String_Vectors.Vector;
      Mode                   : Clipboard_Mode := Clipboard_None;
      System_Request         : UString;
      System_Request_Pending : Boolean := False;
   end record;

   --  Owner and group names resolved by the window layer, and the revision
   --  they were last sampled at (Natural'Last: never).
   type Account_Names_State is record
      Names   : Account_Name_Tables;
      Sampled : Natural := Natural'Last;
   end record;

   --  The root (volume) selector overlay: whether it is shown, the roots it
   --  lists and the highlighted one (0 = none). Every default is the closed
   --  state.
   type Root_Selector_State is record
      Open     : Boolean := False;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Selected : Natural := 0;
   end record;

   --  The label picker overlay: whether it is shown and its keyboard
   --  highlight. Every default is the closed state.
   type Label_Picker_State is record
      Open   : Boolean := False;
      Swatch : Positive := Files.Types.Clear_Swatch;
   end record;

   --  The volume-space sample and where and when it was taken; Sampled is
   --  meaningful only once Path is set. Every default is the unsampled state.
   type Volume_Sample_State is record
      Space   : Volume_Space;
      Path    : UString;
      Sampled : Ada.Calendar.Time;
   end record;

   --  The grouping the items are ordered by: the effective mode, the labels
   --  and day it was computed with, and the rows revision it was last
   --  checked at (a selection or scroll moves no item). Every default is the
   --  never-synced, ungrouped state.
   type Grouping_State is record
      Mode            : Files.Types.Group_Mode := Files.Types.No_Grouping;
      Labels          : Files.Settings.Path_Label_Vectors.Vector;
      Day             : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Synced_Revision : Natural := Natural'Last;
   end record;

   type Navigation_Mark is record
      Path            : UString;
      Recent          : Boolean := False;
      Back, Forward   : Files.Types.String_Vectors.Vector;
   end record;

   type Window_Model is record
      Current_Path_Value   : UString;
      Home_Path_Value      : UString;
      --  True while the synthetic recent-items view is shown. The listing then
      --  reflects the stored recent paths rather than a real directory, so
      --  editing commands gate on it exactly as they gate on the trash view.
      Recent_View_Active   : Boolean := False;
      --  Active scope of the shared filter-bar query, and whether the current
      --  view holds recursive search results (name or content) rather than a
      --  plain directory listing. Both reset on navigation and on Clear_Filter.
      Search_Scope_Value    : Files.Types.Search_Scope := Files.Types.Filter_Here;
      Search_Results_Active : Boolean := False;
      --  Paths opened since the last drain, awaiting fold into the persisted
      --  recent list by the interaction layer (see Note_Recent_Open).
      Recent_Open_Queue    : Files.Types.String_Vectors.Vector;
      --  Renames and moves since the last drain, awaiting the interaction
      --  layer so labels, favorites and recent paths follow (Note_Path_Move).
      Path_Move_Queue      : Files.Types.Path_Move_Vectors.Vector;
      Items                : Files.Items.Item_Vectors.Vector;
      Directory_Signature  : Files.File_System.Directory_Signature;
      Filter_Value         : UString;
      Type_Ahead_Buffer_Value : UString;
      Selected_Item_Index  : Natural := 0;
      Selected_Item_Indexes : Natural_Vectors.Vector;
      --  The item a shift-extended range grows from (Range_Anchor): set by a
      --  plain or Ctrl selection and by a cursor move, kept by a range. A
      --  path, so a reload or a resort cannot turn it into another item.
      Range_Anchor_Path    : UString;
      --  The visible rows, worked out once per listing, filter and search
      --  (Support.Invalidate_Visible at every write of those): which item each
      --  visible row is, and each item's row (0: hidden). A visible-index
      --  lookup used to walk the items each time, about ten walks a key.
      Visible_Cache_Valid : Boolean := False;
      Visible_Items       : Natural_Vectors.Vector;
      Item_Visible_Rows   : Natural_Vectors.Vector;
      --  Hidden items among all loaded ones, counted with the map.
      Hidden_Items        : Natural := 0;
      --  Moved by scrolling alone (Scroll_Revision), apart from Revision:
      --  a scroll changes three numbers of the snapshot, not its items.
      Scroll_Revision_Value : Natural := 0;
      Selection_Columns   : Positive := 1;
      Selection_Page_Rows_Value : Positive := 10;
      View_Value           : Files.Types.View_Mode := Files.Types.Small_Icons;
      Sort_Field_Value     : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Sort_Ascending       : Boolean := True;
      Sort_Menu            : Sort_Menu_State;
      Back_History         : Files.Types.String_Vectors.Vector;
      Forward_History      : Files.Types.String_Vectors.Vector;
      Focus_Value          : Files.Types.Focus_Target := Files.Types.Focus_None;
      Path_Input           : Path_Input_State;
      Info_Pane_Open       : Boolean := False;
      Settings_Pane_Open   : Boolean := False;
      Settings_Draft_Value : Files.Settings.Settings_Draft;
      Settings_Panel_View  : Guikit.Settings_Panel.Panel;
      Ownership_Input      : Ownership_Input_State;
      Info_Pane_Scroll     : Natural := 0;
      Main_View_Scroll     : Natural := 0;
      Root_Selector        : Root_Selector_State;
      Tree_Panel           : Tree_Panel_State;
      Tree_Pick               : Tree_Pick_State;
      Command_Palette          : Command_Palette_State;
      Quick_Look               : Quick_Look_State;
      Label_Picker             : Label_Picker_State;
      Rename                   : Rename_State;
      Temporary            : Temporary_Item_State;
      Filter_Cursor        : Natural := 0;
      Last_Error           : UString;
      Last_Error_Path_Value : UString;
      Clipboard             : Clipboard_State;
      History               : Undo_History_State;
      Folder_Sizes            : Folder_Size_Maps.Map;
      Folder_Scan             : Files.Folder_Size.Session;
      Context_Menu                  : Context_Menu_State;
      Paste_Conflict                : Paste_Conflict_State;
      Background_Transfers_Value    : Boolean := False;
      Paste_Exec_Job                 : Files.Transfer_Jobs.Session;
      Operation_Job                 : Files.Process_Jobs.Session;
      Refresh_Job                   : Files.Process_Jobs.Session;
      Operation_Label_Key           : UString;
      Paste_Exec                    : Paste_Execution_State;
      --  Monotonic change counter bumped by every model mutator. The render
      --  layer caches the value it built a snapshot at and rebuilds only when it
      --  differs, so snapshot invalidation follows the model automatically
      --  rather than relying on each call site to remember.
      Revision_Value : Natural := 0;
      --  Bumped by every change to the window's live settings
      --  (Note_Settings_Changed), apart from Revision_Value: settings live
      --  outside the model, and the snapshot follows them on its own.
      Settings_Revision_Value : Natural := 0;
      --  Bumped with Revision_Value by every mutator except those that move
      --  only the selection (Support.Touch_Selection): while it holds, a view
      --  snapshot's rows are still right but for their selected flags.
      Rows_Revision_Value : Natural := 0;
      --  Bumped with Revision_Value by every change of the selection.
      Selection_Revision_Value : Natural := 0;
      --  The volume-space sample (Set_Volume_Space).
      Volume_Sample : Volume_Sample_State;
      Account_Names         : Account_Names_State;
      --  The grouping the items are ordered by (Sync_Grouping).
      Grouping : Grouping_State;
      --  Narrower generation used to reject stale background directory reads
      --  without treating harmless interaction as a listing-context change.
      Listing_Revision_Value : Natural := 0;
      --  Generation of the displayed view; advanced only by navigation.
      View_Incarnation_Value : Natural := 0;
      Current_Is_Trash_Value : Boolean := False;
      --  A reload still owed (Note_Owed_Refresh).
      Owed_Refresh            : Owed_Refresh_State;
   end record;
end Files.Model;

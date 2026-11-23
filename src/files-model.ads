with Files.Text_Case;
with Files.Preference_Types;
with Files.Items;
with Ada.Calendar;
private with Ada.Real_Time;
private with Files.Desktop_Application_Types;
private with Files.Jobs.Process;
private with Files.Paste_States;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with Files.File_System_Types;
with Files.File_Types;
private with Files.Folder_Tree;
private with Files.Folder_Size;
private with Files.Quick_Look;
with Files.Settings;
private with Guikit.Command_Palette;
with Guikit.Input;
private with Guikit.Settings_Panel;
with Files.Types;
with Files.UI_Types;
private with Files.Undo.History;

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
      Default_View_Mode : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons);

   --  The revision counters. A view keeps what it built and asks these
   --  which parts are stale; every counter wraps at Natural'Last and is only
   --  ever compared for equality. Mutators move them through one helper
   --  each in Files.Model.Support, never by hand:
   --
   --    Helper (Support)   Moves                         Read by
   --    Touch              Revision, Rows_Revision       snapshot: full rebuild
   --    Touch_Rename       Revision, Rename_Revision     snapshot: patch rename rows
   --    Touch_Selection    Revision, Selection_Revision  snapshot: patch selected flags
   --    Touch_Header       Revision                      snapshot: header-only build
   --    Touch_Info         Revision, Info_Revision       snapshot: info-pane rows
   --    Note_Folder_Sizes  Revision, Folder_Sizes.Revision  selection total, info pane
   --    Touch_Overlay      Overlay_Revision              window: model-drawn overlays
   --    Touch_Scroll       Scroll_Revision               snapshot: scroll patch
   --    Touch_Listing      Listing_Revision              Refresh: stale background reads
   --    (navigation)       View_Incarnation              Refresh: view still on screen
   --    Note_Settings_Changed  Settings_Revision         window: settings sharing
   --
   --  A mutator calls the narrowest helper that covers what it changed;
   --  a change no narrower helper covers calls Touch.

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

   --  Moved by a change that only an overlay drawn from the model shows (the
   --  command palette's query, highlight and page; the settings pane's
   --  focus, values, scroll and section), and by nothing else: such a
   --  change leaves Revision, and with it the snapshot and the palette's
   --  command list, as they were. The window layer rebuilds an overlay when
   --  either moved.
   --
   --  @param Model Model to inspect.
   --  @return The overlay revision.
   function Overlay_Revision
     (Model : Window_Model)
      return Natural;

   --  Moved, with Revision, by a change the info pane shows and no other
   --  revision tracks: a selected item's details read in (extra info), an
   --  account name or the host's capabilities sampled. With the selection,
   --  rows, folder-size and settings revisions it keys the snapshot's
   --  info-pane rows, which a header-only rebuild then reuses.
   --
   --  @param Model Model to inspect.
   --  @return The info revision.
   function Info_Revision
     (Model : Window_Model)
      return Natural;

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

   --  Moved by every change of a rename field's text or caret and by
   --  nothing else (typing, deleting, moving the caret while renaming):
   --  with Rows_Revision, what the renamed rows show. Starting or ending a
   --  rename moves Rows_Revision instead, as it changes which rows edit.
   --
   --  @param Model Model to inspect.
   --  @return The rename revision.
   function Rename_Revision
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
   --  earlier one (Force wins; a nonempty selection, by name or by path,
   --  replaces the old one).
   --
   --  @param Model Model to update.
   --  @param Force Whether the discarded read was a forced reload.
   --  @param Select_Name Item name the discarded read was asked to select.
   --  @param Select_Path Full path the discarded read was asked to select
   --  (an item a leaf name cannot single out among search results).
   procedure Note_Owed_Refresh
     (Model       : in out Window_Model;
      Force       : Boolean;
      Select_Name : String;
      Select_Path : String := "");

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

   --  @param Model Model to inspect.
   --  @return Full path the owed reload should select, or "".
   function Owed_Refresh_Path
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

   --  The transient surfaces that own window input while open
   --  (Files.UI_Types.Input_Overlay); every model query reads that list.
   subtype Input_Overlay is Files.UI_Types.Input_Overlay;
   use all type Files.UI_Types.Input_Overlay;

   --  The overlays with their own text-entry surface.
   subtype Text_Input_Overlay is Input_Overlay range Settings_Pane_Overlay .. Command_Palette_Overlay;

   --  The overlays Escape (the close command) closes; the paste dialogs have
   --  their own way out.
   subtype Escape_Closable_Overlay is Input_Overlay range Settings_Pane_Overlay .. Tree_Pick_Overlay;

   --  The open overlay on top (the first open one of Files.UI_Types.Overlay_Stack):
   --  the one whose own controls alone still act, and the one drawn on top.
   --  Escape, the keyboard, the pointer and the window's drawing follow it.
   --
   --  @param Model Model to inspect.
   --  @param Overlay Set to the top-most open overlay when one is open.
   --  @return True when any input-owning overlay is open.
   function Topmost_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean;

   --  Whether the window layer draws Overlay (the command palette or the
   --  settings pane, which it merges over the frame): it is open and nothing
   --  is open above it in Files.UI_Types.Overlay_Stack. A paste dialog, drawn in
   --  the frame, is above both; the palette is above the pane.
   --
   --  @param Model Model to inspect.
   --  @param Overlay The palette or the pane.
   --  @return True when Overlay is to be drawn.
   function Window_Overlay_Shown (Model : Window_Model; Overlay : Text_Input_Overlay) return Boolean;

   --  The overlay Escape (the close command) closes: the top-most one
   --  (Topmost_Overlay), when it is one Escape closes -- any but the paste
   --  dialogs, which have their own way out; an overlay below one of those
   --  is not closed past it.
   --
   --  @param Model Model to inspect.
   --  @param Overlay Set to that overlay when one is open.
   --  @return True when an overlay Escape closes is open.
   function Escape_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean;

   --  Whether the close command (Escape unless rebound) has anything to do:
   --  an overlay it closes (Escape_Overlay), a focused text field, or a
   --  rename or new item being edited. The one rule both the command's
   --  status and running it follow.
   --
   --  @param Model Model to inspect.
   --  @return True when the close command would close or cancel something.
   function Has_Something_To_Close (Model : Window_Model) return Boolean;

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

   --  Whether typed characters are contained: the overlay on top
   --  (Files.UI_Types.Overlay_Stack, which keys, clicks and the wheel follow too)
   --  takes them only when it is the command palette or the settings pane with
   --  its own text field focused; any other overlay on top swallows them.
   --
   --  @param Model Model to inspect.
   --  @return True while an overlay owns input and does not take characters.
   function Character_Input_Is_Contained
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
      return Files.File_System_Types.Directory_Signature;

   --  Replace the stored directory polling signature.
   --
   --  @param Model Model to update.
   --  @param Signature Signature captured after loading or polling a directory.
   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System_Types.Directory_Signature);

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
      return Files.Preference_Types.View_Mode;

   --  Set the active view mode.
   --
   --  @param Model Model to update.
   --  @param Mode New view mode.
   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Preference_Types.View_Mode);

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

   --  The item index that stands for the pending create row wherever a row
   --  or a field names its item: the selection, a rename field, a visible
   --  row. No loaded item has it, and it is not zero, so a field or row that
   --  names no item (0) never matches the create row.
   Temporary_Item_Index : constant Natural := Natural'Last;

   --  One visible row: the directory item plus whether it is selected.
   type Visible_Row is record
      Item       : Files.Items.Directory_Item;
      Selected   : Boolean := False;
      --  Index into the loaded items, or Temporary_Item_Index for the pending
      --  create row. Lets a caller walking the rows skip a per-row
      --  visible-to-item scan.
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
   --  @param Item_Index Its index into the loaded items; Temporary_Item_Index
   --    for the pending create row.
   --  @param Selected Whether it is selected.
   procedure For_Each_Visible_Row
     (Model : Window_Model;
      Visit : not null access procedure
        (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean));

   --  Apply changed listing settings to the items in view, in place, for a
   --  view that cannot be read again (search results): hidden items leave
   --  the view when Settings hides them and come back when it shows them
   --  (the results keep them), and with Reclassify each item's type and icon
   --  are worked out afresh from Settings' mappings (its details with them).
   --  The items are ordered by the model's sort; the selection (less what is
   --  now hidden), a rename or a new item's name in progress, the palette,
   --  Quick Look on a still-selected item, the scroll and the info pane's
   --  scroll stay, and the view still holds search results. Hidden items
   --  the search itself left out cannot come back without searching again.
   --
   --  @param Model Model to update.
   --  @param Settings The settings now in force.
   --  @param Reclassify Whether the type and icon mappings changed.
   procedure Reapply_Listing_Settings
     (Model      : in out Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Reclassify : Boolean);

   --  Navigate to a directory and push the previous path onto the back navigation history.
   --
   --  @param Model Model to update.
   --  @param Directory_Path Destination directory path.
   --  @param Items Loaded directory items for the destination.
   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.Items.Item_Vectors.Vector);

   --  Enter the virtual recent-items view, showing Items in place of an ordinary
   --  directory listing. Entering pushes the current path onto the back
   --  navigation history so Back leaves the view. Already in the view, it does
   --  nothing: the shown view is listed again through
   --  Files.Refresh.Reinstall_Listing (Replace_Recent_Items). The current path
   --  is cleared because the view is synthetic and has no backing directory.
   --
   --  @param Model Model to update.
   --  @param Items Recent items materialized from the stored recent paths.
   procedure Navigate_Recent
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector);

   --  Return whether back navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the back navigation history is not empty.
   function Can_Go_Back
     (Model : Window_Model)
      return Boolean;

   --  Return whether forward navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the forward navigation history is not empty.
   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean;

   --  Navigate backward if the navigation history allows it.
   --
   --  @param Model Model to update.
   procedure Go_Back
     (Model : in out Window_Model);

   --  Navigate forward if the navigation history allows it.
   --
   --  @param Model Model to update.
   procedure Go_Forward
     (Model : in out Window_Model);

   --  The folder Go_Back moves to, so a caller can load it before moving.
   --
   --  @param Model Model to inspect; Can_Go_Back must hold.
   --  @return The last path of the back navigation history.
   function Back_Target (Model : Window_Model) return String
     with Pre => Can_Go_Back (Model);

   --  The folder Go_Forward moves to, so a caller can load it before moving.
   --
   --  @param Model Model to inspect; Can_Go_Forward must hold.
   --  @return The last path of the forward navigation history.
   function Forward_Target (Model : Window_Model) return String
     with Pre => Can_Go_Forward (Model);

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

   --  Destination-picker mode driving the folder tree while the user chooses a
   --  Copy to.../Move to... target directory.
   type Tree_Pick_Mode is (Pick_None, Pick_Copy, Pick_Move);

   --  Return the current focus target.
   --
   --  @param Model Model to inspect.
   --  @return Focus target.
   function Focus
     (Model : Window_Model)
      return Files.UI_Types.Focus_Target;

   --  Return the text of the currently focused text input: the path, filter,
   --  rename, palette query, settings value or ownership field.
   --
   --  @param Model Model to inspect.
   --  @return The focused field's text, or "" when no text input is focused.
   function Focused_Text
     (Model : Window_Model)
      return String;

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
   --  @param Direction Left and right move to the next character boundary that way on the screen, so through
   --  right-to-left text in the opposite byte order (Guikit.Bidi.Caret_Step); up moves back and down forward.
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
      Result : Files.File_System_Types.Path_Result;
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

   type Palette_Mode is (Palette_Commands, Palette_Open_With);

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

   --  Replace the shown Recent view's items, in recency order, without
   --  changing path history (Files.Refresh.Reinstall_Listing's install of a
   --  Recent view listed again).
   --
   --  @param Model Model to update; it shows the Recent view.
   --  @param Items Recent items materialized from the stored recent paths.
   procedure Replace_Recent_Items
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector);

   --  Whether a selection was set by name since the window last scrolled the
   --  selection into view: the window reveals it after the step that set it
   --  (a reload, a mouse or menu command), not only after a key.
   --
   --  @param Model Model to inspect.
   --  @return True when the selection still waits to be revealed.
   function Reveal_Is_Pending
     (Model : Window_Model)
      return Boolean;

   --  Note that the selection has been scrolled into view (or that there is
   --  nothing to reveal).
   --
   --  @param Model Model to update.
   procedure Clear_Reveal
     (Model : in out Window_Model);

   subtype Context_Menu_Target is Files.UI_Types.Context_Menu_Target;

   type Clipboard_Mode is (Clipboard_None, Clipboard_Copy, Clipboard_Cut);

   --  The one modal job a window runs at a time: shown with its progress,
   --  owning the input, cancellable. A paste (Files.Model.Pasting's
   --  execution) or an operation on a helper (Files.Job_Drivers.Operation: trash,
   --  search, undo and the rest). Files.Model.Jobs asks and ends it.
   type Foreground_Job_Kind is (No_Foreground_Job, Paste_Job, Operation_Job);

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

   --  Add a second message to the error just recorded: something the user
   --  must also learn (an Undo the failed operation could not record) that
   --  is not the failure itself. The next Set_Error drops it.
   --
   --  @param Model Model to update.
   --  @param Notice_Key Localized message key, without a {path}.
   procedure Set_Error_Notice
     (Model      : in out Window_Model;
      Notice_Key : String);

   --  @param Model Model to inspect.
   --  @return The notice added to the last error, or "".
   function Last_Error_Notice
     (Model : Window_Model)
      return String;

private

   --  The next value of a revision counter: every counter below wraps from
   --  Natural'Last to 0, as its readers compare values only for equality.
   --
   --  @param Value The counter's current value.
   --  @return Its next value.
   function Bumped (Value : Natural) return Natural is
     (if Value = Natural'Last then 0 else Value + 1);

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

   --  A single-line text field: what is typed, and where the caret is (a
   --  byte offset into Text). Every default is the empty field.
   type Text_Field_State is record
      Text   : UString;
      Cursor : Natural := 0;
   end record;

   --  One inline rename editor. Item_Index is a loaded-item index (1 .. last)
   --  for a real item, or Temporary_Item_Index for the temporary create item;
   --  0 names no item. Edit holds the edited name and that field's caret.
   type Rename_Field is record
      Item_Index : Natural := 0;
      Edit       : Text_Field_State;
   end record;

   package Rename_Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Field);

   --  Cache of recursive folder-size measurements, keyed by absolute path. Holds
   --  one entry per measured selected directory so a multi-item selection can
   --  show each folder's size; pruned to the selection by
   --  Folder_Sizes.Prune_To_Selection.
   use type Files.File_System_Types.Directory_Size_Result;
   package Folder_Size_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => UString,
      Element_Type => Files.File_System_Types.Directory_Size_Result,
      "<"          => Ada.Strings.Unbounded."<");

   --  Each selected folder and when it was listed, by path.
   package Folder_Time_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => UString,
      Element_Type    => Ada.Calendar.Time,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => Ada.Strings.Unbounded."=",
      "="             => Ada.Calendar."=");

   --  The selected folders and the selection's combined size, kept across
   --  folder-size hand-overs (Files.Model.Folder_Sizes): each hand-over then
   --  looks up only the folders it measured and moves the total by their
   --  difference, where it used to map every selected folder and the
   --  snapshot summed the whole selection again. Folders is current while
   --  the selection and rows revisions are those it was built at; the total
   --  while the folder sizes' revision is Sizes_Revision too.
   type Selected_Folders_Cache is record
      Built             : Boolean := False;
      Selection_Rev     : Natural := 0;
      Rows_Rev          : Natural := 0;
      Folders           : Folder_Time_Maps.Map;
      Total_Valid       : Boolean := False;
      Sizes_Revision    : Natural := 0;
      Total_Bytes       : Long_Long_Integer := 0;
      Unmeasured        : Natural := 0;
   end record;

   use type Files.Types.Account_Id;

   --  Resolved account names keyed by numeric id (Set_Account_Name).
   package Account_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Files.Types.Account_Id,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   type Account_Name_Tables is array (Files.File_System_Types.Account_Kind) of Account_Name_Maps.Map;

   --  The right-click menu: where it opened, what it was opened on, and the
   --  keyboard highlight (0 = none). Every default is the closed state.
   type Context_Menu_State is record
      Open       : Boolean := False;
      X          : Natural := 0;
      Y          : Natural := 0;
      Target     : Context_Menu_Target := Files.UI_Types.Context_Menu_None;
      Highlight  : Natural := 0;
   end record;

   --  The path bar's text field, and whether the last commit failed and
   --  why. Every default is a fresh, valid field.
   type Path_Input_State is record
      Edit  : Text_Field_State;
      Valid : Boolean := True;
      Error : UString;
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
      --  The maps the row's type and icon are worked out by, as the listing
      --  it joins is classified (the settings' when the creation began, and
      --  again when they change: Reapply_Listing_Settings).
      Classes      : Files.File_Types.Classification;
   end record;

   --  A discarded background read whose reload is still owed, the view
   --  incarnation it is owed to, whether it must be forced, and the item it
   --  should select (by name, or by full path). Every default is the settled state.
   type Owed_Refresh_State is record
      Owed        : Boolean := False;
      Incarnation : Natural := 0;
      Forced      : Boolean := False;
      Selection   : UString;
      Path        : UString;
   end record;

   --  The info pane's owner or group field, and whether it edits the group
   --  rather than the owner. Every default is the idle field.
   type Ownership_Input_State is record
      Edit          : Text_Field_State;
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
   --  its command list was handed over at (Files.Model.Command_Palette.List),
   --  so it is built again (every command's enablement) only after a change. Every default is the closed state.
   type Command_Palette_State is record
      Open                   : Boolean := False;
      Mode                   : Palette_Mode := Palette_Commands;
      View                   : Guikit.Command_Palette.Palette;
      Open_With_Targets      : Files.Types.String_Vectors.Vector;
      Open_With_Applications : Files.Desktop_Application_Types.Application_Vectors.Vector;
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
      --  Children are read off the UI thread (Tree_Panel.Load_In_Background):
      --  the nodes whose children are asked for and not yet in.
      Background : Boolean := False;
      Pending    : Natural_Vectors.Vector;
   end record;

   --  Inline rename: whether it is active and one field per renamed item.
   --  Every default is the idle state.
   type Rename_State is record
      Active : Boolean := False;
      Fields : Rename_Field_Vectors.Vector;
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
      Entries  : Files.File_System_Types.Root_Entry_Vectors.Vector;
      Selected : Natural := 0;
   end record;

   --  The label picker overlay: whether it is shown and its keyboard
   --  highlight. Every default is the closed state.
   type Label_Picker_State is record
      Open   : Boolean := False;
      Swatch : Positive := Files.UI_Types.Clear_Swatch;
   end record;

   --  A loaded item's name and the same name folded for the filter.
   type Folded_Name is record
      Name   : UString;
      Folded : UString;
   end record;

   package Folded_Name_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Folded_Name);

   --  What the window layer sampled of the host (Status_Samples.Set_Host)
   --  and when; Sampled False until it did.
   type Host_Sample_State is record
      Sampled               : Boolean := False;
      Trash_Available       : Boolean := False;
      Permissions_Supported : Boolean := False;
      Ownership_Supported   : Boolean := False;
      Sampled_At            : Ada.Calendar.Time := Files.Types.Unknown_Time;
   end record;

   --  The volume-space sample and where and when it was taken; Sampled is
   --  meaningful only once Path is set. Every default is the unsampled state.
   type Volume_Sample_State is record
      Space   : Files.File_System_Types.Volume_Space;
      Path    : UString;
      Sampled : Ada.Calendar.Time;
   end record;

   --  Whether the volume of the folder Path names fold case, as the window
   --  layer asked it once for that folder. Every default is the unsampled
   --  state.
   type Name_Folding_Sample is record
      Path    : UString;
      Folding : Files.Text_Case.Path_Folding := Files.Text_Case.Ask_Each_Path;
   end record;

   --  The grouping the items are ordered by: the effective mode, the labels
   --  and day it was computed with, and whether the items have been put in
   --  band order since they were last replaced (only a new listing, a
   --  navigation or a sort moves an item; a rename keystroke, a selection or
   --  a scroll does not, so none of them walks the items again). Next_Day is
   --  the midnight Day ends at, so a pass learns the day has not turned from
   --  one clock reading. Every default is the never-synced, ungrouped state.
   type Grouping_State is record
      Mode     : Files.Preference_Types.Group_Mode := Files.Preference_Types.No_Grouping;
      Labels   : Files.Settings.Path_Label_Vectors.Vector;
      Day      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Next_Day : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Banded   : Boolean := False;
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
      Search_Scope_Value    : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Search_Results_Active : Boolean := False;
      --  Whether search results leave out their hidden items: the setting
      --  applies when the rows are worked out (Item_Is_Visible), so the
      --  results keep the hidden matches the search found, and showing
      --  hidden files again brings them back. Reset with the search state.
      Results_Hide_Hidden   : Boolean := False;
      --  The query the search results shown answer (Note_Search_Results):
      --  what they are searched again for, whatever the filter field holds
      --  since. Reset with the search state.
      Search_Query          : UString;
      --  Paths opened since the last drain, awaiting fold into the persisted
      --  recent list by the interaction layer (see Note_Recent_Open).
      Recent_Open_Queue    : Files.Types.String_Vectors.Vector;
      --  Renames and moves since the last drain, awaiting the interaction
      --  layer so labels, favorites and recent paths follow (Note_Path_Move).
      Path_Move_Queue      : Files.Types.Path_Move_Vectors.Vector;
      Items                : Files.Items.Item_Vectors.Vector;
      Directory_Signature  : Files.File_System_Types.Directory_Signature;
      --  The filter bar's query and caret, and the query folded
      --  (Files.Text_Case.Fold_Case) once a keystroke for matching each item.
      Filter               : Text_Field_State;
      Folded_Filter        : UString;
      Type_Ahead_Buffer_Value : UString;
      Selected_Item_Index  : Natural := 0;
      Selected_Item_Indexes : Natural_Vectors.Vector;
      --  The item a shift-extended range grows from (Range_Anchor): set by a
      --  plain or Ctrl selection and by a cursor move, kept by a range. A
      --  path, so a reload or a resort cannot turn it into another item.
      Range_Anchor_Path    : UString;
      --  The anchor's item index when it was noted (kept through a resort):
      --  checked against the path, it finds the anchor's row without a
      --  search of the items on every shift-extend. 0: search by path.
      Range_Anchor_Item    : Natural := 0;
      --  The visible rows, worked out once per listing, filter and search
      --  (Support.Invalidate_Visible at every write of those): which item each
      --  visible row is, and each item's row (0: hidden), so a visible-index
      --  lookup does not walk the items.
      Visible_Cache_Valid : Boolean := False;
      --  Moved each time the map is built again, so a caller holding rows
      --  worked out from it can tell they still stand.
      Visible_Generation  : Natural := 0;
      Visible_Items       : Natural_Vectors.Vector;
      Item_Visible_Rows   : Natural_Vectors.Vector;
      --  Each item's name folded (Files.Text_Case.Fold_Case) for the filter,
      --  by item index, with the name it was folded from: a name that no
      --  longer matches is folded again, so the map needs no invalidation of
      --  its own. Only names that are not ASCII are kept; ASCII ones match in
      --  place. Without it a filter keystroke folded every such name again.
      Folded_Names        : Folded_Name_Vectors.Vector;
      --  Hidden items among all loaded ones, counted with the map.
      Hidden_Items        : Natural := 0;
      --  Moved by scrolling alone (Scroll_Revision), apart from Revision:
      --  a scroll changes three numbers of the snapshot, not its items.
      Scroll_Revision_Value : Natural := 0;
      Selection_Columns   : Positive := 1;
      Selection_Page_Rows_Value : Positive := 10;
      --  Set by Select_By_Name, cleared once the window revealed it.
      Reveal_Pending : Boolean := False;
      View_Value           : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons;
      Sort_Field_Value     : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Sort_Ascending       : Boolean := True;
      Sort_Menu            : Sort_Menu_State;
      --  The navigation history (Go_Back, Go_Forward); the undo history is
      --  History below.
      Back_History         : Files.Types.String_Vectors.Vector;
      Forward_History      : Files.Types.String_Vectors.Vector;
      Focus_Value          : Files.UI_Types.Focus_Target := Files.UI_Types.Focus_None;
      Path_Input           : Path_Input_State;
      Info_Pane_Open       : Boolean := False;
      Settings_Pane_Open   : Boolean := False;
      Settings_Draft_Value : Files.Settings.Settings_Draft;
      --  The settings as saved: what the pane opened on, or what was saved
      --  since (Settings_Pane.Saved_Of).
      Settings_Saved_Value : Files.Settings.Settings_Model;
      --  A held key is repeating into the pane (Settings_Pane.Note_Key_Repeat),
      --  and a change it made is in force but not yet written
      --  (Settings_Pane.Defer_Save).
      Settings_Key_Repeat    : Boolean := False;
      Settings_Save_Deferred : Boolean := False;
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
      Last_Error           : UString;
      Last_Error_Path_Value : UString;
      Last_Error_Notice_Key : UString;
      Clipboard             : Clipboard_State;
      History               : Files.Undo.History.Undo_History_State;
      Folder_Sizes            : Folder_Size_Maps.Map;
      --  Moves with every change to Folder_Sizes (Support.Note_Folder_Sizes):
      --  what a selection's total, kept across builds, is keyed on.
      Folder_Sizes_Revision   : Natural := 0;
      Selected_Folders        : Selected_Folders_Cache;
      Folder_Scan             : Files.Folder_Size.Session;
      Context_Menu                  : Context_Menu_State;
      Paste_Conflict                : Files.Paste_States.Conflict_State;
      Background_Transfers_Value    : Boolean := False;
      Paste_Exec_Job                 : Files.Jobs.Process.Session;
      Foreground_Kind               : Foreground_Job_Kind := No_Foreground_Job;
      Operation_Job                 : Files.Jobs.Process.Session;
      --  Defer_Operation_Merge's wait for the job's journal.
      Operation_Merge_Deferred      : Boolean := False;
      Operation_Merge_Deadline      : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  The folder the modal operation runs in, for its progress.
      Operation_Name                : UString;
      Refresh_Job                   : Files.Jobs.Process.Session;
      Operation_Label_Key           : UString;
      Paste_Exec                    : Files.Paste_States.Execution_State;
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
      --  See Overlay_Revision.
      Overlay_Revision_Value : Natural := 0;
      --  See Info_Revision.
      Info_Revision_Value : Natural := 0;
      --  Bumped with Revision_Value by every change of the selection.
      Selection_Revision_Value : Natural := 0;
      --  Bumped with Revision_Value by every change of a rename field's text
      --  or caret alone (Support.Touch_Rename).
      Rename_Revision_Value : Natural := 0;
      --  Whether a selected item is an archive (Selection.Has_Archive), and
      --  the selection and rows revisions it was worked out at: the Extract
      --  command's status is asked on every snapshot, and after a Select All
      --  of a large folder walked the whole selection each time. A cache
      --  filled through a constant view, like the visible-row map.
      Archive_Memo_Selection : Natural := Natural'Last;
      Archive_Memo_Rows      : Natural := Natural'Last;
      Archive_Memo_Value     : Boolean := False;
      --  What the window layer sampled of the host (Status_Samples.Set_Host).
      Host_Sample : Host_Sample_State;
      --  The volume-space sample (Set_Volume_Space).
      Volume_Sample : Volume_Sample_State;
      --  How the current folder's paths are matched (Set_Name_Folding).
      Name_Folding : Name_Folding_Sample;
      Account_Names         : Account_Names_State;
      --  The grouping the items are ordered by (Sync_Grouping).
      Grouping : Grouping_State;
      --  Narrower generation that rejects stale background directory reads
      --  without treating harmless interaction as a listing-context change.
      Listing_Revision_Value : Natural := 0;
      --  Generation of the displayed view; advanced only by navigation.
      View_Incarnation_Value : Natural := 0;
      Current_Is_Trash_Value : Boolean := False;
      --  A reload still owed (Note_Owed_Refresh).
      Owed_Refresh            : Owed_Refresh_State;
   end record;
end Files.Model;

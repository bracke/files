--  The selection over the visible rows: single, multi and range selection,
--  keyboard movement, type-ahead, and queries of what is selected.
package Files.Model.Selection is

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

   --  Select an item by name in the full loaded model. A selection made so
   --  (after a reload that names its item, Open Containing Folder, a new or
   --  renamed item) asks the window to scroll it into view: see
   --  Reveal_Is_Pending.
   --
   --  @param Model Model to update.
   --  @param Name Loaded item name to select.
   --  @return True when a matching visible item was selected.
   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean;

end Files.Model.Selection;

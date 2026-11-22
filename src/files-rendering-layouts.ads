with Files.Preference_Types;
with Ada.Containers.Vectors;

with Files.Commands;
with Files.Types;
with Files.UI_Types;
with Guikit.Item_Grid;
with Guikit.Layout;
with Guikit.Segmented;
with Guikit.Text_Fields;

--  Where everything a frame draws lies: the window's regions, the items, the
--  panels and overlays, the rows of lists and menus -- worked out from a view
--  snapshot and the window's size, by the frame builder, the hit tests
--  (Files.Rendering.Hit), the input translation (Files.Events) and the
--  window layer alike, so what is drawn and what is hit agree.
package Files.Rendering.Layouts is

   --  Pieces every region shares: the panel close button, the paddings, the
   --  font box, the default window size.

   --  A panel's top-right close (X) button: Guikit's, which every panel --
   --  files' and guikit's own -- draws and hit-tests by.
   subtype Close_Button_Layout is Guikit.Layout.Close_Button_Layout;

   --  Calculate the top-right close (X) button rectangle for an overlay panel
   --  (Guikit.Layout.Panel_Close_Button): Visible is False when the panel is
   --  too small to host the button, which is then neither drawn nor hit.
   --
   --  @param Panel_X Panel left edge in pixels.
   --  @param Panel_Y Panel top edge in pixels.
   --  @param Panel_Width Panel width in pixels.
   --  @param Panel_Height Panel height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Close-button rectangle; Visible is False when it does not fit.
   function Panel_Close_Button
     (Panel_X      : Natural;
      Panel_Y      : Natural;
      Panel_Width  : Natural;
      Panel_Height : Natural;
      Line_Height  : Positive)
      return Close_Button_Layout renames Guikit.Layout.Panel_Close_Button;

   --  An input field's inner padding at a line height: Guikit's, scaled with
   --  the text past Guikit.Layout.Reference_Line_Height.
   --
   --  @param Line_Height The line height in use.
   --  @return The padding in pixels.
   function Field_Padding (Line_Height : Positive) return Natural is
     (Guikit.Layout.Scaled (Guikit.Layout.Input_Field_Padding, Line_Height));

   --  The inset of the bottom bar's status fields (the counts and the free
   --  space) from their edges, which the splitter and the renderer share:
   --  4 px at Guikit.Layout.Reference_Line_Height, scaled with the text.
   --
   --  @param Line_Height The line height in use.
   --  @return The inset in pixels.
   function Status_Field_Padding (Line_Height : Positive) return Natural is
     (Guikit.Layout.Scaled (4, Line_Height));

   --  Height of the font box a line of text is drawn in: four fifths of the
   --  line height, the size guikit renders glyphs at.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Font box height in pixels.
   function Font_Box_Height (Line_Height : Positive) return Natural
   is (Guikit.Layout.Saturating_Multiply (Line_Height, 4) / 5);

   --  A window's size when the settings name none, and the size the smoke
   --  runs render at.
   Default_Window_Width  : constant := 1024;

   Default_Window_Height : constant := 768;

   --  The main view: its items' cells, its scroll and reveal, the marquee,
   --  the rename field, and the details columns' geometry.

   --  Per-item geometry is Guikit.Item_Grid's; the layout code here and its
   --  clients name it by these short names.
   subtype Item_Layout is Guikit.Item_Grid.Item_Layout;

   package Item_Layout_Vectors renames Guikit.Item_Grid.Item_Layout_Vectors;

   --  The item cells on screen only (Guikit.Item_Grid.Placed_Layout): what
   --  a frame draws and a pointer hits, without an entry per item.
   subtype Placed_Item_Layout is Guikit.Item_Grid.Placed_Layout;

   --  A placed layout's cell for a position: all-zero off screen.
   --
   --  @param Items Placed item cells.
   --  @param Position One-based row position.
   --  @return The position's cell.
   function Cell_At (Items : Placed_Item_Layout; Position : Positive) return Item_Layout
     renames Guikit.Item_Grid.Cell_At;

   --  The position of a placed layout's last cell.
   --
   --  @param Items Placed item cells.
   --  @return Its last position; Items.First - 1 when none is placed.
   function Last (Items : Placed_Item_Layout) return Natural renames Guikit.Item_Grid.Last;

   type Main_View_Layout is record
      Columns           : Positive := 1;
      Content_Height    : Natural := 0;
      Scroll_Pixels     : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
      --  Row geometry, so callers can tell which rows the viewport shows: an
      --  item at snapshot position P sits on row (P - 1) / Columns, Row_Stride
      --  pixels apart, each Cell_Height tall, in a Viewport_Height window that
      --  scrolls at most Max_Scroll_Pixels.
      Cell_Height       : Natural := 0;
      Row_Stride        : Natural := 0;
      Viewport_Height   : Natural := 0;
      Max_Scroll_Pixels : Natural := 0;
   end record;

   --  The main content rectangle: the main-view region inset on all sides by the
   --  content padding, dropping the inset when the region is too small to hold
   --  it. Shared by the item layout, the details header/rows, and their click
   --  hit-tests so they agree on the drawable content area.
   type Content_Rectangle is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   --  The main content rectangle for a window layout.
   --
   --  @param Layout High-level window layout metrics.
   --  @return The padded main-view content rectangle.
   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle;

   --  Geometry of one detail-view column: whether it is shown and, when shown,
   --  its left edge and width in window pixels.
   type Detail_Column_Geometry is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Width   : Natural := 0;
   end record;

   type Detail_Column_Geometry_Array is
     array (Files.Preference_Types.Detail_Column) of Detail_Column_Geometry;

   --  Calculate stable layout metrics for a window.
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Layout metrics.
   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Layout_Metrics;

   --  Calculate item rectangles for the active view mode.
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @param Whole_Content False for the rectangles on screen, where items
   --    scrolled out of view have no area; True for every item at its place
   --    in the unscrolled content (on-screen Y plus the scroll in pixels), as
   --    a marquee that scrolls the view needs.
   --  @param Window_Top With Whole_Content, where the items needed start, in
   --    the result's coordinates (the frame's, plus the scroll in pixels).
   --  @param Window_Height With Whole_Content, how far they reach: only cells
   --    overlapping that band are placed (the rest have no area), so a marquee
   --    over a large folder does not lay out every item; 0 places them all.
   --  @return Item layout rectangles in visible-item order.
   function Calculate_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Whole_Content : Boolean := False;
      Window_Top    : Natural := 0;
      Window_Height : Natural := 0)
      return Item_Layout_Vectors.Vector;

   --  The cells Calculate_Item_Layout gives an area, and only those: the
   --  layout a frame draws and a click or a marquee hits. Same parameters.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @param Whole_Content As for Calculate_Item_Layout.
   --  @param Window_Top As for Calculate_Item_Layout.
   --  @param Window_Height As for Calculate_Item_Layout.
   --  @return The placed cells, in visible-item order.
   function Place_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Whole_Content : Boolean := False;
      Window_Top    : Natural := 0;
      Window_Height : Natural := 0)
      return Placed_Item_Layout;

   --  Calculate main-view scroll metrics for the current view snapshot.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Main-view content and scrollbar layout.
   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Main_View_Layout;

   --  Where the item with Visible_Index sits among the snapshot's rows (and
   --  so in Calculate_Item_Layout's result). Visible indices count items
   --  only, while the rows also hold group-header rows when grouping is on,
   --  so the two differ after the first header.
   --
   --  @param Snapshot View snapshot holding the rows.
   --  @param Visible_Index Visible index of the item, as Hit.Item_At answers.
   --  @return One-based row position, or 0 when no row has Visible_Index.
   function Row_Position_Of
     (Snapshot      : View_Snapshot;
      Visible_Index : Natural)
      return Natural;

   --  Where one wheel step of a main view whose rows are at least a line
   --  tall takes its scroll, in lines. The view draws its offset snapped down
   --  to whole row periods, and a row period (an icon cell plus its gap) is
   --  rarely a whole number of lines, so a step in lines alone can land
   --  inside the row already shown and move nothing. The step is therefore
   --  made in rows -- at least one, as many as the lines asked for cover --
   --  from the offset actually drawn, then expressed as the fewest lines
   --  whose snapped offset is that row (Lines_For_Offset); at the end the
   --  exact maximum takes over, as the drawing does.
   --
   --  @param Main Main-view layout (row period, drawn offset).
   --  @param Line_Height Text line height in pixels.
   --  @param Maximum The view's largest scroll, in lines.
   --  @param Lines The wheel step in lines, negative towards the top.
   --  @return The scroll position the step reaches, in lines.
   function Main_View_Wheel_Lines
     (Main        : Main_View_Layout;
      Line_Height : Positive;
      Maximum     : Natural;
      Lines       : Integer)
      return Natural;

   --  The main-view scroll, in lines, that shows the item with Visible_Index
   --  whole: unchanged when it already is, otherwise just far enough that it
   --  becomes the first or the last row in view.
   --
   --  @param Snapshot View snapshot holding the item and the current scroll.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @param Visible_Index Visible index of the item to show.
   --  @return Scroll position in lines.
   function Scroll_Lines_Revealing
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Visible_Index : Positive)
      return Natural;

   --  How many whole item rows the main view shows at once (at least one).
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Rows in view.
   function Main_View_Page_Rows
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Positive;

   --  Largest line offset the main view can take, as wheel, track-click,
   --  thumb-drag and marquee auto-scroll handling all bound it: its viewport
   --  is the scrollbar track.
   --
   --  @param Main Main-view layout.
   --  @param Line_Height Pixels scrolled per line.
   --  @return Maximum scroll offset in lines; zero when no scrollbar shows.
   function Main_View_Max_Scroll
     (Main        : Main_View_Layout;
      Line_Height : Positive)
      return Natural;

   --  Normalize the two corner points of a marquee (rubber-band) drag into an
   --  origin-plus-extent rectangle so a drag in any direction (including up or
   --  left) yields a well-formed rectangle. Start is the press point, Current
   --  the live pointer.
   --
   --  @param Start_X Press-point x coordinate in framebuffer pixels.
   --  @param Start_Y Press-point y coordinate in framebuffer pixels.
   --  @param Current_X Live pointer x coordinate in framebuffer pixels.
   --  @param Current_Y Live pointer y coordinate in framebuffer pixels.
   --  @param X Normalized left edge.
   --  @param Y Normalized top edge.
   --  @param Width Normalized width (Current and Start x distance).
   --  @param Height Normalized height (Current and Start y distance).
   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural);

   --  How many text lines to auto-scroll the item view during a marquee drag,
   --  given the pointer's y and the scrollable rows region. Negative scrolls up,
   --  positive scrolls down, zero holds. It engages within one Line_Height of the
   --  region's top or bottom edge (so the pointer need not leave the window to
   --  reach beyond the fold), and accelerates with distance past the edge up to
   --  Max_Step lines per call. Lets a rubber-band gesture reach items above or
   --  below the current view.
   --
   --  @param Cursor_Y Pointer y in framebuffer pixels.
   --  @param Region_Top Top of the scrollable rows region in framebuffer pixels.
   --  @param Region_Bottom Bottom of that region in framebuffer pixels.
   --  @param Line_Height Row height in pixels; also the edge-zone thickness.
   --  @param Max_Step Largest step magnitude in lines.
   --  @return Signed line delta (negative up, positive down, zero none).
   function Marquee_Auto_Scroll_Step
     (Cursor_Y      : Integer;
      Region_Top    : Integer;
      Region_Bottom : Integer;
      Line_Height   : Positive;
      Max_Step      : Positive := 4)
      return Integer;

   --  Return the horizontal extent of an item's inline rename field.
   --
   --  Both the renderer and the click hit-test use this so the editable region
   --  they present exactly matches the region a click resolves against.
   --
   --  @param Item Item cell layout.
   --  @param View_Mode Active view mode.
   --  @param Renaming Whether the item is currently being renamed.
   --  @param Field_X Left edge of the rename field.
   --  @param Field_W Width of the rename field.
   --  @param Line_Height Current line height.
   procedure Rename_Field_Extent
     (Item        : Item_Layout;
      View_Mode   : Files.Preference_Types.View_Mode;
      Renaming    : Boolean;
      Field_X     : out Natural;
      Field_W     : out Natural;
      Line_Height : Positive);

   --  The toolbar: its buttons, the path field (breadcrumbs and the favourite
   --  star), the filter field and its scope chip, the view-mode
   --  segments, and the text fields' scrolling.

   --  Zero-based index of a left-toolbar button, left to right.
   subtype Toolbar_Button_Index is Natural range 0 .. Guikit.Layout.Toolbar_Button_Count - 1;

   --  The command each left-toolbar button triggers, by button index. The
   --  toolbar renderer and the toolbar click hit-test share this one table.
   Toolbar_Button_Commands : constant array (Toolbar_Button_Index) of Files.Commands.Registered_Command_Id :=
     [Files.Commands.Select_Drive_Command,
      Files.Commands.Navigate_Home_Command,
      Files.Commands.Navigate_Back_Command,
      Files.Commands.Navigate_Forward_Command,
      Files.Commands.Navigate_Parent_Command,
      Files.Commands.Create_File_Command,
      Files.Commands.Delete_Selected_Items_Command];

   --  The first button of the file-action group (create/delete); the buttons
   --  before it form the navigation group. The renderer widens the padding on
   --  both sides of this boundary and draws a divider at its left edge.
   First_File_Action_Button : constant Toolbar_Button_Index := 5;

   --  Height of the toolbar at Line_Height, as the layout and every hit-test
   --  use it.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Toolbar height in pixels.
   function Toolbar_Height (Line_Height : Positive) return Natural;

   type Breadcrumb_Segment_Layout is record
      Segment_Index : Natural := 0;
      X             : Natural := 0;
      Y             : Natural := 0;
      Width         : Natural := 0;
      Height        : Natural := 0;
      Clickable     : Boolean := True;
   end record;

   package Breadcrumb_Segment_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Breadcrumb_Segment_Layout);

   --  Bounding rectangle of the clickable favorite-star toggle drawn at the
   --  left of the path bar, in window pixels. Visible is False when the path
   --  bar is too narrow to reserve room for the star.
   type Path_Favorite_Star_Bounds is record
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
      Visible : Boolean := False;
   end record;

   --  Pixel width of the caret drawn in a single-line input field.
   Field_Caret_Width : constant := 2;

   --  The visible part of a focused single-line input: the leading bytes
   --  scrolled off its left edge and where its caret is drawn, by guikit's
   --  one scroll and caret rule (Guikit.Text_Fields.View_Of). Drawing and
   --  click-to-caret mapping both read it, so a click lands on the character
   --  drawn under it, and both lay Arabic out with the fonts the text is
   --  drawn with (Guikit.Text.Can_Draw_Form).
   --
   --  @param Text Field text (UTF-8).
   --  @param Cursor Caret byte offset within Text.
   --  @param Text_Width Pixel width available to the text.
   --  @param Line_Height Text line height in pixels.
   --  @return Bytes skipped and the caret's offset from the text's left edge.
   function Field_View
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Guikit.Text_Fields.View
   is (Guikit.Text_Fields.View_Of
         (Text, Cursor, Text_Width, Line_Height, Field_Caret_Width));

   --  Horizontal extent of a toolbar input field: the box drawn for it, which
   --  is also where a click focuses it, and inside it where the first
   --  character is drawn and how wide the text may run.
   type Field_Text_Region is record
      X           : Natural := 0;
      Width       : Natural := 0;
      --  The field's box, margins excluded.
      Field_X     : Natural := 0;
      Field_Width : Natural := 0;
   end record;

   --  Box and text extent of the path field: the box inside the toolbar's
   --  middle section's margins, the text after its padding and the favorite
   --  star's reserve. Drawing, the field's click zone and click-to-caret
   --  mapping all use it, so a click lands the caret on the character drawn
   --  under it and only a click on the drawn box focuses the field.
   --
   --  @param Toolbar Toolbar section layout.
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Path field box and text start and width in pixels.
   function Path_Field_Text_Region
     (Toolbar     : Guikit.Layout.Toolbar_Layout;
      Width       : Natural;
      Line_Height : Positive)
      return Field_Text_Region;

   --  Width the filter scope chip needs so its label is never abbreviated:
   --  the widest of the localized scope words (here/names/contents) plus the
   --  input-field padding on both sides.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Scope chip width in pixels that fits the longest scope label.
   function Filter_Scope_Chip_Width
     (Line_Height : Positive)
      return Natural;

   --  Box and text extent of the filter field: the box after its margin,
   --  ending before the search-scope chip, the text after its padding.
   --  Drawing, the field's click zone and click-to-caret mapping all use it.
   --
   --  @param Toolbar Toolbar section layout.
   --  @param Line_Height Text line height in pixels.
   --  @return Filter field box and text start and width in pixels.
   function Filter_Field_Text_Region
     (Toolbar     : Guikit.Layout.Toolbar_Layout;
      Line_Height : Positive)
      return Field_Text_Region;

   --  Calculate clickable breadcrumb segment rectangles inside the path bar.
   --
   --  Returns an empty vector while the path input is focused (edit mode). When
   --  the segments would overflow the path bar the leading segments are elided
   --  through Files.Breadcrumbs so the root and trailing components stay
   --  visible; the elision marker carries Clickable => False.
   --
   --  @param Snapshot View snapshot containing breadcrumb segments and focus.
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Segment rectangles in left-to-right order.
   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive)
      return Breadcrumb_Segment_Layout_Vectors.Vector;

   --  Rectangle of the clickable favorite-star toggle at the left of the path
   --  bar. Rendering, the path-bar layout, and click hit-testing all derive the
   --  star's position from this single function so they never drift.
   --
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Star bounds; Visible is False when the path bar is too narrow.
   function Path_Favorite_Star_Region
     (Width       : Natural;
      Line_Height : Positive)
      return Path_Favorite_Star_Bounds;

   --  The bottom-bar view-mode switcher cells (Small / Large / Details), left to
   --  right, labelled with their short localized names. The renderer and the
   --  click hit-test share this single definition so the variable-width cells
   --  they compute agree; the renderer enriches each cell with a tooltip and
   --  enabled state.
   --
   --  @return The three view-mode segments.
   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector;

   --  The command each view mode's switcher cell runs. The cells run left to
   --  right in View_Mode order (View_Mode_Cell), so drawing and the click
   --  hit-test read the same table.
   View_Mode_Commands : constant array (Files.Preference_Types.View_Mode) of Files.Commands.Registered_Command_Id :=
     [Files.Preference_Types.Small_Icons => Files.Commands.Select_Small_Icons_Command,
      Files.Preference_Types.Large_Icons => Files.Commands.Select_Large_Icons_Command,
      Files.Preference_Types.Details     => Files.Commands.Select_Details_Command];

   --  @param Mode A view mode.
   --  @return Its cell in View_Mode_Segments (1-based).
   function View_Mode_Cell (Mode : Files.Preference_Types.View_Mode) return Positive is
     (Files.Preference_Types.View_Mode'Pos (Mode) + 1);

   --  The bottom bar: its height and place, its status regions and the free
   --  space label.

   --  Calculate bottom-bar section and button rectangles, sizing the view-mode,
   --  sort, and info controls to their localized labels.
   --
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Three-section bottom-bar layout.
   --  @param Sort_Field The active sort field; the sort button is sized to fit
   --    only this field's label (plus the direction indicator), not the widest.
   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Guikit.Layout.Bottom_Bar_Layout;

   --  Height of the bottom bar (and of each sort-menu row) at Line_Height.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Bottom bar height in pixels.
   function Bottom_Bar_Height (Line_Height : Positive) return Natural;

   --  The bottom bar's top edge in a window Height tall, 0 when the window
   --  is no taller than the bar.
   --
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return The bar's top Y in pixels.
   function Bottom_Bar_Y (Height : Natural; Line_Height : Positive) return Natural;

   --  The rendered pixel width of Free_Space_Label, or zero when there is no
   --  free field.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @param Line_Height Row height in pixels, sizing the monospace cell.
   --  @return The free-space label width in pixels, or zero.
   function Free_Space_Label_Width
     (Snapshot : View_Snapshot; Line_Height : Positive) return Natural;

   --  Partition the bottom-bar status region into the interactive hidden-files
   --  toggle area on the left and, when a free-space field is present and there
   --  is room, a separate free-space field on the right divided by a one-pixel
   --  rule. When Free_Label_Width is zero (no free field) the toggle spans the
   --  whole region. The renderer and the click hit-test both call this so the
   --  toggle's hover/click area and the free-space field agree.
   --
   --  @param Info_X Left edge of the status region.
   --  @param Info_Width Width of the status region.
   --  @param Free_Label_Width Rendered pixel width of the free-space text, or
   --    zero when there is no free-space field.
   --  @param Toggle_Width Width of the interactive toggle area from Info_X.
   --  @param Divider_X X of the dividing rule, or zero when there is no field.
   --  @param Free_Field_X Left edge of the free-space text box, or zero.
   --  @param Free_Field_Width Width of the free-space text box, or zero.
   --  @param Free_Region_Width Width of the free-space field's interactive
   --    region, from the divider to the region's right edge, or zero.
   --  @param Line_Height Text line height used to reserve a legible count field.
   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural;
      Free_Region_Width : out Natural;
      Line_Height      : Positive);

   --  The side panels: the folder tree's region and the info pane. What lies
   --  inside the tree is Layouts.Tree's.

   type Tree_Panel_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Calculate the folder-tree sidebar panel rectangle.
   --
   --  @param Snapshot View snapshot containing tree state.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Tree sidebar panel layout.
   function Calculate_Tree_Panel_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Tree_Panel_Layout;

   --  Return the number of tree rows that fit below the title and above any
   --  destination-picker button bar.
   --
   --  @param Snapshot View snapshot containing tree-picker state.
   --  @param Layout Tree sidebar panel layout.
   --  @return Number of fully visible rows in the viewport (at least one
   --  when any content height remains).
   function Tree_Row_Capacity
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural;

   --  Largest first-row offset the folder tree can take: enough rows to bring
   --  the last row fully into the panel's row capacity.
   --
   --  @param Snapshot View snapshot containing the visible tree rows.
   --  @param Layout Tree sidebar panel layout.
   --  @return Maximum scroll offset in rows; zero when every row fits.
   function Tree_Max_Scroll
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural;

   type Info_Pane_Layout is record
      X                 : Natural := 0;
      Y                 : Natural := 0;
      Width             : Natural := 0;
      Height            : Natural := 0;
      Content_Height    : Natural := 0;
      Scroll_Pixels     : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Calculate info-pane content and scrollbar geometry.
   --
   --  @param Snapshot View snapshot containing selected metadata.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Info-pane layout and scrollbar metrics.
   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Info_Pane_Layout;

   --  Largest line offset the info pane can take, as wheel, track-click and
   --  thumb-drag handling all bound it: its viewport is the whole pane.
   --
   --  @param Info Info-pane layout.
   --  @param Line_Height Pixels scrolled per line.
   --  @return Maximum scroll offset in lines; zero when no scrollbar shows.
   function Info_Pane_Max_Scroll
     (Info        : Info_Pane_Layout;
      Line_Height : Positive)
      return Natural;

   --  The overlays and dialogs: the command palette, the settings pane, Quick
   --  Look, the label picker, the root selector and its
   --  paths, the paste conflict dialog and
   --  the paste progress. The menus' rows are Layouts.Menus'.

   --  Palette overlay geometry lives in Guikit.Layout; kept under the local
   --  name so the renderer and event code read unchanged.
   subtype Command_Palette_Layout is Guikit.Layout.Palette_Layout;

   --  Calculate command-palette search and result-section rectangles.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Command-palette layout rectangles.
   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Command_Palette_Layout;

   --  The settings pane's region: the one place drawing, clicks, the wheel
   --  and the window layer's overlay take it from.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return The settings pane's rectangle.
   function Settings_Pane_Region
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Guikit.Layout.Settings_Pane_Layout
   is (Guikit.Layout.Calculate_Settings_Pane_Layout
         (Layout.Width, Layout.Height, Layout.Toolbar_Height, Line_Height));

   --  Geometry of the centered Quick Look overlay panel, its title and its
   --  inner content region (inside the padding, below the title band).
   type Quick_Look_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Title_X    : Natural := 0;
      Title_Y    : Natural := 0;
      Title_W    : Natural := 0;
      Content_X  : Natural := 0;
      Content_Y  : Natural := 0;
      Content_Width  : Natural := 0;
      Content_Height : Natural := 0;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Calculate the centered Quick Look overlay panel rectangle and its inner
   --  content region.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Quick Look panel and content-region geometry.
   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Quick_Look_Layout;

   type Label_Swatch_Bounds is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   type Label_Swatch_Array is
     array (1 .. Files.UI_Types.Swatch_Count) of Label_Swatch_Bounds;

   --  Geometry of the centered color-label picker overlay: the outer panel,
   --  its title and its row of clickable swatches. Swatches 1 .. 7
   --  correspond to the colors Red .. Gray (Files.Preference_Types.Real_Color_Label in
   --  order); the last, Files.UI_Types.Clear_Swatch, is the "None" clear swatch.
   type Label_Picker_Layout is record
      X           : Natural := 0;
      Y           : Natural := 0;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Title_X     : Natural := 0;
      Title_Y     : Natural := 0;
      Title_W     : Natural := 0;
      Swatch_Size : Natural := 0;
      Swatches    : Label_Swatch_Array;
      Visible     : Boolean := False;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Calculate the centered color-label picker overlay panel rectangle and its
   --  row of swatch rectangles.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Label-picker panel and swatch geometry.
   function Calculate_Label_Picker_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Label_Picker_Layout;

   type Root_Selector_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
      --  The selector's inner padding at the line height it was laid out for.
      Padding    : Natural := 8;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Calculate root-selector dropdown rectangle.
   --
   --  @param Snapshot View snapshot containing root selector state.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Root-selector dropdown layout.
   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Root_Selector_Layout;

   type Root_Path_Layout is record
      Root_Index : Natural := 0;
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Selected   : Boolean := False;
   end record;

   package Root_Path_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Path_Layout);

   --  Calculate root-selector row rectangles.
   --
   --  @param Snapshot View snapshot containing root paths.
   --  @param Layout Root-selector dropdown layout.
   --  @return Root selector row rectangles in root path order.
   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector;

   --  Geometry of the centered paste-conflict dialog: the outer panel, its four
   --  action buttons (left to right) and the "apply to all" toggle row.
   type Conflict_Dialog_Layout is record
      X            : Natural := 0;
      Y            : Natural := 0;
      Width        : Natural := 0;
      Height       : Natural := 0;
      Message_X      : Natural := 0;
      Message_Y      : Natural := 0;
      Message_Width  : Natural := 0;
      Message_Height : Natural := 0;
      Apply_X      : Natural := 0;
      Apply_Y      : Natural := 0;
      Apply_Width  : Natural := 0;
      Apply_Height : Natural := 0;
      Button_Y      : Natural := 0;
      Button_Height : Natural := 0;
      Replace_X    : Natural := 0;
      Skip_X       : Natural := 0;
      Rename_X     : Natural := 0;
      Cancel_X     : Natural := 0;
      Button_Width : Natural := 0;
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

   --  Compute the centered paste-conflict dialog geometry for a window.
   --
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, button, and toggle rectangles for the dialog.
   function Calculate_Conflict_Dialog_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Conflict_Dialog_Layout;

   --  Geometry of the centered paste-progress overlay: the outer panel, the
   --  progress-bar track, and the single Cancel button.
   type Paste_Progress_Layout is record
      X             : Natural := 0;
      Y             : Natural := 0;
      Width         : Natural := 0;
      Height        : Natural := 0;
      Message_X      : Natural := 0;
      Message_Y      : Natural := 0;
      Message_Width  : Natural := 0;
      Message_Height : Natural := 0;
      Bar_X         : Natural := 0;
      Bar_Y         : Natural := 0;
      Bar_Width     : Natural := 0;
      Bar_Height    : Natural := 0;
      Cancel_X      : Natural := 0;
      Cancel_Y      : Natural := 0;
      Cancel_Width  : Natural := 0;
      Cancel_Height : Natural := 0;
   end record;

   --  Compute the centered paste-progress overlay geometry for a window.
   --
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, progress-bar, and Cancel-button rectangles for the overlay.
   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout;

   --  The whole frame: every region laid out once.

   --  Everything a frame lays out once but the per-row vectors: the window's
   --  regions, and the text bands of its two bars that every toolbar field
   --  and bottom-bar status shares.
   type Frame_Layout is record
      Layout        : Layout_Metrics;
      Main_View     : Main_View_Layout;
      Toolbar       : Guikit.Layout.Toolbar_Layout;
      Bottom        : Guikit.Layout.Bottom_Bar_Layout;
      Palette       : Command_Palette_Layout;
      Root_Selector : Root_Selector_Layout;
      Tree_Panel    : Tree_Panel_Layout;
      Info_Pane     : Info_Pane_Layout;
      Settings_Pane : Guikit.Layout.Settings_Pane_Layout;
      --  The toolbar fields' box: its top and height.
      Toolbar_Input_Y      : Natural := 0;
      Toolbar_Input_H      : Natural := 0;
      --  The band the toolbar fields' text is drawn in. The text origin is
      --  pulled up by the optical bias above the geometric centre, matching
      --  the bottom bar's optical centring (Bottom_Content_Y) exactly -- the
      --  fields share the same height -- so the text reads centred in its
      --  field, aligning with the geometric-centred toolbar icons and
      --  favourite star rather than sitting a pixel low.
      Toolbar_Input_Text_Y : Natural := 0;
      Toolbar_Input_Text_H : Natural := 0;
      --  The bottom bar's top, and the band inside its padding, optically
      --  raised, that its content is drawn in.
      Bottom_Y         : Natural := 0;
      Bottom_Content_Y : Natural := 0;
      Bottom_Content_H : Natural := 0;
   end record;

   --  Lay out a frame's regions and bar text bands, as Build_Frame_Commands
   --  draws them.
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return The frame's layout.
   function Calculate_Frame_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Frame_Layout;

private

   --  The inset of a modal dialog's content from its frame: 12 px at
   --  Guikit.Layout.Reference_Line_Height, scaled with the text.
   --
   --  @param Line_Height The line height in use.
   --  @return The inset in pixels.
   function Dialog_Padding (Line_Height : Positive) return Natural is
     (Guikit.Layout.Scaled (12, Line_Height));

   --  Height of the Choose/Cancel footer the tree panel reserves in pick
   --  mode; zero otherwise or when the panel is too short to spare a row.
   --  Here for the panel's region and for its rows (Layouts.Tree).
   --
   --  @param Snapshot View snapshot laid out.
   --  @param Layout The tree panel's region.
   --  @return The footer's height in pixels.
   function Tree_Footer_Height
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural is
     (if Snapshot.Tree_Pick_Active
        and then Layout.Width > 0
        and then Layout.Row_Height > 0
        and then Layout.Height > Guikit.Layout.Saturating_Multiply (Layout.Row_Height, 2)
      then Layout.Row_Height
      else 0);

   --  Used only by the parent's own bodies (placing items and the wheel).

   --  Lay out the visible detail columns left to right across the row content
   --  area (see the body for the sizing rules). The sticky header, the header
   --  hit-tests, and every item row share it so their columns always align.
   --
   --  @param Visible Per-column visibility flags.
   --  @param Widths Per-column customized widths in reference units (pixels at
   --  Guikit.Layout.Reference_Line_Height, scaled to Line_Height here; zero
   --  means default).
   --  @param Order Left-to-right permutation of the columns (name pinned first).
   --  @param Content_X Left edge of the detail content area.
   --  @param Content_W Width of the detail content area.
   --  @param Line_Height Text line height in pixels.
   --  @param Pad Row content padding applied before the icon gutter.
   --  @return Per-column geometry for the visible columns.
   function Compute_Detail_Columns
     (Visible     : Files.Preference_Types.Detail_Column_Visibility;
      Widths      : Files.Preference_Types.Detail_Column_Widths;
      Order       : Files.Preference_Types.Detail_Column_Order;
      Content_X   : Natural;
      Content_W   : Natural;
      Line_Height : Positive;
      Pad         : Natural)
      return Detail_Column_Geometry_Array;

   --  The fewest main-view scroll lines the drawing turns into the row
   --  boundary Target (pixels), or into the exact end when Target is the
   --  maximum. The view draws its offset snapped down to whole row periods,
   --  except that lines reaching the last pixel draw at the exact end; so
   --  moving Up to a Target short of the end takes one line less, which
   --  snaps to the row at or above Target. Rows lower than a line cannot be
   --  hit exactly: then Up rounds down and down rounds up, so the drawn
   --  offset never passes Target in the direction of travel's far side.
   --  The wheel and revealing an item both ask this, so they agree.
   --
   --  @param Main Main-view layout (row period, drawn offset, maximum).
   --  @param Line_Height Text line height in pixels.
   --  @param Target Wanted pixel offset: a row boundary, or the maximum.
   --  @param Up Whether the view is moving towards the top.
   --  @return Scroll position in lines.
   function Lines_For_Offset
     (Main        : Main_View_Layout;
      Line_Height : Positive;
      Target      : Natural;
      Up          : Boolean)
      return Natural;

   --  Inset of the path and filter input boxes inside their toolbar sections,
   --  scaled with the text (guikit's margin, which also spaces the filter box
   --  from the scope chip). Drawing, breadcrumb layout and click-to-caret
   --  mapping must all use it, or a click lands the caret beside the
   --  character it was aimed at.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return The inset in pixels.
   function Toolbar_Field_Margin (Line_Height : Positive) return Natural
     renames Guikit.Layout.Toolbar_Field_Margin;

   --  Horizontal space reserved at the left of the path bar's interior for the
   --  favorite star, in pixels. Breadcrumbs and the editable path field start
   --  this many pixels further right so they never overlap the star.
   --
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Reserved width in pixels, or zero when the star is not shown.
   function Path_Bar_Content_Offset
     (Width       : Natural;
      Line_Height : Positive)
      return Natural;

   --  Height of the details-view sticky column header: one text line plus the
   --  row padding above and below, clamped to the content height. The header
   --  drawing, its click hit-tests, and the main-view scroll viewport share it.
   --
   --  @param Content_H Height of the main content rectangle.
   --  @param Line_Height Text line height in pixels.
   --  @return Header height in pixels.
   function Details_Header_Height
     (Content_H   : Natural;
      Line_Height : Positive)
      return Natural;

end Files.Rendering.Layouts;

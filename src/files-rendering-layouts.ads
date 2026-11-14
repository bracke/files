with Ada.Containers.Vectors;

with Files.Commands;
with Files.Types;
with Guikit.Item_Grid;
with Guikit.Layout;

--  Where everything a frame draws lies: the window's regions, the items, the
--  panels and overlays, the rows of lists and menus -- worked out from a view
--  snapshot and the window's size, by the frame builder, the hit tests
--  (Files.Rendering.Hit), the input translation (Files.Events) and the
--  window layer alike, so what is drawn and what is hit agree.
package Files.Rendering.Layouts is

   --  The laid-out context menu. Its rows are Files.Commands' own (selectable
   --  commands and the non-selectable dividers that group them), so the
   --  renderer, the hit-test and the keyboard navigation share one row set.
   type Context_Menu_Layout is record
      Visible          : Boolean := False;
      X                : Natural := 0;
      Y                : Natural := 0;
      Width            : Natural := 0;
      Height           : Natural := 0;
      Row_Height       : Natural := 0;
      Separator_Height : Natural := 0;
      Padding          : Natural := 0;
      Column_Count     : Positive := 1;
      Column_Width     : Natural := 0;
      Column_Break_Row : Natural := 0;
      Row_Count        : Natural := 0;
      Rows             : Files.Commands.Context_Menu_Row_Array;
   end record;

   --  Calculate the context-menu popup rectangle and per-row geometry.
   --
   --  @param Snapshot Active view snapshot.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Menu layout; Visible is false when no menu should be rendered.
   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Context_Menu_Layout;

   --  Per-item geometry lives in Guikit.Item_Grid now; these aliases keep the
   --  existing Files.Rendering.Item_Layout / *_Vectors references compiling.
   subtype Item_Layout is Guikit.Item_Grid.Item_Layout;
   package Item_Layout_Vectors renames Guikit.Item_Grid.Item_Layout_Vectors;

   type Main_View_Layout is record
      Columns           : Positive := 1;
      Content_Height    : Natural := 0;
      Scroll_Lines      : Natural := 0;
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

   --  Palette overlay geometry lives in Guikit.Layout; kept under the local
   --  name so the renderer and event code read unchanged.
   subtype Command_Palette_Layout is Guikit.Layout.Palette_Layout;

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
   end record;

   type Label_Swatch_Bounds is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   type Label_Swatch_Array is
     array (1 .. Files.Types.Swatch_Count) of Label_Swatch_Bounds;

   --  Geometry of the centered color-label picker overlay: the outer panel,
   --  its title and its row of clickable swatches. Swatches 1 .. 7
   --  correspond to the colors Red .. Gray (Files.Types.Real_Color_Label in
   --  order); the last, Files.Types.Clear_Swatch, is the "None" clear swatch.
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
   end record;

   --  Return the color label a picker swatch index selects. Indices 1 .. 7 map
   --  to Red .. Gray; index 8 (and any out-of-range value) maps to No_Label.
   --
   --  @param Index One-based swatch index.
   --  @return The color label the swatch assigns.
   function Label_For_Swatch
     (Index : Positive)
      return Files.Types.Color_Label renames Files.Types.Label_For_Swatch;

   type Root_Selector_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
      --  The selector's inner padding at the line height it was laid out for.
      Padding    : Natural := 8;
   end record;

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
   end record;

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
   end record;

   type Tree_Row_Layout is record
      Visible_Row_Index : Natural := 0;
      Node_Index   : Natural := 0;
      X            : Natural := 0;
      Y            : Natural := 0;
      Width        : Natural := 0;
      Height       : Natural := 0;
      Depth        : Natural := 0;
      Expanded     : Boolean := False;
      Has_Children : Boolean := False;
      Selected     : Boolean := False;
      Triangle_X   : Natural := 0;
      Triangle_Y   : Natural := 0;
      Triangle_W   : Natural := 0;
      Triangle_H   : Natural := 0;
   end record;

   package Tree_Row_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tree_Row_Layout);

   --  Geometry of the destination picker's Choose (left) and Cancel (right)
   --  button bar drawn along the bottom of the folder-tree panel. Both buttons
   --  share the same Y, Height, and Button_Width.
   type Tree_Pick_Button_Layout is record
      Visible      : Boolean := False;
      Choose_X     : Natural := 0;
      Cancel_X     : Natural := 0;
      Y            : Natural := 0;
      Button_Width : Natural := 0;
      Height       : Natural := 0;
   end record;

   type Info_Pane_Layout is record
      X                 : Natural := 0;
      Y                 : Natural := 0;
      Width             : Natural := 0;
      Height            : Natural := 0;
      Content_Height    : Natural := 0;
      Scroll_Lines      : Natural := 0;
      Scroll_Pixels     : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
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

   --  The rendered pixel width of Free_Space_Label, or zero when there is no
   --  free field.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @param Line_Height Row height in pixels, sizing the monospace cell.
   --  @return The free-space label width in pixels, or zero.
   function Free_Space_Label_Width
     (Snapshot : View_Snapshot; Line_Height : Positive) return Natural;

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
      View_Mode   : Files.Types.View_Mode;
      Renaming    : Boolean;
      Field_X     : out Natural;
      Field_W     : out Natural;
      Line_Height : Positive);

   --  A details-header cell under a coordinate. Present is False when the
   --  coordinate misses the header band. Column is the column whose cell body
   --  the coordinate falls in, and Command the sort command that a plain click
   --  on it triggers (No_Command for a column that does not sort, e.g. the
   --  permissions column). Callers use Column to begin a reorder drag and
   --  Command to fall back to a sort when the press turns out to be a click.
   type Detail_Header_Cell is record
      Present : Boolean := False;
      Column  : Files.Types.Detail_Column := Files.Types.Name_Column;
      Command : Files.Commands.Command_Id := Files.Commands.No_Command;
   end record;

   --  A draggable details-header column separator. Present is False when a
   --  coordinate misses every separator hot zone. Column is the optional column
   --  a drag on this separator resizes (the column whose left edge the separator
   --  is). Origin_X is that left edge in window pixels and Width the column's
   --  current effective width, both captured so a drag can grow or shrink the
   --  column relative to the size it had when the drag began.
   type Detail_Column_Separator is record
      Present  : Boolean := False;
      Column   : Files.Types.Optional_Detail_Column := Files.Types.Modified_Column;
      Origin_X : Natural := 0;
      Width    : Natural := 0;
   end record;

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

   --  Calculate root-selector row rectangles.
   --
   --  @param Snapshot View snapshot containing root paths.
   --  @param Layout Root-selector dropdown layout.
   --  @return Root selector row rectangles in root path order.
   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector;

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

   --  Inset of the path and filter input boxes inside their toolbar sections.
   --  Drawing, breadcrumb layout and click-to-caret mapping must all use it,
   --  or a click lands the caret beside the character it was aimed at.
   Toolbar_Field_Margin : constant := 6;

   --  Display columns a focused single-line input scrolls off its left edge so
   --  the caret stays visible: typing at the end of a long path used to happen
   --  behind the field's ellipsis. Stateless, so drawing and click-to-caret
   --  mapping derive the same offset from the same text, cursor and width.
   --
   --  @param Text Field text (UTF-8).
   --  @param Cursor Caret byte offset within Text.
   --  @param Text_Width Pixel width available to the text.
   --  @param Line_Height Text line height in pixels.
   --  @return Columns hidden on the left; zero when the caret already fits.
   function Input_Scroll_Columns
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Natural;

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

   --  Calculate folder-tree row rectangles with per-depth indentation.
   --
   --  @param Snapshot View snapshot containing the visible tree rows.
   --  @param Layout Tree sidebar panel layout.
   --  @param Line_Height Text line height in pixels.
   --  @return Tree row rectangles in top-to-bottom order.
   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Row_Layout_Vectors.Vector;

   --  Calculate the destination picker's Choose/Cancel button bar geometry from
   --  the folder-tree panel layout. Visible is False when the panel is too small
   --  to host a button row below its title.
   --
   --  @param Panel Folder-tree panel layout.
   --  @param Line_Height Text line height in pixels.
   --  @return Button-bar rectangles; Visible is False when they do not fit.
   function Tree_Pick_Buttons
     (Panel       : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Pick_Button_Layout;

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

end Files.Rendering.Layouts;

with Ada.Containers.Vectors;

with Files.Commands;
with Files.Types;
with Files.UI_Types;
with Guikit.Item_Grid;
with Guikit.Layout;
with Guikit.Segmented;
with Guikit.Text;
with Guikit.Text_Fields;

--  Where everything a frame draws lies: the window's regions, the items, the
--  panels and overlays, the rows of lists and menus -- worked out from a view
--  snapshot and the window's size, by the frame builder, the hit tests
--  (Files.Rendering.Hit), the input translation (Files.Events) and the
--  window layer alike, so what is drawn and what is hit agree.
package Files.Rendering.Layouts is

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

   --  Per-item geometry is Guikit.Item_Grid's; the layout code here and its
   --  clients name it by these short names.
   subtype Item_Layout is Guikit.Item_Grid.Item_Layout;
   package Item_Layout_Vectors renames Guikit.Item_Grid.Item_Layout_Vectors;

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
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
   end record;

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
   --  correspond to the colors Red .. Gray (Files.Types.Real_Color_Label in
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
      --  Its close (X) button (Panel_Close_Button), drawn and hit alike.
      Close_Button : Close_Button_Layout;
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

   --  Compute the centered paste-progress overlay geometry for a window.
   --
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, progress-bar, and Cancel-button rectangles for the overlay.
   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout;

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

   --  Display columns a focused single-line input scrolls off its left edge so
   --  the caret stays visible (Guikit.Layout.Input_Scroll_Columns, the rule
   --  Field_View starts from). Stateless: the same text, cursor and width
   --  always give the same offset.
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
         (Text, Cursor, Text_Width, Line_Height, Field_Caret_Width, Has_Glyph => Guikit.Text.Can_Draw_Form'Access));

   --  Height of the font box a line of text is drawn in: four fifths of the
   --  line height, the size guikit renders glyphs at.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Font box height in pixels.
   function Font_Box_Height (Line_Height : Positive) return Natural
   is (Guikit.Layout.Saturating_Multiply (Line_Height, 4) / 5);

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
   --  @return Button-bar rectangles; Visible is False when they do not fit.
   function Tree_Pick_Buttons (Panel : Tree_Panel_Layout) return Tree_Pick_Button_Layout;

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

   --  The window chrome around the layouts below -- input-field and dialog
   --  paddings, the default window size, the toolbar and bottom bar, the sort
   --  dropdown, the view-mode switcher, the status-line split -- measured
   --  with the localized labels it shows, over Guikit.Layout's geometry.

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

   --  The inset of a modal dialog's content from its frame: 12 px at
   --  Guikit.Layout.Reference_Line_Height, scaled with the text.
   --
   --  @param Line_Height The line height in use.
   --  @return The inset in pixels.
   function Dialog_Padding (Line_Height : Positive) return Natural is
     (Guikit.Layout.Scaled (12, Line_Height));

   --  A window's size when the settings name none, and the size the smoke
   --  runs render at.
   Default_Window_Width  : constant := 1024;
   Default_Window_Height : constant := 768;

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

   --  Width of the sort dropdown menu: sized to the widest sort-field label (plus
   --  the direction indicator and padding), so every row fits even though the sort
   --  button itself is only as wide as the active field's label.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Sort-menu width in pixels.
   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural;

   --  Height of the toolbar at Line_Height, as the layout and every hit-test
   --  use it.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Toolbar height in pixels.
   function Toolbar_Height (Line_Height : Positive) return Natural;

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

   --  Geometry of the open sort dropdown: the menu rectangle (it opens upward
   --  from the bottom bar, left-aligned with the sort button), the top of its
   --  first row, the row height, and the row count (one row per sort field).
   type Sort_Menu_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Rows_Y     : Natural := 0;
      Row_Height : Natural := 0;
      Row_Count  : Natural := 0;
   end record;

   --  Calculate the sort dropdown geometry at a window size. The renderer and
   --  the dropdown's click hit-tests share it so the drawn rows and the rows a
   --  click resolves to cannot drift apart.
   --
   --  @param Width Framebuffer width in pixels.
   --  @param Height Framebuffer height in pixels.
   --  @param Sort_Field Currently selected sort field.
   --  @param Line_Height Text line height in pixels.
   --  @return The dropdown rectangle and row geometry.
   function Calculate_Sort_Menu_Layout
     (Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Sort_Menu_Layout;

   --  The top of dropdown row Row: the one row geometry the renderer draws
   --  and the click hit-test resolves by.
   --
   --  @param Menu The dropdown's layout (Calculate_Sort_Menu_Layout).
   --  @param Row One-based row index.
   --  @return Window Y of the row's top edge.
   function Sort_Menu_Row_Top
     (Menu : Sort_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  The dropdown row under a point, by Sort_Menu_Row_Top's rows; 0 when the
   --  point is on none, or the menu is not shown (Width 0).
   --
   --  @param Menu The dropdown's layout (Calculate_Sort_Menu_Layout).
   --  @param X Window X.
   --  @param Y Window Y.
   --  @return One-based row index, or 0.
   function Sort_Menu_Row_At
     (Menu : Sort_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  The sort field a dropdown row shows: rows follow Sort_Field's
   --  declaration order, top to bottom.
   --
   --  @param Row One-based row index, at most the layout's Row_Count.
   --  @return The sort field of that row.
   function Sort_Menu_Row_Field
     (Row : Positive)
      return Files.Types.Sort_Field
     with Pre => Row <= Files.Types.Sort_Field'Pos (Files.Types.Sort_Field'Last) + 1;

   --  The bottom-bar view-mode switcher cells (Small / Large / Details), left to
   --  right, labelled with their short localized names. The renderer and the
   --  click hit-test share this single definition so the variable-width cells
   --  they compute agree; the renderer enriches each cell with a tooltip and
   --  enabled state.
   --
   --  @return The three view-mode segments.
   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector;

   --  Width the filter scope chip needs so its label is never abbreviated:
   --  the widest of the localized scope words (here/names/contents) plus the
   --  input-field padding on both sides.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Scope chip width in pixels that fits the longest scope label.
   function Filter_Scope_Chip_Width
     (Line_Height : Positive)
      return Natural;

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

   --  Shared by the drawing and the hit tests (Files.Rendering.Hit), so what
   --  is drawn and what is hit resolve against one geometry.

   --  Return the top Y coordinate of a menu row, accounting for the smaller
   --  height of any separator rows above it. Rows have variable heights, so a
   --  simple row * Row_Height offset is not correct; callers (renderer and
   --  hit-tests) use this to place and probe rows consistently.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Top window Y coordinate of the row.
   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Return the left edge of the column containing a menu row.
   --  Compact menus can split at a group boundary into two columns.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Left window coordinate of the row's column.
   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Return the width of the column containing a menu row.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Width of the row's column.
   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Return the height of a menu row: a separator is shorter than a command.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Height of the row.
   function Context_Menu_Row_Height
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
   is (if Files.Commands."=" (Menu.Rows (Row).Kind, Files.Commands.Menu_Separator)
       then Menu.Separator_Height
       else Menu.Row_Height);

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
     array (Files.Types.Detail_Column) of Detail_Column_Geometry;

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
     (Visible     : Files.Types.Detail_Column_Visibility;
      Widths      : Files.Types.Detail_Column_Widths;
      Order       : Files.Types.Detail_Column_Order;
      Content_X   : Natural;
      Content_W   : Natural;
      Line_Height : Positive;
      Pad         : Natural)
      return Detail_Column_Geometry_Array;

   --  Where the divider before a detail column is drawn: this far left of
   --  the column's edge, in the column padding.
   --
   --  @param Column_X Left edge of the column in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return X of the one-pixel divider line.
   function Column_Separator_X (Column_X : Natural; Line_Height : Positive) return Natural
   is (Column_X - Natural'Min (Column_X, Guikit.Layout.Scaled (2, Line_Height)));

   --  Half-width, in reference pixels, of the invisible band around a column
   --  divider where a press begins a column resize: wide enough to grab,
   --  narrow enough that a click well inside a header cell still sorts.
   Column_Separator_Grab_Half_Width : constant := 5;

   --  Whether X is within the resize grab band centred on the divider drawn
   --  before a detail column.
   --
   --  @param Column_X Left edge of the column in pixels.
   --  @param X Pointer X in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return True when a press at X grabs that column's divider.
   function On_Column_Separator (Column_X : Natural; X : Natural; Line_Height : Positive) return Boolean
   is (abs (Integer (X) - Integer (Column_Separator_X (Column_X, Line_Height)))
       <= Guikit.Layout.Scaled (Column_Separator_Grab_Half_Width, Line_Height));

   --  Geometry of the details-view sticky column header: the content rectangle
   --  it spans the top of, its height and inner padding, and the column layout
   --  its cells (and every item row) align to.
   type Details_Header_Layout is record
      Content : Content_Rectangle;
      Height  : Natural := 0;
      Pad     : Natural := 0;
      Columns : Detail_Column_Geometry_Array;
   end record;

   --  The details header geometry for a snapshot and window layout. The header
   --  renderer and the header hit-tests (cell, drop slot, separator) all derive
   --  their rectangles from this one function so they cannot drift apart.
   --
   --  @param Snapshot View snapshot holding the detail-column settings.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return The header's content rectangle, height, padding, and columns.
   function Details_Header_Geometry
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Details_Header_Layout;

   --  Whether a detail column defines a sort and, when it does, the field a
   --  header click on it sorts by.
   type Detail_Column_Sort is record
      Sortable : Boolean := False;
      Field    : Files.Types.Sort_Field := Files.Types.Sort_Name;
   end record;

   --  The one mapping from a detail column to its sort field. The header label
   --  (which column shows the direction indicator) and the header click
   --  hit-test both read it. The permissions column defines no sort.
   Detail_Column_Sorts : constant array (Files.Types.Detail_Column) of Detail_Column_Sort :=
     [Files.Types.Name_Column        => (Sortable => True, Field => Files.Types.Sort_Name),
      Files.Types.Modified_Column    => (Sortable => True, Field => Files.Types.Sort_Changed),
      Files.Types.Size_Column        => (Sortable => True, Field => Files.Types.Sort_Size),
      Files.Types.Filetype_Column    => (Sortable => True, Field => Files.Types.Sort_Type),
      Files.Types.Created_Column     => (Sortable => True, Field => Files.Types.Sort_Created),
      Files.Types.Permissions_Column => (Sortable => False, Field => Files.Types.Sort_Name)];

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

private

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

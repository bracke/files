with Ada.Calendar;

with Files.Types;
with Guikit.Item_Grid;
with Guikit.Layout;

--  The metrics the layouts and the frame builder build on: paddings, column
--  widths, saturating arithmetic, and the wrapping and row counts of the info
--  pane's fields. Where something lies -- anything a drawing and a hit test
--  both resolve against -- is Files.Rendering.Layouts'; what is drawn there as
--  text or colour is Files.Rendering.Labels'. Private to Files.Rendering's
--  own units; it does not depend on Layouts.
private package Files.Rendering.Geometry is

   use type Ada.Calendar.Time;
   use type Files.Types.View_Mode;

   --  The info pane's inner padding: 10 px at the reference line height.
   --
   --  @param LH Text line height in pixels.
   --  @return The padding in pixels.
   function Info_Pane_Padding (LH : Positive) return Natural is (Guikit.Layout.Scaled (10, LH));

   --  Vertical rows the permission matrix reserves in the single-item info pane:
   --  a "Permissions" label, an R/W/E header, three cell rows (user/group/other)
   --  and one spacing row. Both the row-count math and the renderer use it so
   --  layout and scroll agree.
   Permission_Grid_Rows : constant Natural := 6;

   --  The main view's content margin: 8 px at
   --  Guikit.Layout.Reference_Line_Height, scaled with the layout's line height.
   --
   --  @param L The window's layout.
   --  @return The margin in pixels.
   function Main_Content_Padding (L : Layout_Metrics) return Natural is (Guikit.Layout.Scaled (8, L.Line_Height));

   --  The grid's own spacing (Guikit.Item_Grid draws the grid).
   --
   --  @param LH Text line height in pixels.
   --  @return The gap between grid cells in pixels.
   function Main_Grid_Gap (LH : Positive) return Natural renames Guikit.Item_Grid.Grid_Gap;

   --  The padding inside a details column (Guikit.Item_Grid's).
   --
   --  @param LH Text line height in pixels.
   --  @return The padding in pixels.
   function Details_Column_Padding (LH : Positive) return Natural renames Guikit.Item_Grid.Column_Padding;

   --  The command palette's padding, scaled with the text.
   --
   --  @param LH Text line height in pixels.
   --  @return The padding in pixels.
   function Command_Palette_Padding (LH : Positive) return Natural is
     (Guikit.Layout.Scaled (Guikit.Layout.Palette_Padding, LH));

   --  The main-view scrollbar is an overlay drawn over the content's right
   --  margin (Main_Content_Padding), not a reserved gutter, so it must be no
   --  wider than that margin or it paints over -- and steals clicks from -- the
   --  rightmost column of items. Keep it equal to the margin.
   --
   --  @param L The window's layout.
   --  @return The scrollbar width in pixels.
   function Scrollbar_Width (L : Layout_Metrics) return Natural renames Main_Content_Padding;

   --  The root selector's padding: 8 px at the reference line height.
   --
   --  @param LH Text line height in pixels.
   --  @return The padding in pixels.
   function Root_Selector_Padding (LH : Positive) return Natural is (Guikit.Layout.Scaled (8, LH));

   --  @param Value A pixel count.
   --  @param Factor Its multiplier.
   --  @return Value * Factor, or Natural'Last when that overflows.
   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural
     renames Guikit.Layout.Saturating_Multiply;

   --  Visible glyph content sits low in its Line_Height cell, so text placed at
   --  a geometric inset reads a little low. Every single-line field (toolbar
   --  inputs, bottom bar, details header) lifts its text origin by this many
   --  pixels (at the reference line height, scaled with the text) so the
   --  glyphs read as centred and the fields agree.
   Glyph_Optical_Bias : constant Natural := 2;

   --  Return a text offset lifted by the optical bias, stopping at zero.
   --
   --  @param Offset Geometric text offset (an inset or a centred Y).
   --  @param Line_Height Text line height in pixels.
   --  @return Offset minus the scaled Glyph_Optical_Bias, or zero when smaller.
   function Optically_Raised (Offset : Natural; Line_Height : Positive) return Natural is
     (if Offset >= Guikit.Layout.Scaled (Glyph_Optical_Bias, Line_Height)
      then Offset - Guikit.Layout.Scaled (Glyph_Optical_Bias, Line_Height)
      else 0);

   --  The width every time a listing shows fits in: the widest of today,
   --  yesterday, each weekday and a full date in the locale, cached per line
   --  height and locale.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return The width in pixels.
   function Time_Column_Width (Line_Height : Positive) return Natural;

   --  A details column's width when the settings give none.
   --
   --  @param Column The column.
   --  @param Line_Height Text line height in pixels.
   --  @return The width in pixels.
   function Default_Detail_Column_Width
     (Column      : Files.Types.Optional_Detail_Column;
      Line_Height : Positive)
      return Natural;

   --  @param Value A pixel count.
   --  @param Numerator The scale's numerator.
   --  @param Denominator The scale's denominator.
   --  @return Value * Numerator / Denominator, without overflowing.
   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural;

   --  @param Value A pixel count.
   --  @param Factor Its multiplier.
   --  @param Denominator The divisor.
   --  @return Value * Factor / Denominator, computed without overflowing.
   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Positive)
      return Natural;

   --  @param Left A signed offset.
   --  @param Right What is added to it.
   --  @return Left + Right, or Integer'Last when that overflows.
   function Saturating_Integer_Add
     (Left  : Integer;
      Right : Natural)
      return Integer;

   --  Cell sizing lives in Guikit.Item_Grid now; this alias keeps existing
   --  Item_Cell_Metrics references (Width/Height/Icon_Size/Large) compiling.
   subtype Item_Cell_Metrics is Guikit.Item_Grid.Cell_Metrics;

   --  Map the file-manager view mode to the grid component's neutral view kind.
   --
   --  @param Mode The view mode.
   --  @return The grid's view kind.
   function Grid_View (Mode : Files.Types.View_Mode) return Guikit.Item_Grid.View_Kind is
     (case Mode is
         when Files.Types.Small_Icons => Guikit.Item_Grid.Icons_Small,
         when Files.Types.Large_Icons => Guikit.Item_Grid.Icons_Large,
         when Files.Types.Details     => Guikit.Item_Grid.Details);

   --  The padding of a centred, titled panel (Quick Look, the label picker),
   --  which also places its title.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return The padding in pixels.
   function Titled_Panel_Padding (Line_Height : Positive) return Natural is
     (Natural'Max (Command_Palette_Padding (Line_Height), Line_Height / 2));

   --  Return the last byte of the next display line. Prefer an ASCII word
   --  boundary when one exists; an individual word longer than Capacity is
   --  still split at a valid UTF-8 display boundary.
   --
   --  @param Raw The text.
   --  @param Start The line's first byte.
   --  @param Segment_Last The last byte of the text's current line.
   --  @param Capacity Display cells the line holds.
   --  @return The line's last byte.
   function Wrapped_Line_Last
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer;
      Capacity     : Natural)
      return Integer;

   --  Whitespace used as a wrap boundary belongs to neither rendered line.
   --
   --  @param Raw The text.
   --  @param Start Where the next line would start.
   --  @param Segment_Last The last byte of the text's current line.
   --  @return The first byte past the boundary's whitespace.
   function Skip_Wrap_Whitespace
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer)
      return Integer;

   --  Visit each row Text takes when wrapped to Text_W: its index from zero
   --  and its byte range (empty for a blank row). Line breaks start a row;
   --  a long line breaks at the last blank that fits, and the blanks at the
   --  break are dropped. Counting rows (Wrapped_Line_Count) and drawing them
   --  (the info pane) both walk this, so the height laid out is the height
   --  drawn.
   --
   --  @param Text The text.
   --  @param Text_W The width it wraps to, in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @param Visit Called for each row: its index and byte range.
   --  @param First The row's first byte (Visit's).
   --  @param Last The row's last byte, before First for a blank row (Visit's).
   procedure For_Each_Wrapped_Line
     (Text        : String;
      Text_W      : Natural;
      Line_Height : Positive;
      Visit       : not null access procedure (Row : Natural; First : Integer; Last : Integer));

   --  How many rows Text takes wrapped to Text_W (For_Each_Wrapped_Line).
   --
   --  @param Text The text.
   --  @param Text_W The width it wraps to, in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return The row count.
   function Wrapped_Line_Count
     (Text        : UString;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural;

   --  The width the info pane's text wraps to.
   --
   --  @param Layout The window's layout.
   --  @param Scrollbar_W The pane's scrollbar width.
   --  @return The width in pixels.
   function Info_Text_Width
     (Layout      : Layout_Metrics;
      Scrollbar_W : Natural)
      return Natural;

   --  Rows one item's info block takes in the single-item pane: its heading
   --  and every shown field's label, wrapped value and gap.
   --
   --  @param Info The item's info block.
   --  @param Text_W The width values wrap to.
   --  @param Line_Height Text line height in pixels.
   --  @param Now The time relative times are shown at (the snapshot's).
   --  @return The row count.
   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive;
      Now         : Ada.Calendar.Time)
      return Natural;

   --  Rows the coalesced sections occupy: each section is one label row plus one
   --  gap row plus the wrapped height of every per-item value. Mirrors the single
   --  view's per-field "2 + Wrapped_Line_Count" so layout and rendering agree.
   --
   --  @param Sections Coalesced sections from Coalesced_Info_Sections.
   --  @param Text_W Available text width used for wrapping.
   --  @param Line_Height Row height in pixels.
   --  @return Total rows the coalesced sections occupy.
   function Coalesced_Info_Rows
     (Sections    : Coalesced_Section_Vectors.Vector;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural;

   --  Largest line offset a scrollable region can take: enough lines to
   --  bring the content's bottom edge into the viewport. Shared by wheel,
   --  track-click, and thumb-drag handling so their limits cannot drift.
   --
   --  @param Content_Height Total content height in pixels.
   --  @param Viewport_Height Visible height in pixels.
   --  @param Line_Height Pixels scrolled per line.
   --  @return Maximum scroll offset in lines; zero when everything fits.
   function Max_Scroll_Lines
     (Content_Height  : Natural;
      Viewport_Height : Natural;
      Line_Height     : Positive)
      return Natural is
     (if Content_Height <= Viewport_Height then 0
      else 1 + (Content_Height - Viewport_Height - 1) / Line_Height);

   --  How wide a centred dialog (paste conflict, paste progress) is: 22
   --  rows' worth, or less in a window that leaves it two rows each side.
   Dialog_Width_Rows  : constant := 22;
   Dialog_Margin_Rows : constant := 2;

   --  A centred dialog's width (Dialog_Width_Rows, Dialog_Margin_Rows).
   --
   --  @param Layout The window's layout.
   --  @param Line_Height Text line height in pixels.
   --  @return The width in pixels.
   function Dialog_Box_Width (Layout : Layout_Metrics; Line_Height : Positive) return Natural is
     (Natural'Min
        (Guikit.Layout.Saturating_Multiply (Line_Height, Dialog_Width_Rows),
         (if Layout.Width > Guikit.Layout.Saturating_Multiply (Line_Height, 2 * Dialog_Margin_Rows)
          then Layout.Width - Guikit.Layout.Saturating_Multiply (Line_Height, 2 * Dialog_Margin_Rows)
          else Layout.Width)));

   --  Where a box of Inner pixels starts, centred in Outer.
   --
   --  @param Outer The space.
   --  @param Inner The box.
   --  @return The box's offset in the space.
   function Centered (Outer : Natural; Inner : Natural) return Natural is
     (if Outer > Inner then (Outer - Inner) / 2 else 0);

   --  Whether a popup or modal panel is open, owning the pointer
   --  (Files.Rendering.Overlay_Open of any Files.Types.Input_Overlay).
   --  Tooltips of the controls it covers are not drawn then, or one could be
   --  painted over the popup.
   --
   --  @param Snapshot Snapshot to inspect.
   --  @return True when any input-owning overlay is open.
   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean is
     (Topmost_Overlay_Position (Snapshot) /= 0);

   --  Vertical padding above and below a details-view row (and the header):
   --  the grid's own, scaled with the text.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return The padding in pixels.
   function Details_Row_Padding (Line_Height : Positive) return Natural
     renames Guikit.Item_Grid.Row_Padding;

   --  Whether a point lies inside a rectangle; an empty rectangle holds none.
   --
   --  @param X Rectangle left edge.
   --  @param Y Rectangle top edge.
   --  @param Box_W Rectangle width.
   --  @param Box_H Rectangle height.
   --  @param Point_X Point X coordinate.
   --  @param Point_Y Point Y coordinate.
   --  @return True when the point is inside the rectangle.
   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean;

end Files.Rendering.Geometry;

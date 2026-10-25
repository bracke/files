--  Pure geometry hit-tests: map a window pixel to the item, row, header cell,
--  overlay control, or toolbar/bottom-bar command under it.
--
--  Every function here reads only layout values the caller already holds (a
--  snapshot, a calculated layout, the hit regions a built frame recorded) and
--  returns an index, region, or command; none touches model state, the
--  filesystem, or the GPU. Input translation (Files.Events) and the window
--  layer call these; the renderer itself never needs them.
package Files.Rendering.Hit is

   --  Return the row index at a window coordinate, or zero when outside.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param X Window X coordinate.
   --  @param Y Window Y coordinate.
   --  @return Row index between 1 and Row_Count, or 0 when outside the menu.
   function Context_Menu_Row_At
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the paste-conflict-dialog control containing a point, if any.
   --
   --  @param Frame Frame whose conflict hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The control at the point, or a region with Kind Conflict_Hit_None.
   function Conflict_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Conflict_Hit_Region;

   --  Return the info-pane permission cell containing a point, if any.
   --
   --  @param Frame Frame whose permission hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The cell at the point, or a region with Present False when none.
   function Permission_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Permission_Hit_Region;

   --  Return the info-pane ownership value containing a point, if any.
   --
   --  @param Frame Frame whose ownership hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The value at the point, or a region with Present False when none.
   function Ownership_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Ownership_Hit_Region;

   --  Return the visible item index at a position.
   --
   --  @param Items Item layout rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return Visible item index, or zero when no item is hit.
   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural;

   --  Return, in ascending order, the one-based visible indices of every item
   --  whose layout rectangle intersects the given (already normalized) marquee
   --  rectangle. Any overlap counts as a hit; a zero-area rectangle (Width or
   --  Height zero, e.g. a plain click that never dragged) touches nothing.
   --
   --  @param Items Item layout rectangles in visible-item order.
   --  @param X Marquee left edge in framebuffer pixels.
   --  @param Y Marquee top edge in framebuffer pixels.
   --  @param Width Marquee width in framebuffer pixels.
   --  @param Height Marquee height in framebuffer pixels.
   --  @return Ascending visible indices the rectangle intersects.
   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector;

   --  Hit-test a details-header coordinate against the header cell bodies,
   --  returning the column under it plus its sort command. It reports every
   --  column (including ones that do not sort) so a press can begin a
   --  column-reorder drag. Returns a cell
   --  with Present False outside the header band or the details view.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Calculated frame layout.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Line_Height Text line height in pixels.
   --  @return The header cell under the coordinate, or one with Present False.
   function Details_Header_Cell_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Header_Cell;

   --  Return the target order slot for a column-reorder drop at (X, Y): the
   --  one-based position the dragged column should occupy. It is the ordered
   --  slot of the visible column under the pointer; a drop left of the first
   --  optional column targets the slot just after the name column, and a drop
   --  past the last visible column targets the final slot. Returns 0 when the
   --  coordinate lies outside the details header band.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Calculated frame layout.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Line_Height Text line height in pixels.
   --  @return The target slot index, or 0 outside the header band.
   function Details_Header_Drop_Index
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Natural;

   --  Hit-test a details-header coordinate against the draggable column
   --  separators. Every visible optional column carries a separator on its left
   --  edge (the boundary shared with the column to its left); dragging that
   --  separator resizes the optional column. The separator hot zone takes
   --  precedence over the header cell's sort click, so a press on a separator
   --  begins a resize instead of changing the sort field. Returns a separator
   --  with Present False when the coordinate lies outside every hot zone, the
   --  header band, or the details view.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Calculated frame layout.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Line_Height Text line height in pixels.
   --  @return The separator under the coordinate, or one with Present False.
   function Details_Header_Separator_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Column_Separator;

   --  Return the root path index at a position.
   --
   --  @param Rows Root-selector row layouts.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return Root path index, or zero when no root row is hit.
   function Root_Path_At
     (Rows : Root_Path_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the breadcrumb segment index at a position, or zero.
   --
   --  @param Rows Breadcrumb segment rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based segment index of a clickable segment, or zero.
   function Breadcrumb_At
     (Rows : Breadcrumb_Segment_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the tree node index whose row contains a position, or zero.
   --
   --  @param Rows Tree row rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based tree node index, or zero when no row is hit.
   function Tree_Row_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the tree node index whose expander triangle contains a position.
   --
   --  @param Rows Tree row rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based node index when an expander triangle is hit, else zero.
   function Tree_Triangle_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the toolbar command at a window position.
   --
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Matching command or No_Command.
   function Toolbar_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id;

   --  Return the bottom-bar command at a window position.
   --
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Sort_Field Active sort field (sizes the sort button).
   --  @param Free_Label_Width Rendered pixel width of the free-space field, or
   --    zero when there is none; the hidden-files toggle stops at the divider so
   --    the separate free-space field is not part of the toggle.
   --  @param Line_Height Text line height in pixels.
   --  @return Matching command or No_Command.
   function Bottom_Bar_Command_At
     (X                : Natural;
      Y                : Natural;
      Width            : Natural;
      Height           : Natural;
      Sort_Field       : Files.Types.Sort_Field;
      Free_Label_Width : Natural := 0;
      Line_Height      : Positive := 20)
      return Files.Commands.Command_Id;

   --  Return the command for a bottom-bar sort menu row.
   --
   --  @param X Mouse X coordinate.
   --  @param Y Mouse Y coordinate.
   --  @param Width Window width.
   --  @param Height Window height.
   --  @param Sort_Field Active sort field (sizes the sort button).
   --  @param Line_Height Text line height in pixels.
   --  @return Sort command for the row, or No_Command outside the menu.
   function Bottom_Bar_Sort_Menu_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id;

   --  Return whether a point lies within the open sort-menu's full rectangle
   --  (including its padding bands), so callers can treat the menu as modal.
   --
   --  @param X Mouse X coordinate.
   --  @param Y Mouse Y coordinate.
   --  @param Width Window width.
   --  @param Height Window height.
   --  @param Sort_Field Active sort field (sizes the sort button).
   --  @param Line_Height Text line height in pixels.
   --  @return True when the point is inside the sort-menu rectangle.
   function Bottom_Bar_Sort_Menu_Contains
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Boolean;

end Files.Rendering.Hit;

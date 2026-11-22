--  The rows of the context menu and the sort menu: where the menus open,
--  where each row lies, and which row a point hits -- what their drawing
--  and their hit tests both resolve against.
package Files.Rendering.Layouts.Menus is

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

   --  Width of the sort dropdown menu: sized to the widest sort-field label (plus
   --  the direction indicator and padding), so every row fits even though the sort
   --  button itself is only as wide as the active field's label.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Sort-menu width in pixels.
   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural;

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
     with Pre => Row <= Files.UI_Types.Sort_Menu_Rows;

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

end Files.Rendering.Layouts.Menus;

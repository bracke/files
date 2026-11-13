--  Test-only access to private subprograms of Files.Rendering, kept out of the program.
package Files.Rendering.Testing is

   --  Return the palette color role that renders a color label's swatch/dot.
   --  No_Label resolves to Muted_Text_Color; it is never drawn, so the value
   --  only keeps the mapping total.
   --
   --  @param Label Color label to resolve.
   --  @return The palette role drawn in that label's color.
   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Guikit.Draw.Render_Color;

   --  Whether any overlay covers the view (what hides background tooltips).
   --
   --  @param Snapshot The view snapshot.
   --  @return True when an overlay is open.
   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean;

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

   --  Compute the centered paste-progress overlay geometry for a window.
   --
   --  @param Snapshot View snapshot (used only for consistent sizing).
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, progress-bar, and Cancel-button rectangles for the overlay.
   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout;

end Files.Rendering.Testing;

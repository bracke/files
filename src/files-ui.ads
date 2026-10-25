with Files.Types;
with Guikit.Layout;
with Guikit.Segmented;

--  Domain-coupled UI layer over the generic Guikit.Layout geometry.
--
--  This package is the thin application-side seam between the pure geometry in
--  Guikit.Layout and the file-manager domain: it looks up localized labels,
--  measures them, and delegates the rectangle math to Guikit.Layout. Mapping
--  toolbar/bottom-bar pixels to the commands they trigger lives with the other
--  hit-tests in Files.Rendering.Hit. Everything here depends on
--  Files.Localization; the geometry it composes from does not.
package Files.UI is

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
      Line_Height : Positive := 20)
      return Guikit.Layout.Bottom_Bar_Layout;

   --  Width of the sort dropdown menu: sized to the widest sort-field label (plus
   --  the direction indicator and padding), so every row fits even though the sort
   --  button itself is only as wide as the active field's label.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Sort-menu width in pixels.
   function Sort_Menu_Width
     (Line_Height : Positive := 20)
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

   --  Width of the visible sort dropdown at a particular window width. This
   --  clamps the preferred width at the right framebuffer edge and is shared by
   --  rendering and hit-testing.
   --
   --  @param Width Available framebuffer width in pixels.
   --  @param Sort_Field Currently selected sort field.
   --  @param Line_Height Text line height in pixels.
   --  @return Visible dropdown width in pixels.
   function Sort_Menu_Visible_Width
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
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
      Line_Height : Positive := 20)
      return Sort_Menu_Layout;

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
     (Line_Height : Positive := 20)
      return Natural;

   --  Calculate settings add/remove button rectangles, sizing each button to
   --  its localized label.
   --
   --  @param Pane_X Settings pane horizontal origin.
   --  @param Pane_Width Settings pane width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Right-aligned add/remove button layout.
   function Calculate_Settings_Entry_Button_Layout
     (Pane_X      : Natural;
      Pane_Width  : Natural;
      Line_Height : Positive := 20)
      return Guikit.Layout.Settings_Entry_Button_Layout;

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
   --  @param Line_Height Text line height used to reserve a legible count field.
   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural;
      Line_Height      : Positive := 20);

end Files.UI;

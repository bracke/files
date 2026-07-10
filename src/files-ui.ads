with Files.Commands;
with Files.Model;
with Guikit.Layout;
with Guikit.Segmented;

--  Domain-coupled UI layer over the generic Guikit.Layout geometry.
--
--  This package is the thin application-side seam between the pure geometry in
--  Guikit.Layout and the file-manager domain: it looks up localized labels,
--  measures them, and delegates the rectangle math to Guikit.Layout, and it
--  maps toolbar/bottom-bar pixels to the commands they trigger. Everything here
--  depends on Files.Commands and Files.Localization; the geometry it composes
--  from does not.
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
      Sort_Field  : Files.Model.Sort_Field;
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
   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural);

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
      Sort_Field       : Files.Model.Sort_Field;
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
      Sort_Field  : Files.Model.Sort_Field;
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
      Sort_Field  : Files.Model.Sort_Field;
      Line_Height : Positive := 20)
      return Boolean;

end Files.UI;

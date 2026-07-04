with Files.Commands;
with Guikit.Layout;

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
   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Guikit.Layout.Bottom_Bar_Layout;

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

   --  Return the bottom-bar command at a window position.
   --
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Matching command or No_Command.
   function Bottom_Bar_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id;

   --  Return the command for a bottom-bar sort menu row.
   --
   --  @param X Mouse X coordinate.
   --  @param Y Mouse Y coordinate.
   --  @param Width Window width.
   --  @param Height Window height.
   --  @param Line_Height Text line height in pixels.
   --  @return Sort command for the row, or No_Command outside the menu.
   function Bottom_Bar_Sort_Menu_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id;

   --  Return whether a point lies within the open sort-menu's full rectangle
   --  (including its padding bands), so callers can treat the menu as modal.
   --
   --  @param X Mouse X coordinate.
   --  @param Y Mouse Y coordinate.
   --  @param Width Window width.
   --  @param Height Window height.
   --  @param Line_Height Text line height in pixels.
   --  @return True when the point is inside the sort-menu rectangle.
   function Bottom_Bar_Sort_Menu_Contains
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Boolean;

end Files.UI;

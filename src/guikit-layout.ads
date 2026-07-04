--  Generic GUI layout geometry, free of any file-manager domain dependency.
--
--  This package holds the pure geometry shared by the toolbar, bottom bar,
--  filter bar, and settings pane: the region/rect/layout record types and the
--  calculators that turn window dimensions and pixel measurements into control
--  rectangles. Nothing here depends on the application model, commands, or
--  localization; callers that need localized labels measure them (with
--  Label_Pixel_Width) and pass the resulting pixel widths in, so the geometry
--  stays domain-free and the compiler can enforce the boundary.
package Guikit.Layout is

   Bottom_Bar_Padding : constant Natural := 4;
   Sort_Menu_Padding : constant Natural := 8;
   Input_Field_Padding : constant Natural := 8;
   Toolbar_Button_Width : constant Natural := 40;
   Toolbar_Button_Count : constant Natural := 7;

   Settings_Pane_Padding : constant Natural := 14;
   Settings_Row_Gap      : constant Natural := 8;

   --  Return whether a horizontal coordinate lies inside a rectangle span.
   --
   --  @param X Horizontal coordinate to test.
   --  @param Start_X Left edge of the span.
   --  @param Rect_Width Span width in pixels (zero means empty).
   --  @return True when X is within [Start_X, Start_X + Rect_Width).
   function Within
     (X          : Natural;
      Start_X    : Natural;
      Rect_Width : Natural)
      return Boolean;

   --  Return whether a point lies inside a rectangle.
   --
   --  @param X Horizontal coordinate to test.
   --  @param Y Vertical coordinate to test.
   --  @param Rect_X Left edge of the rectangle.
   --  @param Rect_Y Top edge of the rectangle.
   --  @param Rect_Width Rectangle width in pixels (zero means empty).
   --  @param Rect_Height Rectangle height in pixels (zero means empty).
   --  @return True when the point is inside the rectangle.
   function Within_Rect
     (X           : Natural;
      Y           : Natural;
      Rect_X      : Natural;
      Rect_Y      : Natural;
      Rect_Width  : Natural;
      Rect_Height : Natural)
      return Boolean;

   --  Multiply two values, clamping at Natural'Last instead of overflowing.
   --
   --  @param Value First operand.
   --  @param Factor Second operand.
   --  @return Value * Factor, saturated to Natural'Last.
   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural;

   --  Add two values, clamping at Natural'Last instead of overflowing.
   --
   --  @param Left First operand.
   --  @param Right Second operand.
   --  @return Left + Right, saturated to Natural'Last.
   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural;

   --  Return the pixel width of a label measured in display cells.
   --
   --  The text is measured in display units (grapheme-approximating cells) and
   --  multiplied by the cell width, so callers can size controls to arbitrary
   --  plain strings without any localization or model dependency.
   --
   --  @param Text Label text to measure.
   --  @param Cell_W Pixel advance of one display cell.
   --  @return Label width in pixels, saturated to Natural'Last.
   function Label_Pixel_Width
     (Text   : String;
      Cell_W : Natural)
      return Natural;

   --  Return the horizontal pixel advance of one text display cell.
   --
   --  Both the caret renderer and the click-to-caret hit-test measure text with
   --  this single width so a click lands exactly on the cell the caret draws at.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Pixel advance of one display cell (never zero).
   function Caret_Advance_Width
     (Line_Height : Positive := 20)
      return Positive;

   --  Return the toolbar input-field height including vertical padding.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Height of toolbar input fields.
   function Toolbar_Input_Height
     (Line_Height : Positive := 20)
      return Natural;

   --  Return the toolbar input-field Y coordinate inside the toolbar.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Vertical origin of toolbar input fields.
   function Toolbar_Input_Y
     (Line_Height : Positive := 20)
      return Natural;

   type Toolbar_Layout is record
      Left_X       : Natural := 0;
      Left_Width   : Natural := 0;
      Middle_X     : Natural := 0;
      Middle_Width : Natural := 0;
      Right_X      : Natural := 0;
      Right_Width  : Natural := 0;
   end record;

   --  Rectangle of the filter-bar search-scope chip. The chip is a small
   --  clickable control right-aligned inside the toolbar's right (filter)
   --  section; the filter input field is narrowed to end before it. Visible is
   --  False when the right section is too narrow to host the chip alongside a
   --  usable input field, in which case the chip is neither drawn nor hit-tested.
   type Scope_Chip_Region is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
   end record;

   --  Return the filter-bar search-scope chip rectangle for a toolbar layout.
   --
   --  @param Toolbar Toolbar layout containing the right (filter) section.
   --  @param Line_Height Text line height in pixels.
   --  @return Chip rectangle, with Visible reflecting whether it fits.
   function Filter_Scope_Chip_Region_Of
     (Toolbar     : Toolbar_Layout;
      Line_Height : Positive := 20)
      return Scope_Chip_Region;

   --  Return the width of the filter input field once the scope chip has been
   --  carved out of the toolbar's right section, matching the renderer's layout.
   --
   --  @param Toolbar Toolbar layout containing the right (filter) section.
   --  @param Line_Height Text line height in pixels.
   --  @return Filter input field width in pixels (never negative).
   function Filter_Input_Field_Width
     (Toolbar     : Toolbar_Layout;
      Line_Height : Positive := 20)
      return Natural;

   type Bottom_Bar_Layout is record
      View_Mode_X          : Natural := 0;
      View_Mode_Width      : Natural := 0;
      Small_Button_X       : Natural := 0;
      Small_Button_Width   : Natural := 0;
      Large_Button_X       : Natural := 0;
      Large_Button_Width   : Natural := 0;
      Details_Button_X     : Natural := 0;
      Details_Button_Width : Natural := 0;
      Sort_Button_X        : Natural := 0;
      Sort_Button_Width    : Natural := 0;
      Info_X               : Natural := 0;
      Info_Width           : Natural := 0;
      Info_Pane_X          : Natural := 0;
      Info_Pane_Width      : Natural := 0;
   end record;

   type Settings_Entry_Button_Layout is record
      Add_Button_X       : Natural := 0;
      Add_Button_Width   : Natural := 0;
      Remove_Button_X    : Natural := 0;
      Remove_Button_Width : Natural := 0;
      Total_X            : Natural := 0;
      Total_Width        : Natural := 0;
   end record;

   type Settings_Action_Button_Layout is record
      First_Button_X       : Natural := 0;
      First_Button_Width   : Natural := 0;
      Second_Button_X      : Natural := 0;
      Second_Button_Width  : Natural := 0;
      Total_X              : Natural := 0;
      Total_Width          : Natural := 0;
   end record;

   type Settings_Pane_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Text_X     : Natural := 0;
      Text_Y     : Natural := 0;
      Text_Width : Natural := 0;
   end record;

   --  Calculate toolbar section widths for a window.
   --
   --  @param Width Window width in pixels.
   --  @return Three-section toolbar layout.
   function Calculate_Toolbar_Layout
     (Width : Natural)
      return Toolbar_Layout;

   --  Return the X coordinate of a left-toolbar button.
   --
   --  @param Toolbar Toolbar layout containing the left section.
   --  @param Button_Index Zero-based left-toolbar button index.
   --  @return Button X coordinate.
   function Toolbar_Left_Button_X
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural;

   --  Return the width of a left-toolbar button.
   --
   --  @param Toolbar Toolbar layout containing the left section.
   --  @param Button_Index Zero-based left-toolbar button index.
   --  @return Button width in pixels.
   function Toolbar_Left_Button_Width
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural;

   --  Calculate bottom-bar section and button rectangles.
   --
   --  Callers measure the localized short labels themselves (with
   --  Label_Pixel_Width) and pass their pixel widths in, keeping this geometry
   --  free of any localization dependency.
   --
   --  @param Width Window width in pixels.
   --  @param Small_Label_Width Pixel width of the small-icons label.
   --  @param Large_Label_Width Pixel width of the large-icons label.
   --  @param Details_Label_Width Pixel width of the details label.
   --  @param Sort_Label_Width Pixel width of the widest sort label.
   --  @param Info_Label_Width Pixel width of the info-toggle label.
   --  @param Line_Height Text line height in pixels.
   --  @return Three-section bottom-bar layout.
   function Calculate_Bottom_Bar_Layout
     (Width               : Natural;
      Small_Label_Width   : Natural;
      Large_Label_Width   : Natural;
      Details_Label_Width : Natural;
      Sort_Label_Width    : Natural;
      Info_Label_Width    : Natural;
      Line_Height         : Positive := 20)
      return Bottom_Bar_Layout;

   --  Calculate settings add/remove button rectangles.
   --
   --  Callers measure the localized button labels themselves (with
   --  Label_Pixel_Width) and pass their pixel widths in.
   --
   --  @param Pane_X Settings pane horizontal origin.
   --  @param Pane_Width Settings pane width in pixels.
   --  @param Add_Label_Width Pixel width of the add-button label.
   --  @param Remove_Label_Width Pixel width of the remove-button label.
   --  @return Right-aligned add/remove button layout.
   function Calculate_Settings_Entry_Button_Layout
     (Pane_X             : Natural;
      Pane_Width         : Natural;
      Add_Label_Width    : Natural;
      Remove_Label_Width : Natural)
      return Settings_Entry_Button_Layout;

   --  Calculate settings reset/save button rectangles.
   --
   --  @param Text_X Settings pane text column origin.
   --  @param Text_Width Settings pane text column width.
   --  @return Two-column action button layout.
   function Calculate_Settings_Action_Button_Layout
     (Text_X     : Natural;
      Text_Width : Natural)
      return Settings_Action_Button_Layout;

   --  Calculate settings pane and inner text rectangles.
   --
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Toolbar_Height Toolbar height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Settings pane layout.
   function Calculate_Settings_Pane_Layout
     (Width          : Natural;
      Height         : Natural;
      Toolbar_Height : Natural;
      Line_Height    : Positive := 20)
      return Settings_Pane_Layout;

end Guikit.Layout;

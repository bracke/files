with Files.Commands;

--  UI layout state shared by toolbar, bottom bar, and main view code.
package Files.UI is

   Bottom_Bar_Padding : constant Natural := 4;
   Sort_Menu_Padding : constant Natural := 8;
   Input_Field_Padding : constant Natural := 8;
   Toolbar_Button_Width : constant Natural := 40;
   Toolbar_Button_Count : constant Natural := 6;

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

   Settings_Pane_Padding : constant Natural := 14;
   Settings_Row_Gap      : constant Natural := 8;

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
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Three-section bottom-bar layout.
   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Bottom_Bar_Layout;

   --  Calculate settings add/remove button rectangles.
   --
   --  @param Pane_X Settings pane horizontal origin.
   --  @param Pane_Width Settings pane width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Right-aligned add/remove button layout.
   function Calculate_Settings_Entry_Button_Layout
     (Pane_X      : Natural;
      Pane_Width  : Natural;
      Line_Height : Positive := 20)
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

end Files.UI;

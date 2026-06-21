with Files.Commands;

--  UI layout state shared by toolbar, bottom bar, and main view code.
package Files.UI is

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
      Info_X               : Natural := 0;
      Info_Width           : Natural := 0;
      Info_Pane_X          : Natural := 0;
      Info_Pane_Width      : Natural := 0;
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
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Three-section bottom-bar layout.
   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Bottom_Bar_Layout;

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

end Files.UI;

with Ada.Containers;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Localization;
with Files.UI;
with Guikit.Utf8;
with Files.Rendering.Geometry;

package body Files.Rendering.Layouts is

   use Files.Rendering.Geometry;
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.Types.Focus_Target;
   use type Files.Types.View_Mode;

   function Free_Space_Label_Width
     (Snapshot : View_Snapshot; Line_Height : Positive) return Natural
   is
      Label  : constant String := Free_Space_Label (Snapshot);
      Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
   begin
      --  Bar mode reserves a fixed-width band for the graphical bar.
      if Free_Space_Bar_Active (Snapshot) then
         return Saturating_Multiply (Line_Height, 3);
      end if;

      return Saturating_Multiply (Guikit.Utf8.Display_Units (Label), Cell_W);
   end Free_Space_Label_Width;

   function Metrics_For
     (Mode        : Files.Types.View_Mode;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Item_Cell_Metrics
   is
   begin
      return Guikit.Item_Grid.Cell_Metrics_For (Grid_View (Mode), Main_Width, Line_Height);
   end Metrics_For;

   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Layout_Metrics
 is separate;

   function Calculate_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Whole_Content : Boolean := False;
      Window_Top    : Natural := 0;
      Window_Height : Natural := 0)
      return Item_Layout_Vectors.Vector
 is separate;

   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Main_View_Layout
 is separate;

   function Row_Position_Of
     (Snapshot      : View_Snapshot;
      Visible_Index : Natural)
      return Natural
 is separate;

   function Scroll_Lines_Revealing
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Visible_Index : Positive)
      return Natural
 is separate;

   function Main_View_Page_Rows
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Positive
 is separate;

   function Calculate_Conflict_Dialog_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Conflict_Dialog_Layout
 is separate;

   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Context_Menu_Layout
 is separate;

   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural)
      renames Guikit.Item_Grid.Marquee_Rect;

   function Marquee_Auto_Scroll_Step
     (Cursor_Y      : Integer;
      Region_Top    : Integer;
      Region_Bottom : Integer;
      Line_Height   : Positive;
      Max_Step      : Positive := 4)
      return Integer
   is
      subtype Wide_Integer is Long_Long_Integer;

      Cursor      : constant Wide_Integer := Wide_Integer (Cursor_Y);
      Top_Edge    : constant Wide_Integer :=
        Wide_Integer (Region_Top) + Wide_Integer (Line_Height);
      Bottom_Edge : constant Wide_Integer :=
        Wide_Integer (Region_Bottom) - Wide_Integer (Line_Height);
      Line        : constant Wide_Integer := Wide_Integer (Line_Height);
      Limit       : constant Wide_Integer := Wide_Integer (Max_Step);
      Step        : Wide_Integer;
   begin
      if Cursor < Top_Edge then
         Step := Wide_Integer'Min
           (Limit, 1 + (Top_Edge - Cursor) / Line);
         return -Integer (Step);
      elsif Cursor > Bottom_Edge then
         Step := Wide_Integer'Min
           (Limit, 1 + (Cursor - Bottom_Edge) / Line);
         return Integer (Step);
      else
         return 0;
      end if;
   end Marquee_Auto_Scroll_Step;

   procedure Rename_Field_Extent
     (Item        : Item_Layout;
      View_Mode   : Files.Types.View_Mode;
      Renaming    : Boolean;
      Field_X     : out Natural;
      Field_W     : out Natural;
      Line_Height : Positive) is
   begin
      Guikit.Item_Grid.Rename_Field_Extent (Item, Grid_View (View_Mode), Renaming, Field_X, Field_W, Line_Height);
   end Rename_Field_Extent;

   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Command_Palette_Layout is
   begin
      --  The palette always carries a title, so reserve the title band the
      --  component renders, or clicks on results would be offset from the
      --  drawn rows.
      return Guikit.Layout.Calculate_Palette_Layout
        (Command_X      => Layout.Command_X,
         Command_Y      => Layout.Command_Y,
         Command_Width  => Layout.Command_Width,
         Command_Height => Layout.Command_Height,
         Line_Height    => Line_Height,
         Title_Height   => Guikit.Layout.Palette_Title_Height (Line_Height));
   end Calculate_Command_Palette_Layout;

   procedure Titled_Panel_Title
     (Panel_X, Panel_Y, Panel_W : Natural;
      Line_Height               : Positive;
      Title_X, Title_Y, Title_W : out Natural)
   is
      Margin : constant Natural := Titled_Panel_Padding (Line_Height);
   begin
      Title_X := Guikit.Layout.Saturating_Add (Panel_X, Margin);
      Title_Y := Guikit.Layout.Saturating_Add (Panel_Y, Guikit.Layout.Panel_Edge_Inset (Line_Height));
      --  As the guikit panels title theirs: clear of the close button.
      Title_W :=
        (if Panel_W > Guikit.Layout.Saturating_Add (Margin, Guikit.Layout.Close_Button_Reserve (Line_Height))
         then Panel_W - Margin - Guikit.Layout.Close_Button_Reserve (Line_Height)
         else 0);
   end Titled_Panel_Title;

   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Quick_Look_Layout
   is
      Padding   : constant Natural := Titled_Panel_Padding (Line_Height);
      --  A large centered panel: roughly three quarters of the window, with a
      --  sensible floor so it stays usable in tiny windows.
      Panel_W   : constant Natural :=
        Natural'Min (Layout.Width, Natural'Max (Saturating_Multiply (Line_Height, 16),
                                                Bounded_Product_Divide (Layout.Width, 3, 4)));
      Panel_H   : constant Natural :=
        Natural'Min (Layout.Height, Natural'Max (Saturating_Multiply (Line_Height, 12),
                                                 Bounded_Product_Divide (Layout.Height, 3, 4)));
      Panel_X   : constant Natural :=
        Centered (Layout.Width, Panel_W);
      Panel_Y   : constant Natural :=
        Centered (Layout.Height, Panel_H);
      --  The title band reserves one line height plus padding at the top.
      Desired_Title_H : constant Natural := Guikit.Layout.Saturating_Add (Line_Height, Padding);
      Title_H   : constant Natural := Natural'Min (Desired_Title_H, Panel_H);
      Horizontal_Padding : constant Natural := Natural'Min (Padding, Panel_W / 2);
      Remaining_H : constant Natural := Panel_H - Title_H;
      Bottom_Padding : constant Natural := Natural'Min (Padding, Remaining_H);
      Content_X : constant Natural := Guikit.Layout.Saturating_Add (Panel_X, Horizontal_Padding);
      Content_Y : constant Natural := Guikit.Layout.Saturating_Add (Panel_Y, Title_H);
      Used_W    : constant Natural := Saturating_Multiply (Horizontal_Padding, 2);
   begin
      return Result : Quick_Look_Layout :=
        (X              => Panel_X,
         Y              => Panel_Y,
         Width          => Panel_W,
         Height         => Panel_H,
         Content_X      => Content_X,
         Content_Y      => Content_Y,
         Content_Width  => Panel_W - Used_W,
         Content_Height => Remaining_H - Bottom_Padding,
         others         => 0)
      do
         Titled_Panel_Title (Panel_X, Panel_Y, Panel_W, Line_Height, Result.Title_X, Result.Title_Y, Result.Title_W);
      end return;
   end Calculate_Quick_Look_Layout;

   function Calculate_Label_Picker_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Label_Picker_Layout
   is separate;

   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Root_Selector_Layout
   is
      Preferred_Width : constant Natural := Natural'Max (Layout.Width / 3, Saturating_Multiply (Line_Height, 18));
      Dropdown_Width  : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Row_Height      : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Guikit.Layout.Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Field_Padding (Line_Height), 2)),
           Saturating_Multiply (Root_Selector_Padding (Line_Height), 2));
      Wanted_Height   : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Saturating_Multiply (Natural (Snapshot.Roots.Length), Row_Height),
           Saturating_Multiply (Root_Selector_Padding (Line_Height), 2));
      Dropdown_Height : constant Natural := Natural'Min (Layout.Main_Height, Wanted_Height);
   begin
      if not Snapshot.Root_Selector_Open then
         return (others => <>);
      end if;

      return
        (X          => 0,
         Y          => Layout.Toolbar_Height,
         Width      => Dropdown_Width,
         Height     => Dropdown_Height,
         Row_Height => Row_Height,
         Padding    => Root_Selector_Padding (Line_Height));
   end Calculate_Root_Selector_Layout;

   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector
 is separate;

   function Path_Favorite_Star_Region
     (Width       : Natural;
      Line_Height : Positive)
      return Path_Favorite_Star_Bounds
   is
      Toolbar      : constant Guikit.Layout.Toolbar_Layout :=
        Guikit.Layout.Calculate_Toolbar_Layout (Width, Line_Height);
      Field_Margin : constant Natural := Toolbar_Field_Margin;
      Path_X       : constant Natural := Guikit.Layout.Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Pad          : constant Natural := Files.UI.Field_Padding (Line_Height);
      --  Box for the drawn favourite star (a filled/outline vector shape); a
      --  near-line-height square so the star reads clearly at the input height.
      Star_W       : constant Positive := Line_Height;
   begin
      if Toolbar.Middle_Width
        <= Guikit.Layout.Saturating_Add
             (Saturating_Multiply (Field_Margin, 2), Guikit.Layout.Saturating_Add (Star_W, Pad))
      then
         return (others => <>);
      end if;
      return
        (X       => Guikit.Layout.Saturating_Add (Path_X, Pad),
         Y       => Guikit.Layout.Toolbar_Input_Y (Line_Height),
         Width   => Star_W,
         Height  => Guikit.Layout.Toolbar_Input_Height (Line_Height),
         Visible => True);
   end Path_Favorite_Star_Region;

   function Path_Field_Text_Region
     (Toolbar : Guikit.Layout.Toolbar_Layout; Width : Natural; Line_Height : Positive) return Field_Text_Region
     is separate;

   function Filter_Field_Text_Region
     (Toolbar : Guikit.Layout.Toolbar_Layout; Line_Height : Positive) return Field_Text_Region is separate;

   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive)
      return Breadcrumb_Segment_Layout_Vectors.Vector
 is separate;

   --  Height of the Choose/Cancel footer the tree panel reserves in pick
   --  mode; zero otherwise or when the panel is too short to spare a row.
   function Tree_Footer_Height
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural is
     (if Snapshot.Tree_Pick_Active
        and then Layout.Width > 0
        and then Layout.Row_Height > 0
        and then Layout.Height > Saturating_Multiply (Layout.Row_Height, 2)
      then Layout.Row_Height
      else 0);

   --  Height left for folder rows below the header and above any footer.
   function Tree_Content_Height
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural
   is
      Reserved : constant Natural :=
        Guikit.Layout.Saturating_Add (Layout.Row_Height, Tree_Footer_Height (Snapshot, Layout));
   begin
      return (if Layout.Height > Reserved then Layout.Height - Reserved else 0);
   end Tree_Content_Height;

   function Calculate_Tree_Panel_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Tree_Panel_Layout
 is separate;

   function Input_Scroll_Columns
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Natural
   is
     (Guikit.Layout.Input_Scroll_Columns
        (Guikit.Utf8.Display_Units_Before (Text, Natural'Min (Cursor, Text'Length)), Text_Width, Line_Height));

   function Tree_Row_Capacity (Snapshot : View_Snapshot; Layout : Tree_Panel_Layout) return Natural is separate;

   function Main_View_Max_Scroll (Main : Main_View_Layout; Line_Height : Positive) return Natural is separate;

   function Info_Pane_Max_Scroll (Info : Info_Pane_Layout; Line_Height : Positive) return Natural is separate;

   function Tree_Max_Scroll (Snapshot : View_Snapshot; Layout : Tree_Panel_Layout) return Natural is separate;

   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Row_Layout_Vectors.Vector
 is separate;

   function Tree_Pick_Buttons
     (Panel       : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Pick_Button_Layout
   is
      pragma Unreferenced (Line_Height);
      Height : constant Natural := Panel.Row_Height;
      Half   : constant Natural := Panel.Width / 2;
   begin
      --  Need room for the title band, at least one row, and the button bar.
      if Panel.Width = 0
        or else Height = 0
        or else Panel.Height <= Saturating_Multiply (Height, 2)
      then
         return (others => <>);
      end if;

      return
        (Visible      => True,
         Choose_X     => Panel.X,
         Cancel_X     => Guikit.Layout.Saturating_Add (Panel.X, Half),
         Y            => Guikit.Layout.Saturating_Add (Panel.Y, Panel.Height - Height),
         Button_Width => Half,
         Height       => Height);
   end Tree_Pick_Buttons;

   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Info_Pane_Layout
 is separate;

end Files.Rendering.Layouts;

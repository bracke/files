with Ada.Containers;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Localization;
with Guikit.Utf8;
with Files.Rendering.Geometry;
with Files.Rendering.Labels;

package body Files.Rendering.Layouts is

   use Files.Rendering.Geometry;
   use Files.Rendering.Labels;
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

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
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
   is separate;

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
   is separate;

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
   is separate;

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
      Pad          : constant Natural := Field_Padding (Line_Height);
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

   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Guikit.Layout.Bottom_Bar_Layout
   is separate;

   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural
   is separate;

   function Toolbar_Height (Line_Height : Positive) return Natural is
     (Guikit.Layout.Saturating_Multiply (Line_Height, 2));

   function Bottom_Bar_Y (Height : Natural; Line_Height : Positive) return Natural is
     (if Height > Bottom_Bar_Height (Line_Height) then Height - Bottom_Bar_Height (Line_Height) else 0);

   function Bottom_Bar_Height (Line_Height : Positive) return Natural is
     (Guikit.Layout.Saturating_Add
        (Line_Height,
         Guikit.Layout.Saturating_Multiply
           (Guikit.Layout.Scaled (Guikit.Layout.Bottom_Bar_Padding, Line_Height), 2)));

   function Sort_Menu_Row_Top
     (Menu : Sort_Menu_Layout;
      Row  : Positive)
      return Natural is
     (Guikit.Layout.Saturating_Add (Menu.Rows_Y, Guikit.Layout.Saturating_Multiply (Row - 1, Menu.Row_Height)));

   function Sort_Menu_Row_At
     (Menu : Sort_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural
   is separate;

   function Calculate_Sort_Menu_Layout
     (Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Sort_Menu_Layout
   is separate;

   function Sort_Menu_Row_Field
     (Row : Positive)
      return Files.Types.Sort_Field is (Files.Types.Sort_Field'Val (Row - 1));

   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector
   is separate;

   function Filter_Scope_Chip_Width
     (Line_Height : Positive)
      return Natural
   is separate;

   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural;
      Free_Region_Width : out Natural;
      Line_Height      : Positive)
   is separate;

end Files.Rendering.Layouts;

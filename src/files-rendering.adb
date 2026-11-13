with Files.File_System;
with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with Files.Fonts;
with Guikit.Segmented;
with Guikit.Text;
with Guikit.Widgets;
with Files.Display_Text;
with Files.Localization;
with Files.UI;
with Files.UTF8;

package body Files.Rendering is

   --  Thumbnail pixels never contribute to Item_Snapshot equality (see the
   --  Thumbnail_Bitmap type in the spec).
   overriding function "=" (Left, Right : Thumbnail_Bitmap) return Boolean is
      pragma Unreferenced (Left, Right);
   begin
      return True;
   end "=";

   --  Text rendering is provided by the guikit toolkit. One renderer (fonts
   --  and atlas) per text configuration, shared by the windows that use it:
   --  windows at different zoom levels each keep theirs, instead of loading
   --  the fonts again every time the other one draws. The least recently
   --  used is reloaded when a fifth configuration is needed.
   Max_Pooled_Renderers : constant := 4;
   type Pooled_Renderer is limited record
      Key  : UString;
      Used : Natural := 0;
      R    : Guikit.Text.Renderer;
   end record;
   Pool       : array (1 .. Max_Pooled_Renderers) of Pooled_Renderer;
   Pool_Clock : Natural := 0;

   --  Mark Slot as used now: every use advances the clock, so of two windows
   --  drawing between loads the one that drew last is the more recent. On
   --  the (distant) wrap every stamp starts over.
   procedure Touch (Slot : Positive) is
   begin
      if Pool_Clock = Natural'Last then
         for Item of Pool loop
            Item.Used := 0;
         end loop;
         Pool_Clock := 0;
      end if;
      Pool_Clock := Pool_Clock + 1;
      Pool (Slot).Used := Pool_Clock;
   end Touch;

   --  Parsed icon assets by their text: every icon drawn was parsed again on
   --  every frame rebuild. Keyed by the text itself, so a theme switch or
   --  another asset source (the tests install their own) never reuses a
   --  stale parse. A theme has a few dozen icons; the bound only guards
   --  against an unbounded source.
   package Parsed_Asset_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Guikit.Draw.Icon_Asset,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Guikit.Draw."=");
   Parsed_Assets     : Parsed_Asset_Maps.Map;
   Max_Parsed_Assets : constant := 512;

   --  The icon Name of Theme, parsed.
   function Parsed_Icon_Asset (Name, Theme : String) return Guikit.Draw.Icon_Asset is
      Text     : constant String := Guikit.Draw.Icon_Asset_Text (Name, Theme);
      Position : constant Parsed_Asset_Maps.Cursor := Parsed_Assets.Find (Text);
   begin
      if Parsed_Asset_Maps.Has_Element (Position) then
         return Parsed_Asset_Maps.Element (Position);
      end if;
      declare
         Asset : constant Guikit.Draw.Icon_Asset := Guikit.Draw.Parse_Icon_Asset (Text);
      begin
         if Natural (Parsed_Assets.Length) >= Max_Parsed_Assets then
            Parsed_Assets.Clear;
         end if;
         Parsed_Assets.Insert (Text, Asset);
         return Asset;
      end;
   end Parsed_Icon_Asset;

   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Calendar.Time;
   use type Files.Commands.Registered_Command_Id;
   use type Files.Types.Sort_Field;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Quick_Look.Content_Kind;
   use type Files.Types.Color_Label;
   use type Text_Render_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Group_Mode;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;

   Ellipsis_Text : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  U+00D7 MULTIPLICATION SIGN, the conventional close-affordance glyph.
   Close_Glyph_Text : constant String :=
     [Character'Val (16#C3#), Character'Val (16#97#)];
   --  Separator drawn between breadcrumb segments; a path-like glyph, not text.
   Breadcrumb_Separator_Text : constant String := ">";
   --  U+2605 BLACK STAR: the filled favorite indicator/toggle glyph, a symbol
   --  rather than translatable text.
   Favorite_Star_Filled_Text : constant String :=
     [Character'Val (16#E2#), Character'Val (16#98#), Character'Val (16#85#)];
   --  Folder-tree expander glyphs: a plus/minus affordance, not translatable text.
   Tree_Expander_Collapsed_Text : constant String := "+";
   Tree_Expander_Expanded_Text  : constant String := "-";
   function Info_Pane_Padding (LH : Positive) return Natural is (Guikit.Layout.Scaled (10, LH));
   --  Vertical rows the permission matrix reserves in the single-item info pane:
   --  a "Permissions" label, an R/W/E header, three cell rows (user/group/other)
   --  and one spacing row. Both the row-count math and the renderer use it so
   --  layout and scroll agree.
   Permission_Grid_Rows : constant Natural := 6;
   --  8 px at Guikit.Layout.Reference_Line_Height, scaled with the layout's line height.
   function Main_Content_Padding (L : Layout_Metrics) return Natural is (Guikit.Layout.Scaled (8, L.Line_Height));
   --  The grid's own spacing (Guikit.Item_Grid draws the grid).
   function Main_Grid_Gap (LH : Positive) return Natural renames Guikit.Item_Grid.Grid_Gap;
   function Details_Column_Padding (LH : Positive) return Natural renames Guikit.Item_Grid.Column_Padding;
   function Command_Palette_Padding (LH : Positive) return Natural is
     (Guikit.Layout.Scaled (Guikit.Layout.Palette_Padding, LH));
   --  The main-view scrollbar is an overlay drawn over the content's right
   --  margin (Main_Content_Padding), not a reserved gutter, so it must be no
   --  wider than that margin or it paints over -- and steals clicks from -- the
   --  rightmost column of items. Keep it equal to the margin.
   function Scrollbar_Width (L : Layout_Metrics) return Natural renames Main_Content_Padding;
   function Root_Selector_Padding (LH : Positive) return Natural is (Guikit.Layout.Scaled (8, LH));

   function Clock_Time_Text (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Clock_Time_Text;
   function Full_Time_Text (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Full_Time_Text;
   function Weekday_Key (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Weekday_Key;
   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time := Ada.Calendar.Clock)
      return String renames Files.Display_Text.Humanized_Time_Text;

   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean is
     (Guikit.Layout.Within_Rect (Point_X, Point_Y, X, Y, Box_W, Box_H));

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural
     renames Guikit.Layout.Saturating_Add;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural
     renames Guikit.Layout.Saturating_Multiply;

   --  Visible glyph content sits low in its Line_Height cell, so text placed at
   --  a geometric inset reads a little low. Every single-line field (toolbar
   --  inputs, bottom bar, details header) lifts its text origin by this many
   --  pixels (at the reference line height, scaled with the text) so the
   --  glyphs read as centred and the fields agree.
   Glyph_Optical_Bias : constant Natural := 2;

   --  Return a text offset lifted by the optical bias, stopping at zero.
   --
   --  @param Offset Geometric text offset (an inset or a centred Y).
   --  @param Line_Height Text line height in pixels.
   --  @return Offset minus the scaled Glyph_Optical_Bias, or zero when smaller.
   function Optically_Raised (Offset : Natural; Line_Height : Positive) return Natural is
     (if Offset >= Guikit.Layout.Scaled (Glyph_Optical_Bias, Line_Height)
      then Offset - Guikit.Layout.Scaled (Glyph_Optical_Bias, Line_Height)
      else 0);

   --  Proportional default width for a toggleable column, scaled to the line
   --  height so the layout tracks the font size. Applied whenever the settings
   --  do not pin an explicit width for the column.
   --
   --  @param Column Toggleable detail column.
   --  @param Line_Height Text line height in pixels.
   --  @return Default column width in pixels.
   --  The widest text a time column can show in the current time locale --
   --  every relative form ("Today", each weekday) with a clock time, and a full
   --  date with two-digit fields -- measured at the advance the renderer draws
   --  at, plus the cell padding. A fixed multiple of the line height cut off
   --  "Donnerstag 17:00:00" and "21.10.2026, 17:00:00". Cached per locale and
   --  line height: layouts ask on every frame.
   Cached_Time_Width        : Natural := 0;
   Cached_Time_Width_Height : Natural := 0;
   Cached_Time_Width_Locale : Ada.Strings.Unbounded.Unbounded_String;

   function Time_Column_Width (Line_Height : Positive) return Natural is
      Locale : constant String := Files.Localization.System_Time_Locale;
   begin
      if Cached_Time_Width_Height /= Line_Height
        or else Ada.Strings.Unbounded.To_String (Cached_Time_Width_Locale) /= Locale
      then
         declare
            Sample  : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (2026, 12, 28, 86_399.0);
            Clock   : constant String := Clock_Time_Text (Sample);
            Advance : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
            Widest  : Natural := Guikit.Layout.Label_Pixel_Width (Full_Time_Text (Sample), Advance);

            procedure Consider (Key : String) is
            begin
               Widest :=
                 Natural'Max
                   (Widest,
                    Guikit.Layout.Label_Pixel_Width
                      (Files.Localization.Text (Key, Locale) & " " & Clock, Advance));
            end Consider;
         begin
            Consider ("time.relative.today");
            Consider ("time.relative.yesterday");
            for Day in Ada.Calendar.Formatting.Day_Name loop
               Consider (Weekday_Key (Sample + Duration (Ada.Calendar.Formatting.Day_Name'Pos (Day)) * 86_400.0));
            end loop;
            --  Padding before the text and a gap of the same again either side of
            --  the column divider.
            Cached_Time_Width := Saturating_Add (Widest, 3 * Details_Column_Padding (Line_Height));
         end;
         Cached_Time_Width_Height := Line_Height;
         Cached_Time_Width_Locale := Ada.Strings.Unbounded.To_Unbounded_String (Locale);
      end if;
      return Cached_Time_Width;
   end Time_Column_Width;

   function Default_Detail_Column_Width
     (Column      : Files.Types.Optional_Detail_Column;
      Line_Height : Positive)
      return Natural is
   begin
      case Column is
         when Files.Types.Modified_Column | Files.Types.Created_Column =>
            return Time_Column_Width (Line_Height);
         when Files.Types.Size_Column =>
            return Saturating_Multiply (Line_Height, 6);
         when Files.Types.Filetype_Column =>
            return Saturating_Multiply (Line_Height, 9);
         when Files.Types.Permissions_Column =>
            return Saturating_Multiply (Line_Height, 8);
      end case;
   end Default_Detail_Column_Width;

   --  Lay out the visible detail columns left to right across the row content
   --  area. The mandatory name column starts after the icon gutter and absorbs
   --  whatever width the visible fixed-width columns leave behind; each
   --  toggleable column takes its customized width (clamped to the minimum) or a
   --  proportional default. The sticky header, the header hit-test, and every
   --  item row share this function so their columns always align.
   --
   --  @param Visible Per-column visibility flags.
   --  @param Widths Per-column customized widths (zero means default).
   --  @param Order Left-to-right permutation of the columns (name pinned first).
   --  @param Content_X Left edge of the detail content area.
   --  @param Content_W Width of the detail content area.
   --  @param Line_Height Text line height in pixels.
   --  @param Pad Row content padding applied before the icon gutter.
   --  @return Per-column geometry for the visible columns.
   function Compute_Detail_Columns
     (Visible     : Files.Types.Detail_Column_Visibility;
      Widths      : Files.Types.Detail_Column_Widths;
      Order       : Files.Types.Detail_Column_Order;
      Content_X   : Natural;
      Content_W   : Natural;
      Line_Height : Positive;
      Pad         : Natural)
      return Detail_Column_Geometry_Array
 is separate;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Grouped_Integer_Text (Value : Long_Long_Integer) return String
     renames Files.Display_Text.Grouped_Integer_Text;
   function Size_Text (Value : Long_Long_Integer) return String renames Files.Display_Text.Size_Text;

   --  Whether the free-space field should render the graphical used/free bar
   --  (bar mode selected and the capacity totals are usable). When False the
   --  field falls back to the free/used text label.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @return True when the field should draw the used/free bar.
   function Free_Space_Bar_Active (Snapshot : View_Snapshot) return Boolean is
     (Snapshot.Show_Space_Bar
      and then Snapshot.Free_Space_Known
      and then Length (Snapshot.Last_Error_Key) = 0
      and then Snapshot.Free_Space_Bytes >= 0
      and then Snapshot.Total_Space_Bytes > 0
      and then Snapshot.Total_Space_Bytes >= Snapshot.Free_Space_Bytes);

   --  The bottom-bar free-space field's text, e.g. "12 GB free", or the empty
   --  string when free space is unknown or an error line is showing. Shared by
   --  the renderer (to draw) and the hit-test (to locate the field), so both
   --  agree on where the free-space field begins.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @return The free-space label text, or "" when there is no free field.
   function Free_Space_Label (Snapshot : View_Snapshot) return String is
   begin
      --  Omitted when free space is unknown or an error line is showing, so the
      --  status area shows no bogus free-space field in those cases.
      if not Snapshot.Free_Space_Known
        or else Length (Snapshot.Last_Error_Key) > 0
      then
         return "";
      end if;

      --  In bar mode the field is a graphical bar, so no text is drawn (falls
      --  through to text when the totals are missing).
      if Free_Space_Bar_Active (Snapshot) then
         return "";
      end if;

      --  In used-space mode, show the difference from total capacity; fall back
      --  to free space when the total is unknown or inconsistent.
      if Snapshot.Show_Used_Space
        and then Snapshot.Total_Space_Bytes > 0
        and then Snapshot.Total_Space_Bytes >= Snapshot.Free_Space_Bytes
      then
         return Files.Localization.Text
           ("status.used_space", "size", Size_Text (Snapshot.Total_Space_Bytes - Snapshot.Free_Space_Bytes));
      end if;

      return Files.Localization.Text ("status.free_space", "size", Size_Text (Snapshot.Free_Space_Bytes));
   end Free_Space_Label;

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

      return Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
   end Free_Space_Label_Width;

   function Permission_Text (Permissions : String; Inline : Boolean := False) return String
     renames Files.Display_Text.Permission_Text;

   function Folder_Contents_Text (Info : Info_Snapshot) return UString is
      Result : Unbounded_String;
      --  "1 item" / "3 items" where the locale's catalog has the plural
      --  message; else the number and the catalog's word.
      Counted : constant String :=
        Files.Localization.Count_Text ("info.contents.items.count", Info.Folder_File_Count);
   begin
      if Counted /= "" then
         Append (Result, Counted);
      else
         Append (Result, Grouped_Integer_Text (Long_Long_Integer (Info.Folder_File_Count)));
         Append (Result, " ");
         Append (Result, Files.Localization.Text ("info.contents.items"));
      end if;
      Append (Result, Files.Localization.Text ("info.contents.separator"));
      Append (Result, Size_Text (Info.Folder_Size_Bytes));
      Append (Result, " ");
      Append (Result, Files.Localization.Text ("info.contents.total"));
      if Info.Folder_Size_Capped then
         Append (Result, " ");
         Append (Result, Files.Localization.Text ("info.contents.capped"));
      end if;

      return Result;
   end Folder_Contents_Text;

   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Positive)
      return Natural is
   begin
      if Factor = 0 or else Value = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Scaled_Down (Value, Factor, Denominator);
      else
         return (Value * Factor) / Denominator;
      end if;
   end Bounded_Product_Divide;

   function Saturating_Integer_Add
     (Left  : Integer;
      Right : Natural)
      return Integer is
   begin
      if Left > Integer'Last - Integer (Right) then
         return Integer'Last;
      else
         return Left + Integer (Right);
      end if;
   end Saturating_Integer_Add;

   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Guikit.Draw.Render_Color is
   begin
      case Label is
         when Files.Types.No_Label => return Guikit.Draw.Muted_Text_Color;
         when Files.Types.Red      => return Guikit.Draw.Accent_Red_Color;
         when Files.Types.Orange   => return Guikit.Draw.Accent_Orange_Color;
         when Files.Types.Yellow   => return Guikit.Draw.Accent_Yellow_Color;
         when Files.Types.Green    => return Guikit.Draw.Accent_Green_Color;
         when Files.Types.Blue     => return Guikit.Draw.Accent_Blue_Color;
         when Files.Types.Purple   => return Guikit.Draw.Accent_Purple_Color;
         when Files.Types.Gray     => return Guikit.Draw.Accent_Gray_Color;
      end case;
   end Label_Render_Color;

   --  Cell sizing lives in Guikit.Item_Grid now; this alias keeps existing
   --  Item_Cell_Metrics references (Width/Height/Icon_Size/Large) compiling.
   subtype Item_Cell_Metrics is Guikit.Item_Grid.Cell_Metrics;

   --  Map the file-manager view mode to the grid component's neutral view kind.
   function Grid_View (Mode : Files.Types.View_Mode) return Guikit.Item_Grid.View_Kind is
     (case Mode is
         when Files.Types.Small_Icons => Guikit.Item_Grid.Icons_Small,
         when Files.Types.Large_Icons => Guikit.Item_Grid.Icons_Large,
         when Files.Types.Details     => Guikit.Item_Grid.Details);

   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle is
      Padding : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding (Layout), 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding (Layout), 2)
         then Main_Content_Padding (Layout)
         else 0);
   begin
      return
        (X      => Saturating_Add (Layout.Main_X, Padding),
         Y      => Saturating_Add (Layout.Main_Y, Padding),
         Width  => (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
                    then Layout.Main_Width - Saturating_Multiply (Padding, 2)
                    else Layout.Main_Width),
         Height => (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
                    then Layout.Main_Height - Saturating_Multiply (Padding, 2)
                    else Layout.Main_Height));
   end Main_Content_Rect;

   function Details_Header_Height
     (Content_H   : Natural;
      Line_Height : Positive)
      return Natural is
   begin
      return
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding (Line_Height), 2)), Content_H);
   end Details_Header_Height;

   function Details_Header_Geometry
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Details_Header_Layout
   is
      Content  : constant Content_Rectangle := Main_Content_Rect (Layout);
      Header_H : constant Natural := Details_Header_Height (Content.Height, Line_Height);
      Pad      : constant Natural := Natural'Min (Details_Row_Padding (Line_Height), Header_H);
   begin
      return
        (Content => Content,
         Height  => Header_H,
         Pad     => Pad,
         Columns =>
           Compute_Detail_Columns
             (Snapshot.Detail_Columns_Visible,
              Snapshot.Detail_Column_Widths,
              Snapshot.Detail_Column_Order,
              Content.X,
              Content.Width,
              Line_Height,
              Pad));
   end Details_Header_Geometry;

   function Metrics_For
     (Mode        : Files.Types.View_Mode;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Item_Cell_Metrics
   is
   begin
      return Guikit.Item_Grid.Cell_Metrics_For (Grid_View (Mode), Main_Width, Line_Height);
   end Metrics_For;

   function Build_Snapshot
     (Model : Files.Model.Window_Model)
      return View_Snapshot
   is
   begin
      return Build_Snapshot (Model, Files.Settings.Default_Settings);
   end Build_Snapshot;

   --  Build the ordered coalesced sections for the current multi-item selection.
   --  Each section carries one value per selected item so the layout and the
   --  renderer stay in lock-step. Intended for Selected_Info.Length >= 2.
   --
   --  @param Snapshot View snapshot holding the selected-item info blocks.
   --  @return The ordered sections, each with one display value per selected item.
   function Build_Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector;

   --  The sections Build_Snapshot_Into formatted, or formatted now for a
   --  snapshot assembled another way.
   function Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector is
     (if Snapshot.Info_Sections_Built then Snapshot.Info_Sections else Build_Coalesced_Info_Sections (Snapshot));

   procedure Build_Snapshot_Into
     (Snapshot  : in out View_Snapshot;
      Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Keep_Rows : Boolean := False)
   is separate;

   function Build_Snapshot
     (Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Rows_From : access constant View_Snapshot := null)
      return View_Snapshot
   is
   begin
      return Result : View_Snapshot do
         if Rows_From /= null then
            Result.Items := Rows_From.Items;
         end if;
         Build_Snapshot_Into (Result, Model, Settings, Keep_Rows => Rows_From /= null);
      end return;
   end Build_Snapshot;

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

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
 is separate;

   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Context_Menu_Layout
 is separate;

   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
 is separate;

   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural is
   begin
      if Menu.Column_Count > 1 and then Row > Menu.Column_Break_Row then
         return Saturating_Add (Menu.X, Menu.Column_Width);
      else
         return Menu.X;
      end if;
   end Context_Menu_Row_Left;

   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural is
   begin
      if Menu.Column_Count > 1 and then Row > Menu.Column_Break_Row then
         return
           (if Menu.Width > Menu.Column_Width
            then Menu.Width - Menu.Column_Width
            else 0);
      else
         return Menu.Column_Width;
      end if;
   end Context_Menu_Row_Width;

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
      --  The palette always carries a title, so reserve the same title band the
      --  component renders (guikit-command_palette.adb: LH + Palette_Padding) or
      --  clicks on results would be offset from the drawn rows.
      return Guikit.Layout.Calculate_Palette_Layout
        (Command_X      => Layout.Command_X,
         Command_Y      => Layout.Command_Y,
         Command_Width  => Layout.Command_Width,
         Command_Height => Layout.Command_Height,
         Line_Height    => Line_Height,
         Title_Height   => Saturating_Add (Line_Height, Command_Palette_Padding (Line_Height)));
   end Calculate_Command_Palette_Layout;

   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Quick_Look_Layout
   is
      Padding   : constant Natural := Natural'Max (Command_Palette_Padding (Line_Height), Line_Height / 2);
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
      Desired_Title_H : constant Natural := Saturating_Add (Line_Height, Padding);
      Title_H   : constant Natural := Natural'Min (Desired_Title_H, Panel_H);
      Horizontal_Padding : constant Natural := Natural'Min (Padding, Panel_W / 2);
      Remaining_H : constant Natural := Panel_H - Title_H;
      Bottom_Padding : constant Natural := Natural'Min (Padding, Remaining_H);
      Content_X : constant Natural := Saturating_Add (Panel_X, Horizontal_Padding);
      Content_Y : constant Natural := Saturating_Add (Panel_Y, Title_H);
      Used_W    : constant Natural := Saturating_Multiply (Horizontal_Padding, 2);
   begin
      return
        (X              => Panel_X,
         Y              => Panel_Y,
         Width          => Panel_W,
         Height         => Panel_H,
         Content_X      => Content_X,
         Content_Y      => Content_Y,
         Content_Width  => Panel_W - Used_W,
         Content_Height => Remaining_H - Bottom_Padding);
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
        Saturating_Add
          (Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Field_Padding (Line_Height), 2)),
           Saturating_Multiply (Root_Selector_Padding (Line_Height), 2));
      Wanted_Height   : constant Natural :=
        Saturating_Add
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
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Pad          : constant Natural := Files.UI.Field_Padding (Line_Height);
      --  Box for the drawn favourite star (a filled/outline vector shape); a
      --  near-line-height square so the star reads clearly at the input height.
      Star_W       : constant Positive := Line_Height;
   begin
      if Toolbar.Middle_Width <= Saturating_Add (Saturating_Multiply (Field_Margin, 2), Saturating_Add (Star_W, Pad))
      then
         return (others => <>);
      end if;
      return
        (X       => Saturating_Add (Path_X, Pad),
         Y       => Guikit.Layout.Toolbar_Input_Y (Line_Height),
         Width   => Star_W,
         Height  => Guikit.Layout.Toolbar_Input_Height (Line_Height),
         Visible => True);
   end Path_Favorite_Star_Region;

   function Path_Bar_Content_Offset
     (Width       : Natural;
      Line_Height : Positive)
      return Natural
   is
      Star : constant Path_Favorite_Star_Bounds :=
        Path_Favorite_Star_Region (Width, Line_Height);
   begin
      if not Star.Visible then
         return 0;
      end if;
      --  Star cell width plus one full character cell of separation so the
      --  breadcrumbs/edit text are clearly detached from the star.
      return Saturating_Add (Star.Width, Guikit.Layout.Caret_Advance_Width (Line_Height));
   end Path_Bar_Content_Offset;

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
        Saturating_Add (Layout.Row_Height, Tree_Footer_Height (Snapshot, Layout));
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
        (Files.UTF8.Display_Units_Before (Text, Natural'Min (Cursor, Text'Length)), Text_Width, Line_Height));

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
         Cancel_X     => Saturating_Add (Panel.X, Half),
         Y            => Saturating_Add (Panel.Y, Panel.Height - Height),
         Button_Width => Half,
         Height       => Height);
   end Tree_Pick_Buttons;

   function Info_Metadata_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time)
      return UString
   is
   begin
      if not Available then
         return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
      end if;

      return
        To_Unbounded_String (Humanized_Time_Text (Value));
   end Info_Metadata_Text;

   --  The fields of an item's info block. Name is the pane's heading; the
   --  remaining fields are the single-item pane's labelled sections, and their
   --  declaration order is the order those sections are drawn top to bottom.
   --  The renderer and the row count (Info_Section_Row_Count) both walk
   --  Info_Section_Field in this order, so the drawn rows and the scroll extent
   --  cannot drift apart.
   type Info_Field is
     (Info_Name,
      Info_Filetype,
      Info_Size,
      Info_Folder_Size,
      Info_Created,
      Info_Modified,
      Info_Permissions,
      Info_Owner,
      Info_Group,
      Info_Metadata_Error,
      Info_Extra);

   --  The labelled sections of the single-item info pane, in drawing order.
   subtype Info_Section_Field is Info_Field range Info_Filetype .. Info_Extra;

   --  The localization key of an info section's label.
   --
   --  @param Field Info section.
   --  @return The section label's localization key.
   function Info_Field_Label_Key (Field : Info_Section_Field) return String is
     (case Field is
         when Info_Filetype       => "info.filetype",
         when Info_Size           => "info.size",
         when Info_Folder_Size    => "info.folder_size",
         when Info_Created        => "info.created",
         when Info_Modified       => "info.modified",
         when Info_Permissions    => "info.permissions",
         when Info_Owner          => "info.owner",
         when Info_Group          => "info.group",
         when Info_Metadata_Error => "info.metadata_error",
         when Info_Extra          => "info.extra");

   --  Whether the single-item info pane shows a section for an item. Filesize
   --  is file-only (a folder shows Contents instead, once its size is known);
   --  permissions need the item's mode, owner/group its ownership, and the
   --  metadata-error row appears only when metadata actually failed.
   --
   --  @param Info The selected-item info block.
   --  @param Field Info section.
   --  @return True when the section is drawn for this item.
   function Info_Field_Shown
     (Info  : Info_Snapshot;
      Field : Info_Section_Field)
      return Boolean is
     (case Field is
         when Info_Size           => not Info.Is_Directory,
         when Info_Folder_Size    => Info.Is_Directory and then Info.Folder_Size_Available,
         when Info_Permissions    => Info.Mode_Available,
         when Info_Owner
            | Info_Group          => Info.Ownership_Available,
         when Info_Metadata_Error => Info.Metadata_Error,
         when Info_Filetype
            | Info_Created
            | Info_Modified
            | Info_Extra          => True);

   function Info_Field_Value
     (Info  : Info_Snapshot;
      Field : Info_Field)
      return UString
   is
   begin
      case Field is
         when Info_Name =>
            return Info.Name;
         when Info_Filetype =>
            return Info.Filetype_Detail;
         when Info_Size =>
            return
              (if Info.Size_Available
               then To_Unbounded_String (Size_Text (Info.Size))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when Info_Folder_Size =>
            return Folder_Contents_Text (Info);
         when Info_Created =>
            return Info_Metadata_Text (Info.Creation_Available, Info.Creation_Time);
         when Info_Modified =>
            return Info_Metadata_Text (Info.Modified_Available, Info.Modified_Time);
         when Info_Permissions =>
            return
              (if Length (Info.Permissions) = 0
               then To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"))
               else To_Unbounded_String (Permission_Text (To_String (Info.Permissions))));
         when Info_Metadata_Error =>
            return
              (if Info.Metadata_Error
               then To_Unbounded_String (Files.Localization.Text (To_String (Info.Error_Key)))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when Info_Extra =>
            return Info.Filetype_Extra;
         when Info_Owner =>
            return
              (if Info.Owner_Editing then Info.Ownership_Buffer
               elsif Length (Info.Owner_Name) > 0 then Info.Owner_Name
               else To_Unbounded_String
                      (Files.Types.Account_Image (Info.Owner_Id)));
         when Info_Group =>
            return
              (if Info.Group_Editing then Info.Ownership_Buffer
               elsif Length (Info.Group_Name) > 0 then Info.Group_Name
               else To_Unbounded_String
                      (Files.Types.Account_Image (Info.Group_Id)));
      end case;
   end Info_Field_Value;

   function Info_Field_Display_Value
     (Info  : Info_Snapshot;
      Field : Info_Field)
      return UString
   is
      Value : constant UString := Info_Field_Value (Info, Field);
   begin
      if Field /= Info_Extra then
         return Value;
      end if;

      declare
         Raw    : constant String := To_String (Value);
         Result : Unbounded_String;
         Index  : Integer := Raw'First;
      begin
         while Index <= Raw'Last loop
            if Index < Raw'Last
              and then Raw (Index) = '.'
              and then Raw (Index + 1) = ' '
            then
               Append (Result, ".");
               Append (Result, ASCII.LF);
               Index := Index + 2;
            else
               Append (Result, Raw (Index));
               Index := Index + 1;
            end if;
         end loop;

         return Result;
      end;
   end Info_Field_Display_Value;

   --  Return the last byte of the next display line. Prefer an ASCII word
   --  boundary when one exists; an individual word longer than Capacity is
   --  still split at a valid UTF-8 display boundary.
   function Wrapped_Line_Last
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer;
      Capacity     : Natural)
      return Integer
 is separate;

   --  Whitespace used as a wrap boundary belongs to neither rendered line.
   function Skip_Wrap_Whitespace
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer)
      return Integer
   is
      Result : Integer := Start;
   begin
      while Result <= Segment_Last
        and then (Raw (Result) = ' ' or else Raw (Result) = ASCII.HT)
      loop
         Result := Result + 1;
      end loop;
      return Result;
   end Skip_Wrap_Whitespace;

   --  Visit each row Text takes when wrapped to Text_W: its index from zero
   --  and its byte range (empty for a blank row). Line breaks start a row;
   --  a long line breaks at the last blank that fits, and the blanks at the
   --  break are dropped. Counting rows (Wrapped_Line_Count) and drawing them
   --  (the info pane) both walk this, so the height laid out is the height
   --  drawn.
   procedure For_Each_Wrapped_Line
     (Text        : String;
      Text_W      : Natural;
      Line_Height : Positive;
      Visit       : not null access procedure (Row : Natural; First : Integer; Last : Integer))
   is
      Cell_W   : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Capacity : constant Natural := Text_W / Cell_W;
      Row      : Natural := 0;

      procedure Segment (First : Integer; Last : Integer) is
         Start : Integer;
      begin
         if Last < First then
            Visit (Row, First, First - 1);
            Row := Saturating_Add (Row, 1);
            return;
         end if;
         Start := Skip_Wrap_Whitespace (Text, First, Last);
         if Start > Last then
            Visit (Row, First, First - 1);
            Row := Saturating_Add (Row, 1);
            return;
         end if;
         loop
            declare
               Line_Last : constant Integer := Wrapped_Line_Last (Text, Start, Last, Capacity);
            begin
               Visit (Row, Start, Line_Last);
               Row := Saturating_Add (Row, 1);
               exit when Line_Last >= Last;
               Start := Skip_Wrap_Whitespace (Text, Line_Last + 1, Last);
               exit when Start > Last;
            end;
         end loop;
      end Segment;

      Line_First : Integer := Text'First;
   begin
      if Text'Length = 0 or else Capacity = 0 then
         Visit (0, Text'First, Text'Last);
         return;
      end if;
      for Position in Text'Range loop
         if Text (Position) = ASCII.LF then
            Segment (Line_First, Position - 1);
            Line_First := Position + 1;
         end if;
      end loop;
      if Line_First <= Text'Last then
         Segment (Line_First, Text'Last);
      elsif Text (Text'Last) = ASCII.LF then
         Visit (Row, Text'Last + 1, Text'Last);
      end if;
   end For_Each_Wrapped_Line;

   function Wrapped_Line_Count
     (Text        : UString;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      Rows : Natural := 0;

      procedure Count (Row : Natural; First : Integer; Last : Integer) is
         pragma Unreferenced (First, Last);
      begin
         Rows := Natural'Max (Rows, Saturating_Add (Row, 1));
      end Count;
   begin
      For_Each_Wrapped_Line (To_String (Text), Text_W, Line_Height, Count'Access);
      return Rows;
   end Wrapped_Line_Count;

   function Info_Text_Width
     (Layout      : Layout_Metrics;
      Scrollbar_W : Natural)
      return Natural
   is
      Reserved_W : constant Natural :=
        Saturating_Add (Scrollbar_W, Saturating_Multiply (Info_Pane_Padding (Layout.Line_Height), 2));
   begin
      return
        (if Layout.Info_Pane_Width > Reserved_W
         then Layout.Info_Pane_Width - Reserved_W
         else 0);
   end Info_Text_Width;

   --  The " (<name>)" suffix appended to coalesced multi-selection values so a
   --  row shows which item it describes. A single-item pane renders the name
   --  once as its heading instead of repeating it after every value.
   --
   --  @param Info The selected-item info block.
   --  @return The parenthesised item-name suffix.
   function Info_Postfix (Info : Info_Snapshot) return String is
   begin
      return " (" & To_String (Info.Name) & ")";
   end Info_Postfix;

   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
 is separate;

   --  Placeholder shown for an item a section does not apply to. ASCII so it is
   --  always covered by the glyph atlas (the live-smoke asserts no missing glyphs).
   Coalesced_Placeholder : constant String := "-";

   function Build_Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector
 is separate;

   --  Rows the coalesced sections occupy: each section is one label row plus one
   --  gap row plus the wrapped height of every per-item value. Mirrors the single
   --  view's per-field "2 + Wrapped_Line_Count" so layout and rendering agree.
   --
   --  @param Sections Coalesced sections from Coalesced_Info_Sections.
   --  @param Text_W Available text width used for wrapping.
   --  @param Line_Height Row height in pixels.
   --  @return Total rows the coalesced sections occupy.
   function Coalesced_Info_Rows
     (Sections    : Coalesced_Section_Vectors.Vector;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      Rows : Natural := 0;
   begin
      for Section of Sections loop
         Rows := Saturating_Add (Rows, 2);
         for Value of Section.Values loop
            Rows := Saturating_Add (Rows, Wrapped_Line_Count (Value, Text_W, Line_Height));
         end loop;
      end loop;
      return Rows;
   end Coalesced_Info_Rows;

   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Info_Pane_Layout
 is separate;

   function Panel_Close_Button
     (Panel_X      : Natural;
      Panel_Y      : Natural;
      Panel_Width  : Natural;
      Panel_Height : Natural;
      Line_Height  : Positive)
      return Close_Button_Layout
   is
      Inset   : constant Natural := Natural'Max (Guikit.Layout.Scaled (4, Line_Height), Line_Height / 4);
      Reserve : constant Natural := Saturating_Add (Saturating_Multiply (Inset, 2), Line_Height);
   begin
      --  Need room for the inset on both sides plus the square itself.
      if Panel_Width < Reserve or else Panel_Height < Reserve then
         return (others => <>);
      end if;

      return
        (Visible => True,
         X       => Saturating_Add (Panel_X, Panel_Width - Inset - Line_Height),
         Y       => Saturating_Add (Panel_Y, Inset),
         Width   => Line_Height,
         Height  => Line_Height);
   end Panel_Close_Button;

   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands
   is separate;

   function Default_Font_Path return String is
   begin
      return Files.Fonts.Default_Font_Path;
   end Default_Font_Path;

   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive := 16;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status
   is
      Fallbacks : Guikit.Text.Font_Path_Vectors.Vector;
      Status    : Text_Render_Status;
      Key       : constant UString :=
        To_Unbounded_String
          (Font_Path & Positive'Image (Pixel_Size) & Positive'Image (Cell_Width) & Positive'Image (Cell_Height)
           & Positive'Image (Atlas_Width) & Positive'Image (Atlas_Height));
      Slot      : Positive := 1;
   begin
      Renderer.Pixel_Size := Pixel_Size;
      Renderer.Key := Key;
      --  Already loaded for this configuration: nothing to load.
      for Index in Pool'Range loop
         if Pool (Index).Key = Key then
            Touch (Index);
            Renderer.Slot := Index;
            Renderer.Loaded := True;
            Renderer.Font_Path    := To_Unbounded_String (Font_Path);
            Renderer.Cell_Width   := Cell_Width;
            Renderer.Cell_Height  := Cell_Height;
            Renderer.Atlas_Width  := Atlas_Width;
            Renderer.Atlas_Height := Atlas_Height;
            return Text_Render_Success;
         end if;
      end loop;
      for Index in Pool'Range loop
         if Pool (Index).Used < Pool (Slot).Used then
            Slot := Index;
         end if;
      end loop;
      Pool (Slot).Key := Null_Unbounded_String;
      Touch (Slot);
      Renderer.Slot := Slot;

      --  Delegate to the guikit text layer; the app owns the font paths.
      for Path of Files.Fonts.Fallback_Font_Paths loop
         Fallbacks.Append (To_String (Path));
      end loop;
      Status :=
        Guikit.Text.Initialize
          (R              => Pool (Slot).R,
           Font_Path      => Font_Path,
           Fallback_Paths => Fallbacks,
           Pixel_Size     => Pixel_Size,
           Cell_Width     => Cell_Width,
           Cell_Height    => Cell_Height,
           Atlas_Width    => Atlas_Width,
           Atlas_Height   => Atlas_Height);
      Renderer.Loaded       := Status = Text_Render_Success;

      --  With this installed the emoji font in the fallback chain can be drawn
      --  in colour; without it those codepoints fall back as they always did.
      if Renderer.Loaded then
         Pool (Slot).Key := Key;
         Guikit.Text.Set_Image_Decoder
           (Pool (Slot).R,
            Files.Fonts.Colour_Glyph_Image_Extent'Access,
            Files.Fonts.Decode_Colour_Glyph_Image'Access);
      end if;

      Renderer.Font_Path    := To_Unbounded_String ((if Renderer.Loaded then Font_Path else ""));
      Renderer.Cell_Width   := Cell_Width;
      Renderer.Cell_Height  := Cell_Height;
      Renderer.Atlas_Width  := Atlas_Width;
      Renderer.Atlas_Height := Atlas_Height;
      return Status;
   end Initialize_Text;

   function Item_Now
     (Drawn : View_Snapshot;
      Index : Natural;
      Model : Files.Model.Window_Model)
      return Natural is
   begin
      if Index = 0 then
         return 0;
      end if;
      for Item of Drawn.Items loop
         if Item.Visible_Index = Index then
            return Files.Model.Visible_Index_Of (Model, To_String (Item.Full_Path));
         end if;
      end loop;
      return 0;
   end Item_Now;

   function Text_Loaded (Renderer : Text_Renderer) return Boolean is (Renderer.Loaded);

   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean is
     (Renderer.Loaded
      and then Renderer.Slot in Pool'Range
      and then Pool (Renderer.Slot).Key = Renderer.Key
      and then Guikit.Text.Atlas_Version (Pool (Renderer.Slot).R) = Glyphs.Atlas_Version);

   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result
   is
      Empty : Text_Render_Result;
   begin
      if not Renderer.Loaded then
         return Empty;
      end if;
      --  Its pooled renderer went to another configuration meanwhile.
      if Renderer.Slot not in Pool'Range or else Pool (Renderer.Slot).Key /= Renderer.Key then
         declare
            Status : constant Text_Render_Status :=
              Initialize_Text
                (Renderer, To_String (Renderer.Font_Path), Renderer.Pixel_Size, Renderer.Cell_Width,
                 Renderer.Cell_Height, Renderer.Atlas_Width, Renderer.Atlas_Height);
         begin
            if Status /= Text_Render_Success then
               return Empty;
            end if;
         end;
      end if;
      Touch (Renderer.Slot);
      return Guikit.Text.Build_Glyphs (Pool (Renderer.Slot).R, Frame.Text, Frame.Overlay_Text);
   end Build_Text_Glyphs;

end Files.Rendering;

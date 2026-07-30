with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with Textrender;
with Util.Dates.Formats;
with Util.Properties;

with Files.Accessibility;
with Files.File_Types;
with Files.Fonts;
with Guikit.Segmented;
with Guikit.Text;
with Guikit.Widgets;
with Files.Localization;
with Hostkit.Metadata;
with Files.UTF8;
with Files.UI;

package body Files.Rendering is

   --  Thumbnail pixels never contribute to Item_Snapshot equality (see the
   --  Thumbnail_Bitmap type in the spec).
   overriding function "=" (Left, Right : Thumbnail_Bitmap) return Boolean is
      pragma Unreferenced (Left, Right);
   begin
      return True;
   end "=";

   --  Build_Snapshot queries the current volume's free space (a statvfs syscall)
   --  on every rebuild -- i.e. every scroll frame that bumps the model revision,
   --  though free space does not change at that cadence. Cache it per current
   --  path so scrolling reuses it; navigating to another directory re-queries.
   --  It also expires after a few seconds so the readout follows an in-place
   --  change (a delete or paste in the same directory leaves the path unchanged,
   --  and another process can change free space at any time) rather than sticking
   --  until the user navigates away. Single-threaded render, so state is safe.
   Free_Space_Refresh_Interval : constant Duration := 3.0;
   Cached_Free_Path  : Ada.Strings.Unbounded.Unbounded_String;
   Cached_Free_Cap   : Hostkit.Metadata.Volume_Capacity;
   Cached_Free_Ready : Boolean := False;
   Cached_Free_Time  : Ada.Calendar.Time;  --  meaningful only once Ready

   --  Text rendering is provided by the guikit toolkit; this process-wide
   --  renderer holds the shared font/atlas the whole app draws through.
   The_Renderer : Guikit.Text.Renderer;

   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.Commands.Registered_Command_Id;
   use type Files.Model.Sort_Field;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Quick_Look.Content_Kind;
   use type Files.Types.Color_Label;
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
   Info_Pane_Padding : constant Natural := 10;
   --  Vertical rows the permission matrix reserves in the single-item info pane:
   --  a "Permissions" label, an R/W/E header, three cell rows (user/group/other)
   --  and one spacing row. Both the row-count math and the renderer use it so
   --  layout and scroll agree.
   Permission_Grid_Rows : constant Natural := 6;
   Main_Content_Padding : constant Natural := 8;
   Main_Grid_Gap : constant Natural := 8;
   Item_Content_Padding : constant Natural := 4;
   Item_Icon_Text_Gap : constant Natural := 12;
   Details_Row_Padding : constant Natural := 4;
   Details_Column_Padding : constant Natural := 6;
   Command_Palette_Padding : constant Natural := Guikit.Layout.Palette_Padding;
   Command_Result_Row_Padding : constant Natural := Guikit.Layout.Palette_Result_Row_Padding;
   Command_Palette_Scrollbar_Gap : constant Natural := 8;
   --  The main-view scrollbar is an overlay drawn over the content's right
   --  margin (Main_Content_Padding), not a reserved gutter, so it must be no
   --  wider than that margin or it paints over -- and steals clicks from -- the
   --  rightmost column of items. Keep it equal to the margin.
   Scrollbar_Width : constant Natural := Main_Content_Padding;
   Root_Selector_Padding : constant Natural := 8;

   --  Building the Util date bundle costs ~43 localization catalog lookups plus
   --  environment reads (System_Time_Locale). It depends only on the time
   --  locale, which is invariant across a frame (effectively across a session),
   --  yet Formatted_Time_Text used to rebuild it on every call -- i.e. several
   --  times per visible details row per frame while scrolling. Cache it and
   --  rebuild only when the locale actually changes. Single-threaded render, so
   --  package-level state is safe here.
   Cached_Bundle        : Util.Properties.Manager;
   Cached_Bundle_Locale : Ada.Strings.Unbounded.Unbounded_String;
   Cached_Bundle_Ready  : Boolean := False;

   function Date_Bundle return Util.Properties.Manager is
      Locale : constant String := Files.Localization.System_Time_Locale;
   begin
      if Cached_Bundle_Ready
        and then Ada.Strings.Unbounded.To_String (Cached_Bundle_Locale) = Locale
      then
         return Cached_Bundle;
      end if;

      declare
         Result : Util.Properties.Manager;

         procedure Set_Text
           (Util_Key : String;
            Text_Key : String)
         is
         begin
            Result.Set (Util_Key, Files.Localization.Text (Text_Key, Locale));
         end Set_Text;
      begin
         Set_Text (Util.Dates.Formats.DATE_TIME_LOCALE_NAME, "time.locale.datetime_pattern");
         Set_Text (Util.Dates.Formats.DATE_LOCALE_NAME, "time.locale.date_pattern");
         Set_Text (Util.Dates.Formats.TIME_LOCALE_NAME, "time.locale.time_pattern");
         Set_Text (Util.Dates.Formats.AM_NAME, "time.locale.am");
         Set_Text (Util.Dates.Formats.PM_NAME, "time.locale.pm");

         for Index in 1 .. 12 loop
            declare
               Image : constant String := Ada.Strings.Fixed.Trim (Natural'Image (Index), Ada.Strings.Both);
            begin
               Set_Text ("util.month" & Image & ".short", "time.month" & Image & ".short");
               Set_Text ("util.month" & Image & ".long", "time.month" & Image & ".long");
            end;
         end loop;

         for Index in 0 .. 6 loop
            declare
               Image : constant String := Ada.Strings.Fixed.Trim (Natural'Image (Index), Ada.Strings.Both);
            begin
               Set_Text ("util.day" & Image & ".short", "time.day" & Image & ".short");
               Set_Text ("util.day" & Image & ".long", "time.day" & Image & ".long");
            end;
         end loop;

         Cached_Bundle := Result;
      end;

      Cached_Bundle_Locale := Ada.Strings.Unbounded.To_Unbounded_String (Locale);
      Cached_Bundle_Ready := True;
      return Cached_Bundle;
   end Date_Bundle;

   function Formatted_Time_Text
     (Value  : Ada.Calendar.Time;
      Format : String)
      return String is
   begin
      return Util.Dates.Formats.Format (Pattern => Format, Date => Value, Bundle => Date_Bundle);
   end Formatted_Time_Text;

   function Clock_Time_Text (Value : Ada.Calendar.Time) return String is
   begin
      return
        Formatted_Time_Text
          (Value, Files.Localization.Text ("time.format.clock", Files.Localization.System_Time_Locale));
   end Clock_Time_Text;

   function Full_Time_Text (Value : Ada.Calendar.Time) return String is
   begin
      return
        Formatted_Time_Text
          (Value, Files.Localization.Text ("time.format.full", Files.Localization.System_Time_Locale));
   end Full_Time_Text;

   function Weekday_Key (Value : Ada.Calendar.Time) return String is
   begin
      case Ada.Calendar.Formatting.Day_Of_Week (Value) is
         when Ada.Calendar.Formatting.Monday =>
            return "time.weekday.monday";
         when Ada.Calendar.Formatting.Tuesday =>
            return "time.weekday.tuesday";
         when Ada.Calendar.Formatting.Wednesday =>
            return "time.weekday.wednesday";
         when Ada.Calendar.Formatting.Thursday =>
            return "time.weekday.thursday";
         when Ada.Calendar.Formatting.Friday =>
            return "time.weekday.friday";
         when Ada.Calendar.Formatting.Saturday =>
            return "time.weekday.saturday";
         when Ada.Calendar.Formatting.Sunday =>
            return "time.weekday.sunday";
      end case;
   end Weekday_Key;

   function Day_Start (Value : Ada.Calendar.Time) return Ada.Calendar.Time is
      Year    : Ada.Calendar.Year_Number;
      Month   : Ada.Calendar.Month_Number;
      Day     : Ada.Calendar.Day_Number;
      Seconds : Ada.Calendar.Day_Duration;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      return Ada.Calendar.Time_Of (Year, Month, Day);
   end Day_Start;

   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time := Ada.Calendar.Clock)
      return String
   is
      Today    : constant Ada.Calendar.Time := Day_Start (Now);
      Date     : constant Ada.Calendar.Time := Day_Start (Value);
      Locale   : constant String := Files.Localization.System_Time_Locale;
   begin
      if abs (Now - Value) < 60.0 then
         return Files.Localization.Text ("time.relative.now", Locale);
      elsif Date = Today then
         return Files.Localization.Text ("time.relative.today", Locale) & " " & Clock_Time_Text (Value);
      elsif Date = Today - 86_400.0 then
         return Files.Localization.Text ("time.relative.yesterday", Locale) & " " & Clock_Time_Text (Value);
      else
         for Days_Ago in 2 .. 6 loop
            if Date = Today - Duration (Days_Ago) * 86_400.0 then
               return Files.Localization.Text (Weekday_Key (Value), Locale) & " " & Clock_Time_Text (Value);
            end if;
         end loop;
      end if;

      --  Older than a week: fall back to the full absolute date. Computed here
      --  (lazily) so recent files, which return above, never build it.
      return Full_Time_Text (Value);
   end Humanized_Time_Text;

   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean
   is
   begin
      return Box_W > 0
        and then Box_H > 0
        and then Point_X >= X
        and then Point_Y >= Y
        and then Point_X - X < Box_W
        and then Point_Y - Y < Box_H;
   end Contains_Rectangle_Point;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   --  Geometry of one detail-view column: whether it is shown and, when shown,
   --  its left edge and width in window pixels.
   type Detail_Column_Geometry is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Width   : Natural := 0;
   end record;

   type Detail_Column_Geometry_Array is
     array (Files.Types.Detail_Column) of Detail_Column_Geometry;

   --  Proportional default width for a toggleable column, scaled to the line
   --  height so the layout tracks the font size. Applied whenever the settings
   --  do not pin an explicit width for the column.
   --
   --  @param Column Toggleable detail column.
   --  @param Line_Height Text line height in pixels.
   --  @return Default column width in pixels.
   function Default_Detail_Column_Width
     (Column      : Files.Types.Optional_Detail_Column;
      Line_Height : Positive)
      return Natural is
   begin
      case Column is
         when Files.Types.Modified_Column =>
            return Saturating_Multiply (Line_Height, 11);
         when Files.Types.Size_Column =>
            return Saturating_Multiply (Line_Height, 6);
         when Files.Types.Filetype_Column =>
            return Saturating_Multiply (Line_Height, 9);
         when Files.Types.Created_Column =>
            return Saturating_Multiply (Line_Height, 11);
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

   function Integer_Text (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Integer_Text;

   function Number_Symbol
     (Key      : String;
      Fallback : String)
      return String
   is
      Locale : constant String := Files.Localization.System_Number_Locale;
      Text   : constant String := Files.Localization.Text (Key, Locale);
   begin
      if Text = Key then
         return Fallback;
      end if;

      return Text;
   end Number_Symbol;

   function Decimal_Separator return String is
   begin
      return Number_Symbol ("number.decimal", ".");
   end Decimal_Separator;

   function Group_Separator return String is
   begin
      return Number_Symbol ("number.group", ",");
   end Group_Separator;

   function Grouped_Integer_Text (Value : Long_Long_Integer) return String is
      Number_Text : constant String := Integer_Text (Value);
      Separator  : constant String := Group_Separator;
      First_Size : Natural := Number_Text'Length mod 3;
      Result     : Unbounded_String;
   begin
      if Separator'Length = 0 or else Number_Text'Length <= 3 then
         return Number_Text;
      end if;

      if First_Size = 0 then
         First_Size := 3;
      end if;

      for Index in Number_Text'Range loop
         if Index > Number_Text'First
           and then (Index - Number_Text'First - First_Size) mod 3 = 0
         then
            Append (Result, Separator);
         end if;
         Append (Result, Number_Text (Index));
      end loop;

      return To_String (Result);
   end Grouped_Integer_Text;

   function Localized_Number_Text
     (Tenths       : Long_Long_Integer;
      Use_Decimal  : Boolean)
      return String
   is
      Whole   : constant Long_Long_Integer := Tenths / 10;
      Decimal : constant Long_Long_Integer := Tenths mod 10;
   begin
      if not Use_Decimal or else Decimal = 0 then
         return Grouped_Integer_Text (Whole);
      end if;

      return Grouped_Integer_Text (Whole) & Decimal_Separator & Integer_Text (Decimal);
   end Localized_Number_Text;

   function Size_Text (Value : Long_Long_Integer) return String is
      Unit_Index : Natural := 0;
      Divisor    : Long_Long_Integer := 1;
      Locale     : constant String := Files.Localization.System_Number_Locale;

      function Unit_Key return String is
      begin
         case Unit_Index is
            when 0 =>
               return "details.size.unit.bytes";
            when 1 =>
               return "details.size.unit.kib";
            when 2 =>
               return "details.size.unit.mib";
            when 3 =>
               return "details.size.unit.gib";
            when 4 =>
               return "details.size.unit.tib";
            when others =>
               return "details.size.unit.pib";
         end case;
      end Unit_Key;

      function Scaled_Number return String is
         Whole     : constant Long_Long_Integer := Value / Divisor;
         Remainder : constant Long_Long_Integer := Value mod Divisor;
         Tenths    : constant Long_Long_Integer :=
           Whole * 10 + ((Remainder * 10) + Divisor / 2) / Divisor;
      begin
         return Localized_Number_Text (Tenths, Unit_Index /= 0);
      end Scaled_Number;
   begin
      while Unit_Index < 5 and then Value >= Divisor * 1024 loop
         Unit_Index := Unit_Index + 1;
         Divisor := Divisor * 1024;
      end loop;

      return Scaled_Number & " " & Files.Localization.Text (Unit_Key, Locale);
   end Size_Text;

   function Free_Space_Bar_Active (Snapshot : View_Snapshot) return Boolean is
     (Snapshot.Show_Space_Bar
      and then Snapshot.Free_Space_Known
      and then Length (Snapshot.Last_Error_Key) = 0
      and then Snapshot.Total_Space_Bytes > 0
      and then Snapshot.Total_Space_Bytes >= Snapshot.Free_Space_Bytes);

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
         return
           Size_Text (Snapshot.Total_Space_Bytes - Snapshot.Free_Space_Bytes)
           & " "
           & Files.Localization.Text ("status.used_space.suffix");
      end if;

      return
        Size_Text (Snapshot.Free_Space_Bytes)
        & " "
        & Files.Localization.Text ("status.free_space.suffix");
   end Free_Space_Label;

   function Free_Space_Label_Width
     (Snapshot : View_Snapshot; Line_Height : Positive) return Natural
   is
      Label  : constant String := Free_Space_Label (Snapshot);
      Cell_W : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
   begin
      --  Bar mode reserves a fixed-width band for the graphical bar.
      if Free_Space_Bar_Active (Snapshot) then
         return Saturating_Multiply (Line_Height, 3);
      end if;

      return Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
   end Free_Space_Label_Width;

   function Permission_Text
     (Permissions : String;
      Inline      : Boolean := False)
      return String
   is
      Result : Unbounded_String;
      --  Stack the parts one per line by default; Inline joins them with the
      --  localized separator so a whole item fits on one row (coalesced view).
      Separator : constant String :=
        (if Inline then Files.Localization.Text ("info.permissions.separator") else [1 => ASCII.LF]);

      procedure Append_Part (Key : String) is
      begin
         if Length (Result) > 0 then
            Append (Result, Separator);
         end if;
         Append (Result, Files.Localization.Text (Key));
      end Append_Part;
   begin
      if Permissions'Length < 3 then
         return Permissions;
      end if;

      if Permissions (Permissions'First) = 'r' then
         Append_Part ("info.permissions.readable");
      end if;
      if Permissions (Permissions'First + 1) = 'w' then
         Append_Part ("info.permissions.writable");
      end if;
      if Permissions (Permissions'First + 2) = 'x' then
         Append_Part ("info.permissions.executable");
      end if;

      if Length (Result) = 0 then
         return Files.Localization.Text ("info.permissions.none");
      end if;

      return To_String (Result);
   end Permission_Text;

   function Folder_Contents_Text (Info : Info_Snapshot) return UString is
      Result : Unbounded_String;
   begin
      Append (Result, Grouped_Integer_Text (Long_Long_Integer (Info.Folder_File_Count)));
      Append (Result, " ");
      Append (Result, Files.Localization.Text ("info.contents.items"));
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

   function Visible_Row_Count
     (Available_Height : Natural;
      Row_Height       : Natural)
      return Natural is
   begin
      if Available_Height = 0 or else Row_Height = 0 then
         return 0;
      end if;

      return Available_Height / Row_Height
        + (if Available_Height mod Row_Height = 0 then 0 else 1);
   end Visible_Row_Count;

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
      return Render_Color is
   begin
      case Label is
         when Files.Types.No_Label => return Muted_Text_Color;
         when Files.Types.Red      => return Label_Red_Color;
         when Files.Types.Orange   => return Label_Orange_Color;
         when Files.Types.Yellow   => return Label_Yellow_Color;
         when Files.Types.Green    => return Label_Green_Color;
         when Files.Types.Blue     => return Label_Blue_Color;
         when Files.Types.Purple   => return Label_Purple_Color;
         when Files.Types.Gray     => return Label_Gray_Color;
      end case;
   end Label_Render_Color;

   function Label_For_Swatch
     (Index : Positive)
      return Files.Types.Color_Label is
   begin
      if Index in 1 .. 7 then
         return Files.Types.Color_Label'Val (Index);
      else
         return Files.Types.No_Label;
      end if;
   end Label_For_Swatch;

   function Default_Theme return Render_Theme is
   begin
      return
        (Name             => To_Unbounded_String ("default"),
         High_Contrast    => False,
         Selection_Strong => False,
         Focus_Ring       => Border_Color,
         Warning_Color    => Error_Text_Color);
   end Default_Theme;

   function High_Contrast_Theme return Render_Theme is
   begin
      return
        (Name             => To_Unbounded_String ("high_contrast"),
         High_Contrast    => True,
         Selection_Strong => True,
         Focus_Ring       => Selection_Color,
         Warning_Color    => Error_Text_Color);
   end High_Contrast_Theme;

   function Default_Accessibility_Profile return Accessibility_Profile is
   begin
      return
        (Keyboard_Navigation => True,
         Focus_Rings         => True,
         High_Contrast       => False,
         Tooltips            => True,
         Text_Truncation     => True,
         Screen_Reader_Role_Metadata => True);
   end Default_Accessibility_Profile;

   function High_Contrast_Accessibility_Profile return Accessibility_Profile is
   begin
      return
        (Keyboard_Navigation => True,
         Focus_Rings         => True,
         High_Contrast       => True,
         Tooltips            => True,
         Text_Truncation     => True,
         Screen_Reader_Role_Metadata => True);
   end High_Contrast_Accessibility_Profile;

   function Accessibility_Integration_Profile_Of_Current_UI
      return Accessibility_Integration_Profile is
   begin
      return Files.Accessibility.Integration_Profile;
   end Accessibility_Integration_Profile_Of_Current_UI;

   function Settings_Editor_Profile_Of_Current_UI return Settings_Editor_Profile is
   begin
      return
        (Scalar_Controls       => 14,
         Mapping_Controls      => 4,
         Open_Action_Controls  => 2,
         Supports_Save         => True,
         Supports_Reset        => True,
         Per_Field_Diagnostics => True,
         Supports_Option_Cycling => True,
         Supports_Add_Remove_Mapping => True,
         Supports_Draft_Validation => True,
         Saves_Central_Settings => True);
   end Settings_Editor_Profile_Of_Current_UI;

   function Icon_Theme_Profile_Of_Current_UI return Icon_Theme_Profile is
   begin
      return
        (Theme_Name          => To_Unbounded_String ("files-basic"),
         Placeholder_Icons   => False,
         Scalable_Icons      => True,
         Filetype_Icons      => Natural (Bundled_Icon_Asset_Names.Length),
         Asset_Directory     => To_Unbounded_String ("share/files/icons"),
         Asset_Format        => To_Unbounded_String ("files-icon-v1"),
         User_Selectable     => True,
         High_Contrast_Ready => True);
   end Icon_Theme_Profile_Of_Current_UI;

   function Icon_Theme_Profile_For
     (Settings : Files.Settings.Settings_Model)
      return Icon_Theme_Profile
   is
      Theme : constant String := To_String (Settings.Icon_Theme_Name);
   begin
      if Theme = "files-high-contrast" then
         return
           (Theme_Name          => To_Unbounded_String ("files-high-contrast"),
            Placeholder_Icons   => False,
            Scalable_Icons      => True,
            Filetype_Icons      => Natural (Bundled_Icon_Asset_Names.Length),
            Asset_Directory     => To_Unbounded_String ("share/files/icons/high-contrast"),
            Asset_Format        => To_Unbounded_String ("files-icon-v1"),
            User_Selectable     => True,
            High_Contrast_Ready => True);
      end if;

      return Icon_Theme_Profile_Of_Current_UI;
   end Icon_Theme_Profile_For;

   function Bundled_Icon_Asset_Names return Files.Types.String_Vectors.Vector is
      Names : Files.Types.String_Vectors.Vector;
   begin
      Names.Append (To_Unbounded_String ("folder"));
      Names.Append (To_Unbounded_String ("text"));
      Names.Append (To_Unbounded_String ("image"));
      Names.Append (To_Unbounded_String ("executable"));
      Names.Append (To_Unbounded_String ("link"));
      Names.Append (To_Unbounded_String ("unknown"));
      Names.Append (To_Unbounded_String ("ada"));
      Names.Append (To_Unbounded_String ("markdown"));
      Names.Append (To_Unbounded_String ("toolbar-home"));
      Names.Append (To_Unbounded_String ("toolbar-back"));
      Names.Append (To_Unbounded_String ("toolbar-forward"));
      Names.Append (To_Unbounded_String ("toolbar-create"));
      Names.Append (To_Unbounded_String ("toolbar-delete"));
      return Names;
   end Bundled_Icon_Asset_Names;

   --  Cell sizing lives in Guikit.Item_Grid now; this alias keeps existing
   --  Item_Cell_Metrics references (Width/Height/Icon_Size/Large) compiling.
   subtype Item_Cell_Metrics is Guikit.Item_Grid.Cell_Metrics;

   --  Map the file-manager view mode to the grid component's neutral view kind.
   function Grid_View (Mode : Files.Types.View_Mode) return Guikit.Item_Grid.View_Kind is
     (case Mode is
         when Files.Types.Small_Icons => Guikit.Item_Grid.Icons_Small,
         when Files.Types.Large_Icons => Guikit.Item_Grid.Icons_Large,
         when Files.Types.Details     => Guikit.Item_Grid.Details);

   --  The main content rectangle: the main-view region inset on all sides by the
   --  content padding, dropping the inset when the region is too small to hold
   --  it. Shared by the item layout, the details header/rows, and their click
   --  hit-tests so they agree on the drawable content area.
   type Content_Rectangle is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle is
      Padding : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
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

   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot
   is separate;

   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Layout_Metrics
   is
      Toolbar    : constant Natural := Saturating_Multiply (Line_Height, 2);
      Bottom     : constant Natural :=
        Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Bottom_Bar_Padding, 2));
      Used_Y     : constant Natural := Saturating_Add (Toolbar, Bottom);
      Main_H     : constant Natural := (if Height > Used_Y then Height - Used_Y else 0);
      Pane_W     : constant Natural := (if Snapshot.Info_Pane_Open then Width / 4 else 0);
      Main_W     : constant Natural := (if Width > Pane_W then Width - Pane_W else 0);
      Command_W  : constant Natural := Scaled_Down (Width, 8, 10);
      Command_H  : constant Natural := Scaled_Down (Height, 8, 10);
      Command_X  : constant Natural := (if Width > Command_W then (Width - Command_W) / 2 else 0);
      Command_Y  : constant Natural :=
        (if Height > Command_H then Natural'Min (Line_Height, Height - Command_H) else 0);
   begin
      return
        (Width             => Width,
         Height            => Height,
         Toolbar_Height    => Toolbar,
         Bottom_Bar_Height => Bottom,
         Main_X            => 0,
         Main_Y            => Toolbar,
         Main_Width        => Main_W,
         Main_Height       => Main_H,
         Info_Pane_Width   => Pane_W,
         Command_X         => Command_X,
         Command_Y         => Command_Y,
         Command_Width     => Command_W,
         Command_Height    => Command_H);
   end Calculate_Layout;

   function Calculate_Item_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Item_Layout_Vectors.Vector
 is separate;

   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Main_View_Layout
 is separate;

   function Calculate_Conflict_Dialog_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Conflict_Dialog_Layout
 is separate;

   function Calculate_Paste_Progress_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Paste_Progress_Layout
 is separate;

   function Conflict_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Conflict_Hit_Region is
   begin
      for Index in reverse 1 .. Natural (Frame.Conflict_Hits.Length) loop
         declare
            Region : constant Conflict_Hit_Region :=
              Frame.Conflict_Hits.Element (Positive (Index));
         begin
            if Region.Width > 0
              and then Region.Height > 0
              and then X >= Region.X
              and then X < Region.X + Region.Width
              and then Y >= Region.Y
              and then Y < Region.Y + Region.Height
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Conflict_Hit_At;

   function Permission_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Permission_Hit_Region is
   begin
      for Index in 1 .. Natural (Frame.Permission_Hits.Length) loop
         declare
            Region : constant Permission_Hit_Region :=
              Frame.Permission_Hits.Element (Positive (Index));
         begin
            if Region.Width > 0
              and then Region.Height > 0
              and then X >= Region.X
              and then X < Region.X + Region.Width
              and then Y >= Region.Y
              and then Y < Region.Y + Region.Height
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Permission_Hit_At;

   function Ownership_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Ownership_Hit_Region is
   begin
      for Index in 1 .. Natural (Frame.Ownership_Hits.Length) loop
         declare
            Region : constant Ownership_Hit_Region :=
              Frame.Ownership_Hits.Element (Positive (Index));
         begin
            if Region.Width > 0
              and then Region.Height > 0
              and then X >= Region.X
              and then X < Region.X + Region.Width
              and then Y >= Region.Y
              and then Y < Region.Y + Region.Height
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Ownership_Hit_At;

   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Context_Menu_Layout
 is separate;

   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
   is
      Top : Natural := Saturating_Add (Menu.Y, Menu.Padding);
   begin
      for Preceding in 1 .. Row - 1 loop
         Top :=
           Saturating_Add
             (Top,
              (if Menu.Row_Kinds (Preceding) = Separator_Row
               then Menu.Separator_Height
               else Menu.Row_Height));
      end loop;
      return Top;
   end Context_Menu_Row_Top;

   function Context_Menu_Row_At
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      if not Menu.Visible
        or else X < Menu.X
        or else X >= Menu.X + Menu.Width
        or else Y < Menu.Y + Menu.Padding
        or else Menu.Row_Height = 0
      then
         return 0;
      end if;

      --  Rows have variable heights (separators are shorter), so walk them in
      --  order and return the command row containing Y. Separator rows are not
      --  selectable and resolve to no row.
      declare
         Row_Top : Natural := Menu.Y + Menu.Padding;
      begin
         for Row in 1 .. Menu.Row_Count loop
            declare
               Row_H : constant Natural :=
                 (if Menu.Row_Kinds (Row) = Separator_Row
                  then Menu.Separator_Height
                  else Menu.Row_Height);
            begin
               if Y >= Row_Top and then Y < Row_Top + Row_H then
                  if Menu.Row_Kinds (Row) = Separator_Row then
                     return 0;
                  else
                     return Row;
                  end if;
               end if;
               Row_Top := Row_Top + Row_H;
            end;
         end loop;
         return 0;
      end;
   end Context_Menu_Row_At;

   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural
      renames Guikit.Item_Grid.Item_At;

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
      Edge : constant Integer := Line_Height;
   begin
      if Cursor_Y < Region_Top + Edge then
         return Integer'Max
           (-Max_Step, -(1 + (Region_Top + Edge - Cursor_Y) / Line_Height));
      elsif Cursor_Y > Region_Bottom - Edge then
         return Integer'Min
           (Max_Step, 1 + (Cursor_Y - (Region_Bottom - Edge)) / Line_Height);
      else
         return 0;
      end if;
   end Marquee_Auto_Scroll_Step;

   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector
      renames Guikit.Item_Grid.Items_In_Rect;

   procedure Rename_Field_Extent
     (Item      : Item_Layout;
      View_Mode : Files.Types.View_Mode;
      Renaming  : Boolean;
      Field_X   : out Natural;
      Field_W   : out Natural) is
   begin
      Guikit.Item_Grid.Rename_Field_Extent (Item, Grid_View (View_Mode), Renaming, Field_X, Field_W);
   end Rename_Field_Extent;

   function Details_Header_Command_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
 is separate;

   --  Map a detail column to the sort command a header click on it triggers.
   --  Columns that do not define a sort (the permissions column) return
   --  No_Command.
   function Header_Sort_Command
     (Column : Files.Types.Detail_Column)
      return Files.Commands.Command_Id is
   begin
      case Column is
         when Files.Types.Name_Column =>
            return Files.Commands.Sort_By_Name_Command;
         when Files.Types.Modified_Column =>
            return Files.Commands.Sort_By_Changed_Command;
         when Files.Types.Size_Column =>
            return Files.Commands.Sort_By_Size_Command;
         when Files.Types.Filetype_Column =>
            return Files.Commands.Sort_By_Type_Command;
         when Files.Types.Created_Column =>
            return Files.Commands.Sort_By_Created_Command;
         when Files.Types.Permissions_Column =>
            return Files.Commands.No_Command;
      end case;
   end Header_Sort_Command;

   function Details_Header_Cell_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Header_Cell
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);

      function Within (Column : Files.Types.Detail_Column) return Boolean is
      begin
         return Columns (Column).Visible
           and then Contains_Rectangle_Point
             (Columns (Column).X, Content_Y, Columns (Column).Width, Header_H, X, Y);
      end Within;
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else not Contains_Rectangle_Point (Content_X, Content_Y, Content_W, Header_H, X, Y)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Types.Detail_Column loop
         if Within (Column) then
            return
              (Present => True,
               Column  => Column,
               Command => Header_Sort_Command (Column));
         end if;
      end loop;

      return (Present => False, others => <>);
   end Details_Header_Cell_At;

   function Details_Header_Drop_Index
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Natural
 is separate;

   --  Half-width, in pixels, of the invisible hot zone straddling a header
   --  column separator. A press within this band of a separator's edge begins a
   --  resize; it is wide enough to be grabbable yet narrow enough that clicks
   --  well inside a header cell still resolve to a sort.
   Detail_Separator_Hot_Zone : constant := 5;

   function Details_Header_Separator_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Column_Separator
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);
      Low       : constant Natural :=
        (if X > Detail_Separator_Hot_Zone then X - Detail_Separator_Hot_Zone else 0);
      High      : constant Natural := Saturating_Add (X, Detail_Separator_Hot_Zone);
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Types.Optional_Detail_Column loop
         if Columns (Column).Visible
           and then Columns (Column).X >= Low
           and then Columns (Column).X <= High
         then
            return
              (Present  => True,
               Column   => Column,
               Origin_X => Columns (Column).X,
               Width    => Columns (Column).Width);
         end if;
      end loop;

      return (Present => False, others => <>);
   end Details_Header_Separator_At;

   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
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
         Title_Height   => Saturating_Add (Line_Height, Guikit.Layout.Palette_Padding));
   end Calculate_Command_Palette_Layout;

   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Quick_Look_Layout
   is
      Padding   : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
      --  A large centered panel: roughly three quarters of the window, with a
      --  sensible floor so it stays usable in tiny windows.
      Panel_W   : constant Natural :=
        Natural'Min (Layout.Width, Natural'Max (Saturating_Multiply (Line_Height, 16),
                                                (Layout.Width * 3) / 4));
      Panel_H   : constant Natural :=
        Natural'Min (Layout.Height, Natural'Max (Saturating_Multiply (Line_Height, 12),
                                                 (Layout.Height * 3) / 4));
      Panel_X   : constant Natural :=
        (if Layout.Width > Panel_W then (Layout.Width - Panel_W) / 2 else 0);
      Panel_Y   : constant Natural :=
        (if Layout.Height > Panel_H then (Layout.Height - Panel_H) / 2 else 0);
      --  The title band reserves one line height plus padding at the top.
      Title_H   : constant Natural := Saturating_Add (Line_Height, Padding);
      Content_X : constant Natural := Saturating_Add (Panel_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Panel_Y, Title_H);
      Used_W    : constant Natural := Saturating_Multiply (Padding, 2);
      Used_H    : constant Natural := Saturating_Add (Title_H, Padding);
   begin
      return
        (X              => Panel_X,
         Y              => Panel_Y,
         Width          => Panel_W,
         Height         => Panel_H,
         Content_X      => Content_X,
         Content_Y      => Content_Y,
         Content_Width  => (if Panel_W > Used_W then Panel_W - Used_W else 0),
         Content_Height => (if Panel_H > Used_H then Panel_H - Used_H else 0));
   end Calculate_Quick_Look_Layout;

   function Calculate_Label_Picker_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Label_Picker_Layout
   is
      Count    : constant Positive := Label_Picker_Swatch_Count;
      Padding  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
      Gap      : constant Natural := Natural'Max (4, Line_Height / 4);
      --  A compact centered panel: a single row of square swatches under a
      --  one-line title band. The swatch edge tracks the line height.
      Swatch   : constant Natural := Saturating_Multiply (Line_Height, 2);
      Title_H  : constant Natural := Saturating_Add (Line_Height, Padding);
      Row_W    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Swatch, Count),
           Saturating_Multiply (Gap, Count - 1));
      Panel_W  : constant Natural :=
        Natural'Min (Layout.Width, Saturating_Add (Row_W, Saturating_Multiply (Padding, 2)));
      Panel_H  : constant Natural :=
        Natural'Min
          (Layout.Height,
           Saturating_Add (Title_H, Saturating_Add (Swatch, Saturating_Multiply (Padding, 2))));
      Panel_X  : constant Natural :=
        (if Layout.Width > Panel_W then (Layout.Width - Panel_W) / 2 else 0);
      Panel_Y  : constant Natural :=
        (if Layout.Height > Panel_H then (Layout.Height - Panel_H) / 2 else 0);
      Row_X    : constant Natural := Saturating_Add (Panel_X, Padding);
      Row_Y    : constant Natural := Saturating_Add (Panel_Y, Title_H);
      Result   : Label_Picker_Layout;
   begin
      Result.X           := Panel_X;
      Result.Y           := Panel_Y;
      Result.Width       := Panel_W;
      Result.Height      := Panel_H;
      Result.Swatch_Size := Swatch;
      Result.Visible     := Panel_W > 0 and then Panel_H > 0;
      for Index in Result.Swatches'Range loop
         Result.Swatches (Index) :=
           (X      => Saturating_Add
                        (Row_X,
                         Saturating_Multiply (Index - 1, Saturating_Add (Swatch, Gap))),
            Y      => Row_Y,
            Width  => Swatch,
            Height => Swatch);
      end loop;
      return Result;
   end Calculate_Label_Picker_Layout;

   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Root_Selector_Layout
   is
      Preferred_Width : constant Natural := Natural'Max (Layout.Width / 3, Saturating_Multiply (Line_Height, 18));
      Dropdown_Width  : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Row_Height      : constant Natural :=
        Saturating_Add
          (Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)),
           Saturating_Multiply (Root_Selector_Padding, 2));
      Wanted_Height   : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Natural (Snapshot.Root_Paths.Length), Row_Height),
           Saturating_Multiply (Root_Selector_Padding, 2));
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
         Row_Height => Row_Height);
   end Calculate_Root_Selector_Layout;

   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector
 is separate;

   function Root_Path_At
     (Rows : Root_Path_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point
              (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Root_Index;
         end if;
      end loop;

      return 0;
   end Root_Path_At;

   function Path_Favorite_Star_Region
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Path_Favorite_Star_Bounds
   is
      Toolbar      : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Field_Margin : constant Natural := 6;
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Pad          : constant Natural := Guikit.Layout.Input_Field_Padding;
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
      Line_Height : Positive := 20)
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

   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Breadcrumb_Segment_Layout_Vectors.Vector
 is separate;

   function Breadcrumb_At
     (Rows : Breadcrumb_Segment_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Row.Clickable
           and then Row.Segment_Index /= 0
           and then Contains_Rectangle_Point (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Segment_Index;
         end if;
      end loop;
      return 0;
   end Breadcrumb_At;

   function Calculate_Tree_Panel_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Tree_Panel_Layout
   is
      Preferred_Width : constant Natural :=
        Natural'Max (Layout.Width / 4, Saturating_Multiply (Line_Height, 16));
      Panel_Width     : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Row_Height      : constant Natural :=
        Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2));
   begin
      if not Snapshot.Tree_Panel_Open then
         return (others => <>);
      end if;

      return
        (X          => 0,
         Y          => Layout.Toolbar_Height,
         Width      => Panel_Width,
         Height     => Layout.Main_Height,
         Row_Height => Row_Height);
   end Calculate_Tree_Panel_Layout;

   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive := 20)
      return Tree_Row_Layout_Vectors.Vector
 is separate;

   function Tree_Row_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point (Row.X, Row.Y, Row.Width, Row.Height, X, Y) then
            return Row.Node_Index;
         end if;
      end loop;
      return 0;
   end Tree_Row_At;

   function Tree_Triangle_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Row.Has_Children
           and then Row.Triangle_W > 0
           and then Contains_Rectangle_Point
                      (Row.Triangle_X, Row.Triangle_Y, Row.Triangle_W, Row.Triangle_H, X, Y)
         then
            return Row.Node_Index;
         end if;
      end loop;
      return 0;
   end Tree_Triangle_At;

   function Tree_Pick_Buttons
     (Panel       : Tree_Panel_Layout;
      Line_Height : Positive := 20)
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

   function Info_Field_Value
     (Info  : Info_Snapshot;
      Field : Natural)
      return UString
   is
   begin
      case Field is
         when 0 =>
            return Info.Name;
         when 1 =>
            return Info.Filetype_Detail;
         when 2 =>
            return
              (if Info.Size_Available
               then To_Unbounded_String (Size_Text (Info.Size))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when 3 =>
            return Info_Metadata_Text (Info.Creation_Available, Info.Creation_Time);
         when 4 =>
            return Info_Metadata_Text (Info.Modified_Available, Info.Modified_Time);
         when 5 =>
            return
              (if Length (Info.Permissions) = 0
               then To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"))
               else To_Unbounded_String (Permission_Text (To_String (Info.Permissions))));
         when 6 =>
            return
              (if Info.Metadata_Error
               then To_Unbounded_String (Files.Localization.Text (To_String (Info.Error_Key)))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when 7 =>
            return Info.Filetype_Detail;
         when 8 =>
            return Info.Filetype_Extra;
         when 9 =>
            return
              (if Info.Owner_Editing then Info.Ownership_Buffer
               elsif Length (Info.Owner_Name) > 0 then Info.Owner_Name
               else To_Unbounded_String
                      (Ada.Strings.Fixed.Trim (Natural'Image (Info.Owner_Id), Ada.Strings.Both)));
         when 10 =>
            return
              (if Info.Group_Editing then Info.Ownership_Buffer
               elsif Length (Info.Group_Name) > 0 then Info.Group_Name
               else To_Unbounded_String
                      (Ada.Strings.Fixed.Trim (Natural'Image (Info.Group_Id), Ada.Strings.Both)));
         when others =>
            return Null_Unbounded_String;
      end case;
   end Info_Field_Value;

   function Info_Field_Display_Value
     (Info  : Info_Snapshot;
      Field : Natural)
      return UString
   is
      Value : constant UString := Info_Field_Value (Info, Field);
   begin
      if Field /= 8 then
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

   function Wrapped_Line_Count
     (Text        : UString;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      Cell_W   : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
      Capacity : constant Natural := Text_W / Cell_W;
      Raw      : constant String := To_String (Text);

      function Segment_Row_Count
        (First : Integer;
         Last  : Integer)
         return Natural
      is
         Units : constant Natural :=
           (if Last < First then 0 else Files.UTF8.Display_Units (Raw (First .. Last)));
      begin
         if Capacity = 0 or else Units = 0 then
            return 1;
         end if;

         return Units / Capacity + (if Units mod Capacity = 0 then 0 else 1);
      end Segment_Row_Count;

      Rows       : Natural := 0;
      Line_First : Integer := Raw'First;
   begin
      if Raw'Length = 0 then
         return 1;
      end if;

      for Position in Raw'Range loop
         if Raw (Position) = ASCII.LF then
            Rows := Saturating_Add (Rows, Segment_Row_Count (Line_First, Position - 1));
            Line_First := Position + 1;
         end if;
      end loop;

      if Line_First <= Raw'Last then
         Rows := Saturating_Add (Rows, Segment_Row_Count (Line_First, Raw'Last));
      elsif Raw (Raw'Last) = ASCII.LF then
         Rows := Saturating_Add (Rows, 1);
      end if;

      return Rows;
   end Wrapped_Line_Count;

   function Info_Text_Width
     (Layout      : Layout_Metrics;
      Scrollbar_W : Natural)
      return Natural
   is
      Reserved_W : constant Natural :=
        Saturating_Add (Scrollbar_W, Saturating_Multiply (Info_Pane_Padding, 2));
   begin
      return
        (if Layout.Info_Pane_Width > Reserved_W
         then Layout.Info_Pane_Width - Reserved_W
         else 0);
   end Info_Text_Width;

   --  The " (<name>)" suffix appended to each info-pane value so a row shows the
   --  item it describes. Applied uniformly (single and multi selection); the
   --  dedicated Name field is dropped since the name now rides on every row.
   --
   --  @param Info The selected-item info block.
   --  @return The parenthesised item-name suffix.
   function Info_Postfix (Info : Info_Snapshot) return String is
   begin
      return " (" & To_String (Info.Name) & ")";
   end Info_Postfix;

   --  The display value of a numbered info field with the item-name suffix.
   --
   --  @param Info The selected-item info block.
   --  @param Field Field index (see Info_Field_Value).
   --  @return The postfixed display value used for both layout and rendering.
   function Info_Field_Postfixed_Value
     (Info  : Info_Snapshot;
      Field : Natural)
      return UString is
   begin
      return Info_Field_Display_Value (Info, Field) & Info_Postfix (Info);
   end Info_Field_Postfixed_Value;

   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
 is separate;

   --  One coalesced info-pane section for a multi-item selection: a single field
   --  label plus the per-item display values (one entry per selected item, in
   --  order, with placeholders already filled for items the field omits).
   package Info_Value_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   type Coalesced_Section is record
      Key    : Unbounded_String;
      Values : Info_Value_Vectors.Vector;
   end record;

   package Coalesced_Section_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Coalesced_Section);

   --  Placeholder shown for an item a section does not apply to. ASCII so it is
   --  always covered by the glyph atlas (the live-smoke asserts no missing glyphs).
   Coalesced_Placeholder : constant String := "-";

   --  Build the ordered coalesced sections for the current multi-item selection.
   --  Each section carries one value per selected item so the layout and the
   --  renderer stay in lock-step. Intended for Selected_Info.Length >= 2.
   --
   --  @param Snapshot View snapshot holding the selected-item info blocks.
   --  @return The ordered sections, each with one display value per selected item.
   function Coalesced_Info_Sections
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
      Line_Height : Positive := 20)
      return Info_Pane_Layout
 is separate;

   function Panel_Close_Button
     (Panel_X      : Natural;
      Panel_Y      : Natural;
      Panel_Width  : Natural;
      Panel_Height : Natural;
      Line_Height  : Positive := 20)
      return Close_Button_Layout
   is
      Inset   : constant Natural := Natural'Max (4, Line_Height / 4);
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
      Line_Height : Positive := 20;
      Hover_X     : Natural := 0;
      Hover_Y     : Natural := 0;
      Has_Hover   : Boolean := False;
      Pressed_X   : Natural := 0;
      Pressed_Y   : Natural := 0;
      Has_Press   : Boolean := False;
      Drag_Item_Index : Natural := 0;
      Drag_X      : Natural := 0;
      Drag_Y      : Natural := 0;
      Has_Drag    : Boolean := False;
      Marquee_Active : Boolean := False;
      Marquee_X   : Natural := 0;
      Marquee_Y   : Natural := 0;
      Marquee_W   : Natural := 0;
      Marquee_H   : Natural := 0)
      return Frame_Commands
   is separate;

   function Default_Font_Path return String is
   begin
      return Files.Fonts.Default_Font_Path;
   end Default_Font_Path;

   function Font_Path_For_Frame
     (Frame : Frame_Commands)
      return String
   is
      pragma Unreferenced (Frame);
   begin
      --  Every frame now renders on the monospace primary with per-glyph font
      --  fallback (see Initialize_Text), so the whole-frame font is always the
      --  monospace default. The previous per-frame text-coverage heuristic --
      --  which could flip the entire proportional face for a single symbol such
      --  as the favourite star -- is retired; symbols and CJK resolve per glyph
      --  from the fallback chain instead.
      return Files.Fonts.Default_Font_Path;
   end Font_Path_For_Frame;

   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive := 16;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status
   is
      Fallbacks : Guikit.Text.Font_Path_Vectors.Vector;
      Status    : Text_Render_Status;
   begin
      --  Delegate to the guikit text layer; the app owns the font paths.
      for Path of Files.Fonts.Fallback_Font_Paths loop
         Fallbacks.Append (To_String (Path));
      end loop;
      Status :=
        Guikit.Text.Initialize
          (R              => The_Renderer,
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
         Guikit.Text.Set_Image_Decoder
           (The_Renderer,
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
      return Guikit.Text.Build_Glyphs (The_Renderer, Frame.Text, Frame.Overlay_Text);
   end Build_Text_Glyphs;

end Files.Rendering;

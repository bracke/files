with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Textrender;
with Util.Dates.Formats;
with Util.Properties;

with Files.Accessibility;
with Files.Command_Palette;
with Files.File_Types;
with Files.Fonts;
with Files.Localization;
with Files.Platform.Metadata;
with Files.UTF8;
with Files.UI;

package body Files.Rendering is

   The_Renderer : Textrender.Renderer;

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
   --  U+2606 WHITE STAR: the empty (not-favorited) path-bar toggle glyph.
   Favorite_Star_Empty_Text : constant String :=
     [Character'Val (16#E2#), Character'Val (16#98#), Character'Val (16#86#)];
   --  Folder-tree expander glyphs: a plus/minus affordance, not translatable text.
   Tree_Expander_Collapsed_Text : constant String := "+";
   Tree_Expander_Expanded_Text  : constant String := "-";
   Info_Pane_Padding : constant Natural := 10;
   --  Vertical rows the interactive 3x3 rwx permission grid reserves in the
   --  info pane: three cell rows (user/group/other) plus one spacing row. Both
   --  the row-count math and the renderer use it so layout and scroll agree.
   Permission_Grid_Rows : constant Natural := 4;
   Main_Content_Padding : constant Natural := 8;
   Main_Grid_Gap : constant Natural := 8;
   Item_Content_Padding : constant Natural := 4;
   Item_Icon_Text_Gap : constant Natural := 12;
   Details_Row_Padding : constant Natural := 4;
   Details_Row_Gap : constant Natural := 0;
   Details_Column_Padding : constant Natural := 6;
   Command_Palette_Padding : constant Natural := 8;
   Command_Result_Row_Padding : constant Natural := 4;
   Command_Palette_Scrollbar_Gap : constant Natural := 8;
   Scrollbar_Width : constant Natural := 12;
   Root_Selector_Padding : constant Natural := 8;

   function Date_Bundle return Util.Properties.Manager is
      Result : Util.Properties.Manager;
      Locale : constant String := Files.Localization.System_Time_Locale;

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

      return Result;
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
      Full_Text : constant String := Full_Time_Text (Value);
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

      return Full_Text;
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
   is
      use type Files.Types.Detail_Column;
      Icon_Gap  : constant Natural := Saturating_Add (Line_Height, 6);
      Base_X    : constant Natural :=
        Saturating_Add (Saturating_Add (Content_X, Pad), Icon_Gap);
      Available : constant Natural :=
        (if Content_W > Saturating_Add (Icon_Gap, Saturating_Multiply (Pad, 2))
         then Content_W - Icon_Gap - Saturating_Multiply (Pad, 2)
         else 0);
      Min_Name  : constant Natural := Natural'Min (Available, Saturating_Multiply (Line_Height, 5));
      Result    : Detail_Column_Geometry_Array;
      Fixed_Sum : Natural := 0;
      Cursor    : Natural;
   begin
      --  Size each visible optional column in stored order, so the per-column
      --  width clamp (which reserves the name column's minimum) is applied in
      --  the same visual sequence the columns will be laid out.
      for Slot in Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column := Order (Slot);
         begin
            if Column /= Files.Types.Name_Column and then Visible (Column) then
               declare
                  Raw   : constant Natural :=
                    (if Widths (Column) > 0
                     then Natural'Max (Widths (Column), Files.Types.Minimum_Detail_Column_Width)
                     else Default_Detail_Column_Width (Column, Line_Height));
                  Room  : constant Natural :=
                    (if Available > Saturating_Add (Fixed_Sum, Min_Name)
                     then Available - Fixed_Sum - Min_Name
                     else 0);
                  Width : constant Natural := Natural'Min (Raw, Room);
               begin
                  Result (Column) := (Visible => True, X => 0, Width => Width);
                  Fixed_Sum := Saturating_Add (Fixed_Sum, Width);
               end;
            end if;
         end;
      end loop;

      Result (Files.Types.Name_Column) :=
        (Visible => True,
         X       => Base_X,
         Width   => (if Available > Fixed_Sum then Available - Fixed_Sum else 0));

      --  Place columns left to right: the name column absorbs the remainder in
      --  the first slot, then the visible optional columns follow in stored
      --  order.
      Cursor := Saturating_Add (Base_X, Result (Files.Types.Name_Column).Width);
      for Slot in Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column := Order (Slot);
         begin
            if Column /= Files.Types.Name_Column and then Result (Column).Visible then
               Result (Column).X := Cursor;
               Cursor := Saturating_Add (Cursor, Result (Column).Width);
            end if;
         end;
      end loop;

      return Result;
   end Compute_Detail_Columns;

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

   function Paired_Row_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural is
   begin
      return Natural'Min (Natural (Keys.Length), Natural (Values.Length));
   end Paired_Row_Count;

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

   function Permission_Text (Permissions : String) return String is
      Result : Unbounded_String;

      procedure Append_Part (Key : String) is
      begin
         if Length (Result) > 0 then
            Append (Result, ASCII.LF);
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

   function Complete_Visible_Row_Count
     (Available_Height : Natural;
      Row_Height       : Natural)
      return Natural is
   begin
      if Available_Height = 0 or else Row_Height = 0 then
         return 0;
      end if;

      return Available_Height / Row_Height;
   end Complete_Visible_Row_Count;

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

   function Color_For
     (Role  : Render_Color;
      Theme : Theme_Kind := Theme_Dark)
      return Palette_Color
   is
      function RGB
        (R : Float;
         G : Float;
         B : Float;
         A : Float := 1.0)
         return Palette_Color is
      begin
         return (R => R, G => G, B => B, A => A);
      end RGB;

      --  Dark base palette. Theme_High_Contrast reuses these values so its
      --  rendering is unchanged from before the light theme was introduced.
      function Dark_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.08, 0.09, 0.10);
            when Toolbar_Color         => return RGB (0.07, 0.08, 0.09);
            when Bottom_Bar_Color      => return RGB (0.07, 0.08, 0.09);
            when Main_Color            => return RGB (0.10, 0.11, 0.12);
            when Detail_Alternate_Color => return RGB (0.12, 0.13, 0.14);
            when Pane_Color            => return RGB (0.16, 0.17, 0.18);
            when Input_Color           => return RGB (0.18, 0.19, 0.20);
            when Input_Error_Color     => return RGB (0.44, 0.12, 0.14);
            when Selection_Color       => return RGB (0.21, 0.38, 0.62);
            when Hover_Color           => return RGB (0.20, 0.22, 0.24);
            when Pressed_Color         => return RGB (0.17, 0.24, 0.34);
            when Border_Color          => return RGB (0.28, 0.29, 0.30);
            when Text_Color            => return RGB (0.86, 0.87, 0.88);
            when Muted_Text_Color      => return RGB (0.58, 0.60, 0.62);
            when Error_Text_Color      => return RGB (0.94, 0.30, 0.27);
            when Disabled_Text_Color   => return RGB (0.40, 0.41, 0.42);
            when Icon_Directory_Color  => return RGB (0.32, 0.50, 0.82);
            when Icon_File_Color       => return RGB (0.70, 0.72, 0.74);
            when Icon_Executable_Color => return RGB (0.38, 0.68, 0.42);
            when Icon_Unknown_Color    => return RGB (0.55, 0.55, 0.57);
            when Favorite_Star_Color   => return RGB (0.96, 0.78, 0.28);
            when Label_Red_Color       => return RGB (0.90, 0.30, 0.28);
            when Label_Orange_Color    => return RGB (0.94, 0.58, 0.22);
            when Label_Yellow_Color    => return RGB (0.94, 0.84, 0.30);
            when Label_Green_Color     => return RGB (0.40, 0.74, 0.42);
            when Label_Blue_Color      => return RGB (0.34, 0.56, 0.90);
            when Label_Purple_Color    => return RGB (0.64, 0.44, 0.86);
            when Label_Gray_Color      => return RGB (0.60, 0.62, 0.66);
            when Marquee_Color         => return RGB (0.21, 0.38, 0.62, 0.25);
            when Overlay_Color         => return RGB (0.04, 0.05, 0.06, 0.86);
         end case;
      end Dark_Color;

      --  Light palette: light surfaces, dark text, and selection/hover/border
      --  colors chosen for legible contrast against the light backgrounds.
      function Light_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.93, 0.94, 0.95);
            when Toolbar_Color         => return RGB (0.88, 0.89, 0.91);
            when Bottom_Bar_Color      => return RGB (0.88, 0.89, 0.91);
            when Main_Color            => return RGB (0.98, 0.98, 0.99);
            when Detail_Alternate_Color => return RGB (0.94, 0.95, 0.96);
            when Pane_Color            => return RGB (0.90, 0.91, 0.93);
            when Input_Color           => return RGB (1.00, 1.00, 1.00);
            when Input_Error_Color     => return RGB (0.98, 0.82, 0.82);
            when Selection_Color       => return RGB (0.62, 0.78, 0.98);
            when Hover_Color           => return RGB (0.84, 0.86, 0.89);
            when Pressed_Color         => return RGB (0.72, 0.82, 0.95);
            when Border_Color          => return RGB (0.68, 0.70, 0.73);
            when Text_Color            => return RGB (0.11, 0.12, 0.14);
            when Muted_Text_Color      => return RGB (0.38, 0.40, 0.43);
            when Error_Text_Color      => return RGB (0.72, 0.10, 0.10);
            when Disabled_Text_Color   => return RGB (0.60, 0.62, 0.64);
            when Icon_Directory_Color  => return RGB (0.18, 0.40, 0.74);
            when Icon_File_Color       => return RGB (0.34, 0.36, 0.40);
            when Icon_Executable_Color => return RGB (0.16, 0.52, 0.24);
            when Icon_Unknown_Color    => return RGB (0.44, 0.44, 0.48);
            when Favorite_Star_Color   => return RGB (0.82, 0.60, 0.08);
            when Label_Red_Color       => return RGB (0.82, 0.20, 0.18);
            when Label_Orange_Color    => return RGB (0.86, 0.48, 0.12);
            when Label_Yellow_Color    => return RGB (0.82, 0.70, 0.14);
            when Label_Green_Color     => return RGB (0.24, 0.60, 0.28);
            when Label_Blue_Color      => return RGB (0.20, 0.44, 0.82);
            when Label_Purple_Color    => return RGB (0.50, 0.30, 0.76);
            when Label_Gray_Color      => return RGB (0.46, 0.48, 0.52);
            when Marquee_Color         => return RGB (0.62, 0.78, 0.98, 0.30);
            when Overlay_Color         => return RGB (0.20, 0.22, 0.26, 0.62);
         end case;
      end Light_Color;
   begin
      case Theme is
         when Theme_Dark          => return Dark_Color;
         when Theme_High_Contrast => return Dark_Color;
         when Theme_Light         => return Light_Color;
      end case;
   end Color_For;

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

   function Icon_Asset_Text
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
      LF          : constant String := [1 => ASCII.LF];
      Corner_Role : constant String := (if Theme_Name = "files-high-contrast" then "border" else "muted");

      function Header (Asset_Name : String) return String is
      begin
         return "files-icon-v1" & LF & "name=" & Asset_Name & LF & "grid=16" & LF;
      end Header;

      function Document
        (Asset_Name : String;
         Body_Text  : String)
         return String is
      begin
         return
           Header (Asset_Name)
           & "rect=1,0,14,16,base" & LF
           & "rect=11,0,4,4," & Corner_Role & LF
           & Body_Text;
      end Document;
   begin
      if Icon_Id = "folder" then
         return
           Header ("folder")
           & "rect=0,3,7,3,base" & LF
           & "rect=0,6,16,10,base" & LF
           & "rect=1,7,14,1,border" & LF
           & (if Theme_Name = "files-high-contrast" then "rect=1,14,14,1,border" & LF else "");
      elsif Icon_Id = "text" then
         return
           Document
             ("text",
              "rect=4,6,8,1,border" & LF
              & "rect=4,9,8,1,border" & LF
              & "rect=4,12,6,1,border" & LF);
      elsif Icon_Id = "image" then
         return
           Document
             ("image",
              "rect=3,5,10,6,accent" & LF
              & "rect=4,8,4,2,border" & LF
              & "rect=8,7,4,3,border" & LF);
      elsif Icon_Id = "thumbnail" then
         return
           Header ("thumbnail")
           & "rect=1,1,14,14,border" & LF
           & "rect=2,2,12,12,base" & LF
           & "rect=3,3,10,7,accent" & LF
           & "rect=4,8,4,2,border" & LF
           & "rect=8,7,4,3,border" & LF
           & "rect=3,12,10,1,muted" & LF;
      elsif Icon_Id = "executable" then
         return
           Document
             ("executable",
              "rect=1,0,3,16,accent" & LF
              & "rect=7,5,3,6,accent" & LF
              & "rect=10,8,3,3,accent" & LF);
      elsif Icon_Id = "link" then
         return
           Document
             ("link",
              "rect=3,8,8,2,accent" & LF
              & "rect=8,5,5,2,accent" & LF
              & "rect=8,11,5,2,accent" & LF);
      elsif Icon_Id = "unknown" then
         return
           Document
             ("unknown",
              "rect=5,4,6,2,border" & LF
              & "rect=8,6,2,5,border" & LF
              & "rect=8,13,2,1,border" & LF);
      elsif Icon_Id = "ada" then
         return
           Document
             ("ada",
              "rect=4,5,3,8,accent" & LF
              & "rect=9,5,3,8,accent" & LF
              & "rect=5,8,6,2,border" & LF);
      elsif Icon_Id = "markdown" then
         return
           Document
             ("markdown",
              "rect=4,5,2,8,border" & LF
              & "rect=7,8,2,5,border" & LF
              & "rect=10,5,2,8,border" & LF);
      elsif Icon_Id = "toolbar-home" then
         return
           Header ("toolbar-home")
           & "rect=7,2,2,1,border" & LF
           & "rect=6,3,4,1,border" & LF
           & "rect=5,4,6,1,border" & LF
           & "rect=4,5,8,1,border" & LF
           & "rect=3,6,10,2,border" & LF
           & "rect=4,8,2,5,border" & LF
           & "rect=10,8,2,5,border" & LF
           & "rect=6,12,4,1,border" & LF
           & "rect=7,9,2,4,border" & LF;
      elsif Icon_Id = "toolbar-back" then
         return
           Header ("toolbar-back")
           & "rect=7,3,2,2,border" & LF
           & "rect=6,5,2,2,border" & LF
           & "rect=4,7,8,2,border" & LF
           & "rect=6,9,2,2,border" & LF
           & "rect=7,11,2,2,border" & LF;
      elsif Icon_Id = "toolbar-forward" then
         return
           Header ("toolbar-forward")
           & "rect=7,3,2,2,border" & LF
           & "rect=8,5,2,2,border" & LF
           & "rect=4,7,8,2,border" & LF
           & "rect=8,9,2,2,border" & LF
           & "rect=7,11,2,2,border" & LF;
      elsif Icon_Id = "toolbar-create" then
         return
           Header ("toolbar-create")
           & "rect=7,3,2,10,border" & LF
           & "rect=3,7,10,2,border" & LF;
      elsif Icon_Id = "toolbar-delete" then
         return
           Header ("toolbar-delete")
           & "rect=6,3,4,1,border" & LF
           & "rect=4,5,8,2,border" & LF
           & "rect=5,7,1,6,border" & LF
           & "rect=10,7,1,6,border" & LF
           & "rect=5,12,6,1,border" & LF
           & "rect=7,8,1,4,border" & LF
           & "rect=9,8,1,4,border" & LF;
      else
         return "";
      end if;
   end Icon_Asset_Text;

   function Parse_Icon_Asset
     (Content : String)
      return Icon_Asset
   is
      Result      : Icon_Asset;
      Saw_Header  : Boolean := False;
      Saw_Name    : Boolean := False;
      Saw_Grid    : Boolean := False;
      Parse_Failed : Boolean := False;

      function Starts_With
        (Value  : String;
         Prefix : String)
         return Boolean is
      begin
         return Value'Length >= Prefix'Length
           and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Try_Parse_Natural
        (Text  : String;
         Value : out Natural)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         Value := 0;
         if Clean = "" then
            return False;
         end if;

         for Position in Clean'Range loop
            if Clean (Position) not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Clean (Position)) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Clean (Position)) - Character'Pos ('0');
         end loop;

         return True;
      end Try_Parse_Natural;

      function Try_Parse_Role
        (Text : String;
         Role : out Icon_Asset_Color_Role)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         if Clean = "base" then
            Role := Icon_Asset_Base;
            return True;
         elsif Clean = "accent" then
            Role := Icon_Asset_Accent;
            return True;
         elsif Clean = "border" then
            Role := Icon_Asset_Border;
            return True;
         elsif Clean = "muted" then
            Role := Icon_Asset_Muted;
            return True;
         else
            Role := Icon_Asset_Base;
            return False;
         end if;
      end Try_Parse_Role;

      function Field
        (Text  : String;
         Index : Positive)
         return String
      is
         Start : Positive := Text'First;
         Count : Positive := 1;
      begin
         for Position in Text'Range loop
            if Text (Position) = ',' then
               if Count = Index then
                  return Text (Start .. Position - 1);
               end if;
               Count := Count + 1;
               Start := Position + 1;
            end if;
         end loop;

         if Count = Index then
            return Text (Start .. Text'Last);
         else
            return "";
         end if;
      end Field;

      function Fits_Grid (Rect : Icon_Asset_Rect) return Boolean is
      begin
         return Rect.Grid_X < Result.Grid
           and then Rect.Grid_Y < Result.Grid
           and then Rect.Grid_W <= Result.Grid - Rect.Grid_X
           and then Rect.Grid_H <= Result.Grid - Rect.Grid_Y;
      end Fits_Grid;

      procedure Parse_Line
        (Raw_Line : String)
      is
         Line : constant String := Ada.Strings.Fixed.Trim (Raw_Line, Ada.Strings.Both);
      begin
         if Line = "" then
            return;
         elsif not Saw_Header then
            Saw_Header := Line = "files-icon-v1";
         elsif Starts_With (Line, "name=") then
            Result.Name := To_Unbounded_String (Line (Line'First + 5 .. Line'Last));
            Saw_Name := Length (Result.Name) > 0;
         elsif Starts_With (Line, "grid=") then
            declare
               Grid_Value : Natural;
            begin
               if not Try_Parse_Natural (Line (Line'First + 5 .. Line'Last), Grid_Value)
                 or else Grid_Value = 0
               then
                  Parse_Failed := True;
                  return;
               end if;

               Result.Grid := Grid_Value;
               Saw_Grid := True;
            end;
         elsif Starts_With (Line, "rect=") then
            if not Saw_Grid then
               Parse_Failed := True;
               return;
            end if;

            declare
               Data  : constant String := Line (Line'First + 5 .. Line'Last);
               Rect  : Icon_Asset_Rect;
            begin
               if not Try_Parse_Natural (Field (Data, 1), Rect.Grid_X)
                 or else not Try_Parse_Natural (Field (Data, 2), Rect.Grid_Y)
                 or else not Try_Parse_Natural (Field (Data, 3), Rect.Grid_W)
                 or else not Try_Parse_Natural (Field (Data, 4), Rect.Grid_H)
                 or else not Try_Parse_Role (Field (Data, 5), Rect.Role)
               then
                  Parse_Failed := True;
                  return;
               end if;

               if Rect.Grid_W = 0 or else Rect.Grid_H = 0 or else not Fits_Grid (Rect) then
                  Parse_Failed := True;
                  return;
               end if;
               Result.Rectangles.Append (Rect);
            end;
         else
            Parse_Failed := True;
            return;
         end if;
      end Parse_Line;

      Line_Start : Positive := Content'First;
   begin
      if Content = "" then
         return Result;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            if Index > Line_Start then
               Parse_Line (Content (Line_Start .. Index - 1));
            else
               Parse_Line ("");
            end if;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Parse_Line (Content (Line_Start .. Content'Last));
      end if;

      Result.Valid :=
        not Parse_Failed
        and then Saw_Header
        and then Saw_Name
        and then Saw_Grid
        and then not Result.Rectangles.Is_Empty;
      return Result;
   exception
      when others =>
         Result.Valid := False;
         Result.Rectangles.Clear;
         return Result;
   end Parse_Icon_Asset;

   type Item_Cell_Metrics is record
      Width     : Natural := 0;
      Height    : Natural := 0;
      Icon_Size : Natural := 0;
      Large     : Boolean := False;
   end record;

   function Metrics_For
     (Mode        : Files.Types.View_Mode;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Item_Cell_Metrics
   is
   begin
      case Mode is
         when Files.Types.Small_Icons =>
            return
              (Width     => 216,
               Height    => Saturating_Add (Line_Height, Saturating_Multiply (Item_Content_Padding, 2)),
               Icon_Size => Line_Height,
               Large     => False);
         when Files.Types.Large_Icons =>
            return
              (Width     => Saturating_Multiply (Line_Height, 7),
               Height    => Saturating_Multiply (Line_Height, 5),
               Icon_Size => Saturating_Multiply (Line_Height, 3),
               Large     => True);
         when Files.Types.Details =>
            return
              (Width     => Main_Width,
               Height    =>
                 Saturating_Add
                   (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)),
                    Details_Row_Gap),
               Icon_Size => Line_Height,
               Large     => False);
      end case;
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
   is
      Snapshot : View_Snapshot;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

      function View_Mode_Text (Mode : Files.Types.View_Mode) return String is
      begin
         case Mode is
            when Files.Types.Small_Icons =>
               return Files.Localization.Text ("command.view.small");
            when Files.Types.Large_Icons =>
               return Files.Localization.Text ("command.view.large");
            when Files.Types.Details =>
               return Files.Localization.Text ("command.view.details");
         end case;
      end View_Mode_Text;

      function View_Mode_Token (Mode : Files.Types.View_Mode) return String is
      begin
         case Mode is
            when Files.Types.Small_Icons =>
               return "small_icons";
            when Files.Types.Large_Icons =>
               return "large_icons";
            when Files.Types.Details =>
               return "details";
         end case;
      end View_Mode_Token;

      function Boolean_Text (Value : Boolean) return String is
      begin
         return Files.Localization.Text ((if Value then "settings.value.true" else "settings.value.false"));
      end Boolean_Text;

      function Boolean_Token (Value : Boolean) return String is
      begin
         return (if Value then "true" else "false");
      end Boolean_Token;

      function Sort_Field_Text (Field : Files.Settings.Sort_Field) return String is
      begin
         case Field is
            when Files.Settings.Sort_By_Name =>
               return Files.Localization.Text ("settings.sort.name");
            when Files.Settings.Sort_By_Filetype =>
               return Files.Localization.Text ("settings.sort.filetype");
            when Files.Settings.Sort_By_Size =>
               return Files.Localization.Text ("settings.sort.size");
            when Files.Settings.Sort_By_Created =>
               return Files.Localization.Text ("settings.sort.created");
            when Files.Settings.Sort_By_Modified =>
               return Files.Localization.Text ("settings.sort.modified");
         end case;
      end Sort_Field_Text;

      function Sort_Field_Token (Field : Files.Settings.Sort_Field) return String is
      begin
         case Field is
            when Files.Settings.Sort_By_Name =>
               return "name";
            when Files.Settings.Sort_By_Filetype =>
               return "filetype";
            when Files.Settings.Sort_By_Size =>
               return "size";
            when Files.Settings.Sort_By_Created =>
               return "created";
            when Files.Settings.Sort_By_Modified =>
               return "modified";
         end case;
      end Sort_Field_Token;

      function Theme_Token (Choice : Files.Settings.Theme_Choice) return String is
      begin
         case Choice is
            when Files.Settings.Theme_Dark =>
               return "dark";
            when Files.Settings.Theme_Light =>
               return "light";
            when Files.Settings.Theme_High_Contrast =>
               return "high_contrast";
         end case;
      end Theme_Token;

      function Theme_Display (Token : String) return String is
      begin
         if Token = "light" then
            return Files.Localization.Text ("settings.theme.light");
         elsif Token = "high_contrast" then
            return Files.Localization.Text ("settings.theme.high_contrast");
         else
            return Files.Localization.Text ("settings.theme.dark");
         end if;
      end Theme_Display;

      function Group_By_Token (Mode : Files.Types.Group_Mode) return String is
      begin
         case Mode is
            when Files.Types.No_Grouping =>
               return "none";
            when Files.Types.Group_By_Type =>
               return "type";
            when Files.Types.Group_By_Modified =>
               return "modified";
            when Files.Types.Group_By_Size =>
               return "size";
            when Files.Types.Group_By_Label =>
               return "label";
         end case;
      end Group_By_Token;

      function Group_By_Display (Token : String) return String is
      begin
         if Token = "type" then
            return Files.Localization.Text ("settings.group.type");
         elsif Token = "modified" then
            return Files.Localization.Text ("settings.group.modified");
         elsif Token = "size" then
            return Files.Localization.Text ("settings.group.size");
         elsif Token = "label" then
            return Files.Localization.Text ("settings.group.label");
         else
            return Files.Localization.Text ("settings.group.none");
         end if;
      end Group_By_Display;

      Theme : constant Render_Theme :=
        (case Settings.Theme is
            when Files.Settings.Theme_High_Contrast => High_Contrast_Theme,
            when others => Default_Theme);

      function Filetype_Detail
        (Item : Files.File_System.Directory_Item)
         return UString
      is
         function Upper_Extension (Extension : String) return String is
            Result : String (Extension'Range);
         begin
            for Index in Extension'Range loop
               Result (Index) := Ada.Characters.Handling.To_Upper (Extension (Index));
            end loop;

            return Result;
         end Upper_Extension;

         function Extension_File_Label return UString is
            Extension : constant String := Files.File_Types.Extension_Of (To_String (Item.Name));
         begin
            if Extension = "" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.file"));
            end if;

            return
              To_Unbounded_String (Upper_Extension (Extension));
         end Extension_File_Label;
      begin
         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.symlink"));
            when Files.Types.Executable_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.executable"));
            when Files.Types.Regular_File_Item =>
               if To_String (Item.Filetype) = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.text"));
               elsif To_String (Item.Filetype) = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.markdown"));
               elsif To_String (Item.Filetype) = "text/x-ada" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.ada"));
               elsif To_String (Item.Filetype) = "application/json" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.json"));
               elsif To_String (Item.Filetype) = "application/xml" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.xml"));
               elsif To_String (Item.Filetype) = "image/png" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.png"));
               elsif To_String (Item.Filetype) = "image/jpeg" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.jpeg"));
               elsif To_String (Item.Filetype) = "application/pdf" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.pdf"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.word"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.spreadsheet"));
               elsif To_String (Item.Filetype) = "application/zip"
                 or else To_String (Item.Filetype) = "application/x-tar"
                 or else To_String (Item.Filetype) = "application/gzip-tar"
                 or else To_String (Item.Filetype) = "application/gzip"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.archive"));
               elsif To_String (Item.Filetype) = "audio/mpeg"
                 or else To_String (Item.Filetype) = "audio/wav"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.audio"));
               elsif To_String (Item.Filetype) = "video/mp4" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.video"));
               end if;

               return Extension_File_Label;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.unknown"));
         end case;

      end Filetype_Detail;

      function Filetype_Extra
        (Item : Files.File_System.Directory_Item)
         return UString
      is
         Type_Name : constant String := To_String (Item.Filetype);

         function Token_Detail (Token : String) return UString is
            Separator : constant Natural := Ada.Strings.Fixed.Index (Token, "|");

            function Prefix_Value
              (Prefix_Key : String;
               Value      : String;
               Suffix_Key : String)
               return String
            is
               Prefix : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
               Suffix : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
            begin
               if Suffix'Length > 0
                 and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
               then
                  return Prefix & " " & Value & " " & Suffix;
               else
                  return Prefix & " " & Value & Suffix;
               end if;
            end Prefix_Value;

            function Prefix_Localized_Value
              (Prefix_Key : String;
               Value_Key  : String;
               Suffix_Key : String)
               return String
            is
            begin
               return Prefix_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
            end Prefix_Localized_Value;

            function Lines_And_Encoding
              (Lines_Prefix_Key : String;
               Lines            : String;
               Lines_Suffix_Key : String;
               Encoding         : String)
               return String
            is
            begin
               return
                 Prefix_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
                 & " "
                 & Prefix_Localized_Value
                   ("info.extra.encoding.prefix",
                    "info.extra.encoding." & Encoding,
                    "info.extra.encoding.suffix");
            end Lines_And_Encoding;
         begin
            if Separator <= Token'First or else Separator >= Token'Last then
               return Null_Unbounded_String;
            end if;

            declare
               Key   : constant String := Token (Token'First .. Separator - 1);
               Value : constant String := Token (Separator + 1 .. Token'Last);
               Second : constant Natural := Ada.Strings.Fixed.Index (Value, "|");
            begin
               if Key = "executable.format" then
                  return
                    To_Unbounded_String
                      (Prefix_Localized_Value
                         ("info.extra.executable.format.prefix",
                          "info.extra.executable.format." & Value,
                          "info.extra.executable.format.suffix"));
               elsif Key = "directory.count" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.directory.count.prefix", Value, "info.extra.directory.count.suffix"));
               elsif Key = "text.lines" then
                  return
                    To_Unbounded_String
                      (Prefix_Value ("info.extra.text.lines.prefix", Value, "info.extra.text.lines.suffix"));
               elsif Key = "text.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.text.lines.prefix",
                             Lines,
                             "info.extra.text.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "markdown.lines" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.markdown.lines.prefix", Value, "info.extra.markdown.lines.suffix"));
               elsif Key = "markdown.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.markdown.lines.prefix",
                             Lines,
                             "info.extra.markdown.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "image.dimensions" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.image.dimensions.prefix", Value, "info.extra.image.dimensions.suffix"));
               elsif Key = "symlink.target" then
                  return
                    To_Unbounded_String
                      (Prefix_Value ("info.extra.symlink.target.prefix", Value, "info.extra.symlink.target.suffix"));
               elsif Key = "document.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.document." & Value));
               elsif Key = "document.pdf.pages" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.document.pdf.pages.prefix", Value, "info.extra.document.pdf.pages.suffix"));
               elsif Key = "archive.format" then
                  return
                    To_Unbounded_String
                      (Prefix_Localized_Value
                         ("info.extra.archive.format.prefix",
                          "info.extra.archive.format." & Value,
                          "info.extra.archive.format.suffix"));
               elsif Key = "archive.zip.entries" or else Key = "archive.gzip-tar.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.archive.entries.prefix", Value, "info.extra.archive.entries.suffix"));
               elsif Key = "office.docx.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.office.docx.prefix", Value, "info.extra.office.entries.suffix"));
               elsif Key = "office.xlsx.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.office.xlsx.prefix", Value, "info.extra.office.entries.suffix"));
               elsif Key = "media.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.media." & Value));
               elsif Key = "source.ada.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.ada.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "source.json.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.json.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "source.xml.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.xml.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               end if;
            end;

            return Null_Unbounded_String;
         end Token_Detail;

         function Extension_Detail
           (Name : String)
            return String
         is
            Extension : constant String := Files.File_Types.Extension_Of (Name);
         begin
            if Extension = "" then
               return Files.Localization.Text ("info.extra.file");
            end if;

            return
              Files.Localization.Text ("info.extra.extension.prefix")
              & Extension
              & Files.Localization.Text ("info.extra.extension.suffix");
         end Extension_Detail;
      begin
         if Length (Item.Filetype_Extra) > 0 then
            declare
               Detail : constant UString := Token_Detail (To_String (Item.Filetype_Extra));
            begin
               if Length (Detail) > 0 then
                  return Detail;
               end if;
            end;
         end if;

         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.symlink"));
            when Files.Types.Executable_Item =>
               if Item.Size_Available then
                  declare
                     Prefix : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Files.Localization.Text ("info.extra.executable.size.prefix"), Ada.Strings.Right);
                     Suffix : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Files.Localization.Text ("info.extra.executable.size.suffix"), Ada.Strings.Left);
                     Size_Text : constant String :=
                       Ada.Strings.Fixed.Trim (Long_Long_Integer'Image (Item.Size), Ada.Strings.Both);
                  begin
                     if Suffix'Length > 0
                       and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
                     then
                        return To_Unbounded_String (Prefix & " " & Size_Text & " " & Suffix);
                     else
                        return To_Unbounded_String (Prefix & " " & Size_Text & Suffix);
                     end if;
                  end;
               else
                  return
                    To_Unbounded_String (Files.Localization.Text ("info.extra.executable"));
               end if;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.unknown"));
            when Files.Types.Regular_File_Item =>
               if Type_Name = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.text"));
               elsif Type_Name = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.markdown"));
               elsif Type_Name'Length >= 6
                 and then Type_Name (Type_Name'First .. Type_Name'First + 5) = "image/"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.image"));
               elsif Type_Name = "application/octet-stream" then
                  return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
               end if;
         end case;

         return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
      end Filetype_Extra;

      function Root_Display_Label
        (Path  : String;
         Label : String)
         return String is
      begin
         declare
            Separator : constant Natural := Ada.Strings.Fixed.Index (Label, "|");
         begin
            if Separator > Label'First then
               declare
                  Key       : constant String := Label (Label'First .. Separator - 1);
                  Tail      : constant String := Label (Separator + 1 .. Label'Last);
                  Second    : constant Natural := Ada.Strings.Fixed.Index (Tail, "|");
                  Value_End : constant Natural :=
                    (if Second = 0 then Tail'Last else Second - 1);
                  Value     : constant String := Tail (Tail'First .. Value_End);
               begin
                  if Second = 0 then
                     return
                       Files.Localization.Text (Key & ".prefix")
                       & Value
                       & Files.Localization.Text (Key & ".suffix");
                  else
                     declare
                        Detail : constant String := Tail (Second + 1 .. Tail'Last);
                     begin
                        return
                          Files.Localization.Text (Key & ".prefix")
                          & Value
                          & Files.Localization.Text ("root.detail.prefix")
                          & Detail
                          & Files.Localization.Text ("root.detail.suffix")
                          & Files.Localization.Text (Key & ".suffix");
                     end;
                  end if;
               end;
            end if;
         end;

         if Label'Length >= 5
           and then Label (Label'First .. Label'First + 4) = "root."
         then
            return Files.Localization.Text (Label);
         elsif Label /= "" then
            return Label;
         else
            return Path;
         end if;
      end Root_Display_Label;
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.Current_Path_Is_Favorite :=
        Files.Settings.Is_Favorite (Settings, Files.Model.Current_Path (Model));
      Snapshot.In_Recent_View := Files.Model.In_Recent_View (Model);
      Snapshot.View_Mode := Files.Model.View_Mode_Of (Model);
      Snapshot.Sort_Field := Files.Model.Sort_Field_Of (Model);
      Snapshot.Sort_Ascending := Files.Model.Sort_Is_Ascending (Model);
      Snapshot.Sort_Menu_Open := Files.Model.Sort_Menu_Is_Open (Model);
      Snapshot.Detail_Columns_Visible := Settings.Column_Visible;
      Snapshot.Detail_Column_Widths := Settings.Column_Widths;
      Snapshot.Detail_Column_Order := Settings.Column_Order;
      Snapshot.Group_By := Settings.Group_By;
      Snapshot.Item_Count := Files.Model.Item_Count (Model);
      Snapshot.Visible_Count := Files.Model.Visible_Count (Model);
      Snapshot.Hidden_Count := Files.Model.Hidden_Item_Count (Model);
      Snapshot.Selected_Count := Files.Model.Selected_Count (Model);
      declare
         --  Free-space is derived per snapshot from the current directory's
         --  filesystem, mirroring how the hidden count is queried above. The
         --  platform accessor reports Available = False when the volume cannot
         --  be measured (non-Linux stubs, unreadable paths), so a bogus zero is
         --  never shown as a known value.
         Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
           Files.Platform.Metadata.Volume_Capacity_Of (Files.Model.Current_Path (Model));
      begin
         Snapshot.Free_Space_Known := Capacity.Available;
         Snapshot.Free_Space_Bytes := Capacity.Free_Bytes;
         Snapshot.Total_Space_Bytes := Capacity.Capacity_Bytes;
      end;
      Snapshot.Filter_Text := To_Unbounded_String (Files.Model.Filter_Text (Model));
      Snapshot.Search_Scope := Files.Model.Search_Scope_Of (Model);
      Snapshot.Search_Results_Active := Files.Model.Search_Results_Are_Active (Model);
      Snapshot.Last_Error_Key := To_Unbounded_String (Files.Model.Last_Error_Key (Model));
      Snapshot.Focus := Files.Model.Focus (Model);
      Snapshot.Text_Cursor_Position := Files.Model.Text_Cursor_Position (Model);
      Snapshot.Path_Input_Text := To_Unbounded_String (Files.Model.Path_Input_Text (Model));
      Snapshot.Path_Input_Valid := Files.Model.Path_Input_Is_Valid (Model);
      Snapshot.Path_Input_Error_Key := To_Unbounded_String (Files.Model.Path_Input_Error_Key (Model));
      Snapshot.Rename_Active := Files.Model.Rename_Is_Active (Model);
      Snapshot.Temporary_Item_Active := Files.Model.Temporary_Item_Is_Active (Model);
      Snapshot.Temporary_Item_Name := To_Unbounded_String (Files.Model.Temporary_Item_Name (Model));
      Snapshot.Info_Pane_Open := Files.Model.Info_Pane_Is_Open (Model);
      Snapshot.Settings_Pane_Open := Files.Model.Settings_Pane_Is_Open (Model);
      Snapshot.Settings_Default_View := To_Unbounded_String (View_Mode_Text (Settings.Default_View));
      Snapshot.Settings_Default_View_Token := To_Unbounded_String (View_Mode_Token (Settings.Default_View));
      Snapshot.Settings_Hidden_Files := To_Unbounded_String (Boolean_Text (Settings.Show_Hidden_Files));
      Snapshot.Settings_Hidden_Files_Token := To_Unbounded_String (Boolean_Token (Settings.Show_Hidden_Files));
      Snapshot.Settings_Sort :=
        To_Unbounded_String
          (Sort_Field_Text (Settings.Sort_Field_Value)
           & Files.Localization.Text
             ((if Settings.Sort_Ascending then "settings.sort.ascending" else "settings.sort.descending")));
      Snapshot.Settings_Sort_Field_Token := To_Unbounded_String (Sort_Field_Token (Settings.Sort_Field_Value));
      Snapshot.Settings_Sort_Ascending := To_Unbounded_String (Boolean_Text (Settings.Sort_Ascending));
      Snapshot.Settings_Sort_Ascending_Token := To_Unbounded_String (Boolean_Token (Settings.Sort_Ascending));
      Snapshot.Settings_Theme_Token := To_Unbounded_String (Theme_Token (Settings.Theme));
      Snapshot.Settings_Theme := To_Unbounded_String (Theme_Display (Theme_Token (Settings.Theme)));
      Snapshot.Settings_Icon_Theme := Settings.Icon_Theme_Name;
      Snapshot.Settings_Font_Pixel_Size :=
        To_Unbounded_String (Natural_Text (Settings.Font_Pixel_Size));
      Snapshot.Settings_Opener_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Use_System_Default_Opener));
      Snapshot.Settings_Group_By_Token :=
        To_Unbounded_String (Group_By_Token (Settings.Group_By));
      Snapshot.Settings_Group_By :=
        To_Unbounded_String (Group_By_Display (Group_By_Token (Settings.Group_By)));
      Snapshot.Settings_Column_Modified_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Column_Visible (Files.Types.Modified_Column)));
      Snapshot.Settings_Column_Size_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Column_Visible (Files.Types.Size_Column)));
      Snapshot.Settings_Column_Filetype_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Column_Visible (Files.Types.Filetype_Column)));
      Snapshot.Settings_Column_Created_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Column_Visible (Files.Types.Created_Column)));
      Snapshot.Settings_Column_Permissions_Token :=
        To_Unbounded_String (Boolean_Token (Settings.Column_Visible (Files.Types.Permissions_Column)));
      Snapshot.Settings_Filetypes :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Extension_Filetypes.Length)));
      Snapshot.Settings_Icons :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Icon_Mappings.Length)));
      Snapshot.Settings_Open_Actions :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Open_Actions.Length)));
      if Snapshot.Settings_Pane_Open then
         declare
            Draft : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
         begin
            if Length (Draft.Default_View_Mode) > 0 then
               Snapshot.Settings_Default_View := Draft.Default_View_Mode;
               Snapshot.Settings_Default_View_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Default_View_Mode)));
               Snapshot.Settings_Hidden_Files := Draft.Show_Hidden_Files;
               Snapshot.Settings_Hidden_Files_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Show_Hidden_Files)));
               Snapshot.Settings_Sort := Draft.Sort_Field_Value;
               Snapshot.Settings_Sort_Field_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Sort_Field_Value)));
               Snapshot.Settings_Sort_Ascending := Draft.Sort_Ascending;
               Snapshot.Settings_Sort_Ascending_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Sort_Ascending)));
               Snapshot.Settings_Theme_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Theme)));
               Snapshot.Settings_Theme :=
                 To_Unbounded_String
                   (Theme_Display (Files.Types.To_Lower (To_String (Draft.Theme))));
               Snapshot.Settings_Icon_Theme := Draft.Icon_Theme_Name;
               Snapshot.Settings_Font_Pixel_Size := Draft.Font_Pixel_Size;
               Snapshot.Settings_Opener_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Use_System_Default_Opener)));
               Snapshot.Settings_Group_By_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Group_By)));
               Snapshot.Settings_Group_By :=
                 To_Unbounded_String
                   (Group_By_Display (Files.Types.To_Lower (To_String (Draft.Group_By))));
               Snapshot.Settings_Column_Modified_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Column_Modified)));
               Snapshot.Settings_Column_Size_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Column_Size)));
               Snapshot.Settings_Column_Filetype_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Column_Filetype)));
               Snapshot.Settings_Column_Created_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Column_Created)));
               Snapshot.Settings_Column_Permissions_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Column_Permissions)));
               Snapshot.Settings_Filetype_Extension := Draft.Filetype_Extension;
               Snapshot.Settings_Filetype_Value := Draft.Filetype_Value;
               Snapshot.Settings_Icon_Filetype := Draft.Icon_Filetype;
               Snapshot.Settings_Icon_Value := Draft.Icon_Value;
               Snapshot.Settings_Open_Action_Token := Draft.Open_Action_Token;
               Snapshot.Settings_Open_Action_Command := Draft.Open_Action_Command;
               Snapshot.Settings_Filetypes :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Filetype_Keys, Draft.Filetype_Values)));
               Snapshot.Settings_Icons :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Icon_Keys, Draft.Icon_Values)));
               Snapshot.Settings_Open_Actions :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands)));
               Snapshot.Settings_Draft_Valid := Draft.Valid;
               Snapshot.Settings_Draft_Error := Draft.Error_Key;
            end if;

            Snapshot.Settings_Field_Index := Files.Model.Settings_Field_Index (Model);
         end;
      end if;
      case Snapshot.Settings_Field_Index is
         when 1 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.default_view"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.default_view"));
         when 2 | 4 =>
            Snapshot.Settings_Field_Help := To_Unbounded_String (Files.Localization.Text ("settings.help.boolean"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.boolean"));
         when 5 =>
            Snapshot.Settings_Field_Help := To_Unbounded_String (Files.Localization.Text ("settings.help.theme"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.theme"));
         when 3 =>
            Snapshot.Settings_Field_Help := To_Unbounded_String (Files.Localization.Text ("settings.help.sort"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.sort"));
         when 6 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_theme"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.icon_theme"));
         when 7 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.font_pixel_size"));
            Snapshot.Settings_Control_Options := Null_Unbounded_String;
         when 8 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.system_opener"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.boolean"));
         when 9 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.grouping"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.grouping"));
         when 10 | 11 | 12 | 13 | 14 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.column"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.boolean"));
         when 15 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.filetype_extension"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 16 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.filetype_value"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 17 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_filetype"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 18 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_value"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 19 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.open_action_token"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 20 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.open_action_command"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when others =>
            Snapshot.Settings_Field_Help := Null_Unbounded_String;
            Snapshot.Settings_Control_Options := Null_Unbounded_String;
      end case;
      Snapshot.Info_Pane_Scroll_Lines := Files.Model.Info_Pane_Scroll_Lines (Model);
      Snapshot.Settings_Pane_Scroll_Lines := Files.Model.Settings_Pane_Scroll_Lines (Model);
      Snapshot.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
      Snapshot.Context_Menu_Open := Files.Model.Context_Menu_Is_Open (Model);
      Snapshot.Context_Menu_X := Files.Model.Context_Menu_X (Model);
      Snapshot.Context_Menu_Y := Files.Model.Context_Menu_Y (Model);
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu_Target_Of (Model);
      Snapshot.Context_Menu_Item_Index := Files.Model.Context_Menu_Item_Index (Model);
      Snapshot.Paste_Conflict_Open := Files.Model.Paste_Conflict_Is_Active (Model);
      Snapshot.Paste_Conflict_Name := To_Unbounded_String (Files.Model.Paste_Conflict_Name (Model));
      Snapshot.Paste_Conflict_Apply_All := Files.Model.Paste_Conflict_Apply_All (Model);
      Snapshot.Paste_Progress_Open := Files.Model.Paste_Execution_Is_Active (Model);
      Snapshot.Paste_Progress_Done := Files.Model.Paste_Execution_Done (Model);
      Snapshot.Paste_Progress_Total := Files.Model.Paste_Execution_Total (Model);
      Snapshot.Paste_Progress_Name :=
        To_Unbounded_String (Files.Model.Paste_Execution_Current_Name (Model));
      declare
         use type Files.File_System.Drop_Import_Mode;
      begin
         Snapshot.Paste_Progress_Moving :=
           Files.Model.Paste_Execution_Mode (Model) = Files.File_System.Drop_Move;
      end;
      Snapshot.Settings_Can_Save := Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model);
      Snapshot.Settings_Can_Reset := Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model);
      Snapshot.Theme_Name := Theme.Name;
      Snapshot.Theme_High_Contrast := Theme.High_Contrast;
      Snapshot.Theme_Palette :=
        (case Settings.Theme is
            when Files.Settings.Theme_Dark          => Theme_Dark,
            when Files.Settings.Theme_Light         => Theme_Light,
            when Files.Settings.Theme_High_Contrast => Theme_High_Contrast);
      Snapshot.Theme_Focus_Ring := Theme.Focus_Ring;
      Snapshot.Root_Selector_Open := Files.Model.Root_Selector_Is_Open (Model);
      Snapshot.Root_Selected_Index := Files.Model.Root_Selected_Index (Model);
      Snapshot.Command_Palette_Open := Files.Model.Command_Palette_Is_Open (Model);
      Snapshot.Command_Palette_Query := To_Unbounded_String (Files.Model.Command_Palette_Query (Model));

      Snapshot.Label_Picker_Open := Files.Model.Label_Picker_Is_Open (Model);
      Snapshot.Quick_Look_Open := Files.Model.Quick_Look_Is_Open (Model);
      if Snapshot.Quick_Look_Open then
         declare
            Content : constant Files.Quick_Look.Quick_Look_Content :=
              Files.Model.Quick_Look_Content_Of (Model);
            Item    : constant Files.File_System.Directory_Item :=
              Files.Model.Selected_Item (Model);
         begin
            Snapshot.Quick_Look_Kind           := Content.Kind;
            Snapshot.Quick_Look_Name           := Content.Name;
            Snapshot.Quick_Look_Type           := Content.Filetype;
            Snapshot.Quick_Look_Icon_Id        := Content.Icon_Id;
            Snapshot.Quick_Look_Size_Available := Content.Size_Available;
            Snapshot.Quick_Look_Size           := Content.Size;
            Snapshot.Quick_Look_Text_Lines     := Content.Text_Lines;
            Snapshot.Quick_Look_Text_Truncated := Content.Text_Truncated;
            --  Reuse the item's already-decoded thumbnail pixels for the image
            --  preview; the renderer scales them to fit the panel.
            if Content.Kind = Files.Quick_Look.Image_Content
              and then Item.Thumbnail_Available
            then
               Snapshot.Quick_Look_Image_Width  := Item.Thumbnail_Width;
               Snapshot.Quick_Look_Image_Height := Item.Thumbnail_Height;
               Snapshot.Quick_Look_Image_Pixels := Item.Thumbnail_Pixels;
            end if;
         end;
      end if;

      for Id in Files.Commands.Registered_Command_Id loop
         Snapshot.Command_Enabled (Id) := Files.Commands.Is_Enabled (Id, Model);
      end loop;

      for Index in 1 .. Files.Model.Root_Count (Model) loop
         declare
            Root_Path  : constant String := Files.Model.Root_Path (Model, Index);
            Root_Label : constant String := Files.Model.Root_Label (Model, Index);
         begin
            Snapshot.Root_Paths.Append (To_Unbounded_String (Root_Path));
            Snapshot.Root_Labels.Append (To_Unbounded_String (Root_Display_Label (Root_Path, Root_Label)));
         end;
      end loop;

      Snapshot.Tree_Panel_Open := Files.Model.Tree_Panel_Is_Open (Model);
      Snapshot.Tree_Rows := Files.Model.Tree_Visible_Rows (Model);
      Snapshot.Tree_Pick_Active := Files.Model.Tree_Pick_Is_Active (Model);
      Snapshot.Tree_Pick_Moving :=
        Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Move;
      Snapshot.Tree_Pick_Target := To_Unbounded_String (Files.Model.Tree_Pick_Target (Model));
      Snapshot.Breadcrumb_Segments :=
        Files.Breadcrumbs.Segments (Files.Model.Current_Path (Model));

      if Snapshot.Command_Palette_Open then
         declare
            Palette_Results : constant Files.Command_Palette.Result_Vectors.Vector :=
              Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
            Selected_Index  : Natural := Files.Model.Command_Palette_Selected_Index (Model);
            Result_Offset   : Natural := Files.Model.Command_Palette_Result_Offset (Model);
         begin
            if Selected_Index = 0 and then not Palette_Results.Is_Empty then
               Selected_Index := 1;
            elsif Selected_Index > Natural (Palette_Results.Length) then
               Selected_Index := (if Palette_Results.Is_Empty then 0 else 1);
            end if;

            Snapshot.Command_Palette_Selected_Index := Selected_Index;
            if Palette_Results.Is_Empty then
               Result_Offset := 0;
            elsif Result_Offset >= Natural (Palette_Results.Length) then
               Result_Offset := Natural (Palette_Results.Length) - 1;
            end if;
            Snapshot.Command_Palette_Result_Offset := Result_Offset;

            for Index in 1 .. Natural (Palette_Results.Length) loop
               declare
                  Item : constant Files.Command_Palette.Result_Entry :=
                    Palette_Results.Element (Positive (Index));
                  Primary_Shortcut : constant String :=
                    Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Item.Command));
                  Secondary_Shortcut : constant String :=
                    Files.Commands.Shortcut_Text (Files.Commands.Secondary_Shortcut_For (Item.Command));
                  Display_Shortcut : constant String :=
                    (if Primary_Shortcut = "" then Secondary_Shortcut
                     elsif Secondary_Shortcut = "" then Primary_Shortcut
                     else Primary_Shortcut & " / " & Secondary_Shortcut);
               begin
                  Snapshot.Command_Palette_Results.Append
                    (Command_Result_Snapshot'
                       (Identifier => Item.Identifier,
                        Label      => Item.Label,
                        Description => Item.Description,
                        Shortcut_Text => To_Unbounded_String (Display_Shortcut),
                        Enabled    => Item.Enabled,
                        Selected   => Index = Selected_Index));
               end;
            end loop;
         end;
      end if;

      declare
         use type Files.Model.Clipboard_Mode;
         Cut_Active : constant Boolean :=
           Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut;
         Cut_Paths  : constant Files.Types.String_Vectors.Vector :=
           (if Cut_Active then Files.Model.Clipboard_Paths (Model)
            else Files.Types.String_Vectors.Empty_Vector);

         function Is_Cut_Pending (Full_Path : Ada.Strings.Unbounded.Unbounded_String)
           return Boolean is
         begin
            if not Cut_Active then
               return False;
            end if;
            for Path of Cut_Paths loop
               if Path = Full_Path then
                  return True;
               end if;
            end loop;
            return False;
         end Is_Cut_Pending;
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            declare
               Item : constant Files.File_System.Directory_Item := Files.Model.Visible_Item (Model, Index);
               Rename_On     : Boolean;
               Rename_Value  : Ada.Strings.Unbounded.Unbounded_String;
               Rename_Cursor : Natural;
            begin
               Files.Model.Rename_State_For_Visible
                 (Model, Index, Rename_On, Rename_Value, Rename_Cursor);
               Snapshot.Items.Append
                 (Item_Snapshot'
                    (Name               => Item.Name,
                     Filetype           => Item.Filetype,
                     Filetype_Detail    => Filetype_Detail (Item),
                     Icon_Id            => Item.Icon_Id,
                     Kind               => Item.Kind,
                     Size_Available     => Item.Size_Available,
                     Size               => Item.Size,
                     Creation_Available => Item.Creation_Available,
                     Creation_Time      => Item.Creation_Time,
                     Modified_Available => Item.Modified_Available,
                     Modified_Time      => Item.Modified_Time,
                     Permissions        => Item.Permissions,
                     Filetype_Extra     => Filetype_Extra (Item),
                     Thumbnail_Available => Item.Thumbnail_Available,
                     Thumbnail_Path      => Item.Thumbnail_Path,
                     Thumbnail_Width     => Item.Thumbnail_Width,
                     Thumbnail_Height    => Item.Thumbnail_Height,
                     Thumbnail_Pixels    => Item.Thumbnail_Pixels,
                     Metadata_Error     => Item.Metadata_Error,
                     Error_Key          => Item.Error_Key,
                     Selected           => Files.Model.Is_Selected (Model, Index),
                     Visible_Index      => Index,
                     Cut_Pending        => Is_Cut_Pending (Item.Full_Path),
                     Renaming           => Rename_On,
                     Rename_Value       => Rename_Value,
                     Rename_Cursor      => Rename_Cursor,
                     Is_Group_Header    => False,
                     Group_Label        => Null_Unbounded_String,
                     Is_Favorite        =>
                       Files.Settings.Is_Favorite (Settings, To_String (Item.Full_Path)),
                     Label              =>
                       Files.Settings.Label_Of (Settings, To_String (Item.Full_Path))));
            end;
         end loop;
      end;

      declare
         function Name_Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
            Left_Text       : constant String := To_String (Left.Name);
            Right_Text      : constant String := To_String (Right.Name);
            Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Text);
            Right_Lowercase : constant String := Files.Types.To_Lower (Right_Text);
         begin
            if Left_Lowercase /= Right_Lowercase then
               return Left_Lowercase < Right_Lowercase;
            else
               return Left_Text < Right_Text;
            end if;
         end Name_Less;

         function Field_Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
            Forward_Order : Boolean := False;
            Reverse_Order : Boolean := False;
         begin
            case Snapshot.Sort_Field is
               when Files.Model.Sort_Name =>
                  Forward_Order := Name_Less (Left => Left, Right => Right);
                  Reverse_Order := Name_Less (Left => Right, Right => Left);
               when Files.Model.Sort_Size =>
                  if Left.Size_Available /= Right.Size_Available then
                     return Left.Size_Available;
                  elsif Left.Size /= Right.Size then
                     Forward_Order := Left.Size < Right.Size;
                     Reverse_Order := Right.Size < Left.Size;
                  end if;
               when Files.Model.Sort_Type =>
                  declare
                     Left_Type       : constant String := To_String (Left.Filetype);
                     Right_Type      : constant String := To_String (Right.Filetype);
                     Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Type);
                     Right_Lowercase : constant String := Files.Types.To_Lower (Right_Type);
                  begin
                     if Left_Lowercase /= Right_Lowercase then
                        Forward_Order := Left_Lowercase < Right_Lowercase;
                        Reverse_Order := Right_Lowercase < Left_Lowercase;
                     elsif Left_Type /= Right_Type then
                        Forward_Order := Left_Type < Right_Type;
                        Reverse_Order := Right_Type < Left_Type;
                     end if;
                  end;
               when Files.Model.Sort_Created =>
                  if Left.Creation_Available /= Right.Creation_Available then
                     return Left.Creation_Available;
                  elsif Left.Creation_Time /= Right.Creation_Time then
                     Forward_Order := Left.Creation_Time < Right.Creation_Time;
                     Reverse_Order := Right.Creation_Time < Left.Creation_Time;
                  end if;
               when Files.Model.Sort_Changed =>
                  if Left.Modified_Available /= Right.Modified_Available then
                     return Left.Modified_Available;
                  elsif Left.Modified_Time /= Right.Modified_Time then
                     Forward_Order := Left.Modified_Time < Right.Modified_Time;
                     Reverse_Order := Right.Modified_Time < Left.Modified_Time;
                  end if;
            end case;

            if Snapshot.Sort_Field /= Files.Model.Sort_Name
              and then not Forward_Order
              and then not Reverse_Order
            then
               return Name_Less (Left, Right);
            elsif Snapshot.Sort_Ascending then
               return Forward_Order;
            else
               return Reverse_Order;
            end if;
         end Field_Less;

         function Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
         begin
            return Field_Less (Left, Right);
         end Less;

         package Sorting is new Item_Snapshot_Vectors.Generic_Sorting ("<" => Less);
      begin
         Sorting.Sort (Snapshot.Items);
      end;

      --  Grouping composes with the sort: the sorted items are partitioned into
      --  fixed-order bands, each introduced by a non-selectable header row. The
      --  header carries Visible_Index zero so hit-testing never selects it, and
      --  items keep their sorted order within a band.
      if Snapshot.View_Mode = Files.Types.Details
        and then Snapshot.Group_By /= Files.Types.No_Grouping
        and then not Snapshot.Items.Is_Empty
      then
         declare
            function Starts_With (Text : String; Prefix : String) return Boolean is
              (Text'Length >= Prefix'Length
               and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

            function Type_Band (Item : Item_Snapshot) return Positive is
               Mime : constant String := Files.Types.To_Lower (To_String (Item.Filetype));
            begin
               if Item.Kind = Files.Types.Directory_Item then
                  return 1;
               elsif Starts_With (Mime, "image/") then
                  return 2;
               elsif Starts_With (Mime, "audio/") then
                  return 3;
               elsif Starts_With (Mime, "video/") then
                  return 4;
               elsif Starts_With (Mime, "text/")
                 or else Mime = "application/pdf"
                 or else Starts_With (Mime, "application/json")
                 or else Starts_With (Mime, "application/xml")
                 or else Starts_With (Mime, "application/vnd.")
               then
                  return 5;
               elsif Mime = "application/zip"
                 or else Starts_With (Mime, "application/x-tar")
                 or else Starts_With (Mime, "application/gzip")
                 or else Starts_With (Mime, "application/x-7z")
                 or else Starts_With (Mime, "application/x-rar")
               then
                  return 6;
               else
                  return 7;
               end if;
            end Type_Band;

            function Modified_Band (Item : Item_Snapshot) return Positive is
               Now   : constant Ada.Calendar.Time := Ada.Calendar.Clock;
               Today : constant Ada.Calendar.Time := Day_Start (Now);
            begin
               if not Item.Modified_Available then
                  return 4;
               elsif Day_Start (Item.Modified_Time) = Today then
                  return 1;
               elsif Item.Modified_Time > Today - 6.0 * 86_400.0 then
                  return 2;
               else
                  return 3;
               end if;
            end Modified_Band;

            function Size_Band (Item : Item_Snapshot) return Positive is
            begin
               if not Item.Size_Available then
                  return 5;
               elsif Item.Size <= 0 then
                  return 1;
               elsif Item.Size < 1024 * 1024 then
                  return 2;
               elsif Item.Size < 1024 * 1024 * 1024 then
                  return 3;
               else
                  return 4;
               end if;
            end Size_Band;

            --  Color-label bands in canonical order: Red .. Gray (bands 1 .. 7,
            --  mirroring Files.Types.Real_Color_Label) then unlabeled (band 8).
            function Label_Band (Item : Item_Snapshot) return Positive is
            begin
               if Item.Label = Files.Types.No_Label then
                  return 8;
               else
                  return Files.Types.Color_Label'Pos (Item.Label);
               end if;
            end Label_Band;

            function Band_Count return Positive is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     return 7;
                  when Files.Types.Group_By_Modified =>
                     return 4;
                  when Files.Types.Group_By_Size =>
                     return 5;
                  when Files.Types.Group_By_Label =>
                     return 8;
                  when Files.Types.No_Grouping =>
                     return 1;
               end case;
            end Band_Count;

            function Band_Of (Item : Item_Snapshot) return Positive is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     return Type_Band (Item);
                  when Files.Types.Group_By_Modified =>
                     return Modified_Band (Item);
                  when Files.Types.Group_By_Size =>
                     return Size_Band (Item);
                  when Files.Types.Group_By_Label =>
                     return Label_Band (Item);
                  when Files.Types.No_Grouping =>
                     return 1;
               end case;
            end Band_Of;

            function Band_Label (Band : Positive) return String is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     case Band is
                        when 1 =>
                           return "details.group.folders";
                        when 2 =>
                           return "details.group.images";
                        when 3 =>
                           return "details.group.audio";
                        when 4 =>
                           return "details.group.video";
                        when 5 =>
                           return "details.group.documents";
                        when 6 =>
                           return "details.group.archives";
                        when others =>
                           return "details.group.other";
                     end case;
                  when Files.Types.Group_By_Modified =>
                     case Band is
                        when 1 =>
                           return "details.group.today";
                        when 2 =>
                           return "details.group.this_week";
                        when 3 =>
                           return "details.group.earlier";
                        when others =>
                           return "details.group.unknown_date";
                     end case;
                  when Files.Types.Group_By_Size =>
                     case Band is
                        when 1 =>
                           return "details.group.size_empty";
                        when 2 =>
                           return "details.group.size_small";
                        when 3 =>
                           return "details.group.size_medium";
                        when 4 =>
                           return "details.group.size_large";
                        when others =>
                           return "details.group.size_unknown";
                     end case;
                  when Files.Types.Group_By_Label =>
                     case Band is
                        when 1 =>
                           return "label.color.red";
                        when 2 =>
                           return "label.color.orange";
                        when 3 =>
                           return "label.color.yellow";
                        when 4 =>
                           return "label.color.green";
                        when 5 =>
                           return "label.color.blue";
                        when 6 =>
                           return "label.color.purple";
                        when 7 =>
                           return "label.color.gray";
                        when others =>
                           return "details.group.unlabeled";
                     end case;
                  when Files.Types.No_Grouping =>
                     return "";
               end case;
            end Band_Label;

            Grouped : Item_Snapshot_Vectors.Vector;
         begin
            for Band in 1 .. Band_Count loop
               declare
                  Emitted_Header : Boolean := False;
               begin
                  for Item of Snapshot.Items loop
                     if Band_Of (Item) = Band then
                        if not Emitted_Header then
                           Grouped.Append
                             (Item_Snapshot'
                                (Is_Group_Header => True,
                                 Group_Label     =>
                                   To_Unbounded_String (Files.Localization.Text (Band_Label (Band))),
                                 Visible_Index   => 0,
                                 others          => <>));
                           Emitted_Header := True;
                        end if;
                        Grouped.Append (Item);
                     end if;
                  end loop;
               end;
            end loop;
            Snapshot.Items := Grouped;
         end;
      end if;

      if Snapshot.Info_Pane_Open and then Files.Model.Selected_Count (Model) > 0 then
         declare
            Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);

            function Build_Info
              (Item : Files.File_System.Directory_Item)
               return Info_Snapshot
            is
               Is_Directory : constant Boolean := Item.Kind = Files.Types.Directory_Item;
               Info : Info_Snapshot :=
                 (Name               => Item.Name,
                  Filetype           => Item.Filetype,
                  Size_Available     => Item.Size_Available,
                  Size               => Item.Size,
                  Creation_Available => Item.Creation_Available,
                  Creation_Time      => Item.Creation_Time,
                  Modified_Available => Item.Modified_Available,
                  Modified_Time      => Item.Modified_Time,
                  Permissions        => Item.Permissions,
                  Mode_Available     => Item.Mode_Available,
                  Mode_Bits          => Item.Mode_Bits,
                  Ownership_Available => Item.Ownership_Available,
                  Owner_Id           => Item.Owner_Id,
                  Group_Id           => Item.Group_Id,
                  Is_Directory       => Is_Directory,
                  Metadata_Error     => Item.Metadata_Error,
                  Error_Key          => Item.Error_Key,
                  Filetype_Detail    => Filetype_Detail (Item),
                  Filetype_Extra     => Filetype_Extra (Item),
                  others             => <>);
            begin
               if Is_Directory
                 and then Files.Model.Folder_Size_Cached_For (Model, To_String (Item.Full_Path))
               then
                  declare
                     Measured : constant Files.File_System.Directory_Size_Result :=
                       Files.Model.Folder_Size_Value (Model);
                  begin
                     Info.Folder_Size_Available := Measured.Available;
                     Info.Folder_Size_Bytes     := Measured.Total_Bytes;
                     Info.Folder_File_Count      := Measured.File_Count;
                     Info.Folder_Item_Count      := Measured.Item_Count;
                     Info.Folder_Size_Capped     := Measured.Capped;
                  end;
               end if;

               return Info;
            end Build_Info;

            Single_Item : constant Files.File_System.Directory_Item :=
              Files.Model.Selected_Item (Model);
            In_Trash    : constant Boolean :=
              Files.Model.Current_Path (Model) = Files.File_System.Trash_Files_Directory;
         begin
            Snapshot.Permissions_Editable :=
              Files.Model.Selected_Count (Model) = 1
              and then not In_Trash
              and then Files.File_System.Supports_Permissions
              and then Single_Item.Mode_Available;

            Snapshot.Ownership_Editable :=
              Files.Model.Selected_Count (Model) = 1
              and then not In_Trash
              and then Files.File_System.Supports_Ownership
              and then Single_Item.Ownership_Available;

            if Items.Is_Empty then
               Snapshot.Selected_Info.Append (Build_Info (Single_Item));
            else
               for Item of Items loop
                  Snapshot.Selected_Info.Append (Build_Info (Item));
               end loop;
            end if;

            --  Reflect an active ownership edit on the single selected item so
            --  the info pane shows the editor buffer and draws the caret.
            if Snapshot.Ownership_Editable
              and then Natural (Snapshot.Selected_Info.Length) = 1
              and then Files.Model.Focus (Model) = Files.Types.Focus_Ownership_Input
            then
               declare
                  Editing : Info_Snapshot := Snapshot.Selected_Info.First_Element;
               begin
                  Editing.Ownership_Buffer :=
                    To_Unbounded_String (Files.Model.Ownership_Input_Text (Model));
                  if Files.Model.Ownership_Editing_Group (Model) then
                     Editing.Group_Editing := True;
                  else
                     Editing.Owner_Editing := True;
                  end if;
                  Snapshot.Selected_Info.Replace_Element
                    (Snapshot.Selected_Info.First_Index, Editing);
               end;
            end if;
         end;
      end if;

      return Snapshot;
   end Build_Snapshot;

   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Layout_Metrics
   is
      Toolbar    : constant Natural := Saturating_Multiply (Line_Height, 2);
      Bottom     : constant Natural :=
        Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Bottom_Bar_Padding, 2));
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
   is
      Result : Item_Layout_Vectors.Vector;
      Padding : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
      Content_W : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      Content_H : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
      Main_View : constant Main_View_Layout :=
        Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Scroll_Pixels : constant Natural := Main_View.Scroll_Pixels;

      function Saturating_Subtract (Left : Natural; Right : Natural) return Natural is
      begin
         if Left > Right then
            return Left - Right;
         else
            return 0;
         end if;
      end Saturating_Subtract;

      function Columns_For (Main_Width : Natural; Cell_Width : Positive) return Positive is
         Stride : constant Positive := Positive (Saturating_Add (Cell_Width, Main_Grid_Gap));
      begin
         if Main_Width < Cell_Width then
            return 1;
         else
            return Positive'Max (1, Positive ((Saturating_Add (Main_Width, Main_Grid_Gap)) / Stride));
         end if;
      end Columns_For;

      procedure Append_Grid_Item
        (Index     : Positive;
         Cell_W    : Positive;
         Cell_H    : Positive;
         Icon_Size : Positive;
         Large     : Boolean)
      is
         Columns     : constant Positive := Columns_For (Content_W, Cell_W);
         Offset      : constant Natural := Natural (Index - 1);
         Column      : constant Natural := Offset mod Columns;
         Row         : constant Natural := Offset / Columns;
         Cell_Stride : constant Natural := Saturating_Add (Cell_W, Main_Grid_Gap);
         Row_Stride  : constant Natural := Saturating_Add (Cell_H, Main_Grid_Gap);
         Cell_Offset : constant Natural := Saturating_Multiply (Column, Cell_Stride);
         Row_Offset  : constant Natural := Saturating_Multiply (Row, Row_Stride);
         Hidden_Px   : constant Natural :=
           (if Row_Offset < Scroll_Pixels then Natural'Min (Cell_H, Scroll_Pixels - Row_Offset) else 0);
         Visible_Row : constant Natural := Saturating_Subtract (Row_Offset, Scroll_Pixels);
         Cell_X      : constant Natural := Saturating_Add (Content_X, Cell_Offset);
         Cell_Y      : constant Natural := Saturating_Add (Content_Y, Visible_Row);
         Cell_Width  : constant Natural :=
           (if Content_W > Cell_Offset
            then Natural'Min (Cell_W, Content_W - Cell_Offset)
            else 0);
         Cell_Height : constant Natural :=
           (if Hidden_Px = 0 and then Content_H >= Saturating_Add (Visible_Row, Cell_H)
            then Cell_H
            else 0);
         Draw_Icon   : constant Natural := Natural'Min (Icon_Size, Natural'Min (Cell_Width, Cell_Height));
         Content_Pad : constant Natural := Natural'Min (Item_Content_Padding, Natural'Min (Cell_Width, Cell_Height));
         Inner_X     : constant Natural := Saturating_Add (Cell_X, Content_Pad);
         Inner_Y     : constant Natural := Saturating_Add (Cell_Y, Content_Pad);
         Inner_W     : constant Natural :=
           (if Cell_Width > Saturating_Multiply (Content_Pad, 2)
            then Cell_Width - Saturating_Multiply (Content_Pad, 2)
            else Cell_Width);
         Inner_H     : constant Natural :=
           (if Cell_Height > Saturating_Multiply (Content_Pad, 2)
            then Cell_Height - Saturating_Multiply (Content_Pad, 2)
            else Cell_Height);
         Padded_Icon : constant Natural := Natural'Min (Draw_Icon, Natural'Min (Inner_W, Inner_H));
         Used_X      : constant Natural :=
           (if Large then 0 else Natural'Min (Inner_W, Saturating_Add (Padded_Icon, Item_Icon_Text_Gap)));
         Icon_X      : constant Natural :=
           (if Large then Saturating_Add (Inner_X, (if Inner_W > Padded_Icon then (Inner_W - Padded_Icon) / 2 else 0))
            else Inner_X);
         Icon_Y      : constant Natural := Inner_Y;
         Name_Units  : constant Natural :=
           Files.UTF8.Display_Units (To_String (Snapshot.Items.Element (Index).Name));
         Name_Pixels : constant Natural := Saturating_Multiply (Name_Units, Saturating_Multiply (Line_Height, 12) / 20);
         Large_Text_W : constant Natural := Natural'Min (Inner_W, Name_Pixels);
         Text_X      : constant Natural :=
           (if Large
            then Saturating_Add (Inner_X, (if Inner_W > Large_Text_W then (Inner_W - Large_Text_W) / 2 else 0))
            else Saturating_Add (Inner_X, Used_X));
         Text_Y      : constant Natural :=
           (if Large then Saturating_Add (Saturating_Add (Inner_Y, Padded_Icon), Item_Content_Padding)
            else Inner_Y);
         Text_W      : constant Natural :=
           (if Large then Large_Text_W else Saturating_Subtract (Inner_W, Used_X));
      begin
         Result.Append
           (Item_Layout'
              (Visible_Index => Snapshot.Items.Element (Index).Visible_Index,
               X             => Cell_X,
               Y             => Cell_Y,
               Width         => Cell_Width,
               Height        => Cell_Height,
               Icon_X        => Icon_X,
               Icon_Y         => Icon_Y,
               Icon_Size      => Padded_Icon,
               Text_X         => Text_X,
               Text_Y         => Text_Y,
               Text_Width     => Text_W,
               Name_X         => Text_X,
               Name_Width     => Text_W,
               Modified_X     => 0,
               Modified_Width => 0,
               Size_X         => 0,
               Size_Width     => 0,
               Filetype_X     => 0,
               Filetype_Width => 0,
               Created_X         => 0,
               Created_Width     => 0,
               Permissions_X     => 0,
               Permissions_Width => 0));
      end Append_Grid_Item;
   begin
      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         case Snapshot.View_Mode is
            when Files.Types.Small_Icons | Files.Types.Large_Icons =>
               declare
                  Metrics : constant Item_Cell_Metrics :=
                    Metrics_For (Snapshot.View_Mode, Content_W, Line_Height);
               begin
                  Append_Grid_Item
                    (Positive (Index),
                     Cell_W    => Positive (Metrics.Width),
                     Cell_H    => Positive (Metrics.Height),
                     Icon_Size => Positive (Metrics.Icon_Size),
                     Large     => Metrics.Large);
               end;
            when Files.Types.Details =>
               declare
                  Item       : constant Item_Snapshot := Snapshot.Items.Element (Positive (Index));
                  Metrics    : constant Item_Cell_Metrics :=
                    Metrics_For (Snapshot.View_Mode, Content_W, Line_Height);
                  Row_Step   : constant Natural := Metrics.Height;
                  Header_H   : constant Natural :=
                    Natural'Min
                      (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
                  Rows_Y     : constant Natural := Saturating_Add (Content_Y, Header_H);
                  Rows_H     : constant Natural := Saturating_Subtract (Content_H, Header_H);
                  Row_Offset : constant Natural := Saturating_Multiply (Natural (Index - 1), Row_Step);
                  Hidden_Px  : constant Natural :=
                    (if Row_Offset < Scroll_Pixels
                     then Natural'Min (Row_Step, Scroll_Pixels - Row_Offset)
                     else 0);
                  Visible_Row : constant Natural := Saturating_Subtract (Row_Offset, Scroll_Pixels);
                  Row_Y      : constant Natural := Saturating_Add (Rows_Y, Visible_Row);
                  Row_H      : constant Natural :=
                    (if Hidden_Px = 0 and then Rows_H >= Saturating_Add (Visible_Row, Row_Step)
                     then Row_Step
                     else 0);
                  Row_Draw_H : constant Natural :=
                    (if Row_H > Details_Row_Gap then Row_H - Details_Row_Gap else Row_H);
                  Row_Pad    : constant Natural := Natural'Min (Details_Row_Padding, Row_Draw_H);
                  Inner_H    : constant Natural :=
                    (if Row_Draw_H > Saturating_Multiply (Row_Pad, 2)
                     then Row_Draw_H - Saturating_Multiply (Row_Pad, 2)
                     else Row_Draw_H);
                  Row_Inner_X : constant Natural := Saturating_Add (Content_X, Row_Pad);
                  Text_Pad   : constant Natural := Natural'Min (Details_Column_Padding, Row_Draw_H);
                  Columns    : constant Detail_Column_Geometry_Array :=
                    Compute_Detail_Columns
                      (Snapshot.Detail_Columns_Visible,
                       Snapshot.Detail_Column_Widths,
                       Snapshot.Detail_Column_Order,
                       Content_X,
                       Content_W,
                       Line_Height,
                       Row_Pad);
                  Name_X     : constant Natural := Columns (Files.Types.Name_Column).X;
                  Name_W     : constant Natural := Columns (Files.Types.Name_Column).Width;
                  Header_Name_W : constant Natural :=
                    (if Saturating_Add (Content_X, Content_W) > Name_X
                     then Saturating_Add (Content_X, Content_W) - Name_X
                     else 0);

                  function Col_X (Column : Files.Types.Optional_Detail_Column) return Natural is
                    (Columns (Column).X);

                  function Col_W (Column : Files.Types.Optional_Detail_Column) return Natural is
                    (Columns (Column).Width);
               begin
                  if Item.Is_Group_Header then
                     Result.Append
                       (Item_Layout'
                          (Visible_Index  => 0,
                           X              => Content_X,
                           Y              => Row_Y,
                           Width          => Content_W,
                           Height         => Row_Draw_H,
                           Icon_X         => 0,
                           Icon_Y         => 0,
                           Icon_Size      => 0,
                           Text_X         => Saturating_Add (Name_X, Text_Pad),
                           Text_Y         =>
                             Saturating_Add (Row_Y, Saturating_Subtract (Row_Pad, 2)),
                           Text_Width     => Saturating_Subtract (Header_Name_W, Text_Pad),
                           Name_X         => Name_X,
                           Name_Width     => Header_Name_W,
                           Modified_X     => 0,
                           Modified_Width => 0,
                           Size_X         => 0,
                           Size_Width     => 0,
                           Filetype_X     => 0,
                           Filetype_Width => 0,
                           Created_X         => 0,
                           Created_Width     => 0,
                           Permissions_X     => 0,
                           Permissions_Width => 0));
                  else
                     Result.Append
                       (Item_Layout'
                          (Visible_Index  => Item.Visible_Index,
                           X              => Content_X,
                           Y              => Row_Y,
                           Width          => Content_W,
                           Height         => Row_Draw_H,
                           Icon_X         => Row_Inner_X,
                           Icon_Y         =>
                             Saturating_Add (Row_Y, Saturating_Subtract (Row_Pad, 2)),
                           Icon_Size      => Natural'Min (Line_Height, Inner_H),
                           Text_X         => Saturating_Add (Name_X, Text_Pad),
                           Text_Y         =>
                             Saturating_Add (Row_Y, Saturating_Subtract (Row_Pad, 2)),
                           Text_Width     => Saturating_Subtract (Name_W, Text_Pad),
                           Name_X         => Saturating_Add (Name_X, Text_Pad),
                           Name_Width     => Saturating_Subtract (Name_W, Text_Pad),
                           Modified_X     => Col_X (Files.Types.Modified_Column),
                           Modified_Width => Col_W (Files.Types.Modified_Column),
                           Size_X         => Col_X (Files.Types.Size_Column),
                           Size_Width     => Col_W (Files.Types.Size_Column),
                           Filetype_X     => Col_X (Files.Types.Filetype_Column),
                           Filetype_Width => Col_W (Files.Types.Filetype_Column),
                           Created_X         => Col_X (Files.Types.Created_Column),
                           Created_Width     => Col_W (Files.Types.Created_Column),
                           Permissions_X     => Col_X (Files.Types.Permissions_Column),
                           Permissions_Width => Col_W (Files.Types.Permissions_Column)));
                  end if;
               end;
         end case;
      end loop;

      return Result;
   end Calculate_Item_Layout;

   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Main_View_Layout
   is
      Padding      : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_W    : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      View_H       : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
      Count        : constant Natural := Natural (Snapshot.Items.Length);
      Metrics      : constant Item_Cell_Metrics :=
        Metrics_For (Snapshot.View_Mode, Content_W, Line_Height);
      Cell_W       : constant Natural := Metrics.Width;
      Cell_H       : constant Natural := Metrics.Height;
      Columns      : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details or else Cell_W = 0
         then 1
         elsif Content_W < Cell_W
         then 1
         else Natural'Max
           (1,
            Saturating_Add (Content_W, Main_Grid_Gap) / Saturating_Add (Cell_W, Main_Grid_Gap)));
      Rows         : constant Natural := (if Count = 0 then 0 else 1 + (Count - 1) / Columns);
      Row_Content_H : constant Natural :=
        (if Rows = 0 then 0
         elsif Snapshot.View_Mode = Files.Types.Details
         then Saturating_Multiply (Rows, Cell_H)
         else Saturating_Add
           (Saturating_Multiply (Rows, Cell_H),
            Saturating_Multiply (Rows - 1, Main_Grid_Gap)));
      --  Details shows a sticky column header; its rows scroll in the area
      --  BELOW it. The scrollbar's viewport and track are therefore the rows
      --  area (View_H minus the header), starting below the header -- otherwise
      --  the track spans the non-scrolling header band and the ends misalign.
      Header_H      : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details
         then Natural'Min
           (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), View_H)
         else 0);
      Viewport_H    : constant Natural := (if View_H > Header_H then View_H - Header_H else 0);
      Content_Total_H : constant Natural := Row_Content_H;
      Max_Scroll   : constant Natural :=
        (if Content_Total_H > Viewport_H then Content_Total_H - Viewport_H else 0);
      Requested_Px : constant Natural := Saturating_Multiply (Snapshot.Main_View_Scroll_Lines, Line_Height);
      Bounded_Px   : constant Natural := Natural'Min (Requested_Px, Max_Scroll);
      --  Snap the scroll offset to whole row periods so partially-scrolled
      --  rows at the top don't leave a visible empty band. Icons modes lay
      --  out rows on Cell_H + Main_Grid_Gap centers; Details has no row gap
      --  so the period is just Cell_H.
      Row_Stride   : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details
         then Cell_H
         else Saturating_Add (Cell_H, Main_Grid_Gap));
      --  At the very end of the list use the exact Max_Scroll instead of the
      --  floored multiple: Max_Scroll is rarely a whole row period, and the
      --  per-item visibility test drops a row that doesn't fully fit, so
      --  flooring here would leave the final row permanently clipped/unreachable.
      Scroll_Px    : constant Natural :=
        (if Row_Stride > 0 and then Bounded_Px < Max_Scroll
         then (Bounded_Px / Row_Stride) * Row_Stride
         else Bounded_Px);
      Scroll_Lines : constant Natural := Scroll_Px / Line_Height;
      Bar_W        : constant Natural := Natural'Min (Scrollbar_Width, Layout.Main_Width);
      Visible      : constant Boolean :=
        Viewport_H > 0
        and then Bar_W > 0
        and then Content_Total_H > Viewport_H;
      Thumb_H      : constant Natural :=
        (if Visible
         then Natural'Min
           (Viewport_H,
            Natural'Max
              (Line_Height,
               Bounded_Product_Divide
                 (Value => Viewport_H, Factor => Viewport_H, Denominator => Content_Total_H)))
         else 0);
      Track_H      : constant Natural :=
        (if Viewport_H > Thumb_H then Viewport_H - Thumb_H else 0);
      Track_Top    : constant Natural :=
        Saturating_Add (Saturating_Add (Layout.Main_Y, Padding), Header_H);
      Thumb_Y      : constant Natural :=
        (if Visible and then Max_Scroll > 0
         then Saturating_Add
           (Track_Top,
            Bounded_Product_Divide (Value => Track_H, Factor => Scroll_Px, Denominator => Max_Scroll))
         else Track_Top);
   begin
      return
        (Columns           => Positive'Max (1, Positive (Columns)),
         Content_Height    => Content_Total_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Layout.Main_X, Layout.Main_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Track_Top else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => Thumb_H,
         Scrollbar_Track_Height => (if Visible then Viewport_H else 0));
   end Calculate_Main_View_Layout;

   function Calculate_Conflict_Dialog_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Conflict_Dialog_Layout
   is
      pragma Unreferenced (Snapshot);
      Pad        : constant Natural := 12;
      Max_Width  : constant Natural := Saturating_Multiply (Line_Height, 22);
      Margin     : constant Natural := Saturating_Multiply (Line_Height, 2);
      Inner_W    : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Margin, 2)
         then Layout.Width - Saturating_Multiply (Margin, 2)
         else Layout.Width);
      Width      : constant Natural := Natural'Min (Max_Width, Inner_W);
      Message_H  : constant Natural := Saturating_Multiply (Line_Height, 2);
      Apply_H    : constant Natural := Line_Height;
      Button_H   : constant Natural := Saturating_Add (Line_Height, Pad);
      Height     : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Pad, 4),
           Saturating_Add (Message_H, Saturating_Add (Apply_H, Button_H)));
      X          : constant Natural := (if Layout.Width > Width then (Layout.Width - Width) / 2 else 0);
      Y          : constant Natural := (if Layout.Height > Height then (Layout.Height - Height) / 2 else 0);
      Button_Y   : constant Natural :=
        (if Height > Saturating_Add (Pad, Button_H)
         then Saturating_Add (Y, Height - Pad - Button_H)
         else Y);
      Apply_Y    : constant Natural :=
        (if Button_Y > Saturating_Add (Pad, Apply_H) then Button_Y - Pad - Apply_H else Button_Y);
      Inner_Buttons : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 5) then Width - Saturating_Multiply (Pad, 5) else 0);
      Button_W   : constant Natural := Inner_Buttons / 4;
      Apply_W    : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Apply_X       => Saturating_Add (X, Pad),
         Apply_Y       => Apply_Y,
         Apply_Width   => Apply_W,
         Apply_Height  => Apply_H,
         Button_Y      => Button_Y,
         Button_Height => Button_H,
         Replace_X     => Saturating_Add (X, Pad),
         Skip_X        => Saturating_Add (X, Saturating_Add (Saturating_Multiply (Pad, 2), Button_W)),
         Rename_X      =>
           Saturating_Add
             (X, Saturating_Add (Saturating_Multiply (Pad, 3), Saturating_Multiply (Button_W, 2))),
         Cancel_X      =>
           Saturating_Add
             (X, Saturating_Add (Saturating_Multiply (Pad, 4), Saturating_Multiply (Button_W, 3))),
         Button_Width  => Button_W);
   end Calculate_Conflict_Dialog_Layout;

   function Calculate_Paste_Progress_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Paste_Progress_Layout
   is
      pragma Unreferenced (Snapshot);
      Pad       : constant Natural := 12;
      Max_Width : constant Natural := Saturating_Multiply (Line_Height, 22);
      Margin    : constant Natural := Saturating_Multiply (Line_Height, 2);
      Inner_W   : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Margin, 2)
         then Layout.Width - Saturating_Multiply (Margin, 2)
         else Layout.Width);
      Width     : constant Natural := Natural'Min (Max_Width, Inner_W);
      Message_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Bar_H     : constant Natural := Natural'Max (6, Line_Height / 2);
      Button_H  : constant Natural := Saturating_Add (Line_Height, Pad);
      Height    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Pad, 5),
           Saturating_Add (Message_H, Saturating_Add (Bar_H, Button_H)));
      X         : constant Natural := (if Layout.Width > Width then (Layout.Width - Width) / 2 else 0);
      Y         : constant Natural := (if Layout.Height > Height then (Layout.Height - Height) / 2 else 0);
      Bar_W     : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width);
      Bar_Y     : constant Natural :=
        Saturating_Add (Y, Saturating_Add (Message_H, Saturating_Multiply (Pad, 2)));
      Button_H2 : constant Natural := Button_H;
      Button_Y  : constant Natural :=
        (if Height > Saturating_Add (Pad, Button_H2)
         then Saturating_Add (Y, Height - Pad - Button_H2) else Y);
      Button_W  : constant Natural :=
        Natural'Min
          (Saturating_Multiply (Line_Height, 6),
           (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width));
      Button_X  : constant Natural :=
        (if Width > Saturating_Add (Button_W, Pad) then Saturating_Add (X, Width - Pad - Button_W) else X);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Bar_X         => Saturating_Add (X, Pad),
         Bar_Y         => Bar_Y,
         Bar_Width     => Bar_W,
         Bar_Height    => Bar_H,
         Cancel_X      => Button_X,
         Cancel_Y      => Button_Y,
         Cancel_Width  => Button_W,
         Cancel_Height => Button_H2);
   end Calculate_Paste_Progress_Layout;

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

   function Settings_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Settings_Hit_Region is
   begin
      --  Iterate in reverse so that the most-recently appended (i.e. the most
      --  specific inline) region takes precedence over the catch-all field
      --  row that wraps the entire row above it.
      for Index in reverse 1 .. Natural (Frame.Settings_Hits.Length) loop
         declare
            Region : constant Settings_Hit_Region :=
              Frame.Settings_Hits.Element (Positive (Index));
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
   end Settings_Hit_At;

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
   is
      Result : Context_Menu_Layout;
      Next   : Natural := 0;

      --  Append a selectable command row.
      procedure Add_Command (Command : Files.Commands.Command_Id) is
      begin
         Next := Next + 1;
         Result.Commands (Next) := Command;
         Result.Row_Kinds (Next) := Command_Row;
      end Add_Command;

      --  Append a non-selectable divider row between two command groups.
      procedure Add_Separator is
      begin
         Next := Next + 1;
         Result.Commands (Next) := Files.Commands.No_Command;
         Result.Row_Kinds (Next) := Separator_Row;
      end Add_Separator;
   begin
      if not Snapshot.Context_Menu_Open then
         return Result;
      end if;

      case Snapshot.Context_Menu_Target is
         when Files.Model.Context_Menu_Item =>
            --  Group 1: open actions, including revealing a search result in its
            --  containing folder.
            Add_Command (Files.Commands.Open_Selected_Items_Command);
            Add_Command (Files.Commands.Open_With_Command);
            Add_Command (Files.Commands.Open_Containing_Folder_Command);
            Add_Separator;
            --  Group 2: favorite the current selection and set its color label
            --  (tagging verbs grouped together).
            Add_Command (Files.Commands.Toggle_Favorite_Command);
            Add_Command (Files.Commands.Set_Color_Label_Command);
            Add_Separator;
            --  Group 3: clipboard / duplication, including the copy-to and
            --  move-to destination pickers next to the plain clipboard verbs.
            Add_Command (Files.Commands.Copy_Selected_Items_Command);
            Add_Command (Files.Commands.Cut_Selected_Items_Command);
            Add_Command (Files.Commands.Copy_Path_Command);
            Add_Command (Files.Commands.Copy_To_Command);
            Add_Command (Files.Commands.Move_To_Command);
            Add_Command (Files.Commands.Duplicate_Selected_Command);
            Add_Separator;
            --  Group 4: archive actions.
            Add_Command (Files.Commands.Compress_Zip_Command);
            Add_Command (Files.Commands.Compress_7z_Command);
            Add_Command (Files.Commands.Extract_Archive_Command);
            Add_Separator;
            --  Group 5: link creation.
            Add_Command (Files.Commands.Create_Symlink_Command);
            Add_Command (Files.Commands.Create_Hardlink_Command);
            Add_Separator;
            --  Group 6: destructive / recovery actions.
            Add_Command (Files.Commands.Rename_Selected_Items_Command);
            Add_Command (Files.Commands.Delete_Selected_Items_Command);
            Add_Command (Files.Commands.Restore_From_Trash_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_Empty =>
            Add_Command (Files.Commands.Create_File_Command);
            Add_Command (Files.Commands.New_Folder_Command);
            Add_Command (Files.Commands.Paste_Items_Command);
            Add_Separator;
            --  Background directory actions: open a terminal here and refresh.
            Add_Command (Files.Commands.Open_Terminal_Command);
            Add_Command (Files.Commands.Refresh_Directory_Command);
            Add_Separator;
            --  Trash-view action: permanently purge every trashed entry. Enabled
            --  only while the trash payload directory is shown and non-empty.
            Add_Command (Files.Commands.Empty_Trash_Command);
            --  Recent-view action: empty the recent list. Enabled only while the
            --  virtual recent view is shown and non-empty.
            Add_Command (Files.Commands.Clear_Recent_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_Header =>
            --  Details-view column configuration: toggle each optional column,
            --  then cycle the grouping mode. Reuses the same layout/hit-test the
            --  item and empty-area menus draw with.
            Add_Command (Files.Commands.Toggle_Column_Modified_Command);
            Add_Command (Files.Commands.Toggle_Column_Size_Command);
            Add_Command (Files.Commands.Toggle_Column_Type_Command);
            Add_Command (Files.Commands.Toggle_Column_Created_Command);
            Add_Command (Files.Commands.Toggle_Column_Permissions_Command);
            Add_Separator;
            Add_Command (Files.Commands.Cycle_Group_By_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_None =>
            return Result;
      end case;

      Result.Padding := 4;
      Result.Row_Height :=
        Saturating_Add (Line_Height, Saturating_Multiply (Result.Padding, 2));
      --  A separator is just a 1px divider line surrounded by the row padding,
      --  so it takes noticeably less vertical space than a command row.
      Result.Separator_Height :=
        Saturating_Add (1, Saturating_Multiply (Result.Padding, 2));

      --  Size the menu to the widest command label (using the same monospace
      --  cell metric and edge padding the renderer draws rows with) so labels
      --  are not truncated, then clamp to the available screen width.
      declare
         Cell_W    : constant Positive :=
           Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Edge_Pad  : constant Natural :=
           Saturating_Multiply (Files.UI.Input_Field_Padding, 2);
         Max_Label : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            if Result.Row_Kinds (Row) = Command_Row then
               declare
                  Label : constant String :=
                    Files.Localization.Text
                      (Files.Commands.Name_Key (Result.Commands (Row)));
                  Label_W : constant Natural :=
                    Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
               begin
                  Max_Label := Natural'Max (Max_Label, Label_W);
               end;
            end if;
         end loop;

         Result.Width :=
           Natural'Max
             (Natural'Max (Saturating_Multiply (Line_Height, 9), 180),
              Saturating_Add (Max_Label, Edge_Pad));

         if Width > 0 and then Result.Width > Width then
            Result.Width := Width;
         end if;
      end;

      declare
         Rows_Height : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            Rows_Height :=
              Saturating_Add
                (Rows_Height,
                 (if Result.Row_Kinds (Row) = Separator_Row
                  then Result.Separator_Height
                  else Result.Row_Height));
         end loop;
         Result.Height :=
           Saturating_Add
             (Rows_Height, Saturating_Multiply (Result.Padding, 2));
      end;

      --  Anchor to the cursor but keep the menu fully on-screen.
      Result.X :=
        (if Snapshot.Context_Menu_X + Result.Width > Width
         then (if Width > Result.Width then Width - Result.Width else 0)
         else Snapshot.Context_Menu_X);
      Result.Y :=
        (if Snapshot.Context_Menu_Y + Result.Height > Height
         then (if Height > Result.Height then Height - Result.Height else 0)
         else Snapshot.Context_Menu_Y);
      Result.Visible := Result.Width > 0 and then Result.Height > 0;

      return Result;
   end Calculate_Context_Menu_Layout;

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
      return Natural is
   begin
      for Item of Items loop
         if Contains_Rectangle_Point
              (Item.X, Item.Y, Item.Width, Item.Height, X, Y)
         then
            return Item.Visible_Index;
         end if;
      end loop;

      return 0;
   end Item_At;

   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural) is
   begin
      X := Natural'Min (Start_X, Current_X);
      Y := Natural'Min (Start_Y, Current_Y);
      Width := Natural'Max (Start_X, Current_X) - X;
      Height := Natural'Max (Start_Y, Current_Y) - Y;
   end Marquee_Rect;

   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector
   is
      Hits : Visible_Index_Vectors.Vector;

      --  Half-open rectangle overlap: two rectangles intersect when each axis'
      --  intervals overlap. A zero-width or zero-height marquee touches nothing,
      --  so a plain click (no drag) never selects via this path.
      function Overlaps (Item : Item_Layout) return Boolean is
      begin
         return Width > 0
           and then Height > 0
           and then Item.Width > 0
           and then Item.Height > 0
           and then Item.X < Saturating_Add (X, Width)
           and then X < Saturating_Add (Item.X, Item.Width)
           and then Item.Y < Saturating_Add (Y, Height)
           and then Y < Saturating_Add (Item.Y, Item.Height);
      end Overlaps;
   begin
      for Item of Items loop
         if Item.Visible_Index > 0 and then Overlaps (Item) then
            Hits.Append (Item.Visible_Index);
         end if;
      end loop;

      return Hits;
   end Items_In_Rect;

   procedure Rename_Field_Extent
     (Item      : Item_Layout;
      View_Mode : Files.Types.View_Mode;
      Renaming  : Boolean;
      Field_X   : out Natural;
      Field_W   : out Natural)
   is
      --  Large-icons cells stack a narrow, name-width label centered under the
      --  icon. That region cannot hold an edited (often longer) name, so while
      --  renaming a large-icons cell we edit across the full inner cell width,
      --  mirroring how the wide small-icons/details rows already behave.
      Wide : constant Boolean := Renaming and then View_Mode = Files.Types.Large_Icons;
      Pad  : constant Natural := Natural'Min (Item_Content_Padding, Item.Width / 2);
   begin
      Field_X := (if Wide then Saturating_Add (Item.X, Pad) else Item.Text_X);
      Field_W :=
        (if Wide
         then (if Item.Width > Saturating_Multiply (Pad, 2)
               then Item.Width - Saturating_Multiply (Pad, 2)
               else Item.Width)
         else Item.Text_Width);
   end Rename_Field_Extent;

   function Details_Header_Command_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Padding   : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
      Content_W : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      Content_H : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
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
         return Files.Commands.No_Command;
      elsif Within (Files.Types.Name_Column) then
         return Files.Commands.Sort_By_Name_Command;
      elsif Within (Files.Types.Modified_Column) then
         return Files.Commands.Sort_By_Changed_Command;
      elsif Within (Files.Types.Size_Column) then
         return Files.Commands.Sort_By_Size_Command;
      elsif Within (Files.Types.Filetype_Column) then
         return Files.Commands.Sort_By_Type_Command;
      elsif Within (Files.Types.Created_Column) then
         return Files.Commands.Sort_By_Created_Command;
      else
         return Files.Commands.No_Command;
      end if;
   end Details_Header_Command_At;

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
      Padding   : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
      Content_W : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      Content_H : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
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
   is
      use type Files.Types.Detail_Column;
      Padding   : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
      Content_W : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      Content_H : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
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
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
        or else X < Content_X
        or else X >= Saturating_Add (Content_X, Content_W)
      then
         return 0;
      end if;

      --  The dragged column takes the slot of the first visible optional column
      --  whose right edge is beyond the pointer (i.e. the one the pointer is
      --  over, or the first to its right). A pointer past all of them targets
      --  the final slot.
      for Slot in Snapshot.Detail_Column_Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column :=
              Snapshot.Detail_Column_Order (Slot);
         begin
            if Column /= Files.Types.Name_Column
              and then Columns (Column).Visible
              and then X < Saturating_Add (Columns (Column).X, Columns (Column).Width)
            then
               return Slot;
            end if;
         end;
      end loop;

      return Files.Types.Detail_Column_Count;
   end Details_Header_Drop_Index;

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
      Padding   : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
      Content_W : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      Content_H : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
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
      return Command_Palette_Layout
   is
      Search_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2)),
           (if Layout.Command_Height > Saturating_Multiply (Command_Palette_Padding, 2)
            then Layout.Command_Height - Saturating_Multiply (Command_Palette_Padding, 2)
            else Layout.Command_Height));
      Content_X : constant Natural := Saturating_Add (Layout.Command_X, Command_Palette_Padding);
      Content_Y : constant Natural := Saturating_Add (Layout.Command_Y, Command_Palette_Padding);
      Content_W : constant Natural :=
        (if Layout.Command_Width > Saturating_Multiply (Command_Palette_Padding, 2)
         then Layout.Command_Width - Saturating_Multiply (Command_Palette_Padding, 2)
         else Layout.Command_Width);
      Content_H : constant Natural :=
        (if Layout.Command_Height > Saturating_Multiply (Command_Palette_Padding, 2)
         then Layout.Command_Height - Saturating_Multiply (Command_Palette_Padding, 2)
         else Layout.Command_Height);
      Results_Y : constant Natural :=
        Saturating_Add (Content_Y, Saturating_Add (Search_H, Command_Palette_Padding));
      Used_H    : constant Natural := Saturating_Add (Search_H, Command_Palette_Padding);
   begin
      return
        (X              => Layout.Command_X,
         Y              => Layout.Command_Y,
         Width          => Layout.Command_Width,
         Height         => Layout.Command_Height,
         Search_X       => Content_X,
         Search_Y       => Content_Y,
         Search_Width   => Content_W,
         Search_Height  => Search_H,
         Results_X      => Content_X,
         Results_Y      => Results_Y,
         Results_Width  => Content_W,
         Results_Height => (if Content_H > Used_H then Content_H - Used_H else 0),
         Row_Height     =>
           Saturating_Add
             (Saturating_Multiply (Line_Height, 2),
              Saturating_Multiply (Command_Result_Row_Padding, 2)));
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

   function Calculate_Command_Result_Layout
     (Snapshot : View_Snapshot;
      Layout   : Command_Palette_Layout)
      return Command_Result_Layout_Vectors.Vector
   is
      Result : Command_Result_Layout_Vectors.Vector;
      Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
      Visible_Rows : constant Natural := Complete_Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);
      Max_Offset   : constant Natural :=
        (if Visible_Rows = 0 or else Result_Count <= Visible_Rows then 0 else Result_Count - Visible_Rows);
      Offset       : constant Natural := Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset);
   begin
      if not Snapshot.Command_Palette_Open or else Layout.Row_Height = 0 then
         return Result;
      end if;

      for Index in Offset + 1 .. Result_Count loop
         declare
            Result_Y : constant Natural :=
              Saturating_Add
                (Layout.Results_Y, Saturating_Multiply (Natural (Index - Offset - 1), Layout.Row_Height));
            Results_End_Y : constant Natural := Saturating_Add (Layout.Results_Y, Layout.Results_Height);
         begin
            exit when Result_Y >= Results_End_Y;
            declare
               Remaining : constant Natural := Results_End_Y - Result_Y;
            begin
               exit when Remaining < Layout.Row_Height;

               Result.Append
                 (Command_Result_Layout'
                    (Result_Index => Index,
                     X            => Layout.Results_X,
                     Y            => Result_Y,
                     Width        => Layout.Results_Width,
                     Height       => Layout.Row_Height,
                     Selected     => Snapshot.Command_Palette_Results.Element (Positive (Index)).Selected,
                     Enabled      => Snapshot.Command_Palette_Results.Element (Positive (Index)).Enabled));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Command_Result_Layout;

   function Command_Result_At
     (Rows : Command_Result_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point
              (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Result_Index;
         end if;
      end loop;

      return 0;
   end Command_Result_At;

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
          (Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2)),
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
   is
      Result       : Root_Path_Layout_Vectors.Vector;
      Root_Count   : constant Natural := Natural (Snapshot.Root_Paths.Length);
      Content_H    : constant Natural :=
        (if Layout.Height > Saturating_Multiply (Root_Selector_Padding, 2)
         then Layout.Height - Saturating_Multiply (Root_Selector_Padding, 2)
         else 0);
      Content_W    : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Root_Selector_Padding, 2)
         then Layout.Width - Saturating_Multiply (Root_Selector_Padding, 2)
         else Layout.Width);
      Visible_Rows : constant Natural := Visible_Row_Count (Content_H, Layout.Row_Height);
      Start_Index  : Natural := 1;
      Selected_Index : Natural := Snapshot.Root_Selected_Index;
   begin
      if not Snapshot.Root_Selector_Open
        or else Layout.Row_Height = 0
        or else Root_Count = 0
      then
         return Result;
      end if;

      if Selected_Index > Root_Count then
         Selected_Index := Root_Count;
      end if;

      if Visible_Rows > 0 and then Selected_Index > Visible_Rows then
         Start_Index := Selected_Index - Visible_Rows + 1;
      end if;

      if Start_Index > Root_Count then
         Start_Index := Root_Count;
      end if;

      for Index in Start_Index .. Root_Count loop
         declare
            Row_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Layout.Y, Root_Selector_Padding),
                 Saturating_Multiply (Natural (Index - Start_Index), Layout.Row_Height));
            Layout_End_Y : constant Natural :=
              Saturating_Add
                (Layout.Y,
                 (if Layout.Height > Root_Selector_Padding then Layout.Height - Root_Selector_Padding else 0));
         begin
            exit when Row_Y >= Layout_End_Y;
            declare
               Remaining : constant Natural := Layout_End_Y - Row_Y;
               Row_H     : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
            begin
               Result.Append
                 (Root_Path_Layout'
                    (Root_Index => Index,
                     X          => Saturating_Add (Layout.X, Root_Selector_Padding),
                     Y          => Row_Y,
                     Width      => Content_W,
                     Height     => Row_H,
                     Selected   => Index = Selected_Index));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Root_Path_Layout;

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
      Toolbar      : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (Width);
      Field_Margin : constant Natural := 6;
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Pad          : constant Natural := Files.UI.Input_Field_Padding;
      Star_W       : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
   begin
      if Toolbar.Middle_Width <= Saturating_Add (Saturating_Multiply (Field_Margin, 2), Saturating_Add (Star_W, Pad))
      then
         return (others => <>);
      end if;
      return
        (X       => Saturating_Add (Path_X, Pad),
         Y       => Files.UI.Toolbar_Input_Y (Line_Height),
         Width   => Star_W,
         Height  => Files.UI.Toolbar_Input_Height (Line_Height),
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
      --  Star cell width plus a small gap so breadcrumbs/edit text clear it.
      return Saturating_Add (Star.Width, Natural'Max (2, Files.UI.Input_Field_Padding / 2));
   end Path_Bar_Content_Offset;

   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Breadcrumb_Segment_Layout_Vectors.Vector
   is
      Result       : Breadcrumb_Segment_Layout_Vectors.Vector;
      Toolbar      : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (Width);
      Field_Margin : constant Natural := 6;
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Path_W       : constant Natural :=
        (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
         then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
         else 0);
      Input_Y      : constant Natural := Files.UI.Toolbar_Input_Y (Line_Height);
      Input_H      : constant Natural := Files.UI.Toolbar_Input_Height (Line_Height);
      Pad          : constant Natural := Files.UI.Input_Field_Padding;
      Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
      Advance      : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
      Inner_X      : constant Natural := Saturating_Add (Saturating_Add (Path_X, Pad), Star_Reserve);
      Inner_W      : constant Natural :=
        (if Path_W > Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         then Path_W - Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         else 0);
      Sep_Cells    : constant Natural := 1;

      function Total_Cells
        (Src : Files.Breadcrumbs.Segment_Vectors.Vector)
         return Natural
      is
         Sum   : Natural := 0;
         Count : constant Natural := Natural (Src.Length);
      begin
         for I in 1 .. Count loop
            Sum := Saturating_Add (Sum, Files.UTF8.Display_Units (To_String (Src.Element (I).Label)));
            if I < Count then
               Sum := Saturating_Add (Sum, Sep_Cells);
            end if;
         end loop;
         return Sum;
      end Total_Cells;
   begin
      if Snapshot.Focus = Files.Types.Focus_Path_Input then
         return Result;
      elsif Snapshot.Breadcrumb_Segments.Is_Empty or else Inner_W = 0 then
         return Result;
      end if;

      declare
         Full           : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Snapshot.Breadcrumb_Segments;
         Count          : constant Natural := Natural (Full.Length);
         Capacity_Cells : constant Natural := Inner_W / Advance;
         Shown          : Files.Breadcrumbs.Segment_Vectors.Vector := Full;
         Cursor_X       : Natural := Inner_X;
      begin
         if Total_Cells (Full) > Capacity_Cells then
            declare
               Fitted : Boolean := False;
            begin
               for Max in reverse 3 .. Count loop
                  declare
                     Candidate : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
                       Files.Breadcrumbs.Elide (Full, Max);
                  begin
                     if Total_Cells (Candidate) <= Capacity_Cells then
                        Shown  := Candidate;
                        Fitted := True;
                        exit;
                     end if;
                  end;
               end loop;
               if not Fitted then
                  Shown := Files.Breadcrumbs.Elide (Full, Positive'Max (1, Natural'Min (3, Count)));
               end if;
            end;
         end if;

         for I in 1 .. Natural (Shown.Length) loop
            declare
               Seg        : constant Files.Breadcrumbs.Segment := Shown.Element (Positive (I));
               Cells      : constant Natural := Files.UTF8.Display_Units (To_String (Seg.Label));
               Seg_W      : constant Natural := Saturating_Multiply (Cells, Advance);
               Clickable  : constant Boolean := not Files.Breadcrumbs.Is_Ellipsis (Seg);
               Full_Index : Natural := 0;
            begin
               if Clickable then
                  for F in 1 .. Count loop
                     if Full.Element (Positive (F)).Ancestor_Path = Seg.Ancestor_Path then
                        Full_Index := F;
                        exit;
                     end if;
                  end loop;
               end if;
               Result.Append
                 (Breadcrumb_Segment_Layout'
                    (Segment_Index => Full_Index,
                     X             => Cursor_X,
                     Y             => Input_Y,
                     Width         => Seg_W,
                     Height        => Input_H,
                     Clickable     => Clickable and then Full_Index /= 0));
               Cursor_X :=
                 Saturating_Add
                   (Cursor_X,
                    Saturating_Add (Seg_W, Saturating_Multiply (Sep_Cells, Advance)));
            end;
         end loop;
      end;

      return Result;
   end Calculate_Breadcrumb_Layout;

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
        Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2));
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
   is
      Result      : Tree_Row_Layout_Vectors.Vector;
      Padding     : constant Natural := Root_Selector_Padding;
      Indent_W    : constant Natural := Line_Height;
      Header_H    : constant Natural := Layout.Row_Height;
      Content_X   : constant Natural := Saturating_Add (Layout.X, Padding);
      Panel_End_Y : constant Natural := Saturating_Add (Layout.Y, Layout.Height);
      Current     : constant String := To_String (Snapshot.Current_Path);
   begin
      if not Snapshot.Tree_Panel_Open or else Layout.Row_Height = 0 then
         return Result;
      end if;

      for I in 1 .. Natural (Snapshot.Tree_Rows.Length) loop
         declare
            TR    : constant Files.Folder_Tree.Visible_Row :=
              Snapshot.Tree_Rows.Element (Positive (I));
            Row_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Layout.Y, Header_H),
                 Saturating_Multiply (Natural (I - 1), Layout.Row_Height));
         begin
            exit when Row_Y >= Panel_End_Y;
            declare
               Remaining    : constant Natural := Panel_End_Y - Row_Y;
               Row_H        : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
               Depth_Indent : constant Natural := Saturating_Multiply (TR.Depth, Indent_W);
               Tri_X        : constant Natural := Saturating_Add (Content_X, Depth_Indent);
               Tri_Size     : constant Natural := Natural'Min (Line_Height, Row_H);
               Tri_Y        : constant Natural :=
                 (if Row_H > Tri_Size
                  then Saturating_Add (Row_Y, (Row_H - Tri_Size) / 2)
                  else Row_Y);
            begin
               Result.Append
                 (Tree_Row_Layout'
                    (Node_Index   => TR.Node_Index,
                     X            => Layout.X,
                     Y            => Row_Y,
                     Width        => Layout.Width,
                     Height       => Row_H,
                     Depth        => TR.Depth,
                     Expanded     => TR.Expanded,
                     Has_Children => TR.Has_Children,
                     Selected     =>
                       (if Snapshot.Tree_Pick_Active
                        then To_String (TR.Path) = To_String (Snapshot.Tree_Pick_Target)
                        else To_String (TR.Path) = Current),
                     Triangle_X   => Tri_X,
                     Triangle_Y   => Tri_Y,
                     Triangle_W   => (if TR.Has_Children then Tri_Size else 0),
                     Triangle_H   => (if TR.Has_Children then Tri_Size else 0)));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Tree_Row_Layout;

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
              (if Info.Owner_Editing
               then Info.Ownership_Buffer
               else To_Unbounded_String
                      (Ada.Strings.Fixed.Trim (Natural'Image (Info.Owner_Id), Ada.Strings.Both)));
         when 10 =>
            return
              (if Info.Group_Editing
               then Info.Ownership_Buffer
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

   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive;
      Show_Grid   : Boolean := False)
      return Natural
   is
      Rows : Natural := 0;
   begin
      for Field in 0 .. 8 loop
         Rows :=
           Saturating_Add
             (Rows,
              Saturating_Add
                 (2,
                 Wrapped_Line_Count (Info_Field_Display_Value (Info, Field), Text_W, Line_Height)));
      end loop;

      if Show_Grid then
         Rows := Saturating_Add (Rows, Permission_Grid_Rows);
      end if;

      if Info.Ownership_Available then
         for Field in 9 .. 10 loop
            Rows :=
              Saturating_Add
                (Rows,
                 Saturating_Add
                   (2,
                    Wrapped_Line_Count (Info_Field_Display_Value (Info, Field), Text_W, Line_Height)));
         end loop;
      end if;

      if Info.Is_Directory and then Info.Folder_Size_Available then
         Rows :=
           Saturating_Add
             (Rows,
              Saturating_Add
                (2, Wrapped_Line_Count (Folder_Contents_Text (Info), Text_W, Line_Height)));
      end if;

      return Rows;
   end Info_Section_Row_Count;

   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Info_Pane_Layout
   is
      function Total_Info_Rows return Natural is
         Rows : Natural := 0;
      begin
         for Info of Snapshot.Selected_Info loop
            Rows :=
              Saturating_Add
                (Rows,
                 Info_Section_Row_Count
                   (Info,
                    Info_Text_Width (Layout, Scrollbar_W => Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width)),
                    Line_Height,
                    Show_Grid => Snapshot.Permissions_Editable));
         end loop;

         return Rows;
      end Total_Info_Rows;

      Pane_X        : constant Natural := Layout.Main_Width;
      Bar_W         : constant Natural := Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width);
      Text_W        : constant Natural := Info_Text_Width (Layout, Bar_W);
      Content_Rows  : constant Natural := Total_Info_Rows;
      Raw_Content_H : constant Natural := Saturating_Multiply (Content_Rows, Line_Height);
      Content_H     : constant Natural :=
        (if Raw_Content_H > 0
         then Saturating_Add (Raw_Content_H, Saturating_Multiply (Info_Pane_Padding, 2))
         else 0);
      Visible       : constant Boolean :=
        Snapshot.Info_Pane_Open
        and then Layout.Info_Pane_Width > 0
        and then Bar_W > 0
        and then Layout.Main_Height > 0
        and then Content_H > Layout.Main_Height;
      Thumb_H       : constant Natural :=
        (if Visible
         then Natural'Max
           (Line_Height,
            Bounded_Product_Divide
              (Value => Layout.Main_Height, Factor => Layout.Main_Height, Denominator => Content_H))
         else 0);
      Max_Scroll_Px : constant Natural :=
        (if Content_H > Layout.Main_Height then Content_H - Layout.Main_Height else 0);
      Requested_Px  : constant Natural := Saturating_Multiply (Snapshot.Info_Pane_Scroll_Lines, Line_Height);
      Scroll_Px     : constant Natural := Natural'Min (Requested_Px, Max_Scroll_Px);
      Scroll_Lines  : constant Natural := Scroll_Px / Line_Height;
      Track_H       : constant Natural := (if Layout.Main_Height > Thumb_H then Layout.Main_Height - Thumb_H else 0);
      Thumb_Y       : constant Natural :=
        (if Visible and then Max_Scroll_Px > 0
         then Saturating_Add
           (Layout.Main_Y,
            Bounded_Product_Divide (Value => Track_H, Factor => Scroll_Px, Denominator => Max_Scroll_Px))
         else Layout.Main_Y);
   begin
      if not Snapshot.Info_Pane_Open or else Layout.Info_Pane_Width = 0 then
         return (others => <>);
      end if;

      return
        (X                 => Pane_X,
         Y                 => Layout.Main_Y,
         Width             => Layout.Info_Pane_Width,
         Height            => Layout.Main_Height,
         Content_Height    => Content_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Pane_X, Layout.Info_Pane_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Layout.Main_Y else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => (if Visible then Natural'Min (Thumb_H, Layout.Main_Height) else 0),
         Scrollbar_Track_Height => (if Visible then Layout.Main_Height else 0));
   end Calculate_Info_Pane_Layout;

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
   is
      Result        : Frame_Commands;
      Layout        : constant Layout_Metrics :=
        Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Items         : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Main_View     : constant Main_View_Layout := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Toolbar       : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (Width);
      Bottom        : constant Files.UI.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (Width, Line_Height);
      Palette       : constant Command_Palette_Layout := Calculate_Command_Palette_Layout (Layout, Line_Height);
      Toolbar_Input_Y : constant Natural := Files.UI.Toolbar_Input_Y (Line_Height);
      Toolbar_Input_H : constant Natural := Files.UI.Toolbar_Input_Height (Line_Height);
      --  Visible glyph content sits in the lower half of the Line_Height cell
      --  (see Sel_Y_Offset elsewhere). Pull the text origin up by Line_Height/12
      --  so the rendered glyph centers in the field instead of biasing low.
      Toolbar_Glyph_Bias : constant Natural := Line_Height / 12;
      Toolbar_Input_Text_Y : constant Natural :=
        (if Toolbar_Input_H > Line_Height
         then
            (declare
                Centered : constant Natural :=
                  Saturating_Add
                    (Toolbar_Input_Y, (Toolbar_Input_H - Line_Height) / 2);
             begin
                (if Centered > Toolbar_Glyph_Bias
                 then Centered - Toolbar_Glyph_Bias
                 else 0))
         else Toolbar_Input_Y);
      Toolbar_Input_Text_H : constant Natural :=
        Natural'Min (Line_Height, Toolbar_Input_H);
      Palette_Rows  : constant Command_Result_Layout_Vectors.Vector :=
        Calculate_Command_Result_Layout (Snapshot, Palette);
      Root_Selector : constant Root_Selector_Layout :=
        Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Rows     : constant Root_Path_Layout_Vectors.Vector :=
        Calculate_Root_Path_Layout (Snapshot, Root_Selector);
      Breadcrumb_Rows : constant Breadcrumb_Segment_Layout_Vectors.Vector :=
        Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height);
      Tree_Panel    : constant Tree_Panel_Layout :=
        Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);
      Tree_Rows_Layout : constant Tree_Row_Layout_Vectors.Vector :=
        Calculate_Tree_Row_Layout (Snapshot, Tree_Panel, Line_Height);
      Info_Pane     : constant Info_Pane_Layout := Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Settings_Pane : constant Files.UI.Settings_Pane_Layout :=
        Files.UI.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      Bottom_Y      : constant Natural :=
        (if Height > Layout.Bottom_Bar_Height then Height - Layout.Bottom_Bar_Height else 0);
      Bottom_Content_Y : constant Natural :=
        Saturating_Add
          (Bottom_Y,
           (if Files.UI.Bottom_Bar_Padding >= 2 then Files.UI.Bottom_Bar_Padding - 2 else 0));
      Bottom_Content_H : constant Natural :=
        (if Layout.Bottom_Bar_Height > Saturating_Multiply (Files.UI.Bottom_Bar_Padding, 2)
         then Layout.Bottom_Bar_Height - Saturating_Multiply (Files.UI.Bottom_Bar_Padding, 2)
         else Layout.Bottom_Bar_Height);
      Drawing_Settings_Pane : Boolean := False;
      Drawing_Command_Palette : Boolean := False;

      function Intersects
        (Left_X   : Natural;
         Left_Y   : Natural;
         Left_W   : Natural;
         Left_H   : Natural;
         Right_X  : Natural;
         Right_Y  : Natural;
         Right_W  : Natural;
         Right_H  : Natural)
         return Boolean
      is
      begin
         return Left_W > 0
           and then Left_H > 0
           and then Right_W > 0
           and then Right_H > 0
           and then Left_X < Saturating_Add (Right_X, Right_W)
           and then Right_X < Saturating_Add (Left_X, Left_W)
           and then Left_Y < Saturating_Add (Right_Y, Right_H)
           and then Right_Y < Saturating_Add (Left_Y, Left_H);
      end Intersects;

      function Clipped_Size
        (Start : Natural;
         Size  : Natural;
         Limit : Natural)
         return Natural
      is
      begin
         if Start >= Limit or else Size = 0 then
            return 0;
         else
            return Natural'Min (Size, Limit - Start);
         end if;
      end Clipped_Size;

      function Hidden_By_Settings_Pane
        (X      : Natural;
         Y      : Natural;
         Item_W : Natural;
         Item_H : Natural)
         return Boolean
      is
      begin
         return Snapshot.Settings_Pane_Open
           and then not Drawing_Settings_Pane
           and then Intersects
             (X,
              Y,
              Item_W,
              Item_H,
              Settings_Pane.X,
              Settings_Pane.Y,
              Settings_Pane.Width,
              Settings_Pane.Height);
      end Hidden_By_Settings_Pane;

      function Hidden_By_Command_Palette
        (X      : Natural;
         Y      : Natural;
         Item_W : Natural;
         Item_H : Natural)
         return Boolean
      is
      begin
         return Snapshot.Command_Palette_Open
           and then not Drawing_Command_Palette
           and then Intersects
             (X,
              Y,
              Item_W,
              Item_H,
              Palette.X,
              Palette.Y,
              Palette.Width,
              Palette.Height);
      end Hidden_By_Command_Palette;

      procedure Add_Rect
        (X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Rectangles.Append
              (Rectangle_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Color  => Color));
         end if;
      end Add_Rect;

      procedure Add_Triangle
        (X1    : Float;
         Y1    : Float;
         X2    : Float;
         Y2    : Float;
         X3    : Float;
         Y3    : Float;
         Color : Render_Color)
      is
      begin
         if Layout.Width = 0 or else Layout.Height = 0 then
            return;
         end if;

         Result.Triangles.Append
           (Triangle_Command'
              (X1    => X1,
               Y1    => Y1,
               X2    => X2,
               Y2    => Y2,
               X3    => X3,
               Y3    => Y3,
               Color => Color));
      end Add_Triangle;

      procedure Add_Overlay_Rect
        (X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Overlay_Rectangles.Append
              (Rectangle_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Color  => Color));
         end if;
      end Add_Overlay_Rect;

      function Fitted_Text_For
        (Text     : UString;
         Capacity : Natural)
         return UString
      is
         Raw : constant String := To_String (Text);
      begin
         if Capacity = 0 then
            return Null_Unbounded_String;
         elsif Files.UTF8.Display_Units (Raw) <= Capacity then
            return Text;
         elsif Capacity < 2 then
            return To_Unbounded_String (Files.UTF8.Prefix_By_Units (Raw, Capacity));
         else
            declare
               Prefix  : constant String := Files.UTF8.Prefix_By_Units (Raw, Capacity - 1);
               Trimmed : constant String :=
                 (if Prefix'Length > 0
                    and then (Prefix (Prefix'Last) = '.'
                              or else Prefix (Prefix'Last) = ' ')
                  then Prefix (Prefix'First .. Prefix'Last - 1)
                  else Prefix);
            begin
               if Trimmed = "" then
                  return To_Unbounded_String (Files.UTF8.Prefix_By_Units (Raw, Capacity));
               else
                  return To_Unbounded_String (Trimmed & Ellipsis_Text);
               end if;
            end;
         end if;
      end Fitted_Text_For;

      procedure Add_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False;
         Scale_To_Box : Boolean := False;
         Italic : Boolean := False)
      is
         Draw_W   : constant Natural := Clipped_Size (X, Text_W, Layout.Width);
         Draw_H   : constant Natural := Clipped_Size (Y, Text_H, Layout.Height);
         Cell_W   : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Capacity : constant Natural := Draw_W / Cell_W;
         Raw      : constant String := To_String (Text);
         Fitted   : constant UString := (if Fit then Fitted_Text_For (Text, Capacity) else Text);
         Was_Truncated : constant Boolean := Fit and then To_String (Fitted) /= Raw;
      begin
         if Hidden_By_Settings_Pane (X, Y, Draw_W, Draw_H) then
            return;
         elsif Hidden_By_Command_Palette (X, Y, Draw_W, Draw_H) then
            return;
         end if;

         if Draw_W > 0 and then Draw_H > 0 and then Length (Fitted) > 0 then
            Result.Text.Append
              (Text_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => Fitted,
                  Color  => Color,
                  Truncated => Was_Truncated,
                  Scale_To_Box => Scale_To_Box,
                  Italic => Italic));
         end if;
      end Add_Text;

      procedure Add_Overlay_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False)
      is
         Draw_W : constant Natural := Clipped_Size (X, Text_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Text_H, Layout.Height);
         Cell_W   : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Capacity : constant Natural := Draw_W / Cell_W;
         Raw      : constant String := To_String (Text);
         Fitted   : constant UString := (if Fit then Fitted_Text_For (Text, Capacity) else Text);
         Was_Truncated : constant Boolean := Fit and then To_String (Fitted) /= Raw;
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Length (Fitted) > 0 then
            Result.Overlay_Text.Append
              (Text_Command'
                 (X         => X,
                  Y         => Y,
                  Width     => Draw_W,
                  Height    => Draw_H,
                  Text      => Fitted,
                  Color     => Color,
                  Truncated => Was_Truncated,
                  Scale_To_Box => False,
                  Italic    => False));
         end if;
      end Add_Overlay_Text;

      procedure Add_Tooltip
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text_Key : String)
      is
         Text : constant String := Files.Localization.Text (Text_Key);
         Draw_W : constant Natural := Clipped_Size (X, Tip_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Tip_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Text'Length > 0 then
            Result.Tooltips.Append
              (Tooltip_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => To_Unbounded_String (Text)));
         end if;
      end Add_Tooltip;

      procedure Add_Tooltip_Text
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text     : UString);

      function Command_Tooltip_Text
        (Command : Files.Commands.Command_Id)
         return UString
      is
         Primary   : constant String := Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Command));
         Secondary : constant String := Files.Commands.Shortcut_Text (Files.Commands.Secondary_Shortcut_For (Command));
         Result    : UString :=
           To_Unbounded_String (Files.Localization.Text (Files.Commands.Description_Key (Command)));
      begin
         if Primary /= "" and then Secondary /= "" then
            Result :=
              Result
              & To_Unbounded_String (" (")
              & To_Unbounded_String (Primary)
              & To_Unbounded_String (" / ")
              & To_Unbounded_String (Secondary)
              & To_Unbounded_String (")");
         elsif Primary /= "" then
            Result :=
              Result
              & To_Unbounded_String (" (")
              & To_Unbounded_String (Primary)
              & To_Unbounded_String (")");
         elsif Secondary /= "" then
            Result :=
              Result
              & To_Unbounded_String (" (")
              & To_Unbounded_String (Secondary)
              & To_Unbounded_String (")");
         end if;

         return Result;
      end Command_Tooltip_Text;

      procedure Add_Command_Tooltip
        (X       : Natural;
         Y       : Natural;
         Tip_W   : Natural;
         Tip_H   : Natural;
         Command : Files.Commands.Command_Id) is
      begin
         Add_Tooltip_Text (X, Y, Tip_W, Tip_H, Command_Tooltip_Text (Command));
      end Add_Command_Tooltip;

      procedure Add_Tooltip_Text
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text     : UString)
      is
         Draw_W : constant Natural := Clipped_Size (X, Tip_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Tip_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Length (Text) > 0 then
            Result.Tooltips.Append
              (Tooltip_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => Text));
         end if;
      end Add_Tooltip_Text;

      procedure Add_Accessibility_Node
        (Role        : Accessibility_Role;
         X           : Natural;
         Y           : Natural;
         Node_W      : Natural;
         Node_H      : Natural;
         Name        : UString;
         Description : UString := Null_Unbounded_String;
         Enabled     : Boolean := True;
         Selected    : Boolean := False;
         Focused     : Boolean := False)
      is
         Draw_W : constant Natural := Clipped_Size (X, Node_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Node_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Accessibility.Append
              (Accessibility_Node'
                 (Role        => Role,
                  X           => X,
                  Y           => Y,
                  Width       => Draw_W,
                  Height      => Draw_H,
                  Name        => Name,
                  Description => Description,
                  Enabled     => Enabled,
                  Selected    => Selected,
                  Focused     => Focused));
         end if;
      end Add_Accessibility_Node;

      function Localized (Key : String) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Key));
      end Localized;

      function Path_Input_Accessible_Description return UString is
      begin
         if Snapshot.Path_Input_Valid or else Length (Snapshot.Path_Input_Error_Key) = 0 then
            return Snapshot.Path_Input_Text;
         end if;

         return
           Snapshot.Path_Input_Text
           & To_Unbounded_String (" ")
           & Localized (To_String (Snapshot.Path_Input_Error_Key));
      end Path_Input_Accessible_Description;

      function Command_Result_Accessible_Description
        (Command : Command_Result_Snapshot)
         return UString
      is
         Result : UString := Command.Description;
      begin
         if Length (Command.Shortcut_Text) > 0 then
            Result := Result & To_Unbounded_String (" ") & Command.Shortcut_Text;
         end if;

         if not Command.Enabled then
            Result := Result & To_Unbounded_String (" ") & Localized ("accessibility.command_disabled");
         end if;

         return Result;
      end Command_Result_Accessible_Description;

      function Contains_Point
        (X        : Natural;
         Y        : Natural;
         Box_W    : Natural;
         Box_H    : Natural;
         Point_X  : Natural;
         Point_Y  : Natural)
         return Boolean
      is
      begin
         return Contains_Rectangle_Point (X, Y, Box_W, Box_H, Point_X, Point_Y);
      end Contains_Point;

      function Tooltip_At
        (Point_X : Natural;
         Point_Y : Natural)
         return UString
      is
      begin
         for Command of Result.Tooltips loop
            if Contains_Point (Command.X, Command.Y, Command.Width, Command.Height, Point_X, Point_Y) then
               return Command.Text;
            end if;
         end loop;

         return Null_Unbounded_String;
      end Tooltip_At;

      function Is_Pressed
        (X     : Natural;
         Y     : Natural;
         Box_W : Natural;
         Box_H : Natural)
         return Boolean is
      begin
         return Has_Press and then Contains_Point (X, Y, Box_W, Box_H, Pressed_X, Pressed_Y);
      end Is_Pressed;

      procedure Add_Border
        (X        : Natural;
         Y        : Natural;
         Border_W : Natural;
         Border_H : Natural;
         Color    : Render_Color)
      is
      begin
         if Border_W = 0 or else Border_H = 0 then
            return;
         end if;

         Add_Rect (X, Y, Border_W, 1, Color);
         Add_Rect (X, Y, 1, Border_H, Color);
         Add_Rect (X, Saturating_Add (Y, Border_H - 1), Border_W, 1, Color);
         Add_Rect (Saturating_Add (X, Border_W - 1), Y, 1, Border_H, Color);
      end Add_Border;

      procedure Add_Focus_Ring
        (X      : Natural;
         Y      : Natural;
         Ring_W : Natural;
         Ring_H : Natural) is
      begin
         if Ring_W = 0 or else Ring_H = 0 then
            return;
         end if;

         Add_Border (X, Y, Ring_W, Ring_H, Snapshot.Theme_Focus_Ring);
         if X > 0 and then Y > 0 then
            Add_Border
              (X - 1,
               Y - 1,
               Saturating_Add (Ring_W, 2),
               Saturating_Add (Ring_H, 2),
               Snapshot.Theme_Focus_Ring);
         end if;
      end Add_Focus_Ring;

      procedure Add_Drop_Shadow
        (X        : Natural;
         Y        : Natural;
         Shadow_W : Natural;
         Shadow_H : Natural)
      is
         Shadow_Offset : constant Natural := 3;
      begin
         if Shadow_W = 0 or else Shadow_H = 0 then
            return;
         end if;

         Add_Rect
           (Saturating_Add (X, Shadow_Offset),
            Saturating_Add (Y, Shadow_H),
            Shadow_W,
            Shadow_Offset,
            Pane_Color);
         Add_Rect
           (Saturating_Add (X, Shadow_W),
            Saturating_Add (Y, Shadow_Offset),
            Shadow_Offset,
            Shadow_H,
            Pane_Color);
      end Add_Drop_Shadow;

      procedure Add_Scrollbar
        (Track_X  : Natural;
         Track_Y  : Natural;
         Track_W  : Natural;
         Track_H  : Natural;
         Thumb_Y  : Natural;
         Thumb_H  : Natural) is
         Grip_W : constant Natural := (if Track_W > 2 then Track_W - 2 else 0);
         Grip_X : constant Natural := Saturating_Add (Track_X, 1);
         Mid_Y  : constant Natural := Saturating_Add (Thumb_Y, Thumb_H / 2);
      begin
         Add_Rect (Track_X, Track_Y, Track_W, Track_H, Border_Color);
         Add_Rect (Track_X, Thumb_Y, Track_W, Thumb_H, Selection_Color);
         Add_Border (Track_X, Thumb_Y, Track_W, Thumb_H, Border_Color);

         if Grip_W > 0 and then Thumb_H >= 7 then
            Add_Rect (Grip_X, Mid_Y - 2, Grip_W, 1, Muted_Text_Color);
            Add_Rect (Grip_X, Mid_Y, Grip_W, 1, Muted_Text_Color);
            Add_Rect (Grip_X, Saturating_Add (Mid_Y, 2), Grip_W, 1, Muted_Text_Color);
         end if;
      end Add_Scrollbar;

      --  Draw a panel's top-right close (X) button plus its Role_Button
      --  accessibility node. Overlay panels (the root selector) render into the
      --  overlay layer so the button sits above the overlay body; the other
      --  panels render into the base layer. The button geometry comes from
      --  Panel_Close_Button so it matches the click hit-test exactly.
      procedure Draw_Close_Button
        (Panel_X : Natural;
         Panel_Y : Natural;
         Panel_W : Natural;
         Panel_H : Natural;
         Overlay : Boolean)
      is
         Btn : constant Close_Button_Layout :=
           Panel_Close_Button (Panel_X, Panel_Y, Panel_W, Panel_H, Line_Height);
      begin
         if not Btn.Visible then
            return;
         end if;

         declare
            Hovered    : constant Boolean :=
              Has_Hover and then Contains_Point (Btn.X, Btn.Y, Btn.Width, Btn.Height, Hover_X, Hover_Y);
            Pressed    : constant Boolean := Is_Pressed (Btn.X, Btn.Y, Btn.Width, Btn.Height);
            Fill_Color : constant Render_Color :=
              (if Pressed then Pressed_Color
               elsif Hovered then Hover_Color
               elsif Overlay then Overlay_Color
               else Pane_Color);
            --  Center the glyph cell within the square button.
            Glyph_W    : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
            Glyph_X    : constant Natural :=
              (if Btn.Width > Glyph_W
               then Saturating_Add (Btn.X, (Btn.Width - Glyph_W) / 2)
               else Btn.X);
            Glyph_Y    : constant Natural :=
              (if Btn.Height > Line_Height
               then Saturating_Add (Btn.Y, (Btn.Height - Line_Height) / 2)
               else Btn.Y);
         begin
            if Overlay then
               Add_Overlay_Rect (Btn.X, Btn.Y, Btn.Width, Btn.Height, Fill_Color);
               Add_Overlay_Rect (Btn.X, Btn.Y, Btn.Width, 1, Border_Color);
               Add_Overlay_Rect (Btn.X, Btn.Y, 1, Btn.Height, Border_Color);
               Add_Overlay_Rect
                 (Btn.X, Saturating_Add (Btn.Y, Btn.Height - 1), Btn.Width, 1, Border_Color);
               Add_Overlay_Rect
                 (Saturating_Add (Btn.X, Btn.Width - 1), Btn.Y, 1, Btn.Height, Border_Color);
               Add_Overlay_Text
                 (Glyph_X, Glyph_Y, Glyph_W, Line_Height,
                  To_Unbounded_String (Close_Glyph_Text), Text_Color);
            else
               Add_Rect (Btn.X, Btn.Y, Btn.Width, Btn.Height, Fill_Color);
               Add_Border (Btn.X, Btn.Y, Btn.Width, Btn.Height, Border_Color);
               Add_Text
                 (Glyph_X, Glyph_Y, Glyph_W, Line_Height,
                  To_Unbounded_String (Close_Glyph_Text), Text_Color);
            end if;

            Add_Accessibility_Node
              (Role_Button,
               Btn.X,
               Btn.Y,
               Btn.Width,
               Btn.Height,
               Localized ("command.action.close"));
         end;
      end Draw_Close_Button;

      procedure Add_Hover_Tooltip is
         Padding     : constant Natural := 6;
         --  Even inset on every side; the vertical inset is derived so the box
         --  is comfortably taller than the text with matching top/bottom bands.
         Padding_V   : constant Natural := Natural'Max (Padding, Line_Height / 3 + 2);
         Margin      : constant Natural := 4;
         Horizontal_Gap : constant Natural := 12;
         Vertical_Gap   : constant Natural := 18;
         Text        : constant UString := Tooltip_At (Hover_X, Hover_Y);
         Text_Raw    : constant String := To_String (Text);
         Text_Len    : constant Natural := Files.UTF8.Display_Units (Text_Raw);
         Cell_W      : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Max_Tip_W   : constant Natural :=
           (if Width > 2 * Margin then Width - 2 * Margin else Width);
         Raw_Text_W  : constant Natural := Saturating_Multiply (Text_Len, Cell_W);
         Text_W      : constant Natural :=
           (if Max_Tip_W > 2 * Padding
            then Natural'Min (Raw_Text_W, Max_Tip_W - 2 * Padding)
            else 0);
         Tip_W       : constant Natural := Saturating_Add (Text_W, 2 * Padding);
         Tip_H       : constant Natural := Saturating_Add (Line_Height, 2 * Padding_V);

         function Fits_Right return Boolean is
         begin
            return
              Width > Margin
              and then Hover_X <= Natural'Last - Horizontal_Gap
              and then Saturating_Add (Hover_X, Horizontal_Gap) <= Natural'Last - Tip_W
              and then Saturating_Add (Saturating_Add (Hover_X, Horizontal_Gap), Tip_W) <= Width - Margin;
         end Fits_Right;

         function Fits_Left return Boolean is
         begin
            return Hover_X >= Saturating_Add (Saturating_Add (Tip_W, Horizontal_Gap), Margin);
         end Fits_Left;

         function Fits_Below return Boolean is
         begin
            return
              Height > Margin
              and then Hover_Y <= Natural'Last - Vertical_Gap
              and then Saturating_Add (Hover_Y, Vertical_Gap) <= Natural'Last - Tip_H
              and then Saturating_Add (Saturating_Add (Hover_Y, Vertical_Gap), Tip_H) <= Height - Margin;
         end Fits_Below;

         function Fits_Above return Boolean is
         begin
            return Hover_Y >= Saturating_Add (Saturating_Add (Tip_H, Vertical_Gap), Margin);
         end Fits_Above;

         Tip_X       : constant Natural :=
           (if Fits_Right then Saturating_Add (Hover_X, Horizontal_Gap)
            elsif Fits_Left then Hover_X - Tip_W - Horizontal_Gap
            elsif Width > Saturating_Add (Tip_W, Margin)
            then Natural'Min (Hover_X, Width - Tip_W - Margin)
            else 0);
         Tip_Y       : constant Natural :=
           (if Fits_Below then Saturating_Add (Hover_Y, Vertical_Gap)
            elsif Fits_Above then Hover_Y - Tip_H - Vertical_Gap
            elsif Height > Saturating_Add (Tip_H, Margin)
            then Natural'Min (Hover_Y, Height - Tip_H - Margin)
            else 0);
      begin
         if not Has_Hover or else Text_Len = 0 or else Text_W = 0 then
            return;
         end if;

         Add_Overlay_Rect (Tip_X, Tip_Y, Tip_W, Tip_H, Overlay_Color);
         Add_Overlay_Rect (Tip_X, Tip_Y, Tip_W, 1, Border_Color);
         Add_Overlay_Rect (Tip_X, Tip_Y, 1, Tip_H, Border_Color);
         Add_Overlay_Rect (Tip_X, Saturating_Add (Tip_Y, Tip_H - 1), Tip_W, 1, Border_Color);
         Add_Overlay_Rect (Saturating_Add (Tip_X, Tip_W - 1), Tip_Y, 1, Tip_H, Border_Color);
         Add_Overlay_Text
           (Tip_X + Padding,
            Tip_Y + Padding_V,
            Text_W,
            Line_Height,
            Text,
            Text_Color,
            Fit => True);
      end Add_Hover_Tooltip;

      function Icon_Theme_Name return String is
      begin
         if Length (Snapshot.Settings_Icon_Theme) > 0 then
            return To_String (Snapshot.Settings_Icon_Theme);
         else
            return "files-basic";
         end if;
      end Icon_Theme_Name;

      procedure Add_Toolbar_Asset_Icon
        (Id      : Files.Commands.Registered_Command_Id;
         X       : Natural;
         Y       : Natural;
         Size    : Natural;
         Enabled : Boolean)
      is
         Icon_Name : constant String :=
           (case Id is
              when Files.Commands.Navigate_Home_Command => "toolbar-home",
              when Files.Commands.Navigate_Back_Command => "toolbar-back",
              when Files.Commands.Navigate_Forward_Command => "toolbar-forward",
              when Files.Commands.Navigate_Parent_Command => "toolbar-parent",
              when Files.Commands.Create_File_Command => "toolbar-create",
              when Files.Commands.Delete_Selected_Items_Command => "toolbar-delete",
              when others => "unknown");
         Asset     : constant Icon_Asset := Parse_Icon_Asset (Icon_Asset_Text (Icon_Name, Icon_Theme_Name));
         Color     : constant Render_Color := (if Enabled then Text_Color else Disabled_Text_Color);

         function SX (Numerator : Natural) return Float is
         begin
            return Float (X) + Float (Size * Numerator) / 16.0;
         end SX;

         function SY (Numerator : Natural) return Float is
         begin
            return Float (Y) + Float (Size * Numerator) / 16.0;
         end SY;

         function SN (Numerator : Natural) return Natural is
         begin
            return Natural'Max (1, Bounded_Product_Divide (Value => Size, Factor => Numerator, Denominator => 16));
         end SN;

         procedure Add_Local_Rect
           (Local_X : Natural;
            Local_Y : Natural;
            Local_W : Natural;
            Local_H : Natural)
         is
         begin
            Add_Rect (Natural (SX (Local_X)), Natural (SY (Local_Y)), SN (Local_W), SN (Local_H), Color);
         end Add_Local_Rect;

         procedure Draw_Home is
         begin
            Add_Triangle (SX (2), SY (7), SX (8), SY (2), SX (14), SY (7), Color);
            Add_Local_Rect (4, 7, 8, 6);
            Add_Local_Rect (7, 9, 2, 4);
         end Draw_Home;

         procedure Draw_Back is
         begin
            Add_Triangle (SX (4), SY (8), SX (9), SY (3), SX (9), SY (13), Color);
            Add_Local_Rect (8, 7, 5, 2);
         end Draw_Back;

         procedure Draw_Forward is
         begin
            Add_Triangle (SX (12), SY (8), SX (7), SY (3), SX (7), SY (13), Color);
            Add_Local_Rect (3, 7, 5, 2);
         end Draw_Forward;

         procedure Draw_Parent is
         begin
            Add_Triangle (SX (8), SY (3), SX (3), SY (8), SX (13), SY (8), Color);
            Add_Local_Rect (7, 7, 2, 6);
         end Draw_Parent;

         procedure Draw_Create is
         begin
            Add_Local_Rect (7, 3, 2, 10);
            Add_Local_Rect (3, 7, 10, 2);
         end Draw_Create;

         procedure Draw_Delete is
         begin
            Add_Local_Rect (6, 3, 4, 1);
            Add_Local_Rect (4, 5, 8, 2);
            Add_Local_Rect (5, 7, 1, 6);
            Add_Local_Rect (10, 7, 1, 6);
            Add_Local_Rect (5, 12, 6, 1);
            Add_Local_Rect (7, 8, 1, 4);
            Add_Local_Rect (9, 8, 1, 4);
         end Draw_Delete;
      begin
         if Size = 0 then
            return;
         end if;

         Result.Icons.Append
           (Icon_Command'
              (X          => X,
               Y          => Y,
               Size       => Size,
               Icon_Id    => To_Unbounded_String (Icon_Name),
               Theme_Name => To_Unbounded_String (Icon_Theme_Name),
               Asset_Path => To_Unbounded_String ("share/files/icons/" & Icon_Name & ".icon"),
               Thumbnail_Width  => 0,
               Thumbnail_Height => 0,
               Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));

         if Id = Files.Commands.Navigate_Home_Command then
            Draw_Home;
         elsif Id = Files.Commands.Navigate_Back_Command then
            Draw_Back;
         elsif Id = Files.Commands.Navigate_Forward_Command then
            Draw_Forward;
         elsif Id = Files.Commands.Navigate_Parent_Command then
            Draw_Parent;
         elsif Id = Files.Commands.Create_File_Command then
            Draw_Create;
         elsif Id = Files.Commands.Delete_Selected_Items_Command then
            Draw_Delete;
         elsif Asset.Valid then
            for Rect of Asset.Rectangles loop
               Add_Local_Rect (Rect.Grid_X, Rect.Grid_Y, Rect.Grid_W, Rect.Grid_H);
            end loop;
         end if;
      end Add_Toolbar_Asset_Icon;

      procedure Add_Toolbar_Drive_Icon
        (X       : Natural;
         Y       : Natural;
         Size    : Natural;
         Enabled : Boolean)
      is
         Color     : constant Render_Color := (if Enabled then Text_Color else Disabled_Text_Color);
         Bar_H     : constant Natural := Natural'Max (2, Size / 9);
         Bar_W     : constant Natural := Natural'Max (1, (Size * 2) / 3);
         Gap       : constant Natural := Natural'Max (2, Size / 7);
         Total_H   : constant Natural := Saturating_Add (Saturating_Multiply (Bar_H, 3), Saturating_Multiply (Gap, 2));
         Bar_X     : constant Natural := Saturating_Add (X, (if Size > Bar_W then (Size - Bar_W) / 2 else 0));
         First_Y   : constant Natural := Saturating_Add (Y, (if Size > Total_H then (Size - Total_H) / 2 else 0));

         procedure Add_Bar (Index : Natural) is
            Offset_Y : constant Natural := Saturating_Multiply (Index, Saturating_Add (Bar_H, Gap));
         begin
            Add_Rect (Bar_X, Saturating_Add (First_Y, Offset_Y), Bar_W, Bar_H, Color);
         end Add_Bar;
      begin
         if Size = 0 then
            return;
         end if;

         Add_Bar (0);
         Add_Bar (1);
         Add_Bar (2);
      end Add_Toolbar_Drive_Icon;

      procedure Add_Caret
        (X       : Natural;
         Y       : Natural;
         Field_W : Natural;
         Field_H : Natural;
         Text    : UString;
         Cursor  : Natural)
      is
         Char_W : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
         Raw    : constant String := To_String (Text);
         Raw_X  : constant Natural :=
           Saturating_Add
             (Saturating_Add (X, Files.UI.Input_Field_Padding),
              Saturating_Multiply
                (Files.UTF8.Display_Units_Before (Raw, Cursor), Char_W));
         Max_X  : constant Natural := (if Field_W > 2 then Saturating_Add (X, Field_W - 2) else X);
         --  The caret height tracks the font: a fixed fraction of the line
         --  height (so it scales linearly with the font size), clamped to the
         --  field, and centered vertically. Using Line_Height minus fixed
         --  insets under-scaled it (stubby at small fonts, near-full at large).
         Caret_H : constant Natural :=
           Natural'Min
             ((if Field_H > 2 then Field_H - 2 else Field_H),
              Positive'Max (1, Saturating_Multiply (Line_Height, 4) / 5));
         Caret_Y : constant Natural :=
           Saturating_Add
             (Y, (if Field_H > Caret_H then (Field_H - Caret_H) / 2 else 0));
         Caret_W : constant Natural := Natural'Min (2, Field_W);
      begin
         if Field_W > 0 and then Caret_H > 4 then
            Add_Rect
              (Natural'Min (Raw_X, Max_X),
               Caret_Y,
               Caret_W,
               Caret_H,
               Text_Color);
         end if;
      end Add_Caret;

      procedure Add_Palette_Scrollbar is
         Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
         Visible_Rows : constant Natural := Complete_Visible_Row_Count (Palette.Results_Height, Palette.Row_Height);
         Bar_W       : constant Natural := Natural'Min (Scrollbar_Width, Palette.Results_Width);
         Track_H     : constant Natural := Palette.Results_Height;
         Thumb_H     : Natural := 0;
         Thumb_Y     : Natural := Palette.Results_Y;
         Max_Offset  : Natural := 0;
      begin
         if not Snapshot.Command_Palette_Open
           or else Result_Count = 0
           or else Visible_Rows = 0
           or else Result_Count <= Visible_Rows
           or else Track_H = 0
         then
            return;
         end if;

         Max_Offset := Result_Count - Visible_Rows;
         Thumb_H :=
           Natural'Max
             (Palette.Row_Height,
              Bounded_Product_Divide (Value => Track_H, Factor => Visible_Rows, Denominator => Result_Count));
         Thumb_H := Natural'Min (Thumb_H, Track_H);

         if Max_Offset > 0 and then Track_H > Thumb_H then
            Thumb_Y :=
              Saturating_Add
                (Palette.Results_Y,
                 Bounded_Product_Divide
                   (Value       => Track_H - Thumb_H,
                    Factor      => Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset),
                    Denominator => Max_Offset));
         end if;

         Add_Scrollbar
           (Saturating_Add (Palette.Results_X, Palette.Results_Width - Bar_W),
            Palette.Results_Y,
            Bar_W,
            Track_H,
            Thumb_Y,
            Thumb_H);
      end Add_Palette_Scrollbar;

      function Icon_Color (Kind : Files.Types.Item_Kind) return Render_Color is
      begin
         case Kind is
            when Files.Types.Directory_Item =>
               return Icon_Directory_Color;
            when Files.Types.Executable_Item =>
               return Icon_Executable_Color;
            when Files.Types.Regular_File_Item | Files.Types.Symlink_Item | Files.Types.Other_Item =>
               return Icon_File_Color;
            when Files.Types.Unknown_Item =>
               return Icon_Unknown_Color;
         end case;
      end Icon_Color;

      function Icon_Asset_Directory return String is
      begin
         if To_String (Snapshot.Settings_Icon_Theme) = "files-high-contrast" then
            return "share/files/icons/high-contrast";
         else
            return "share/files/icons";
         end if;
      end Icon_Asset_Directory;

      function Is_Bundled_Icon (Name : String) return Boolean is
      begin
         return
           Name = "folder"
           or else Name = "text"
           or else Name = "image"
           or else Name = "executable"
           or else Name = "link"
           or else Name = "unknown"
           or else Name = "ada"
           or else Name = "markdown";
      end Is_Bundled_Icon;

      procedure Add_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural;
         Use_Thumbnail : Boolean := False)
      is
         Base_Color : constant Render_Color := Icon_Color (Item.Kind);
         Type_Name  : constant String := To_String (Item.Filetype);
         Icon_Name  : constant String := To_String (Item.Icon_Id);
         Draw_Size  : constant Natural :=
           Natural'Min
             (Size,
              Natural'Min
                (Clipped_Size (X, Size, Layout.Width),
                 Clipped_Size (Y, Size, Layout.Height)));
         Accent     : constant Render_Color :=
           (if Item.Kind = Files.Types.Executable_Item or else Icon_Name = "ada"
            then Icon_Executable_Color
            else Selection_Color);
         Fold       : constant Natural := Natural'Max (1, Draw_Size / 4);
         Stripe_W   : constant Natural := Natural'Max (1, Draw_Size / 5);
         Body_Y     : constant Natural := Saturating_Add (Y, Natural'Max (1, Draw_Size / 4));
         Body_H     : constant Natural :=
           (if Draw_Size > Body_Y - Y then Draw_Size - (Body_Y - Y) else Draw_Size);

         function Scale (Numerator : Natural; Denominator : Positive) return Natural is
         begin
            return Bounded_Product_Divide (Draw_Size, Numerator, Denominator);
         end Scale;

         function X_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (X, Offset);
         end X_Offset;

         function Y_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (Y, Offset);
         end Y_Offset;

         function Asset_Color (Role : Icon_Asset_Color_Role) return Render_Color is
         begin
            case Role is
               when Icon_Asset_Base =>
                  return Base_Color;
               when Icon_Asset_Accent =>
                  return Accent;
               when Icon_Asset_Border =>
                  return Border_Color;
               when Icon_Asset_Muted =>
                  return Muted_Text_Color;
            end case;
         end Asset_Color;

         procedure Add_Asset_Rect
         (Asset : Icon_Asset;
          Rect  : Icon_Asset_Rect)
         is
            Rect_X : constant Natural :=
              Saturating_Add
                (X, Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_Y : constant Natural :=
              Saturating_Add
                (Y, Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_W : constant Natural :=
              Natural'Max
                (1, Bounded_Product_Divide (Value => Rect.Grid_W, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_H : constant Natural :=
              Natural'Max
                (1, Bounded_Product_Divide (Value => Rect.Grid_H, Factor => Draw_Size, Denominator => Asset.Grid));
         begin
            Add_Rect (Rect_X, Rect_Y, Rect_W, Rect_H, Asset_Color (Rect.Role));
         end Add_Asset_Rect;

         function Add_Named_Asset (Name : String) return Boolean is
            Asset : constant Icon_Asset := Parse_Icon_Asset (Icon_Asset_Text (Name, Icon_Theme_Name));
         begin
            if not Asset.Valid then
               return False;
            end if;

            for Rect of Asset.Rectangles loop
               Add_Asset_Rect (Asset, Rect);
            end loop;
            return True;
         end Add_Named_Asset;

         function Starts_With
           (Value  : String;
            Prefix : String)
            return Boolean
         is
         begin
            return Value'Length >= Prefix'Length
              and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
         end Starts_With;

         function Resolved_Icon_Name return String is
         begin
            if Use_Thumbnail
              and then Item.Thumbnail_Available
              and then Length (Item.Thumbnail_Path) > 0
            then
               return "thumbnail";
            elsif Is_Bundled_Icon (Icon_Name) then
               return Icon_Name;
            elsif Item.Kind = Files.Types.Directory_Item then
               return "folder";
            elsif Item.Kind = Files.Types.Executable_Item then
               return "executable";
            elsif Item.Kind = Files.Types.Symlink_Item then
               return "link";
            elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
               return "image";
            elsif Type_Name = "text/markdown" then
               return "markdown";
            elsif Type_Name = "application/octet-stream" then
               return "unknown";
            elsif Starts_With (Type_Name, "text/") then
               return "text";
            else
               return "unknown";
            end if;
         end Resolved_Icon_Name;

         Resolved_Name : constant String := Resolved_Icon_Name;
         Resolved_Asset_Path : constant UString :=
           (if Use_Thumbnail
              and then Item.Thumbnail_Available
              and then Length (Item.Thumbnail_Path) > 0
            then Item.Thumbnail_Path
            else To_Unbounded_String (Icon_Asset_Directory & "/" & Resolved_Name & ".icon"));
      begin
         if Draw_Size = 0 then
            return;
         elsif Hidden_By_Settings_Pane (X, Y, Draw_Size, Draw_Size) then
            return;
         elsif Hidden_By_Command_Palette (X, Y, Draw_Size, Draw_Size) then
            return;
         end if;

         Result.Icons.Append
           (Icon_Command'
              (X          => X,
               Y          => Y,
               Size       => Draw_Size,
               Icon_Id    => To_Unbounded_String (Resolved_Name),
               Theme_Name => To_Unbounded_String (Icon_Theme_Name),
               Asset_Path => Resolved_Asset_Path,
               Thumbnail_Width  => (if Use_Thumbnail then Item.Thumbnail_Width else 0),
               Thumbnail_Height => (if Use_Thumbnail then Item.Thumbnail_Height else 0),
               Thumbnail_Pixels =>
                 (if Use_Thumbnail then Item.Thumbnail_Pixels else Files.Types.Byte_Vectors.Empty_Vector)));

         if Use_Thumbnail
           and then Item.Thumbnail_Available
           and then Length (Item.Thumbnail_Path) > 0
           and then Add_Named_Asset ("thumbnail")
         then
            return;
         elsif Add_Named_Asset (Icon_Name) then
            return;
         elsif Item.Kind = Files.Types.Directory_Item and then Add_Named_Asset ("folder") then
            return;
         elsif Item.Kind = Files.Types.Executable_Item and then Add_Named_Asset ("executable") then
            return;
         elsif Item.Kind = Files.Types.Symlink_Item and then Add_Named_Asset ("link") then
            return;
         elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
            if Add_Named_Asset ("image") then
               return;
            end if;
         elsif Type_Name = "text/markdown" then
            if Add_Named_Asset ("markdown") then
               return;
            end if;
         elsif Type_Name = "application/octet-stream" then
            if Add_Named_Asset ("unknown") then
               return;
            end if;
         elsif Starts_With (Type_Name, "text/") then
            if Add_Named_Asset ("text") then
               return;
            end if;
         end if;

         case Item.Kind is
            when Files.Types.Directory_Item =>
               Add_Rect
                 (X,
                  Y_Offset (Scale (1, 6)),
                  Natural'Max (1, Scale (1, 2)),
                  Natural'Max (1, Scale (1, 5)),
                  Base_Color);
               Add_Rect (X, Body_Y, Draw_Size, Body_H, Base_Color);
               if Draw_Size > 4 then
                  Add_Rect (X_Offset (1), Saturating_Add (Body_Y, 1), Draw_Size - 2, 1, Border_Color);
               end if;

            when Files.Types.Executable_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               Add_Rect (X, Y, Stripe_W, Draw_Size, Accent);
               if Draw_Size > 6 then
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Stripe_W,
                     Scale (1, 3),
                     Accent);
                  Add_Rect
                    (X_Offset (Saturating_Add (Scale (1, 2), Stripe_W)),
                     Y_Offset (Scale (1, 2)),
                     Stripe_W,
                     Stripe_W,
                     Accent);
               end if;

            when Files.Types.Symlink_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               if Draw_Size > 5 then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 2),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 4),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (2, 3)),
                     Scale (1, 4),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
               end if;

            when Files.Types.Regular_File_Item | Files.Types.Other_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Base_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               if Draw_Size > 7 then
                  if Icon_Name = "image"
                    or else Starts_With (Type_Name, "image/")
                  then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (3, 5),
                        Scale (1, 3),
                        Selection_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 4)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 5),
                        Scale (1, 6),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 4),
                        Scale (1, 6),
                        Border_Color);
                  elsif Icon_Name = "ada" or else Type_Name = "text/x-ada" then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Icon_Executable_Color);
                     Add_Rect
                       (X_Offset (Scale (3, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Icon_Executable_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 4)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 2),
                        Natural'Max (1, Scale (1, 6)),
                        Selection_Color);
                  elsif Icon_Name = "markdown" or else Type_Name = "text/markdown" then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (2, 5)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 5),
                        Scale (1, 3),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (3, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Border_Color);
                  elsif Icon_Name = "unknown" or else Type_Name = "application/octet-stream" then
                     Add_Rect
                       (X_Offset (Scale (1, 3)),
                        Y_Offset (Scale (1, 4)),
                        Scale (1, 3),
                        Natural'Max (1, Scale (1, 6)),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (1, 3)),
                        Natural'Max (1, Scale (1, 6)),
                        Scale (1, 3),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (3, 4)),
                        Natural'Max (1, Scale (1, 6)),
                        1,
                        Border_Color);
                  else
                     Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 2)), Scale (3, 5), 1, Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Saturating_Add (Scale (1, 2), Scale (1, 5))),
                        Scale (1, 2),
                        1,
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 2) - Scale (1, 5)),
                        Scale (1, 2),
                        1,
                        Border_Color);
                  end if;
               end if;

            when Files.Types.Unknown_Item =>
               Add_Rect (X_Offset (Scale (1, 4)), Y, Scale (1, 2), Draw_Size, Base_Color);
               Add_Rect (X, Y_Offset (Scale (1, 4)), Draw_Size, Scale (1, 2), Base_Color);
               if Draw_Size > 5 then
                  Add_Rect (X_Offset (Scale (1, 2)), Y_Offset (Scale (1, 4)), 1, Scale (1, 2), Border_Color);
               end if;
         end case;
      end Add_Icon;

      procedure Add_Details_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural)
      is
      begin
         Add_Icon (Item, X, Y, Size);
      end Add_Details_Icon;

      procedure Add_Button
        (X        : Natural;
         Button_W : Natural;
         Selected : Boolean;
         Hovered  : Boolean := False;
         Pressed  : Boolean := False)
      is
         Button_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Button_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Add_Rect
           (X,
            Button_Y,
            Button_W,
            Button_H,
            (if Selected then Selection_Color
             elsif Pressed then Pressed_Color
             elsif Hovered then Hover_Color
             else Bottom_Bar_Color));
         if Selected then
            Add_Border (X, Button_Y, Button_W, Button_H, Border_Color);
         end if;
      end Add_Button;

      function Command_Label (Id : Files.Commands.Command_Id) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Files.Commands.Name_Key (Id)));
      end Command_Label;

      function Bottom_Command_Label (Id : Files.Commands.Command_Id) return UString is
      begin
         case Id is
            when Files.Commands.Select_Small_Icons_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.small.short"));
            when Files.Commands.Select_Large_Icons_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.large.short"));
            when Files.Commands.Select_Details_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.details.short"));
            when Files.Commands.Toggle_Info_Pane_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.info.toggle.short"));
            when Files.Commands.Toggle_Sort_Menu_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.sort.name"));
            when others =>
               return Command_Label (Id);
         end case;
      end Bottom_Command_Label;

      function Sort_Field_Label
        (Field : Files.Model.Sort_Field)
         return String is
      begin
         case Field is
            when Files.Model.Sort_Name =>
               return Files.Localization.Text ("command.sort.name");
            when Files.Model.Sort_Size =>
               return Files.Localization.Text ("command.sort.size");
            when Files.Model.Sort_Type =>
               return Files.Localization.Text ("command.sort.type");
            when Files.Model.Sort_Created =>
               return Files.Localization.Text ("command.sort.created");
            when Files.Model.Sort_Changed =>
               return Files.Localization.Text ("command.sort.changed");
         end case;
      end Sort_Field_Label;

      function Sort_Field_Command
        (Field : Files.Model.Sort_Field)
         return Files.Commands.Registered_Command_Id is
      begin
         case Field is
            when Files.Model.Sort_Name =>
               return Files.Commands.Sort_By_Name_Command;
            when Files.Model.Sort_Size =>
               return Files.Commands.Sort_By_Size_Command;
            when Files.Model.Sort_Type =>
               return Files.Commands.Sort_By_Type_Command;
            when Files.Model.Sort_Created =>
               return Files.Commands.Sort_By_Created_Command;
            when Files.Model.Sort_Changed =>
               return Files.Commands.Sort_By_Changed_Command;
         end case;
      end Sort_Field_Command;

      function Direction_Text return String is
      begin
         return
           Files.Localization.Text
             ((if Snapshot.Sort_Ascending then "sort.direction.ascending" else "sort.direction.descending"));
      end Direction_Text;

      function Sort_Button_Label return UString is
      begin
         return To_Unbounded_String (Sort_Field_Label (Snapshot.Sort_Field) & " " & Direction_Text);
      end Sort_Button_Label;

      function Command_Color (Id : Files.Commands.Registered_Command_Id) return Render_Color is
      begin
         return (if Snapshot.Command_Enabled (Id) then Text_Color else Disabled_Text_Color);
      end Command_Color;

      procedure Add_Bottom_Command_Button
        (X        : Natural;
         Button_W : Natural;
         Command  : Files.Commands.Registered_Command_Id;
         Selected : Boolean)
      is
         Hovered : constant Boolean :=
           Has_Hover and then Contains_Point (X, Bottom_Y, Button_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y);
         Pressed : constant Boolean := Is_Pressed (X, Bottom_Y, Button_W, Layout.Bottom_Bar_Height);
      begin
         Add_Button (X, Button_W, Selected, Hovered, Pressed);
         Add_Text
           (Saturating_Add (X, 4),
            Bottom_Content_Y,
            (if Button_W > 8 then Button_W - 8 else 0),
            Bottom_Content_H,
            Bottom_Command_Label (Command),
            Command_Color (Command),
            Fit => True);
         Add_Command_Tooltip
           (X,
            Bottom_Content_Y,
            Button_W,
            Bottom_Content_H,
            Command);
         Add_Accessibility_Node
           (Role_Button,
            X,
            Bottom_Content_Y,
            Button_W,
            Bottom_Content_H,
            Command_Label (Command),
            Localized (Files.Commands.Description_Key (Command)),
            Enabled  => Snapshot.Command_Enabled (Command),
            Selected => Selected);
      end Add_Bottom_Command_Button;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

      function View_Mode_Label return String is
      begin
         case Snapshot.View_Mode is
            when Files.Types.Small_Icons =>
               return Files.Localization.Text ("command.view.small");
            when Files.Types.Large_Icons =>
               return Files.Localization.Text ("command.view.large");
            when Files.Types.Details =>
               return Files.Localization.Text ("command.view.details");
         end case;
      end View_Mode_Label;

      function Hidden_Status_Text return String is
      begin
         --  Built from fragments so no letters-plus-space display literal is
         --  hard-coded: "N" + " " + localized "hidden".
         return
           Natural_Text (Snapshot.Hidden_Count)
           & " "
           & Files.Localization.Text ("status.hidden");
      end Hidden_Status_Text;

      function Selected_Size_Bytes return Long_Long_Integer is
         Total : Long_Long_Integer := 0;
      begin
         --  Sum the byte sizes of the selected items whose size is known.
         --  Directories and metadata-less entries carry no byte total and are
         --  counted (via Selected_Count) without contributing to the sum.
         for Item of Snapshot.Items loop
            if Item.Selected and then Item.Size_Available and then Item.Size > 0 then
               if Total <= Long_Long_Integer'Last - Item.Size then
                  Total := Total + Item.Size;
               else
                  Total := Long_Long_Integer'Last;
               end if;
            end if;
         end loop;
         return Total;
      end Selected_Size_Bytes;

      function Selected_Status_Text return String is
         Count : constant String :=
           Files.Localization.Text ("status.selected")
           & ": "
           & Natural_Text (Snapshot.Selected_Count);
      begin
         --  When something is selected, append the summed size in parentheses,
         --  e.g. "Selected: 3 (4.5 MB)". Only spaces and punctuation are inline
         --  literals; every word comes from the catalog or the size formatter.
         if Snapshot.Selected_Count >= 1 then
            return Count & " (" & Size_Text (Selected_Size_Bytes) & ")";
         else
            return Count;
         end if;
      end Selected_Status_Text;

      function Free_Space_Status_Text return String is
      begin
         --  Omitted entirely when the filesystem cannot report free space so no
         --  bogus "0 B free" appears. "X free" is assembled from the shared size
         --  formatter plus a localized suffix word.
         if not Snapshot.Free_Space_Known then
            return "";
         end if;

         return
           "  "
           & Size_Text (Snapshot.Free_Space_Bytes)
           & " "
           & Files.Localization.Text ("status.free_space.suffix");
      end Free_Space_Status_Text;

      function Count_Status_Text return UString is
      begin
         return
           To_Unbounded_String
             (Hidden_Status_Text
              & "  "
              & Files.Localization.Text ("status.visible")
              & ": "
              & Natural_Text (Snapshot.Visible_Count)
              & "  "
              & Selected_Status_Text
              & Free_Space_Status_Text);
      end Count_Status_Text;

      function Bottom_Info_Text return UString is
      begin
         if Length (Snapshot.Last_Error_Key) > 0 then
            return To_Unbounded_String (Files.Localization.Text (To_String (Snapshot.Last_Error_Key)));
         end if;

         return Count_Status_Text;
      end Bottom_Info_Text;

      function Main_View_Accessible_Description return UString is
      begin
         return
           To_Unbounded_String
             (Files.Localization.Text ("settings.default_view")
              & ": "
              & View_Mode_Label
              & "  ")
           & Count_Status_Text;
      end Main_View_Accessible_Description;

      function Bottom_Info_Color return Render_Color is
      begin
         return (if Length (Snapshot.Last_Error_Key) > 0 then Error_Text_Color else Muted_Text_Color);
      end Bottom_Info_Color;

      function Empty_State_Key return String is
      begin
         if Snapshot.Item_Count = 0 and then Snapshot.In_Recent_View then
            return "recent.empty";
         elsif Snapshot.Item_Count = 0 then
            return "status.empty_directory";
         elsif Snapshot.Visible_Count = 0 and then Length (Snapshot.Filter_Text) > 0 then
            return "status.empty_filter";
         else
            return "";
         end if;
      end Empty_State_Key;

      function Info_Value
        (Label_Key : String;
         Value     : String)
         return UString
      is
      begin
         return To_Unbounded_String (Files.Localization.Text (Label_Key) & ": " & Value);
      end Info_Value;

      function Missing_Info (Label_Key : String) return UString is
      begin
         return Info_Value (Label_Key, Files.Localization.Text ("status.missing_metadata"));
      end Missing_Info;

      function Integer_Text (Value : Long_Long_Integer) return String is
         Image : constant String := Long_Long_Integer'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Integer_Text;

      function Time_Text
        (Available : Boolean;
         Value     : Ada.Calendar.Time;
         Label_Key : String)
         return UString
      is
      begin
         if not Available then
            return Missing_Info (Label_Key);
         end if;

         return
           Info_Value
             (Label_Key,
              Humanized_Time_Text (Value));
      end Time_Text;

      function Detail_Size_Text (Item : Item_Snapshot) return UString is
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
            Whole     : constant Long_Long_Integer := Item.Size / Divisor;
            Remainder : constant Long_Long_Integer := Item.Size mod Divisor;
            Tenths    : constant Long_Long_Integer :=
              Whole * 10 + ((Remainder * 10) + Divisor / 2) / Divisor;
         begin
            return Localized_Number_Text (Tenths, Unit_Index /= 0);
         end Scaled_Number;
      begin
         if not Item.Size_Available then
            return Null_Unbounded_String;
         end if;

         while Unit_Index < 5 and then Item.Size >= Divisor * 1024 loop
            Unit_Index := Unit_Index + 1;
            Divisor := Divisor * 1024;
         end loop;

         return
           To_Unbounded_String
             (Scaled_Number & " " & Files.Localization.Text (Unit_Key, Locale));
      end Detail_Size_Text;

      function Detail_Time_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Modified_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return
           To_Unbounded_String (Humanized_Time_Text (Item.Modified_Time));
      end Detail_Time_Text;

      function Detail_Created_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Creation_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return
           To_Unbounded_String (Humanized_Time_Text (Item.Creation_Time));
      end Detail_Created_Text;

      function Permission_Text (Permissions : String) return String is
         Result : Unbounded_String;

         procedure Append_Part (Key : String) is
         begin
            if Length (Result) > 0 then
               Append (Result, Files.Localization.Text ("info.permissions.separator"));
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

         return To_String (Result) & " (" & Permissions & ")";
      end Permission_Text;
   begin
      Result.Layout := Layout;
      Result.Theme_Palette := Snapshot.Theme_Palette;

      Add_Rect (0, 0, Width, Height, Canvas_Color);
      Add_Rect (0, 0, Width, Layout.Toolbar_Height, Toolbar_Color);
      Add_Rect (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, Main_Color);
      Add_Rect (0, Bottom_Y, Width, Layout.Bottom_Bar_Height, Bottom_Bar_Color);
      if Layout.Toolbar_Height > 0 then
         Add_Rect (0, Layout.Toolbar_Height - 1, Width, 1, Border_Color);
      end if;
      Add_Rect (0, Bottom_Y, Width, 1, Border_Color);
      Add_Accessibility_Node
        (Role_Window,
         0,
         0,
         Width,
         Height,
         Snapshot.Current_Path);
      Add_Accessibility_Node
        (Role_Toolbar,
         0,
         0,
         Width,
         Layout.Toolbar_Height,
         Localized ("accessibility.toolbar"));
      Add_Accessibility_Node
        ((if Snapshot.View_Mode = Files.Types.Details then Role_Table else Role_List),
         Layout.Main_X,
         Layout.Main_Y,
         Layout.Main_Width,
         Layout.Main_Height,
         Localized ("accessibility.main_view"),
         Main_View_Accessible_Description);

      if Layout.Info_Pane_Width > 0 then
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            1,
            Layout.Main_Height,
            Border_Color);
      end if;

      for Button_Index in 0 .. 6 loop
         declare
            Button_X : constant Natural := Files.UI.Toolbar_Left_Button_X (Toolbar, Button_Index);
            Button_W : constant Natural := Files.UI.Toolbar_Left_Button_Width (Toolbar, Button_Index);
            Command  : constant Files.Commands.Registered_Command_Id :=
              (case Button_Index is
                  when 0 => Files.Commands.Select_Drive_Command,
                  when 1 => Files.Commands.Navigate_Home_Command,
                  when 2 => Files.Commands.Navigate_Back_Command,
                  when 3 => Files.Commands.Navigate_Forward_Command,
                  when 4 => Files.Commands.Navigate_Parent_Command,
                  when 5 => Files.Commands.Create_File_Command,
                  when others => Files.Commands.Delete_Selected_Items_Command);
            Button_Y : constant Natural := Toolbar_Input_Y;
            Button_H : constant Natural :=
              (if Button_Y >= Layout.Toolbar_Height
               then 0
               else Natural'Min (Toolbar_Input_H, Layout.Toolbar_Height - Button_Y));
            --  Per-button visual padding so the icons get breathing room and
            --  groups read separately. Inner padding for normal spacing; the
            --  end-of-group cell on either side of the navigation/file-action
            --  boundary gets a wider pad so the gap is visible.
            --  Slim vertical inset so the icon can occupy more of the button
            --  height (a modestly larger glyph) while staying inside the rect.
            Pad_V        : constant Natural :=
              Natural'Min (2, Button_H / 8);
            Inner_Pad    : constant Natural := Natural'Min (3, Button_W / 6);
            Group_Pad    : constant Natural := Natural'Min (8, Button_W / 4);
            Button_Pad_L : constant Natural :=
              (if Button_Index = 5 then Group_Pad else Inner_Pad);
            Button_Pad_R : constant Natural :=
              (if Button_Index = 4 then Group_Pad else Inner_Pad);
            Visible_X : constant Natural := Saturating_Add (Button_X, Button_Pad_L);
            Visible_W : constant Natural :=
              (if Button_W > Saturating_Add (Button_Pad_L, Button_Pad_R)
               then Button_W - Button_Pad_L - Button_Pad_R
               else 0);
            Visible_Y : constant Natural := Saturating_Add (Button_Y, Pad_V);
            Visible_H : constant Natural :=
              (if Button_H > Saturating_Multiply (Pad_V, 2)
               then Button_H - Saturating_Multiply (Pad_V, 2)
               else 0);
            Icon_Size : constant Natural :=
              (if Visible_W >= Files.UI.Toolbar_Button_Width - 4
               then Natural'Min (Visible_H, Files.UI.Toolbar_Button_Width - 8)
               else Natural'Min (Visible_W, Visible_H));
            Icon_X   : constant Natural :=
              (if Visible_W > Icon_Size then Visible_X + (Visible_W - Icon_Size) / 2 else Visible_X);
            Icon_Y   : constant Natural :=
              (if Visible_H > Icon_Size then Visible_Y + (Visible_H - Icon_Size) / 2 else Visible_Y);
            Enabled  : constant Boolean := Snapshot.Command_Enabled (Command);
            Hovered  : constant Boolean :=
              Has_Hover and then Contains_Point (Button_X, Button_Y, Button_W, Button_H, Hover_X, Hover_Y);
            Pressed  : constant Boolean := Is_Pressed (Button_X, Button_Y, Button_W, Button_H);
         begin
            if Visible_W > 0 and then Visible_H > 0 then
               --  Disabled buttons render with no fill and no border, exactly
               --  like an enabled idle button; only the icon dimming differs.
               if Pressed then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Pressed_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               elsif Hovered then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Hover_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               end if;
            end if;
            if Command = Files.Commands.Select_Drive_Command then
               Add_Toolbar_Drive_Icon (Icon_X, Icon_Y, Icon_Size, Enabled);
            else
               Add_Toolbar_Asset_Icon (Command, Icon_X, Icon_Y, Icon_Size, Enabled);
            end if;
            Add_Command_Tooltip
              (Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command);
            Add_Accessibility_Node
              (Role_Button,
               Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command_Label (Command),
               Localized (Files.Commands.Description_Key (Command)),
               Enabled => Enabled);
         end;
      end loop;

      --  Vertical divider between navigation group (drives/home/back/forward)
      --  and file-action group (create/delete) so the two groups read as
      --  distinct sets of controls.
      if Layout.Toolbar_Height > 0 then
         declare
            Group_Boundary_X : constant Natural :=
              Files.UI.Toolbar_Left_Button_X (Toolbar, 5);
            Divider_H : constant Natural :=
              Natural'Max (1, Layout.Toolbar_Height / 3);
            Divider_Y : constant Natural :=
              (if Layout.Toolbar_Height > Divider_H
               then (Layout.Toolbar_Height - Divider_H) / 2
               else 0);
         begin
            if Group_Boundary_X > 0
              and then Group_Boundary_X < Toolbar.Middle_X
            then
               Add_Rect (Group_Boundary_X, Divider_Y, 1, Divider_H, Border_Color);
            end if;
         end;
      end if;

      declare
         Field_Margin : constant Natural := 6;
         Path_X : constant Natural :=
           Saturating_Add (Toolbar.Middle_X, Field_Margin);
         Path_W : constant Natural :=
           (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
            then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
            else 0);
         Star         : constant Path_Favorite_Star_Bounds :=
           Path_Favorite_Star_Region (Width, Line_Height);
         Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
         Text_Start   : constant Natural :=
           Saturating_Add (Saturating_Add (Path_X, Files.UI.Input_Field_Padding), Star_Reserve);
      begin
         Add_Rect
           (Path_X,
            Toolbar_Input_Y,
            Path_W,
            Toolbar_Input_H,
            (if Snapshot.Path_Input_Valid then Input_Color else Input_Error_Color));
         Add_Border
           (Path_X,
            Toolbar_Input_Y,
            Path_W,
            Toolbar_Input_H,
            Border_Color);
         --  Favorite toggle: a filled star when the current directory is a
         --  favorite, an empty star when not, drawn at the left of the path bar
         --  ahead of the breadcrumbs/edit field in both modes.
         if Star.Visible then
            declare
               Star_Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point (Star.X, Star.Y, Star.Width, Star.Height, Hover_X, Hover_Y);
            begin
               Add_Text
                 (Star.X,
                  Toolbar_Input_Text_Y,
                  Star.Width,
                  Toolbar_Input_Text_H,
                  To_Unbounded_String
                    (if Snapshot.Current_Path_Is_Favorite
                     then Favorite_Star_Filled_Text
                     else Favorite_Star_Empty_Text),
                  Color =>
                    (if Snapshot.Current_Path_Is_Favorite
                     then Favorite_Star_Color
                     else Muted_Text_Color));
               if Star_Hovered then
                  Add_Border (Star.X, Star.Y, Star.Width, Star.Height, Hover_Color);
               end if;
               Add_Accessibility_Node
                 (Role_Button,
                  Star.X,
                  Star.Y,
                  Star.Width,
                  Star.Height,
                  Localized
                    (if Snapshot.Current_Path_Is_Favorite
                     then "accessibility.favorite_toggle.on"
                     else "accessibility.favorite_toggle.off"),
                  Snapshot.Current_Path,
                  Enabled  => True,
                  Selected => Snapshot.Current_Path_Is_Favorite);
            end;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input
           or else Breadcrumb_Rows.Is_Empty
         then
            Add_Text
              (Text_Start,
               Toolbar_Input_Text_Y,
               (if Path_W > 2 * Files.UI.Input_Field_Padding + Star_Reserve
                then Path_W - 2 * Files.UI.Input_Field_Padding - Star_Reserve
                else 0),
               Toolbar_Input_Text_H,
               Snapshot.Path_Input_Text,
               Fit => True);
         else
            for I in 1 .. Natural (Breadcrumb_Rows.Length) loop
               declare
                  Seg     : constant Breadcrumb_Segment_Layout :=
                    Breadcrumb_Rows.Element (Positive (I));
                  Is_Last : constant Boolean := I = Natural (Breadcrumb_Rows.Length);
                  Advance : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
                  Label   : constant UString :=
                    (if Seg.Clickable and then Seg.Segment_Index /= 0
                     then Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Label
                     else To_Unbounded_String (Files.Breadcrumbs.Ellipsis_Label));
                  Hovered : constant Boolean :=
                    Seg.Clickable
                    and then Has_Hover
                    and then Contains_Point (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_X, Hover_Y);
               begin
                  Add_Text
                    (Seg.X,
                     Toolbar_Input_Text_Y,
                     Seg.Width,
                     Toolbar_Input_Text_H,
                     Label,
                     Color => (if Seg.Clickable then Text_Color else Muted_Text_Color));
                  if Hovered then
                     Add_Border (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_Color);
                  end if;
                  if Seg.Clickable and then Seg.Segment_Index /= 0 then
                     Add_Accessibility_Node
                       (Role_Button,
                        Seg.X,
                        Seg.Y,
                        Seg.Width,
                        Seg.Height,
                        Label,
                        Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Ancestor_Path);
                  end if;
                  if not Is_Last then
                     Add_Text
                       (Saturating_Add (Seg.X, Seg.Width),
                        Toolbar_Input_Text_Y,
                        Advance,
                        Toolbar_Input_Text_H,
                        To_Unbounded_String (Breadcrumb_Separator_Text),
                        Color => Muted_Text_Color);
                  end if;
               end;
            end loop;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input or else not Snapshot.Path_Input_Valid then
            Add_Border
              (Path_X,
               Toolbar_Input_Y,
               Path_W,
               Toolbar_Input_H,
               (if Snapshot.Path_Input_Valid then Border_Color else Input_Error_Color));
         elsif Has_Hover
           and then Contains_Point
             (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H) then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Pressed_Color);
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input then
            Add_Focus_Ring (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H);
            Add_Caret
              (Saturating_Add (Path_X, Star_Reserve),
               Toolbar_Input_Y,
               (if Path_W > Star_Reserve then Path_W - Star_Reserve else 0),
               Toolbar_Input_H,
               Snapshot.Path_Input_Text,
               Snapshot.Text_Cursor_Position);
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Path_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Path_Input_Command)),
         Path_Input_Accessible_Description,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Path_Input);
      declare
         Field_Margin : constant Natural := 6;
         Filter_X : constant Natural :=
           Saturating_Add (Toolbar.Right_X, Field_Margin);
         --  The filter field is narrowed to end before the scope chip (when the
         --  chip fits); Files.UI owns the shared geometry the click hit-test uses.
         Filter_W : constant Natural :=
           Files.UI.Filter_Input_Field_Width (Toolbar, Line_Height);
         Scope_Chip : constant Files.UI.Scope_Chip_Region :=
           Files.UI.Filter_Scope_Chip_Region_Of (Toolbar, Line_Height);
         Scope_Key : constant String :=
           (case Snapshot.Search_Scope is
              when Files.Types.Filter_Here => "search.scope.here",
              when Files.Types.Search_Names => "search.scope.names",
              when Files.Types.Search_Contents => "search.scope.contents");
      begin
         Add_Rect
           (Filter_X,
            Toolbar_Input_Y,
            Filter_W,
            Toolbar_Input_H,
            Input_Color);
         Add_Border
           (Filter_X,
            Toolbar_Input_Y,
            Filter_W,
            Toolbar_Input_H,
            Border_Color);
         Add_Text
           (Saturating_Add (Filter_X, Files.UI.Input_Field_Padding),
            Toolbar_Input_Text_Y,
            (if Filter_W > 2 * Files.UI.Input_Field_Padding
             then Filter_W - 2 * Files.UI.Input_Field_Padding
             else 0),
            Toolbar_Input_Text_H,
            (if Length (Snapshot.Filter_Text) = 0
             then To_Unbounded_String (Files.Localization.Text ("filter.placeholder"))
             else Snapshot.Filter_Text),
            (if Length (Snapshot.Filter_Text) = 0 then Muted_Text_Color else Text_Color),
            Fit => True);
         if Snapshot.Focus = Files.Types.Focus_Filter_Input then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Border_Color);
            Add_Focus_Ring (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H);
            Add_Caret
              (Filter_X,
               Toolbar_Input_Y,
               Filter_W,
               Toolbar_Input_H,
               Snapshot.Filter_Text,
               Snapshot.Text_Cursor_Position);
         elsif Has_Hover
           and then Contains_Point
             (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H) then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Pressed_Color);
         end if;

         if Scope_Chip.Visible then
            --  The scope chip shows the active scope's short label; its border is
            --  accented while recursive search results are on screen so the view
            --  reads clearly as a search rather than a plain directory listing.
            Add_Rect
              (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Input_Color);
            Add_Border
              (Scope_Chip.X,
               Scope_Chip.Y,
               Scope_Chip.Width,
               Scope_Chip.Height,
               (if Snapshot.Search_Results_Active then Pressed_Color else Border_Color));
            Add_Text
              (Saturating_Add (Scope_Chip.X, Files.UI.Input_Field_Padding),
               Toolbar_Input_Text_Y,
               (if Scope_Chip.Width > 2 * Files.UI.Input_Field_Padding
                then Scope_Chip.Width - 2 * Files.UI.Input_Field_Padding
                else 0),
               Toolbar_Input_Text_H,
               Localized (Scope_Key),
               (if Snapshot.Search_Results_Active then Text_Color else Muted_Text_Color),
               Fit => True);
            if Has_Hover
              and then Contains_Point
                (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Hover_X, Hover_Y)
            then
               Add_Border
                 (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Hover_Color);
            end if;
            Add_Accessibility_Node
              (Role_Button,
               Scope_Chip.X,
               Scope_Chip.Y,
               Scope_Chip.Width,
               Scope_Chip.Height,
               Localized ("accessibility.search_scope"),
               Localized (Scope_Key),
               Enabled => True,
               Focused => False);
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Filter_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Filter_Input_Command)),
         Snapshot.Filter_Text,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Filter_Input);

      Add_Bottom_Command_Button
        (Bottom.Small_Button_X,
         Bottom.Small_Button_Width,
         Files.Commands.Select_Small_Icons_Command,
         Snapshot.View_Mode = Files.Types.Small_Icons);
      Add_Bottom_Command_Button
        (Bottom.Large_Button_X,
         Bottom.Large_Button_Width,
         Files.Commands.Select_Large_Icons_Command,
         Snapshot.View_Mode = Files.Types.Large_Icons);
      Add_Bottom_Command_Button
        (Bottom.Details_Button_X,
         Bottom.Details_Button_Width,
         Files.Commands.Select_Details_Command,
         Snapshot.View_Mode = Files.Types.Details);
      declare
         Hovered : constant Boolean :=
           Has_Hover
           and then Contains_Point
             (Bottom.Sort_Button_X,
              Bottom_Y,
              Bottom.Sort_Button_Width,
              Layout.Bottom_Bar_Height,
              Hover_X,
              Hover_Y);
         Pressed : constant Boolean :=
           Is_Pressed (Bottom.Sort_Button_X, Bottom_Y, Bottom.Sort_Button_Width, Layout.Bottom_Bar_Height);
      begin
         Add_Button (Bottom.Sort_Button_X, Bottom.Sort_Button_Width, Snapshot.Sort_Menu_Open, Hovered, Pressed);
         declare
            Field_Label : constant String := Sort_Field_Label (Snapshot.Sort_Field);
            Arrow_Text  : constant String := Direction_Text;
            Cell_W      : constant Positive :=
              Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
            Text_X0     : constant Natural :=
              Saturating_Add (Bottom.Sort_Button_X, Files.UI.Input_Field_Padding);
            Content_W   : constant Natural :=
              (if Bottom.Sort_Button_Width > Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
               then Bottom.Sort_Button_Width - Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
               else 0);
            Label_W     : constant Natural :=
              Saturating_Multiply (Files.UTF8.Display_Units (Field_Label), Cell_W);
            --  Tighter than a full monospace space so the direction arrow sits
            --  close to the sort field it belongs to.
            Arrow_Gap   : constant Natural := Cell_W / 2;
            Arrow_X     : constant Natural :=
              Saturating_Add (Text_X0, Saturating_Add (Label_W, Arrow_Gap));
            Sort_Color  : constant Render_Color :=
              Command_Color (Files.Commands.Toggle_Sort_Menu_Command);
         begin
            Add_Text
              (Text_X0,
               Bottom_Content_Y,
               Content_W,
               Bottom_Content_H,
               To_Unbounded_String (Field_Label),
               Sort_Color,
               Fit => False);
            if Content_W > Saturating_Add (Label_W, Arrow_Gap) then
               Add_Text
                 (Arrow_X,
                  Bottom_Content_Y,
                  Content_W - Label_W - Arrow_Gap,
                  Bottom_Content_H,
                  To_Unbounded_String (Arrow_Text),
                  Sort_Color,
                  Fit => False);
            end if;
         end;
         Add_Command_Tooltip
           (Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Files.Commands.Toggle_Sort_Menu_Command);
         Add_Accessibility_Node
           (Role_Button,
            Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Sort_Button_Label,
            Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Sort_Menu_Command)),
            Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Sort_Menu_Command),
            Selected => Snapshot.Sort_Menu_Open);
      end;
      --  The status area doubles as the hidden-count control: clicking it
      --  toggles Show_Hidden_Files. Give it button hover/press affordances and
      --  expose it as a button so it matches the neighboring bottom-bar
      --  controls.
      Add_Rect
        (Bottom.Info_X,
         Bottom_Content_Y,
         Bottom.Info_Width,
         Bottom_Content_H,
         (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) then Bottom_Bar_Color
          elsif Is_Pressed (Bottom.Info_X, Bottom_Y, Bottom.Info_Width, Layout.Bottom_Bar_Height)
          then Pressed_Color
          elsif Has_Hover
            and then Contains_Point
              (Bottom.Info_X, Bottom_Y, Bottom.Info_Width, Layout.Bottom_Bar_Height, Hover_X, Hover_Y)
          then Hover_Color
          else Bottom_Bar_Color));
      Add_Text
        (Saturating_Add (Bottom.Info_X, 4),
         Bottom_Content_Y,
         (if Bottom.Info_Width > 8 then Bottom.Info_Width - 8 else 0),
         Bottom_Content_H,
         Bottom_Info_Text,
         Bottom_Info_Color,
         Fit => True);
      Add_Command_Tooltip
        (Bottom.Info_X,
         Bottom_Content_Y,
         Bottom.Info_Width,
         Bottom_Content_H,
         Files.Commands.Toggle_Hidden_Files_Command);
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_X,
         Bottom_Content_Y,
         Bottom.Info_Width,
         Bottom_Content_H,
         Command_Label (Files.Commands.Toggle_Hidden_Files_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Hidden_Files_Command)),
         Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
      declare
         Info_Btn_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Info_Btn_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Add_Rect
           (Bottom.Info_Pane_X,
            Info_Btn_Y,
            Bottom.Info_Pane_Width,
            Info_Btn_H,
            (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) then Pane_Color
             elsif Snapshot.Info_Pane_Open
             then Selection_Color
             elsif Is_Pressed
               (Bottom.Info_Pane_X,
                Bottom_Y,
                Bottom.Info_Pane_Width,
                Layout.Bottom_Bar_Height)
             then Pressed_Color
             elsif Has_Hover
               and then Contains_Point
                 (Bottom.Info_Pane_X,
                  Bottom_Y,
                  Bottom.Info_Pane_Width,
                  Layout.Bottom_Bar_Height,
                  Hover_X,
                  Hover_Y)
             then Hover_Color
             else Bottom_Bar_Color));
      end;
      Add_Text
        (Saturating_Add (Bottom.Info_Pane_X, 4),
         Bottom_Content_Y,
         (if Bottom.Info_Pane_Width > 8 then Bottom.Info_Pane_Width - 8 else 0),
         Bottom_Content_H,
         Bottom_Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Command_Color (Files.Commands.Toggle_Info_Pane_Command),
         Fit => True);
      Add_Command_Tooltip
        (Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Files.Commands.Toggle_Info_Pane_Command);
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command),
         Selected => Snapshot.Info_Pane_Open);
      if Layout.Bottom_Bar_Height > 0
        and then Bottom.Sort_Button_X > 0
        and then Bottom.Sort_Button_Width > 0
      then
         Add_Rect (Bottom.Sort_Button_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_X > 0 then
         Add_Rect (Bottom.Info_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_Pane_X > 0 then
         Add_Rect (Bottom.Info_Pane_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;

      if Snapshot.View_Mode = Files.Types.Details then
         declare
            Padding   : constant Natural :=
              (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
                 and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
               then Main_Content_Padding
               else 0);
            Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
            Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
            Content_W : constant Natural :=
              (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
               then Layout.Main_Width - Saturating_Multiply (Padding, 2)
               else Layout.Main_Width);
            Content_H : constant Natural :=
              (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
               then Layout.Main_Height - Saturating_Multiply (Padding, 2)
               else Layout.Main_Height);
            Header_H  : constant Natural :=
              Natural'Min
                (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
            Header_Y  : constant Natural := Content_Y;
            Header_W  : constant Natural := Content_W;
            Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
            Text_Y    : constant Natural := Saturating_Add (Header_Y, Header_Pad);
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Header_Pad);

            function Cell_X (Column_X : Natural) return Natural is
            begin
               return Saturating_Add (Column_X, Details_Column_Padding);
            end Cell_X;

            function Cell_W (Column_W : Natural) return Natural is
            begin
               return (if Column_W > Details_Column_Padding then Column_W - Details_Column_Padding else 0);
            end Cell_W;

            function Header_Label (Column : Files.Types.Detail_Column) return String is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     return "details.name";
                  when Files.Types.Modified_Column =>
                     return "details.modified";
                  when Files.Types.Size_Column =>
                     return "details.size";
                  when Files.Types.Filetype_Column =>
                     return "details.filetype";
                  when Files.Types.Created_Column =>
                     return "details.created";
                  when Files.Types.Permissions_Column =>
                     return "details.permissions";
               end case;
            end Header_Label;

            function Column_Sort_Field
              (Column : Files.Types.Detail_Column;
               Field  : out Files.Model.Sort_Field)
               return Boolean is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     Field := Files.Model.Sort_Name;
                     return True;
                  when Files.Types.Modified_Column =>
                     Field := Files.Model.Sort_Changed;
                     return True;
                  when Files.Types.Size_Column =>
                     Field := Files.Model.Sort_Size;
                     return True;
                  when Files.Types.Filetype_Column =>
                     Field := Files.Model.Sort_Type;
                     return True;
                  when Files.Types.Created_Column =>
                     Field := Files.Model.Sort_Created;
                     return True;
                  when Files.Types.Permissions_Column =>
                     Field := Files.Model.Sort_Name;
                     return False;
               end case;
            end Column_Sort_Field;

            function Header_Text (Column : Files.Types.Detail_Column) return UString is
               Label : constant String := Files.Localization.Text (Header_Label (Column));
               Field : Files.Model.Sort_Field;
            begin
               if Column_Sort_Field (Column, Field) and then Snapshot.Sort_Field = Field then
                  return To_Unbounded_String (Label & " " & Direction_Text);
               else
                  return To_Unbounded_String (Label);
               end if;
            end Header_Text;

            function Header_Description return UString is
               Result : Unbounded_String := Null_Unbounded_String;
            begin
               for Column in Files.Types.Detail_Column loop
                  if Columns (Column).Visible then
                     if Length (Result) > 0 then
                        Append (Result, ", ");
                     end if;
                     Append (Result, Files.Localization.Text (Header_Label (Column)));
                  end if;
               end loop;
               return Result;
            end Header_Description;
         begin
            Add_Rect (Content_X, Header_Y, Header_W, Header_H, Pane_Color);
            Add_Border (Content_X, Header_Y, Header_W, Header_H, Border_Color);
            for Column in Files.Types.Detail_Column loop
               if Columns (Column).Visible then
                  Add_Text
                    (Cell_X (Columns (Column).X),
                     Text_Y,
                     Cell_W (Columns (Column).Width),
                     Line_Height,
                     Header_Text (Column),
                     Muted_Text_Color,
                     Fit => True);
               end if;
            end loop;
            Add_Accessibility_Node
              (Role_Table_Row,
               Content_X,
               Header_Y,
               Header_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.header")),
               Header_Description);

            if Header_H > 0 then
               for Column in Files.Types.Optional_Detail_Column loop
                  if Columns (Column).Visible then
                     Add_Rect
                       ((if Columns (Column).X > 2 then Columns (Column).X - 2 else 0),
                        Header_Y, 1, Header_H, Border_Color);
                  end if;
               end loop;
               Add_Rect
                 (Content_X,
                  Saturating_Add (Header_Y, Header_H - Natural'Min (2, Header_H)),
                  Header_W,
                  Natural'Min (2, Header_H),
                  Selection_Color);
            end if;
         end;
      end if;

      for Index in 1 .. Natural (Items.Length) loop
         declare
            Item      : constant Item_Snapshot := Snapshot.Items.Element (Positive (Index));
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
         begin
            --  Layout marks off-screen items with Height = 0 (Details rows that
            --  fall outside the scrolled viewport and icon cells past the
            --  bottom). Skip them so we don't pay per-item draw/accessibility
            --  cost for hundreds of invisible rows.
            if Item_Rect.Height = 0 or else Item_Rect.Width = 0 then
               goto Continue_Item_Loop;
            end if;
         end;

         declare
            Item      : constant Item_Snapshot := Snapshot.Items.Element (Positive (Index));
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
            --  Suppress the main-grid item hover highlight while the context
            --  menu is open: the pointer is interacting with the menu, so the
            --  cell under the cursor must not also light up. The menu's own row
            --  hover (drawn separately) is unaffected.
            Hovered   : constant Boolean :=
              Has_Hover
              and then not Snapshot.Context_Menu_Open
              and then Contains_Point
                (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_X, Hover_Y);
            Drop_Target : constant Boolean :=
              Has_Drag
              and then Drag_Item_Index /= 0
              and then Item.Visible_Index /= Drag_Item_Index
              and then Item.Kind = Files.Types.Directory_Item
              and then Hovered;

            function Detail_Cell_X (Column_X : Natural) return Natural is
            begin
               return Saturating_Add (Column_X, Details_Column_Padding);
            end Detail_Cell_X;

            function Detail_Cell_W (Column_W : Natural) return Natural is
            begin
               return (if Column_W > Details_Column_Padding then Column_W - Details_Column_Padding else 0);
            end Detail_Cell_W;
         begin
            --  Grouping band header: a non-selectable caption row. It draws its
            --  own subdued background and label and then skips all per-item
            --  drawing (icon, columns, selection, hover).
            if Item.Is_Group_Header then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Pane_Color);
               Add_Text
                 (Item_Rect.Text_X,
                  Item_Rect.Text_Y,
                  Item_Rect.Text_Width,
                  Natural'Min (Line_Height, Item_Rect.Height),
                  Item.Group_Label,
                  Muted_Text_Color,
                  Fit => True);
               if Item_Rect.Height > 0 then
                  Add_Rect
                    (Item_Rect.X,
                     Item_Rect.Y + Item_Rect.Height - 1,
                     Item_Rect.Width,
                     1,
                     Border_Color);
               end if;
               Add_Accessibility_Node
                 (Role_Table_Row,
                  Item_Rect.X,
                  Item_Rect.Y,
                  Item_Rect.Width,
                  Item_Rect.Height,
                  Item.Group_Label,
                  Item.Group_Label,
                  Enabled  => False,
                  Selected => False,
                  Focused  => False);
               goto Continue_Item_Loop;
            end if;

            if Drop_Target then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Selection_Color);
               Add_Rect
                 (Item_Rect.X,
                  Item_Rect.Y,
                  Natural'Min (4, Item_Rect.Width),
                  Item_Rect.Height,
                  Selection_Color);
            elsif Item.Selected then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Selection_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Selection_Color);
               Add_Rect
                 (Item_Rect.X,
                  Item_Rect.Y,
                  Natural'Min (3, Item_Rect.Width),
                  Item_Rect.Height,
                  Border_Color);
            elsif Hovered then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_Color);
            elsif Snapshot.View_Mode = Files.Types.Details and then Index mod 2 = 0 then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Detail_Alternate_Color);
            end if;

            if Snapshot.View_Mode = Files.Types.Details then
               Add_Details_Icon (Item, Item_Rect.Icon_X, Item_Rect.Icon_Y, Item_Rect.Icon_Size);
            else
               Add_Icon
                 (Item,
                  Item_Rect.Icon_X,
                  Item_Rect.Icon_Y,
                  Item_Rect.Icon_Size,
                  Use_Thumbnail => Snapshot.View_Mode = Files.Types.Large_Icons);
            end if;

            --  Favorite indicator: a small filled star tucked into the
            --  top-left corner of the item's icon in every view mode. Drawn
            --  only for favorited items, so a bare icon means "not favorited".
            if Item.Is_Favorite and then Item_Rect.Icon_Size > 0 then
               declare
                  Star_Box : constant Natural :=
                    Natural'Max
                      (Files.UI.Caret_Advance_Width (Line_Height),
                       Item_Rect.Icon_Size / 2);
               begin
                  Add_Text
                    (Item_Rect.Icon_X,
                     Item_Rect.Icon_Y,
                     Star_Box,
                     Star_Box,
                     To_Unbounded_String (Favorite_Star_Filled_Text),
                     Color => Favorite_Star_Color);
               end;
            end if;

            --  Color-label indicator: a small filled square dot tucked into the
            --  bottom-right corner of the item's icon (opposite the favorite
            --  star), drawn in the label's color. No_Label draws nothing.
            if Item.Label /= Files.Types.No_Label and then Item_Rect.Icon_Size > 0 then
               declare
                  Dot   : constant Natural :=
                    Natural'Max (4, Item_Rect.Icon_Size / 4);
                  Dot_X : constant Natural :=
                    (if Saturating_Add (Item_Rect.Icon_X, Item_Rect.Icon_Size) > Dot
                     then Saturating_Add (Item_Rect.Icon_X, Item_Rect.Icon_Size) - Dot
                     else Item_Rect.Icon_X);
                  Dot_Y : constant Natural :=
                    (if Saturating_Add (Item_Rect.Icon_Y, Item_Rect.Icon_Size) > Dot
                     then Saturating_Add (Item_Rect.Icon_Y, Item_Rect.Icon_Size) - Dot
                     else Item_Rect.Icon_Y);
               begin
                  Add_Rect (Dot_X, Dot_Y, Dot, Dot, Label_Render_Color (Item.Label));
               end;
            end if;
            declare
               Renaming : constant Boolean := Item.Renaming;
               --  While renaming a large-icons cell we edit across the full
               --  inner cell width (see Rename_Field_Extent), so the caret sits
               --  on the single label line rather than the tall cell.
               Wide     : constant Boolean :=
                 Renaming and then Snapshot.View_Mode = Files.Types.Large_Icons;
               Field_X  : Natural;
               Field_W  : Natural;
               Field_Y  : constant Natural := Item_Rect.Text_Y;
               Label_H  : constant Natural :=
                 (if Saturating_Add (Item_Rect.Y, Item_Rect.Height) > Field_Y
                  then Saturating_Add (Item_Rect.Y, Item_Rect.Height) - Field_Y
                  else 0);
               --  The caret sits on the single label line, not the whole cell,
               --  so its height tracks the line height rather than the tall
               --  large-icons cell.
               Field_H  : constant Natural :=
                 (if Wide
                  then Natural'Min
                    (Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2)),
                     Label_H)
                  else Item_Rect.Height);
            begin
               Rename_Field_Extent
                 (Item_Rect, Snapshot.View_Mode, Renaming, Field_X, Field_W);
               Add_Text
                 (Field_X,
                  Field_Y,
                  Field_W,
                  Natural'Min (Line_Height, Item_Rect.Height),
                  (if Renaming then Item.Rename_Value else Item.Name),
                  (if Item.Cut_Pending then Disabled_Text_Color else Text_Color),
                  Italic => Item.Cut_Pending,
                  Fit    => True);

               if Renaming and then Snapshot.Focus = Files.Types.Focus_Rename_Input then
                  Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Border_Color);
                  Add_Focus_Ring (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height);
                  declare
                     Caret_X     : constant Natural :=
                       (if Field_X > Files.UI.Input_Field_Padding
                        then Field_X - Files.UI.Input_Field_Padding
                        else 0);
                     Caret_Inset : constant Natural := Field_X - Caret_X;
                  begin
                     Add_Caret
                       (Caret_X,
                        Field_Y,
                        Saturating_Add (Field_W, Caret_Inset),
                        Field_H,
                        Item.Rename_Value,
                        Item.Rename_Cursor);
                  end;
               end if;
            end;

            if Snapshot.View_Mode = Files.Types.Details and then Item_Rect.Height > 0 then
               Add_Rect
                 (Item_Rect.X,
                  Item_Rect.Y + Item_Rect.Height - 1,
                  Item_Rect.Width,
                  1,
                  Border_Color);
               if Item_Rect.Modified_Width > 0 then
                  Add_Text
                    (Detail_Cell_X (Item_Rect.Modified_X),
                     Item_Rect.Text_Y,
                     Detail_Cell_W (Item_Rect.Modified_Width),
                     Natural'Min (Line_Height, Item_Rect.Height),
                     Detail_Time_Text (Item),
                     (if Item.Cut_Pending then Disabled_Text_Color else Muted_Text_Color),
                     Italic => Item.Cut_Pending);
                  if Item.Modified_Available then
                     Add_Tooltip_Text
                       (Detail_Cell_X (Item_Rect.Modified_X),
                        Item_Rect.Text_Y,
                        Detail_Cell_W (Item_Rect.Modified_Width),
                        Natural'Min (Line_Height, Item_Rect.Height),
                        To_Unbounded_String (Full_Time_Text (Item.Modified_Time)));
                  end if;
               end if;
               if Item_Rect.Size_Width > 0 then
                  Add_Text
                    (Detail_Cell_X (Item_Rect.Size_X),
                     Item_Rect.Text_Y,
                     Detail_Cell_W (Item_Rect.Size_Width),
                     Natural'Min (Line_Height, Item_Rect.Height),
                     Detail_Size_Text (Item),
                     (if Item.Cut_Pending then Disabled_Text_Color else Muted_Text_Color),
                     Italic => Item.Cut_Pending,
                     Fit    => True);
               end if;
               if Item_Rect.Filetype_Width > 0 then
                  Add_Text
                    (Detail_Cell_X (Item_Rect.Filetype_X),
                     Item_Rect.Text_Y,
                     Detail_Cell_W (Item_Rect.Filetype_Width),
                     Natural'Min (Line_Height, Item_Rect.Height),
                     Item.Filetype_Detail,
                     (if Item.Cut_Pending then Disabled_Text_Color else Muted_Text_Color),
                     Italic => Item.Cut_Pending,
                     Fit    => True);
               end if;
               if Item_Rect.Created_Width > 0 then
                  Add_Text
                    (Detail_Cell_X (Item_Rect.Created_X),
                     Item_Rect.Text_Y,
                     Detail_Cell_W (Item_Rect.Created_Width),
                     Natural'Min (Line_Height, Item_Rect.Height),
                     Detail_Created_Text (Item),
                     (if Item.Cut_Pending then Disabled_Text_Color else Muted_Text_Color),
                     Italic => Item.Cut_Pending,
                     Fit    => True);
                  if Item.Creation_Available then
                     Add_Tooltip_Text
                       (Detail_Cell_X (Item_Rect.Created_X),
                        Item_Rect.Text_Y,
                        Detail_Cell_W (Item_Rect.Created_Width),
                        Natural'Min (Line_Height, Item_Rect.Height),
                        To_Unbounded_String (Full_Time_Text (Item.Creation_Time)));
                  end if;
               end if;
               if Item_Rect.Permissions_Width > 0 then
                  Add_Text
                    (Detail_Cell_X (Item_Rect.Permissions_X),
                     Item_Rect.Text_Y,
                     Detail_Cell_W (Item_Rect.Permissions_Width),
                     Natural'Min (Line_Height, Item_Rect.Height),
                     Item.Permissions,
                     (if Item.Cut_Pending then Disabled_Text_Color else Muted_Text_Color),
                     Italic => Item.Cut_Pending,
                     Fit    => True);
               end if;
            end if;

            declare
               Row_Description : constant UString :=
                 (if Snapshot.View_Mode = Files.Types.Details
                  then To_Unbounded_String
                    (Files.Localization.Text ("details.modified") & ": " &
                     To_String (Detail_Time_Text (Item)) & ", " &
                     Files.Localization.Text ("details.size") & ": " &
                     To_String (Detail_Size_Text (Item)) & ", " &
                     Files.Localization.Text ("details.filetype") & ": " &
                     To_String (Item.Filetype_Detail))
                  else Item.Filetype_Detail);
            begin
               Add_Accessibility_Node
                 ((if Snapshot.View_Mode = Files.Types.Details then Role_Table_Row else Role_List_Item),
                  Item_Rect.X,
                  Item_Rect.Y,
                  Item_Rect.Width,
                  Item_Rect.Height,
                  Item.Name,
                  Row_Description,
                  Enabled  => True,
                  Selected => Item.Selected,
                  Focused  => Item.Selected);
            end;
         end;

         <<Continue_Item_Loop>>
         null;
      end loop;

      if Snapshot.View_Mode = Files.Types.Details and then not Items.Is_Empty then
         declare
            Padding   : constant Natural :=
              (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
                 and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
               then Main_Content_Padding
               else 0);
            Content_X : constant Natural := Saturating_Add (Layout.Main_X, Padding);
            Content_W : constant Natural :=
              (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
               then Layout.Main_Width - Saturating_Multiply (Padding, 2)
               else Layout.Main_Width);
            Content_Y : constant Natural := Saturating_Add (Layout.Main_Y, Padding);
            Last_Row  : constant Item_Layout := Items.Element (Positive (Items.Length));
            Separator_Y : constant Natural := Content_Y;
            Separator_H : constant Natural :=
              (if Last_Row.Y >= Content_Y
               then Saturating_Add (Last_Row.Y - Content_Y, (if Last_Row.Height > 0 then Last_Row.Height - 1 else 0))
               else Saturating_Add ((if Last_Row.Height > 0 then Last_Row.Height - 1 else 0), Content_Y - Last_Row.Y));
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Natural'Min (Details_Row_Padding, Line_Height));

            procedure Add_Column_Separator (Column_X : Natural) is
            begin
               Add_Rect ((if Column_X > 2 then Column_X - 2 else 0), Separator_Y, 1, Separator_H, Border_Color);
            end Add_Column_Separator;
         begin
            for Column in Files.Types.Optional_Detail_Column loop
               if Columns (Column).Visible then
                  Add_Column_Separator (Columns (Column).X);
               end if;
            end loop;
         end;
      end if;

      --  Rubber-band (marquee) selection rectangle: a translucent fill plus a
      --  solid selection-colored border over the grid while an empty-space drag
      --  is in progress. The items it touches are already drawn selected via the
      --  selection set, so this only shows the drag region itself.
      if Marquee_Active
        and then Marquee_W > 0
        and then Marquee_H > 0
        and then Width > 0
        and then Height > 0
      then
         Add_Rect (Marquee_X, Marquee_Y, Marquee_W, Marquee_H, Marquee_Color);
         Add_Border (Marquee_X, Marquee_Y, Marquee_W, Marquee_H, Selection_Color);
      end if;

      if Has_Drag
        and then Drag_Item_Index /= 0
        and then not Snapshot.Items.Is_Empty
        and then Width > 0
        and then Height > 0
      then
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            declare
               Item : constant Item_Snapshot := Snapshot.Items.Element (Positive (Index));
            begin
               if Item.Visible_Index = Drag_Item_Index then
                  declare
                     Icon_Size : constant Natural := Natural'Min (Natural'Max (Line_Height, 28), 48);
                     Pad       : constant Natural := 8;
                     Gap       : constant Natural := 8;
                     Panel_H   : constant Natural :=
                       Saturating_Add (Icon_Size, Saturating_Multiply (Pad, 2));
                     Panel_W   : constant Natural :=
                       Natural'Min
                         (Natural'Max
                            (Saturating_Add
                               (Saturating_Add (Icon_Size, Gap),
                                Saturating_Multiply (Line_Height, 8)),
                             Saturating_Add (Icon_Size, Saturating_Multiply (Pad, 2))),
                          Natural'Max (1, Width));
                     Offset    : constant Natural := 14;
                     Panel_X   : constant Natural :=
                       (if Drag_X <= Natural'Last - Offset
                          and then Drag_X + Offset <= Width
                          and then Width > Panel_W
                        then Natural'Min (Drag_X + Offset, Width - Panel_W)
                        elsif Width > Panel_W
                        then Width - Panel_W
                        else 0);
                     Panel_Y   : constant Natural :=
                       (if Drag_Y <= Natural'Last - Offset
                          and then Drag_Y + Offset <= Height
                          and then Height > Panel_H
                        then Natural'Min (Drag_Y + Offset, Height - Panel_H)
                        elsif Height > Panel_H
                        then Height - Panel_H
                        else 0);
                     Icon_X    : constant Natural := Saturating_Add (Panel_X, Pad);
                     Icon_Y    : constant Natural := Saturating_Add (Panel_Y, Pad);
                     Text_X    : constant Natural := Saturating_Add (Icon_X, Saturating_Add (Icon_Size, Gap));
                     Text_W    : constant Natural :=
                       (if Panel_W > Saturating_Add (Icon_Size, Saturating_Add (Gap, Saturating_Multiply (Pad, 2)))
                        then Panel_W - Icon_Size - Gap - Saturating_Multiply (Pad, 2)
                        else 0);
                     Text_Y    : constant Natural :=
                       Saturating_Add
                         (Panel_Y,
                          (if Panel_H > Line_Height then (Panel_H - Line_Height) / 2 else 0));
                  begin
                     Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Hover_Color);
                     Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Selection_Color);
                     Add_Icon (Item, Icon_X, Icon_Y, Icon_Size);
                     Add_Text (Text_X, Text_Y, Text_W, Line_Height, Item.Name, Fit => True);
                  end;

                  exit;
               end if;
            end;
         end loop;
      end if;

      if Empty_State_Key /= "" and then Layout.Main_Width > 0 and then Layout.Main_Height > 0 then
         declare
            Text_H : constant Natural := Line_Height;
            Panel_W : constant Natural :=
              Natural'Min (Natural'Max (240, Layout.Main_Width / 2), Layout.Main_Width);
            Panel_H : constant Natural := Natural'Min (Saturating_Multiply (Line_Height, 3), Layout.Main_Height);
            Panel_X : constant Natural :=
              Saturating_Add
                (Layout.Main_X,
                 (if Layout.Main_Width > Panel_W then (Layout.Main_Width - Panel_W) / 2 else 0));
            Panel_Y : constant Natural :=
              Saturating_Add
                (Layout.Main_Y,
                 (if Layout.Main_Height > Panel_H then (Layout.Main_Height - Panel_H) / 2 else 0));
            Text_Y : constant Natural :=
              Saturating_Add (Panel_Y, (if Panel_H > Text_H then (Panel_H - Text_H) / 2 else 0));
            Icon_Size : constant Natural := Natural'Min (Line_Height, Panel_H);
            Icon_X : constant Natural := Saturating_Add (Panel_X, 8);
            Text_X : constant Natural := Saturating_Add (Panel_X, Saturating_Add (Icon_Size, 16));
            Text_W : constant Natural :=
              (if Panel_W > Saturating_Add (Icon_Size, 24)
               then Panel_W - Saturating_Add (Icon_Size, 24)
               else Panel_W);
         begin
            Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Pane_Color);
            Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Border_Color);
            Add_Rect
              (Icon_X,
               Text_Y,
               Icon_Size,
               Natural'Min (Icon_Size, Text_H),
               Muted_Text_Color);
            if Icon_Size > 6 then
               Add_Rect
                 (Saturating_Add (Icon_X, Icon_Size / 4),
                  Saturating_Add (Text_Y, Icon_Size / 2),
                  Icon_Size / 2,
                  1,
                  Pane_Color);
            end if;
            Add_Text
              (Text_X,
               Text_Y,
               Text_W,
               Text_H,
               To_Unbounded_String (Files.Localization.Text (Empty_State_Key)),
               Muted_Text_Color,
               Fit => True);
         end;
      end if;

      if Main_View.Scrollbar_Visible then
         Add_Scrollbar
           (Main_View.Scrollbar_X,
            Main_View.Scrollbar_Y,
            Main_View.Scrollbar_Width,
            Main_View.Scrollbar_Track_Height,
            Main_View.Scrollbar_Thumb_Y,
            Main_View.Scrollbar_Height);
      end if;

      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (2, Info_Pane.Height),
            Border_Color);
         Add_Accessibility_Node
           (Role_Pane,
            Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Info_Pane.Height,
            Localized ("accessibility.info_pane"));
         declare
            Section_Offset_Rows : Natural := 0;
         begin
            for Index in 1 .. Natural (Snapshot.Selected_Info.Length) loop
               declare
                  Info   : constant Info_Snapshot := Snapshot.Selected_Info.Element (Positive (Index));
                  Section_Offset : constant Natural := Saturating_Multiply (Section_Offset_Rows, Line_Height);
                  Base_Y : constant Integer :=
                    Saturating_Integer_Add
                      (Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding)), Section_Offset);
                  Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
                  Text_X : constant Natural := Saturating_Add (Layout.Main_Width, Info_Pane_Padding);
                  Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
                  Reserved_W : constant Natural :=
                    Saturating_Add
                      ((if Info_Pane.Scrollbar_Visible then Info_Pane.Scrollbar_Width else 0),
                       Saturating_Multiply (Info_Pane_Padding, 2));
                  Text_W : constant Natural :=
                    (if Layout.Info_Pane_Width > Reserved_W
                     then Layout.Info_Pane_Width - Reserved_W
                     else 0);

                  procedure Add_Info_Text
                    (Offset : Natural;
                     Text   : UString;
                     Color  : Render_Color := Text_Color;
                     Fit    : Boolean := True)
                  is
                     Y : constant Integer :=
                       Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
                  begin
                     if Y >= Integer (Info_Pane.Y)
                       and then Y < Integer (Info_Bottom)
                     then
                        Add_Text (Text_X, Natural (Y), Text_W, Line_Height, Text, Color, Fit => Fit);
                     end if;
                  end Add_Info_Text;

                  procedure Add_Info_Label
                    (Row : Natural;
                     Key : String)
                  is
                     Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
                  begin
                     Add_Info_Text (Row, Text, Text_Color);
                     if Text_W > 1 then
                        declare
                           Y : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                        begin
                           if Y >= Integer (Info_Pane.Y)
                             and then Y < Integer (Info_Bottom)
                           then
                              Add_Text
                                (Saturating_Add (Text_X, 1),
                                 Natural (Y),
                                 Text_W - 1,
                                 Line_Height,
                                 Text,
                                 Text_Color,
                                 Fit => True);
                           end if;
                        end;
                     end if;
                  end Add_Info_Label;

                  procedure Add_Info_Wrapped_Value
                    (Row   : Natural;
                     Text  : UString;
                     Color : Render_Color := Muted_Text_Color)
                  is
                     Raw        : constant String := To_String (Text);
                     Cell_W     : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
                     Capacity   : constant Natural := Text_W / Cell_W;
                     Line_Index : Natural := 0;

                     procedure Add_Wrapped_Segment
                       (Segment_First : Integer;
                        Segment_Last  : Integer)
                     is
                        Start : Integer := Segment_First;
                     begin
                        if Segment_Last < Segment_First then
                           Line_Index := Saturating_Add (Line_Index, 1);
                           return;
                        end if;

                        while Start <= Segment_Last loop
                           declare
                              Prefix : constant String :=
                                Files.UTF8.Prefix_By_Units (Raw (Start .. Segment_Last), Capacity);
                              Last   : constant Integer :=
                                (if Prefix'Length = 0 then Start else Start + Prefix'Length - 1);
                           begin
                              Add_Info_Text
                                (Saturating_Add (Row, Line_Index),
                                 To_Unbounded_String (Raw (Start .. Last)),
                                 Color,
                                 Fit => False);
                              exit when Last >= Segment_Last;
                              Start := Last + 1;
                              Line_Index := Saturating_Add (Line_Index, 1);
                           end;
                        end loop;

                        Line_Index := Saturating_Add (Line_Index, 1);
                     end Add_Wrapped_Segment;

                     Line_First : Integer := Raw'First;
                  begin
                     if Raw'Length = 0 or else Capacity = 0 then
                        Add_Info_Text (Row, Text, Color, Fit => False);
                        return;
                     end if;

                     for Position in Raw'Range loop
                        if Raw (Position) = ASCII.LF then
                           Add_Wrapped_Segment (Line_First, Position - 1);
                           Line_First := Position + 1;
                        end if;
                     end loop;

                     if Line_First <= Raw'Last then
                        Add_Wrapped_Segment (Line_First, Raw'Last);
                     elsif Raw (Raw'Last) = ASCII.LF then
                        Add_Info_Text (Saturating_Add (Row, Line_Index), Null_Unbounded_String, Color, Fit => False);
                     end if;
                  end Add_Info_Wrapped_Value;

                  Current_Row : Natural := 0;

                  procedure Add_Info_Field
                    (Key   : String;
                     Value : UString;
                     Field : Natural;
                     Color : Render_Color := Muted_Text_Color)
                  is
                     Display_Value : constant UString :=
                       (if Field = 8 then Info_Field_Display_Value (Info, Field) else Value);
                     Value_Rows : constant Natural := Wrapped_Line_Count (Display_Value, Text_W, Line_Height);
                  begin
                     Add_Info_Label (Current_Row, Key);
                     Current_Row := Saturating_Add (Current_Row, 1);
                     Add_Info_Wrapped_Value (Current_Row, Display_Value, Color);
                     Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                  end Add_Info_Field;

                  Show_Grid_Here : constant Boolean :=
                    Snapshot.Permissions_Editable and then Info.Mode_Available;

                  --  Draw the interactive 3x3 rwx grid (rows user/group/other,
                  --  columns read/write/execute) and register one click hit
                  --  region per cell. Cell index Bit maps to POSIX mode bit
                  --  2 ** (8 - Bit); a filled cell means the bit is set.
                  procedure Add_Permission_Grid is
                     Cell : constant Natural := Natural'Max (6, Line_Height - 6);
                     Gap  : constant Natural := Natural'Max (2, Line_Height / 6);
                  begin
                     for Bit in 0 .. 8 loop
                        declare
                           Col   : constant Natural := Bit mod 3;
                           Row   : constant Natural := Bit / 3;
                           Cell_X : constant Natural :=
                             Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap));
                           Cell_Y : constant Integer :=
                             Saturating_Integer_Add
                               (Row_Y, Saturating_Multiply (Saturating_Add (Current_Row, Row), Line_Height));
                           Is_Set : constant Boolean :=
                             (Info.Mode_Bits / (2 ** (8 - Bit))) mod 2 = 1;
                        begin
                           if Cell_Y >= Integer (Info_Pane.Y)
                             and then Cell_Y + Integer (Cell) <= Integer (Info_Bottom)
                           then
                              Add_Rect (Cell_X, Natural (Cell_Y), Cell, Cell, Border_Color);
                              if Cell > 2 then
                                 Add_Rect
                                   (Saturating_Add (Cell_X, 1),
                                    Natural (Cell_Y) + 1,
                                    Cell - 2,
                                    Cell - 2,
                                    (if Is_Set then Selection_Color else Input_Color));
                              end if;
                              Result.Permission_Hits.Append
                                (Permission_Hit_Region'
                                   (Present => True,
                                    Bit     => Bit,
                                    X       => Cell_X,
                                    Y       => Natural (Cell_Y),
                                    Width   => Cell,
                                    Height  => Cell));
                           end if;
                        end;
                     end loop;

                     Current_Row := Saturating_Add (Current_Row, Permission_Grid_Rows);
                  end Add_Permission_Grid;

                  --  Draw an editable owner or group value and register one
                  --  click hit region over it. While editing, the value shows
                  --  the editor buffer with an underline and a text caret.
                  procedure Add_Ownership_Field
                    (Key     : String;
                     Field   : Natural;
                     Editing : Boolean)
                  is
                     Value      : constant UString := Info_Field_Value (Info, Field);
                     Value_Rows : constant Natural := Wrapped_Line_Count (Value, Text_W, Line_Height);
                     Value_Row  : Natural;
                     Cell_Y     : Integer;
                  begin
                     Add_Info_Label (Current_Row, Key);
                     Current_Row := Saturating_Add (Current_Row, 1);
                     Value_Row := Current_Row;
                     Add_Info_Wrapped_Value
                       (Value_Row, Value, (if Editing then Text_Color else Muted_Text_Color));
                     Cell_Y :=
                       Saturating_Integer_Add (Row_Y, Saturating_Multiply (Value_Row, Line_Height));
                     if Cell_Y >= Integer (Info_Pane.Y)
                       and then Cell_Y < Integer (Info_Bottom)
                       and then Text_W > 0
                     then
                        Result.Ownership_Hits.Append
                          (Ownership_Hit_Region'
                             (Present  => True,
                              Is_Group => Field = 10,
                              X        => Text_X,
                              Y        => Natural (Cell_Y),
                              Width    => Text_W,
                              Height   => Line_Height));
                        if Editing then
                           Add_Rect
                             (Text_X,
                              Saturating_Add (Natural (Cell_Y), Line_Height - 1),
                              Text_W,
                              1,
                              Selection_Color);
                           declare
                              Char_W  : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
                              Raw     : constant String := To_String (Value);
                              Caret_X : constant Natural :=
                                Saturating_Add
                                  (Text_X,
                                   Saturating_Multiply
                                     (Files.UTF8.Display_Units_Before
                                        (Raw, Snapshot.Text_Cursor_Position),
                                      Char_W));
                           begin
                              Add_Rect
                                (Caret_X,
                                 Saturating_Add (Natural (Cell_Y), 2),
                                 2,
                                 (if Line_Height > 4 then Line_Height - 4 else Line_Height),
                                 Text_Color);
                           end;
                        end if;
                     end if;
                     Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                  end Add_Ownership_Field;
               begin
                  Add_Info_Field ("info.name", Info_Field_Value (Info, 0), 0);
                  Add_Info_Field ("info.filetype", Info_Field_Value (Info, 1), 1);
                  Add_Info_Field ("info.size", Info_Field_Value (Info, 2), 2);
                  if Info.Is_Directory and then Info.Folder_Size_Available then
                     Add_Info_Field ("info.folder_size", Folder_Contents_Text (Info), 2);
                  end if;
                  Add_Info_Field ("info.created", Info_Field_Value (Info, 3), 3);
                  Add_Info_Field ("info.modified", Info_Field_Value (Info, 4), 4);
                  Add_Info_Field ("info.permissions", Info_Field_Value (Info, 5), 5);
                  if Show_Grid_Here then
                     Add_Permission_Grid;
                  end if;
                  if Info.Ownership_Available then
                     Add_Ownership_Field ("info.owner", 9, Info.Owner_Editing);
                     Add_Ownership_Field ("info.group", 10, Info.Group_Editing);
                  end if;
                  Add_Info_Field ("info.metadata_error", Info_Field_Value (Info, 6), 6);
                  Add_Info_Field ("info.kind", Info_Field_Value (Info, 7), 7);
                  Add_Info_Field ("info.extra", Info_Field_Value (Info, 8), 8);
                  declare
                     Section_H : constant Natural :=
                       Natural'Min
                         (Saturating_Multiply
                            (Line_Height,
                             Info_Section_Row_Count
                               (Info, Text_W, Line_Height, Snapshot.Permissions_Editable)),
                          Info_Pane.Height);
                     Visible_Y : constant Integer := Integer'Max (Row_Y, Integer (Info_Pane.Y));
                     Raw_Bottom : constant Integer :=
                       Integer'Min
                         (Saturating_Integer_Add (Row_Y, Section_H),
                          Integer (Info_Bottom));
                     Visible_H : constant Natural :=
                       (if Raw_Bottom > Visible_Y then Natural (Raw_Bottom - Visible_Y) else 0);
                     Size_Text : constant String := To_String (Info_Field_Value (Info, 2));
                     Modified_Text : constant String :=
                       To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified"));
                     Description : Unbounded_String :=
                       To_Unbounded_String
                         (Files.Localization.Text ("info.filetype") & ": " &
                          To_String (Info_Field_Value (Info, 1)) & ", " &
                          Files.Localization.Text ("info.size") & ": " &
                          Size_Text & ", " &
                          Modified_Text);
                  begin
                     if Info.Metadata_Error then
                        Append
                          (Description,
                           ", " &
                           Files.Localization.Text ("info.metadata_error") & ": " &
                           Files.Localization.Text (To_String (Info.Error_Key)));
                     end if;

                     Add_Accessibility_Node
                       (Role_List_Item,
                        Info_Pane.X,
                        Natural (Visible_Y),
                        Text_W,
                        Visible_H,
                        Info.Name,
                        Description);
                  end;
                  Section_Offset_Rows :=
                    Saturating_Add
                      (Section_Offset_Rows,
                       Info_Section_Row_Count
                         (Info, Text_W, Line_Height, Snapshot.Permissions_Editable));
               end;
            end loop;
         end;

         if Info_Pane.Scrollbar_Visible then
            Add_Scrollbar
              (Info_Pane.Scrollbar_X,
               Info_Pane.Scrollbar_Y,
               Info_Pane.Scrollbar_Width,
               Info_Pane.Scrollbar_Track_Height,
               Info_Pane.Scrollbar_Thumb_Y,
               Info_Pane.Scrollbar_Height);
         end if;
         --  Keep the close button clear of the scrollbar column on the right.
         Draw_Close_Button
           (Info_Pane.X,
            Info_Pane.Y,
            (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
             then Info_Pane.Width - Info_Pane.Scrollbar_Width
             else Info_Pane.Width),
            Info_Pane.Height,
            Overlay => False);
      end if;

      if Snapshot.Settings_Pane_Open then
         Drawing_Settings_Pane := True;
         declare
            Pane : constant Files.UI.Settings_Pane_Layout := Settings_Pane;
            Pane_W : constant Natural := Pane.Width;
            Pane_H : constant Natural := Pane.Height;
            Pane_X : constant Natural := Pane.X;
            Pane_Y : constant Natural := Pane.Y;
            Text_X : constant Natural := Pane.Text_X;
            Text_Y : constant Natural := Pane.Text_Y;
            Text_W : constant Natural := Pane.Text_Width;
            Row_Step : constant Natural := Saturating_Add (Line_Height, Files.UI.Settings_Row_Gap);
            Inter_Row_Px : constant Natural :=
              Saturating_Multiply (Files.UI.Settings_Row_Gap, 2);
            --  Requested scroll offset; clamped against measured content
            --  height once the settings content has been measured below.
            Scroll_Px : Natural :=
              Saturating_Multiply (Snapshot.Settings_Pane_Scroll_Lines, Line_Height);
            Pane_Bottom : constant Natural :=
              (if Pane_Y + Pane_H > Files.UI.Settings_Pane_Padding
               then Pane_Y + Pane_H - Files.UI.Settings_Pane_Padding
               else Pane_Y);

            --  Settings_Row_Y / Row_Hidden remain for legacy callers that still
            --  pass an integer row index (action buttons, entry buttons). They
            --  use the original Row_Step (with inter-row gap) so the legacy
            --  callers still look the way they used to.
            function Settings_Row_Y (Row : Natural) return Natural is
               Raw : constant Natural := Saturating_Multiply (Row, Row_Step);
            begin
               if Raw + Text_Y > Scroll_Px then
                  return Raw + Text_Y - Scroll_Px;
               else
                  return 0;
               end if;
            end Settings_Row_Y;

            function Row_Hidden (Row : Natural) return Boolean is
               Raw_Top : constant Natural := Saturating_Multiply (Row, Row_Step);
            begin
               if Saturating_Add (Raw_Top, Line_Height) <= Scroll_Px then
                  return True;
               end if;
               return Saturating_Add (Settings_Row_Y (Row), Line_Height) > Pane_Bottom;
            end Row_Hidden;

            --  Pixel-based cursor helpers. Y_Px is an offset from the content
            --  top of the pane (i.e. relative to Text_Y, before scroll).
            function Visible_Y (Y_Px : Natural) return Natural is
            begin
               if Saturating_Add (Y_Px, Text_Y) > Scroll_Px then
                  return Saturating_Add (Y_Px, Text_Y) - Scroll_Px;
               else
                  return 0;
               end if;
            end Visible_Y;

            function Y_Hidden (Y_Px : Natural; Height : Natural) return Boolean is
            begin
               if Saturating_Add (Y_Px, Height) <= Scroll_Px then
                  return True;
               end if;
               return Saturating_Add (Visible_Y (Y_Px), Height) > Pane_Bottom;
            end Y_Hidden;

            procedure Begin_Row (Y_Cursor : in out Natural) is
            begin
               if Y_Cursor > 0 then
                  Y_Cursor := Saturating_Add (Y_Cursor, Inter_Row_Px);
               end if;
            end Begin_Row;

            --  The font's typographic line height (Ascent − Descent in pixels)
            --  spans an extra few pixels of empty room above the cap line. When
            --  text is drawn into a Line_Height-tall row, visible glyph content
            --  sits in the lower portion of that box. We shift selection
            --  rectangles/buttons down so they wrap around the visible glyph
            --  content. The offset scales with Line_Height so it stays correct
            --  as the user zooms the font size.
            Sel_Y_Offset : constant Natural := Line_Height / 6;

            function Sel_Y (Y : Natural) return Natural is
              (Saturating_Add (Y, Sel_Y_Offset));

            function Text_Y_In_Row (Y : Natural) return Natural is (Y);

            Cell_W_Settings : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
            Capacity_Settings : constant Natural := Text_W / Cell_W_Settings;

            function Wrap_To_Lines (Text : String; Capacity : Natural)
               return Files.Types.String_Vectors.Vector
            is
               Lines  : Files.Types.String_Vectors.Vector;
               Buffer : Unbounded_String := Null_Unbounded_String;

               procedure Flush is
               begin
                  Lines.Append (Buffer);
                  Buffer := Null_Unbounded_String;
               end Flush;

               procedure Take_Word (Word : String) is
                  W_Units : constant Natural := Files.UTF8.Display_Units (Word);
                  B_Units : constant Natural := Files.UTF8.Display_Units (To_String (Buffer));
               begin
                  if Length (Buffer) = 0 then
                     Buffer := To_Unbounded_String (Word);
                  elsif B_Units + 1 + W_Units <= Capacity then
                     Append (Buffer, " " & Word);
                  else
                     Flush;
                     Buffer := To_Unbounded_String (Word);
                  end if;
               end Take_Word;

               Start : Integer := Text'First;
            begin
               if Text'Length = 0 or else Capacity = 0 then
                  Lines.Append (To_Unbounded_String (Text));
                  return Lines;
               end if;
               for I in Text'Range loop
                  if Text (I) = ' ' then
                     if I > Start then
                        Take_Word (Text (Start .. I - 1));
                     end if;
                     Start := I + 1;
                  end if;
               end loop;
               if Start <= Text'Last then
                  Take_Word (Text (Start .. Text'Last));
               end if;
               if Length (Buffer) > 0 then
                  Flush;
               end if;
               return Lines;
            end Wrap_To_Lines;

            procedure Add_Settings_Row_At
              (Y_Cursor : in out Natural;
               Key      : String;
               Color    : Render_Color := Muted_Text_Color)
            is
            begin
               Begin_Row (Y_Cursor);
               if not Y_Hidden (Y_Cursor, Line_Height) then
                  Add_Text
                    (Text_X,
                     Text_Y_In_Row (Visible_Y (Y_Cursor)),
                     Text_W,
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Color,
                     Fit => True);
               end if;
               Y_Cursor := Saturating_Add (Y_Cursor, Line_Height);
            end Add_Settings_Row_At;

            procedure Add_Wrapped_Row
              (Y_Cursor : in out Natural;
               Text     : String;
               Color    : Render_Color := Muted_Text_Color;
               Italic   : Boolean := False)
            is
               Lines : constant Files.Types.String_Vectors.Vector :=
                 Wrap_To_Lines (Text, Capacity_Settings);
               Line_Count : constant Natural :=
                 Natural'Max (1, Natural (Lines.Length));
            begin
               Begin_Row (Y_Cursor);
               for I in 1 .. Natural (Lines.Length) loop
                  declare
                     Line_Y : constant Natural :=
                       Saturating_Add (Y_Cursor, Saturating_Multiply (I - 1, Line_Height));
                  begin
                     if not Y_Hidden (Line_Y, Line_Height) then
                        Add_Text
                          (Text_X,
                           Text_Y_In_Row (Visible_Y (Line_Y)),
                           Text_W,
                           Line_Height,
                           Lines.Element (I),
                           Color,
                           Fit    => False,
                           Italic => Italic);
                     end if;
                  end;
               end loop;
               Y_Cursor :=
                 Saturating_Add (Y_Cursor, Saturating_Multiply (Line_Count, Line_Height));
            end Add_Wrapped_Row;

            procedure Add_Settings_Toggle
              (Y_Cursor : in out Natural;
               Key      : String;
               Token    : UString;
               Index    : Natural)
            is
               Is_On      : constant Boolean := To_String (Token) = "true";
               Toggle_W   : constant Natural := Saturating_Multiply (Line_Height, 2);
               Pad        : constant Natural := Files.UI.Input_Field_Padding;
               Label_W    : constant Natural :=
                 (if Text_W > Saturating_Add (Toggle_W, Pad) then Text_W - Toggle_W - Pad else Text_W);
               Label_Cap  : constant Natural :=
                 (if Label_W > 0 then Label_W / Cell_W_Settings else 0);
               Lines      : constant Files.Types.String_Vectors.Vector :=
                 Wrap_To_Lines (Files.Localization.Text (Key), Label_Cap);
               Line_Count : constant Natural :=
                 Natural'Max (1, Natural (Lines.Length));
               Selection_H : constant Natural :=
                 Saturating_Multiply (Line_Count, Line_Height);
               Toggle_X   : constant Natural :=
                 (if Text_W > Toggle_W
                  then Saturating_Add (Text_X, Text_W - Toggle_W)
                  else Text_X);
            begin
               Begin_Row (Y_Cursor);
               declare
                  Start_Visible_Y : constant Natural := Visible_Y (Y_Cursor);
                  Knob_Pad : constant Natural :=
                    Natural'Max (1, Line_Height / 8);
                  Knob_Sz  : constant Natural :=
                    (if Line_Height > 2 * Knob_Pad
                     then Line_Height - 2 * Knob_Pad
                     else Line_Height);
                  Knob_X   : constant Natural :=
                    (if Is_On
                     then Saturating_Add (Toggle_X, Toggle_W - Knob_Pad - Knob_Sz)
                     else Saturating_Add (Toggle_X, Knob_Pad));
               begin
                  if Index /= 0 and then not Y_Hidden (Y_Cursor, Selection_H) then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Field,
                           Field  => Index,
                           Option => 0,
                           X      => (if Text_X > 2 then Text_X - 2 else 0),
                           Y      => Start_Visible_Y,
                           Width  => Saturating_Add (Text_W, 4),
                           Height => Selection_H));
                  end if;

                  if Snapshot.Settings_Field_Index = Index
                    and then not Y_Hidden (Y_Cursor, Selection_H)
                  then
                     Add_Rect (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H, Selection_Color);
                     Add_Focus_Ring (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H);
                     Add_Rect
                       (Text_X - 2,
                        Sel_Y (Start_Visible_Y),
                        Natural'Min (3, Text_W + 4),
                        Selection_H,
                        Border_Color);
                  end if;

                  for I in 1 .. Natural (Lines.Length) loop
                     declare
                        Line_Y : constant Natural :=
                          Saturating_Add (Y_Cursor, Saturating_Multiply (I - 1, Line_Height));
                     begin
                        if not Y_Hidden (Line_Y, Line_Height) then
                           Add_Text
                             (Text_X,
                              Text_Y_In_Row (Visible_Y (Line_Y)),
                              Label_W,
                              Line_Height,
                              Lines.Element (I),
                              Muted_Text_Color,
                              Fit => False);
                        end if;
                     end;
                  end loop;

                  if not Y_Hidden (Y_Cursor, Line_Height) then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Toggle,
                           Field  => Index,
                           Option => (if Is_On then 2 else 1),
                           X      => Toggle_X,
                           Y      => Start_Visible_Y,
                           Width  => Toggle_W,
                           Height => Line_Height));
                     Add_Rect
                       (Toggle_X, Sel_Y (Start_Visible_Y), Toggle_W, Line_Height,
                        (if Is_On then Selection_Color else Input_Color));
                     Add_Border (Toggle_X, Sel_Y (Start_Visible_Y), Toggle_W, Line_Height, Border_Color);
                     Add_Rect
                       (Knob_X,
                        Saturating_Add (Sel_Y (Start_Visible_Y), Knob_Pad),
                        Knob_Sz, Knob_Sz, Text_Color);
                  end if;
               end;
               Y_Cursor := Saturating_Add (Y_Cursor, Selection_H);
            end Add_Settings_Toggle;

            procedure Add_Settings_Default_View_Toggle
              (Y_Cursor : in out Natural;
               Index    : Natural)
            is
               Current     : constant String :=
                 To_String (Snapshot.Settings_Default_View_Token);
               Label_Text  : constant String :=
                 Files.Localization.Text ("settings.default_view");
               Pad         : constant Natural := Files.UI.Input_Field_Padding;

               function Segment_Width_For (Key : String) return Natural is
                  Text : constant String := Files.Localization.Text (Key);
                  Px   : constant Natural :=
                    Saturating_Multiply
                      (Files.UTF8.Display_Units (Text), Cell_W_Settings);
               begin
                  return Saturating_Add (Px, Saturating_Multiply (Pad, 2));
               end Segment_Width_For;

               Segment_W   : constant Natural :=
                 Natural'Max
                   (Segment_Width_For ("command.view.small.short"),
                    Natural'Max
                      (Segment_Width_For ("command.view.large.short"),
                       Segment_Width_For ("command.view.details.short")));
               Segments_W  : constant Natural :=
                 Saturating_Multiply (Segment_W, 3);
               Label_W     : constant Natural :=
                 (if Text_W > Saturating_Add (Segments_W, Pad)
                  then Text_W - Segments_W - Pad
                  else Text_W);
               Label_Cap   : constant Natural :=
                 (if Label_W > 0 then Label_W / Cell_W_Settings else 0);
               Lines       : constant Files.Types.String_Vectors.Vector :=
                 Wrap_To_Lines (Label_Text, Label_Cap);
               Line_Count  : constant Natural :=
                 Natural'Max (1, Natural (Lines.Length));
               Selection_H : constant Natural :=
                 Saturating_Multiply (Line_Count, Line_Height);
               Segments_X  : constant Natural :=
                 (if Text_W > Segments_W
                  then Saturating_Add (Text_X, Text_W - Segments_W)
                  else Text_X);

               procedure Draw_Segment
                 (Offset       : Natural;
                  Key          : String;
                  Active       : Boolean;
                  Start_Vis_Y  : Natural)
               is
                  Segment_X : constant Natural :=
                    Saturating_Add (Segments_X, Saturating_Multiply (Offset, Segment_W));
               begin
                  Result.Settings_Hits.Append
                    (Settings_Hit_Region'
                       (Kind   => Settings_Hit_Segment,
                        Field  => Index,
                        Option => Offset + 1,
                        X      => Segment_X,
                        Y      => Start_Vis_Y,
                        Width  => Segment_W,
                        Height => Line_Height));
                  Add_Rect
                    (Segment_X, Sel_Y (Start_Vis_Y), Segment_W, Line_Height,
                     (if Active then Selection_Color else Input_Color));
                  Add_Border
                    (Segment_X, Sel_Y (Start_Vis_Y), Segment_W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (Segment_X, Pad),
                     Text_Y_In_Row (Start_Vis_Y),
                     (if Segment_W > 2 * Pad then Segment_W - 2 * Pad else 0),
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     (if Active then Text_Color else Muted_Text_Color),
                     Fit => True);
               end Draw_Segment;
            begin
               Begin_Row (Y_Cursor);
               declare
                  Start_Visible_Y : constant Natural := Visible_Y (Y_Cursor);
               begin
                  if Index /= 0 and then not Y_Hidden (Y_Cursor, Selection_H) then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Field,
                           Field  => Index,
                           Option => 0,
                           X      => (if Text_X > 2 then Text_X - 2 else 0),
                           Y      => Start_Visible_Y,
                           Width  => Saturating_Add (Text_W, 4),
                           Height => Selection_H));
                  end if;

                  if Snapshot.Settings_Field_Index = Index
                    and then not Y_Hidden (Y_Cursor, Selection_H)
                  then
                     Add_Rect (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H, Selection_Color);
                     Add_Focus_Ring (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H);
                     Add_Rect
                       (Text_X - 2,
                        Sel_Y (Start_Visible_Y),
                        Natural'Min (3, Text_W + 4),
                        Selection_H,
                        Border_Color);
                  end if;

                  for I in 1 .. Natural (Lines.Length) loop
                     declare
                        Line_Y : constant Natural :=
                          Saturating_Add (Y_Cursor, Saturating_Multiply (I - 1, Line_Height));
                     begin
                        if not Y_Hidden (Line_Y, Line_Height) then
                           Add_Text
                             (Text_X,
                              Text_Y_In_Row (Visible_Y (Line_Y)),
                              Label_W,
                              Line_Height,
                              Lines.Element (I),
                              Muted_Text_Color,
                              Fit => False);
                        end if;
                     end;
                  end loop;

                  if not Y_Hidden (Y_Cursor, Line_Height) then
                     Draw_Segment
                       (0, "command.view.small.short",
                        Current = "small_icons", Start_Visible_Y);
                     Draw_Segment
                       (1, "command.view.large.short",
                        Current = "large_icons", Start_Visible_Y);
                     Draw_Segment
                       (2, "command.view.details.short",
                        Current = "details", Start_Visible_Y);
                  end if;
               end;
               Y_Cursor := Saturating_Add (Y_Cursor, Selection_H);
            end Add_Settings_Default_View_Toggle;

            procedure Add_Settings_Number_Stepper
              (Y_Cursor : in out Natural;
               Key      : String;
               Value    : UString;
               Index    : Natural)
            is
               Label_Text : constant String := Files.Localization.Text (Key);
               Pad        : constant Natural := Files.UI.Input_Field_Padding;
               Button_W   : constant Natural :=
                 Natural'Max (Line_Height, Saturating_Multiply (Cell_W_Settings, 2));
               Value_W    : constant Natural :=
                 Saturating_Add
                   (Saturating_Multiply (Cell_W_Settings, 4),
                    Saturating_Multiply (Pad, 2));
               Stepper_W  : constant Natural :=
                 Saturating_Add (Value_W, Saturating_Multiply (Button_W, 2));
               Label_W    : constant Natural :=
                 (if Text_W > Saturating_Add (Stepper_W, Pad)
                  then Text_W - Stepper_W - Pad
                  else Text_W);
               Label_Cap  : constant Natural :=
                 (if Label_W > 0 then Label_W / Cell_W_Settings else 0);
               Lines      : constant Files.Types.String_Vectors.Vector :=
                 Wrap_To_Lines (Label_Text, Label_Cap);
               Line_Count : constant Natural :=
                 Natural'Max (1, Natural (Lines.Length));
               Selection_H : constant Natural :=
                 Saturating_Multiply (Line_Count, Line_Height);
               Stepper_X  : constant Natural :=
                 (if Text_W > Stepper_W
                  then Saturating_Add (Text_X, Text_W - Stepper_W)
                  else Text_X);
            begin
               Begin_Row (Y_Cursor);
               declare
                  Start_Visible_Y : constant Natural := Visible_Y (Y_Cursor);
                  Value_X  : constant Natural := Stepper_X;
                  Down_X   : constant Natural := Saturating_Add (Value_X, Value_W);
                  Up_X     : constant Natural := Saturating_Add (Down_X, Button_W);

                  procedure Draw_Button (X : Natural; Glyph : String) is
                  begin
                     Add_Rect (X, Sel_Y (Start_Visible_Y), Button_W, Line_Height, Input_Color);
                     Add_Border (X, Sel_Y (Start_Visible_Y), Button_W, Line_Height, Border_Color);
                     Add_Text
                       (Saturating_Add (X, Pad),
                        Text_Y_In_Row (Start_Visible_Y),
                        (if Button_W > 2 * Pad then Button_W - 2 * Pad else 0),
                        Line_Height,
                        To_Unbounded_String (Glyph),
                        Text_Color,
                        Fit => True);
                  end Draw_Button;
               begin
                  if Index /= 0 and then not Y_Hidden (Y_Cursor, Selection_H) then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Field,
                           Field  => Index,
                           Option => 0,
                           X      => (if Text_X > 2 then Text_X - 2 else 0),
                           Y      => Start_Visible_Y,
                           Width  => Saturating_Add (Text_W, 4),
                           Height => Selection_H));
                  end if;

                  if Snapshot.Settings_Field_Index = Index
                    and then not Y_Hidden (Y_Cursor, Selection_H)
                  then
                     Add_Rect (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H, Selection_Color);
                     Add_Focus_Ring (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H);
                     Add_Rect
                       (Text_X - 2,
                        Sel_Y (Start_Visible_Y),
                        Natural'Min (3, Text_W + 4),
                        Selection_H,
                        Border_Color);
                  end if;

                  for I in 1 .. Natural (Lines.Length) loop
                     declare
                        Line_Y : constant Natural :=
                          Saturating_Add (Y_Cursor, Saturating_Multiply (I - 1, Line_Height));
                     begin
                        if not Y_Hidden (Line_Y, Line_Height) then
                           Add_Text
                             (Text_X,
                              Text_Y_In_Row (Visible_Y (Line_Y)),
                              Label_W,
                              Line_Height,
                              Lines.Element (I),
                              Muted_Text_Color,
                              Fit => False);
                        end if;
                     end;
                  end loop;

                  if not Y_Hidden (Y_Cursor, Line_Height) then
                     Add_Rect (Value_X, Sel_Y (Start_Visible_Y), Value_W, Line_Height, Input_Color);
                     Add_Border (Value_X, Sel_Y (Start_Visible_Y), Value_W, Line_Height, Border_Color);
                     Add_Text
                       (Saturating_Add (Value_X, Pad),
                        Text_Y_In_Row (Start_Visible_Y),
                        (if Value_W > 2 * Pad then Value_W - 2 * Pad else 0),
                        Line_Height,
                        Value,
                        Text_Color,
                        Fit => True);
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Stepper_Down,
                           Field  => Index,
                           Option => 0,
                           X      => Down_X,
                           Y      => Start_Visible_Y,
                           Width  => Button_W,
                           Height => Line_Height));
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Stepper_Up,
                           Field  => Index,
                           Option => 0,
                           X      => Up_X,
                           Y      => Start_Visible_Y,
                           Width  => Button_W,
                           Height => Line_Height));
                     Draw_Button (Down_X, "-");
                     Draw_Button (Up_X, "+");
                  end if;
               end;
               Y_Cursor := Saturating_Add (Y_Cursor, Selection_H);
            end Add_Settings_Number_Stepper;

            procedure Add_Settings_Value
              (Y_Cursor : in out Natural;
               Key      : String;
               Value    : UString;
               Index    : Natural)
            is
               Combined : constant String :=
                 Files.Localization.Text (Key) & ": " & To_String (Value);
               Lines : constant Files.Types.String_Vectors.Vector :=
                 Wrap_To_Lines (Combined, Capacity_Settings);
               Line_Count : constant Natural :=
                 Natural'Max (1, Natural (Lines.Length));
               Selection_H : constant Natural :=
                 Saturating_Multiply (Line_Count, Line_Height);
               --  Rows with Index = 0 are informational section headers
               --  (filetypes / icons / open_actions). Render them italic.
               Italic : constant Boolean := Index = 0;
            begin
               Begin_Row (Y_Cursor);
               declare
                  Start_Visible_Y : constant Natural := Visible_Y (Y_Cursor);
               begin
                  if Index /= 0 and then not Y_Hidden (Y_Cursor, Selection_H) then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Field,
                           Field  => Index,
                           Option => 0,
                           X      => (if Text_X > 2 then Text_X - 2 else 0),
                           Y      => Start_Visible_Y,
                           Width  => Saturating_Add (Text_W, 4),
                           Height => Selection_H));
                  end if;

                  if Snapshot.Settings_Field_Index = Index
                    and then not Y_Hidden (Y_Cursor, Selection_H)
                  then
                     Add_Rect (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H, Selection_Color);
                     Add_Focus_Ring (Text_X - 2, Sel_Y (Start_Visible_Y), Text_W + 4, Selection_H);
                     Add_Rect
                       (Text_X - 2,
                        Sel_Y (Start_Visible_Y),
                        Natural'Min (3, Text_W + 4),
                        Selection_H,
                        Border_Color);
                  end if;
               end;
               for I in 1 .. Natural (Lines.Length) loop
                  declare
                     Line_Y : constant Natural :=
                       Saturating_Add (Y_Cursor, Saturating_Multiply (I - 1, Line_Height));
                  begin
                     if not Y_Hidden (Line_Y, Line_Height) then
                        Add_Text
                          (Text_X,
                           Text_Y_In_Row (Visible_Y (Line_Y)),
                           Text_W,
                           Line_Height,
                           Lines.Element (I),
                           Muted_Text_Color,
                           Fit    => False,
                           Italic => Italic);
                     end if;
                  end;
               end loop;
               Y_Cursor := Saturating_Add (Y_Cursor, Selection_H);
            end Add_Settings_Value;

            procedure Add_Settings_Control_Options (Y_Cursor : in out Natural) is
               Y      : Natural;
               --  Segmented-option grid: four cells for the cycling fields that
               --  render their options here (Sort / Theme / Icon theme). The
               --  group-by field (index 9) is rendered separately as its own
               --  full-width two-row control by Add_Settings_Group_By_Segments.
               Cell_Count : constant Natural := 4;
               Cell_W     : constant Natural :=
                 (if Text_W > 0 then Text_W / Cell_Count else 0);
               Hidden : Boolean;

               procedure Add_Cell
                 (Offset : Natural;
                  Key    : String;
                  Active : Boolean)
               is
                  Offset_X : constant Natural := Saturating_Multiply (Offset, Cell_W);
                  X        : constant Natural := Saturating_Add (Text_X, Offset_X);
                  W        : constant Natural :=
                    (if Offset = Cell_Count - 1 then Text_W - Offset_X else Cell_W);
               begin
                  if W = 0 or else Hidden then
                     return;
                  end if;

                  Result.Settings_Hits.Append
                    (Settings_Hit_Region'
                       (Kind   => Settings_Hit_Segment,
                        Field  => Snapshot.Settings_Field_Index,
                        Option => Offset + 1,
                        X      => X,
                        Y      => Y,
                        Width  => W,
                        Height => Line_Height));
                  Add_Rect (X, Sel_Y (Y), W, Line_Height, (if Active then Selection_Color else Input_Color));
                  Add_Border (X, Sel_Y (Y), W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (X, Files.UI.Input_Field_Padding),
                     Text_Y_In_Row (Y),
                     (if W > 2 * Files.UI.Input_Field_Padding
                      then W - 2 * Files.UI.Input_Field_Padding
                      else 0),
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Muted_Text_Color,
                     Fit => True);
               end Add_Cell;

               procedure Add_Toggle (Is_On : Boolean) is
                  Toggle_W : constant Natural :=
                    Saturating_Multiply (Line_Height, 2);
                  Knob_Pad : constant Natural := Natural'Max (1, Line_Height / 8);
                  Knob_Sz  : constant Natural :=
                    (if Line_Height > 2 * Knob_Pad
                     then Line_Height - 2 * Knob_Pad
                     else Line_Height);
                  Knob_X   : constant Natural :=
                    (if Is_On
                     then Saturating_Add (Text_X, Toggle_W - Knob_Pad - Knob_Sz)
                     else Saturating_Add (Text_X, Knob_Pad));
                  Knob_Y   : constant Natural := Saturating_Add (Sel_Y (Y), Knob_Pad);
               begin
                  if Hidden then
                     return;
                  end if;
                  Add_Rect
                    (Text_X, Sel_Y (Y), Toggle_W, Line_Height,
                     (if Is_On then Selection_Color else Input_Color));
                  Add_Border (Text_X, Sel_Y (Y), Toggle_W, Line_Height, Border_Color);
                  Add_Rect (Knob_X, Knob_Y, Knob_Sz, Knob_Sz, Text_Color);
                  Add_Text
                    (Saturating_Add (Text_X, Saturating_Add (Toggle_W, Files.UI.Input_Field_Padding)),
                     Text_Y_In_Row (Y),
                     (if Text_W > Saturating_Add (Toggle_W, Files.UI.Input_Field_Padding)
                      then Text_W - Toggle_W - Files.UI.Input_Field_Padding
                      else 0),
                     Line_Height,
                     To_Unbounded_String
                       (Files.Localization.Text
                          (if Is_On then "settings.value.true" else "settings.value.false")),
                     Muted_Text_Color,
                     Fit => True);
               end Add_Toggle;

               Current : constant String := To_String (Snapshot.Settings_Sort_Field_Token);
            begin
               Begin_Row (Y_Cursor);
               Y := Visible_Y (Y_Cursor);
               Hidden := Y_Hidden (Y_Cursor, Line_Height);
               case Snapshot.Settings_Field_Index is
                  when 1 | 2 | 4 =>
                     --  Inline toggle/segmented control already rendered in
                     --  the field row above.
                     null;
                  when 3 =>
                     Add_Cell (0, "settings.sort.name", Current = "name");
                     Add_Cell (1, "settings.sort.filetype", Current = "filetype");
                     Add_Cell (2, "settings.sort.size", Current = "size");
                     Add_Cell (3, "settings.sort.modified", Current = "modified");
                  when 5 =>
                     declare
                        Theme_Current : constant String := To_String (Snapshot.Settings_Theme_Token);
                     begin
                        Add_Cell (0, "settings.theme.dark", Theme_Current = "dark");
                        Add_Cell (1, "settings.theme.light", Theme_Current = "light");
                        Add_Cell (2, "settings.theme.high_contrast", Theme_Current = "high_contrast");
                     end;
                  when 6 =>
                     Add_Cell (0, "settings.icon_theme.basic", Snapshot.Settings_Icon_Theme = "files-basic");
                     Add_Cell
                       (1,
                        "settings.icon_theme.high_contrast",
                        Snapshot.Settings_Icon_Theme = "files-high-contrast");
                  when others =>
                     null;
               end case;
               Y_Cursor := Saturating_Add (Y_Cursor, Line_Height);
            end Add_Settings_Control_Options;

            --  The group-by field (index 9) is rendered as two rows: its label
            --  row above (drawn by Add_Settings_Value like every other field)
            --  and this dedicated segment row below. Splitting the five options
            --  (None / Type / Modified / Size / Label) onto their own row --
            --  rather than squeezing them beside the label -- gives each segment
            --  a full fifth of the content width, so long labels ("Modified")
            --  are no longer cramped. This runs unconditionally in
            --  Draw_Settings_Fields, so the measurement pass and the paint pass
            --  advance the shared Y cursor by the same extra row: scroll bounds
            --  grow to include it and the segment hit regions land on the same Y
            --  in both passes.
            procedure Add_Settings_Group_By_Segments (Y_Cursor : in out Natural) is
               Cell_Count    : constant Natural := 5;
               Cell_W        : constant Natural :=
                 (if Text_W > 0 then Text_W / Cell_Count else 0);
               Group_Current : constant String :=
                 To_String (Snapshot.Settings_Group_By_Token);
               Y      : Natural;
               Hidden : Boolean;

               procedure Add_Cell
                 (Offset : Natural;
                  Key    : String;
                  Active : Boolean)
               is
                  Offset_X : constant Natural := Saturating_Multiply (Offset, Cell_W);
                  X        : constant Natural := Saturating_Add (Text_X, Offset_X);
                  --  The final cell absorbs the integer-division remainder so the
                  --  five segments span exactly the full content width Text_W.
                  W        : constant Natural :=
                    (if Offset = Cell_Count - 1 then
                        (if Text_W > Offset_X then Text_W - Offset_X else 0)
                     else Cell_W);
               begin
                  if W = 0 or else Hidden then
                     return;
                  end if;

                  Result.Settings_Hits.Append
                    (Settings_Hit_Region'
                       (Kind   => Settings_Hit_Segment,
                        Field  => 9,
                        Option => Offset + 1,
                        X      => X,
                        Y      => Y,
                        Width  => W,
                        Height => Line_Height));
                  Add_Rect (X, Sel_Y (Y), W, Line_Height, (if Active then Selection_Color else Input_Color));
                  Add_Border (X, Sel_Y (Y), W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (X, Files.UI.Input_Field_Padding),
                     Text_Y_In_Row (Y),
                     (if W > 2 * Files.UI.Input_Field_Padding
                      then W - 2 * Files.UI.Input_Field_Padding
                      else 0),
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Muted_Text_Color,
                     Fit => True);
               end Add_Cell;
            begin
               Begin_Row (Y_Cursor);
               Y := Visible_Y (Y_Cursor);
               Hidden := Y_Hidden (Y_Cursor, Line_Height);
               Add_Cell (0, "settings.group.none", Group_Current = "none");
               Add_Cell (1, "settings.group.type", Group_Current = "type");
               Add_Cell (2, "settings.group.modified", Group_Current = "modified");
               Add_Cell (3, "settings.group.size", Group_Current = "size");
               Add_Cell (4, "settings.group.label", Group_Current = "label");
               Y_Cursor := Saturating_Add (Y_Cursor, Line_Height);
            end Add_Settings_Group_By_Segments;

            procedure Add_Settings_Entry_Buttons
              (Y_Cursor : in out Natural;
               Field    : Natural)
            is
               Buttons  : constant Files.UI.Settings_Entry_Button_Layout :=
                 Files.UI.Calculate_Settings_Entry_Button_Layout (Pane_X, Pane_W, Line_Height);
               Y        : Natural;
               Hidden   : Boolean;

               procedure Add_Button
                 (Button_X : Natural;
                  Button_W : Natural;
                  Key      : String;
                  Kind     : Settings_Hit_Kind;
                  Option   : Natural) is
               begin
                  if Button_W = 0 or else Hidden then
                     return;
                  end if;

                  Result.Settings_Hits.Append
                    (Settings_Hit_Region'
                       (Kind   => Kind,
                        Field  => Field,
                        Option => Option,
                        X      => Button_X,
                        Y      => Y,
                        Width  => Button_W,
                        Height => Line_Height));
                  Add_Rect (Button_X, Sel_Y (Y), Button_W, Line_Height, Input_Color);
                  Add_Border (Button_X, Sel_Y (Y), Button_W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (Button_X, Files.UI.Input_Field_Padding),
                     Text_Y_In_Row (Y),
                     (if Button_W > 2 * Files.UI.Input_Field_Padding
                      then Button_W - 2 * Files.UI.Input_Field_Padding
                      else 0),
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Muted_Text_Color,
                     Fit => True);
                  Add_Tooltip (Button_X, Y, Button_W, Line_Height, Key);
                  Add_Accessibility_Node
                    (Role_Button,
                     Button_X,
                     Y,
                     Button_W,
                     Line_Height,
                     Localized (Key));
               end Add_Button;
            begin
               Begin_Row (Y_Cursor);
               Y := Visible_Y (Y_Cursor);
               Hidden := Y_Hidden (Y_Cursor, Line_Height);
               Add_Button
                 (Buttons.Add_Button_X, Buttons.Add_Button_Width,
                  "settings.add", Settings_Hit_Add, 100);
               Add_Button
                 (Buttons.Remove_Button_X, Buttons.Remove_Button_Width,
                  "settings.remove", Settings_Hit_Remove, 101);
               Y_Cursor := Saturating_Add (Y_Cursor, Line_Height);
            end Add_Settings_Entry_Buttons;

            procedure Add_Settings_Action_Buttons (Y_Cursor : in out Natural) is
               Command : constant Files.Commands.Registered_Command_Id :=
                 Files.Commands.Reset_Settings_Command;
               Enabled : constant Boolean := Snapshot.Settings_Can_Reset;
               Y       : Natural;
            begin
               Begin_Row (Y_Cursor);
               if Text_W > 0 and then not Y_Hidden (Y_Cursor, Line_Height) then
                  Y := Visible_Y (Y_Cursor);
                  if Enabled then
                     Result.Settings_Hits.Append
                       (Settings_Hit_Region'
                          (Kind   => Settings_Hit_Reset,
                           Field  => 0,
                           Option => 0,
                           X      => Text_X,
                           Y      => Y,
                           Width  => Text_W,
                           Height => Line_Height));
                  end if;
                  Add_Rect (Text_X, Sel_Y (Y), Text_W, Line_Height,
                            (if Enabled then Input_Color else Pane_Color));
                  Add_Border (Text_X, Sel_Y (Y), Text_W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (Text_X, Files.UI.Input_Field_Padding),
                     Text_Y_In_Row (Y),
                     (if Text_W > 2 * Files.UI.Input_Field_Padding
                      then Text_W - 2 * Files.UI.Input_Field_Padding
                      else 0),
                     Line_Height,
                     Command_Label (Command),
                     (if Enabled then Muted_Text_Color else Disabled_Text_Color),
                     Fit => True);
                  Add_Command_Tooltip (Text_X, Y, Text_W, Line_Height, Command);
                  Add_Accessibility_Node
                    (Role_Button,
                     Text_X,
                     Y,
                     Text_W,
                     Line_Height,
                     Command_Label (Command),
                     Localized (Files.Commands.Description_Key (Command)),
                     Enabled => Enabled);
               end if;
               Y_Cursor := Saturating_Add (Y_Cursor, Line_Height);
            end Add_Settings_Action_Buttons;

            --  A non-interactive section header that visually groups the
            --  editable fields below it. Headers are NOT fields: they carry no
            --  Settings_Hit region, are skipped by keyboard/click navigation,
            --  and do not affect the field index bookkeeping. They only advance
            --  the shared Y cursor, so both the measurement pass and the paint
            --  pass shift the following field rows (and their hit regions) down
            --  by the same amount, keeping hit-testing and scroll bounds exact.
            procedure Add_Settings_Section_Header
              (Y_Cursor : in out Natural;
               Key      : String)
            is
               --  Extra breathing room above the header, layered on top of the
               --  standard inter-row gap applied by Begin_Row, so the section
               --  visually detaches from the preceding group.
               Top_Gap   : constant Natural := Inter_Row_Px;
               Divider_H : constant Natural := Natural'Max (1, Line_Height / 12);
            begin
               Begin_Row (Y_Cursor);
               Y_Cursor := Saturating_Add (Y_Cursor, Top_Gap);
               declare
                  Start_Visible_Y : constant Natural := Visible_Y (Y_Cursor);
               begin
                  if not Y_Hidden (Y_Cursor, Line_Height) then
                     Add_Text
                       (Text_X,
                        Text_Y_In_Row (Start_Visible_Y),
                        Text_W,
                        Line_Height,
                        To_Unbounded_String (Files.Localization.Text (Key)),
                        Text_Color,
                        Fit => True);
                     --  Thin accent divider directly under the heading text,
                     --  spanning the pane content width.
                     Add_Rect
                       (Text_X,
                        Saturating_Add (Sel_Y (Start_Visible_Y), Line_Height),
                        Text_W,
                        Divider_H,
                        Selection_Color);
                     Add_Accessibility_Node
                       (Role_Heading,
                        Text_X,
                        Start_Visible_Y,
                        Text_W,
                        Line_Height,
                        Localized (Key));
                  end if;
               end;
               Y_Cursor := Saturating_Add (Y_Cursor, Saturating_Add (Line_Height, Divider_H));
            end Add_Settings_Section_Header;

            --  Single source of truth for the settings field sequence, run by
            --  both the measurement pass (to size content for scroll clamping)
            --  and the real paint pass below.
            procedure Draw_Settings_Fields (Y_Cursor : in out Natural) is
            begin
               Add_Settings_Row_At (Y_Cursor, "settings.title", Text_Color);
               Add_Settings_Action_Buttons (Y_Cursor);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.view");
               Add_Settings_Default_View_Toggle (Y_Cursor, 1);
               Add_Settings_Toggle (Y_Cursor, "settings.hidden_files", Snapshot.Settings_Hidden_Files_Token, 2);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.sorting");
               Add_Settings_Value (Y_Cursor, "settings.sort", Snapshot.Settings_Sort, 3);
               Add_Settings_Toggle (Y_Cursor, "settings.sort_ascending", Snapshot.Settings_Sort_Ascending_Token, 4);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.appearance");
               Add_Settings_Value (Y_Cursor, "settings.theme", Snapshot.Settings_Theme, 5);
               Add_Settings_Value (Y_Cursor, "settings.icon_theme", Snapshot.Settings_Icon_Theme, 6);
               Add_Settings_Number_Stepper (Y_Cursor, "settings.font_pixel_size", Snapshot.Settings_Font_Pixel_Size, 7);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.behavior");
               Add_Settings_Toggle (Y_Cursor, "settings.system_opener", Snapshot.Settings_Opener_Token, 8);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.details");
               Add_Settings_Value (Y_Cursor, "settings.grouping", Snapshot.Settings_Group_By, 9);
               Add_Settings_Group_By_Segments (Y_Cursor);
               Add_Settings_Toggle (Y_Cursor, "settings.column.modified", Snapshot.Settings_Column_Modified_Token, 10);
               Add_Settings_Toggle (Y_Cursor, "settings.column.size", Snapshot.Settings_Column_Size_Token, 11);
               Add_Settings_Toggle (Y_Cursor, "settings.column.type", Snapshot.Settings_Column_Filetype_Token, 12);
               Add_Settings_Toggle (Y_Cursor, "settings.column.created", Snapshot.Settings_Column_Created_Token, 13);
               Add_Settings_Toggle
                 (Y_Cursor, "settings.column.permissions", Snapshot.Settings_Column_Permissions_Token, 14);
               Add_Settings_Section_Header (Y_Cursor, "settings.section.file_types");
               Add_Settings_Value (Y_Cursor, "settings.filetypes", Snapshot.Settings_Filetypes, 0);
               Add_Settings_Entry_Buttons (Y_Cursor, 15);
               Add_Settings_Value (Y_Cursor, "settings.filetype_extension", Snapshot.Settings_Filetype_Extension, 15);
               Add_Settings_Value (Y_Cursor, "settings.filetype_value", Snapshot.Settings_Filetype_Value, 16);
               Add_Settings_Value (Y_Cursor, "settings.icons", Snapshot.Settings_Icons, 0);
               Add_Settings_Entry_Buttons (Y_Cursor, 17);
               Add_Settings_Value (Y_Cursor, "settings.icon_filetype", Snapshot.Settings_Icon_Filetype, 17);
               Add_Settings_Value (Y_Cursor, "settings.icon_value", Snapshot.Settings_Icon_Value, 18);
               Add_Settings_Value (Y_Cursor, "settings.open_actions", Snapshot.Settings_Open_Actions, 0);
               Add_Settings_Entry_Buttons (Y_Cursor, 19);
               Add_Settings_Value (Y_Cursor, "settings.open_action_token", Snapshot.Settings_Open_Action_Token, 19);
               Add_Settings_Value (Y_Cursor, "settings.open_action_command", Snapshot.Settings_Open_Action_Command, 20);
               if Length (Snapshot.Settings_Field_Help) > 0 then
                  Add_Wrapped_Row
                    (Y_Cursor,
                     To_String (Snapshot.Settings_Field_Help),
                     Muted_Text_Color,
                     Italic => True);
               end if;
               if Length (Snapshot.Settings_Control_Options) > 0 then
                  Add_Wrapped_Row
                    (Y_Cursor,
                     To_String (Snapshot.Settings_Control_Options),
                     Muted_Text_Color,
                     Italic => True);
               end if;
               if Snapshot.Settings_Field_Index in 3 | 5 | 6 then
                  Add_Settings_Control_Options (Y_Cursor);
               end if;
               if not Snapshot.Settings_Draft_Valid and then Length (Snapshot.Settings_Draft_Error) > 0 then
                  Add_Wrapped_Row (Y_Cursor, To_String (Snapshot.Settings_Draft_Error), Error_Text_Color);
               end if;
            end Draw_Settings_Fields;
         begin
            Add_Drop_Shadow (Pane_X, Pane_Y, Pane_W, Pane_H);
            Add_Rect (Pane_X, Pane_Y, Pane_W, Pane_H, Pane_Color);
            Add_Border (Pane_X, Pane_Y, Pane_W, Pane_H, Border_Color);
            Add_Rect (Pane_X, Pane_Y, Pane_W, Natural'Min (3, Pane_H), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog,
               Pane_X,
               Pane_Y,
               Pane_W,
               Pane_H,
               Localized ("settings.title"));
            --  Measure the full content height (independent of the scroll
            --  offset), discard the commands the measurement emitted, then
            --  clamp the scroll so the pane cannot scroll past its content.
            declare
               R0  : constant Ada.Containers.Count_Type := Result.Rectangles.Length;
               T0  : constant Ada.Containers.Count_Type := Result.Text.Length;
               I0  : constant Ada.Containers.Count_Type := Result.Icons.Length;
               OR0 : constant Ada.Containers.Count_Type := Result.Overlay_Rectangles.Length;
               OT0 : constant Ada.Containers.Count_Type := Result.Overlay_Text.Length;
               TR0 : constant Ada.Containers.Count_Type := Result.Triangles.Length;
               TP0 : constant Ada.Containers.Count_Type := Result.Tooltips.Length;
               AC0 : constant Ada.Containers.Count_Type := Result.Accessibility.Length;
               SH0 : constant Ada.Containers.Count_Type := Result.Settings_Hits.Length;
               Measured : Natural := 0;
            begin
               Draw_Settings_Fields (Measured);
               Result.Rectangles.Set_Length (R0);
               Result.Text.Set_Length (T0);
               Result.Icons.Set_Length (I0);
               Result.Overlay_Rectangles.Set_Length (OR0);
               Result.Overlay_Text.Set_Length (OT0);
               Result.Triangles.Set_Length (TR0);
               Result.Tooltips.Set_Length (TP0);
               Result.Accessibility.Set_Length (AC0);
               Result.Settings_Hits.Set_Length (SH0);
               declare
                  Visible_H : constant Natural :=
                    (if Pane_Bottom > Text_Y then Pane_Bottom - Text_Y else 0);
                  Max_Scroll : constant Natural :=
                    (if Measured > Visible_H then Measured - Visible_H else 0);
               begin
                  Scroll_Px := Natural'Min (Scroll_Px, Max_Scroll);
               end;
            end;
            declare
               Y_Cursor : Natural := 0;
            begin
               Draw_Settings_Fields (Y_Cursor);
            end;
            Draw_Close_Button (Pane_X, Pane_Y, Pane_W, Pane_H, Overlay => False);
         end;
         Drawing_Settings_Pane := False;
      end if;

      if Snapshot.Command_Palette_Open then
         Drawing_Command_Palette := True;
         declare
            Search_Text_Y : constant Natural :=
              (if Palette.Search_Height > 2 * Files.UI.Input_Field_Padding
               then Saturating_Add (Palette.Search_Y, Files.UI.Input_Field_Padding)
               else Palette.Search_Y);
            Search_Text_H : constant Natural :=
              (if Palette.Search_Height > 2 * Files.UI.Input_Field_Padding
               then Natural'Min (Line_Height, Palette.Search_Height - 2 * Files.UI.Input_Field_Padding)
               else Palette.Search_Height);
         begin
            Add_Drop_Shadow (Palette.X, Palette.Y, Palette.Width, Palette.Height);
            Add_Rect (Palette.X, Palette.Y, Palette.Width, Palette.Height, Pane_Color);
            Add_Border (Palette.X, Palette.Y, Palette.Width, Palette.Height, Border_Color);
            Add_Rect (Palette.X, Palette.Y, Palette.Width, Natural'Min (3, Palette.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog,
               Palette.X,
               Palette.Y,
               Palette.Width,
               Palette.Height,
               Localized ("command.palette.open"));
            Add_Rect (Palette.Search_X, Palette.Search_Y, Palette.Search_Width, Palette.Search_Height, Input_Color);
            Add_Text
              (Saturating_Add (Palette.Search_X, Files.UI.Input_Field_Padding),
               Search_Text_Y,
               (if Palette.Search_Width > 2 * Files.UI.Input_Field_Padding
                then Palette.Search_Width - 2 * Files.UI.Input_Field_Padding
                else 0),
               Search_Text_H,
               Snapshot.Command_Palette_Query,
               Fit => True);
            if Snapshot.Focus = Files.Types.Focus_Command_Palette then
               Add_Border
                 (Palette.Search_X,
                  Palette.Search_Y,
                  Palette.Search_Width,
                  Palette.Search_Height,
                  Border_Color);
               Add_Focus_Ring
                 (Palette.Search_X,
                  Palette.Search_Y,
                  Palette.Search_Width,
                  Palette.Search_Height);
               Add_Caret
                 (Palette.Search_X,
                  Palette.Search_Y,
                  Palette.Search_Width,
                  Palette.Search_Height,
                  Snapshot.Command_Palette_Query,
                  Snapshot.Text_Cursor_Position);
            end if;
            Add_Accessibility_Node
              (Role_Text_Input,
               Palette.Search_X,
               Palette.Search_Y,
               Palette.Search_Width,
               Palette.Search_Height,
               Localized ("accessibility.command_palette_search"),
               Snapshot.Command_Palette_Query,
               Focused => Snapshot.Focus = Files.Types.Focus_Command_Palette);
         end;

         if Snapshot.Command_Palette_Results.Is_Empty and then Palette.Results_Height > 0 then
            Add_Rect
              (Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Pane_Color);
            Add_Border
              (Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Border_Color);
            Add_Text
              (Saturating_Add (Palette.Results_X, 8),
               Palette.Results_Y,
               (if Palette.Results_Width >
                   Saturating_Add (16, Saturating_Add (Scrollbar_Width, Command_Palette_Scrollbar_Gap))
                then Palette.Results_Width - 16 - Scrollbar_Width - Command_Palette_Scrollbar_Gap
                else 0),
               Natural'Min (Line_Height, Palette.Results_Height),
               Localized ("command.palette.empty"),
               Muted_Text_Color,
               Fit => True);
            Add_Accessibility_Node
              (Role_Status,
               Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Localized ("command.palette.empty"));
         end if;

         for Index in 1 .. Natural (Palette_Rows.Length) loop
            declare
               Row     : constant Command_Result_Layout := Palette_Rows.Element (Positive (Index));
               Command : constant Command_Result_Snapshot :=
                 Snapshot.Command_Palette_Results.Element (Positive (Row.Result_Index));
               Accessible_Description : constant UString :=
                 Command_Result_Accessible_Description (Command);
               Row_Text_X : constant Natural := Saturating_Add (Row.X, Command_Palette_Padding);
               Row_Text_Y : constant Natural := Saturating_Add (Row.Y, Command_Result_Row_Padding);
               Reserved_Scrollbar_W : constant Natural :=
                 (if Palette.Results_Width > 0
                  then Saturating_Add
                    (Natural'Min (Scrollbar_Width, Palette.Results_Width),
                     Command_Palette_Scrollbar_Gap)
                  else 0);
               Row_Text_End_X : constant Natural :=
                 (if Row.Width > Saturating_Add (Command_Palette_Padding, Reserved_Scrollbar_W)
                  then Saturating_Add (Row.X, Row.Width - Reserved_Scrollbar_W)
                  else Row_Text_X);
               Row_Text_W : constant Natural :=
                 (if Row_Text_End_X > Saturating_Add (Row_Text_X, Command_Palette_Padding)
                  then Row_Text_End_X - Row_Text_X - Command_Palette_Padding
                  else 0);
               Shortcut_Width : constant Natural :=
                 (if Length (Command.Shortcut_Text) = 0 then 0
                  else Natural'Min
                    (Natural'Min
                      (Saturating_Multiply
                          (Files.UTF8.Display_Units (To_String (Command.Shortcut_Text)),
                           Saturating_Multiply (Line_Height, 12) / 20),
                        160),
                     (if Row_Text_W > 0 then Natural'Min (Row_Text_W, Row_Text_W / 3) else 0)));
               Label_Width : constant Natural :=
                 (if Row_Text_W = 0 then 0
                  elsif Shortcut_Width = 0 then Row_Text_W
                  elsif Row_Text_W > Shortcut_Width + Command_Palette_Padding
                  then Row_Text_W - Shortcut_Width - Command_Palette_Padding
                  else 0);
               Hovered : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected and then Row.Enabled then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   elsif not Row.Enabled then Pane_Color
                   else Pane_Color));
               if Row.Selected then
                  Add_Rect
                    (Row.X,
                     Row.Y,
                     Natural'Min (3, Row.Width),
                     Row.Height,
                     Border_Color);
               end if;
               Add_Text
                 (Row_Text_X,
                  Row_Text_Y,
                  Label_Width,
                  Natural'Min (Line_Height, Row.Height),
                  Command.Label,
                  (if Row.Enabled then Text_Color else Disabled_Text_Color),
                  Fit => True);
               if Shortcut_Width > 0 then
                  Add_Text
                    (Saturating_Add (Row_Text_X, Row_Text_W - Shortcut_Width),
                     Row_Text_Y,
                     Shortcut_Width,
                     Natural'Min (Line_Height, Row.Height),
                     Command.Shortcut_Text,
                     (if Row.Enabled then Muted_Text_Color else Disabled_Text_Color),
                     Fit => True);
               end if;
               if Row.Height > Line_Height then
                  Add_Text
                    (Row_Text_X,
                     Saturating_Add (Row_Text_Y, Line_Height),
                     Row_Text_W,
                     Natural'Min
                       (Line_Height,
                        (if Row.Height > Saturating_Add (Command_Result_Row_Padding, Line_Height)
                         then Row.Height - Command_Result_Row_Padding - Line_Height
                         else 0)),
                     Command.Description,
                     (if Row.Enabled then Muted_Text_Color else Disabled_Text_Color),
                  Fit => True);
               end if;
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Command.Label,
                  Accessible_Description,
                  Enabled  => Row.Enabled,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;

         Add_Palette_Scrollbar;
         Draw_Close_Button (Palette.X, Palette.Y, Palette.Width, Palette.Height, Overlay => False);
         Drawing_Command_Palette := False;
      end if;

      if Snapshot.Quick_Look_Open then
         declare
            QL      : constant Quick_Look_Layout := Calculate_Quick_Look_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (QL.X, Margin);
            Title_Y : constant Natural := Saturating_Add (QL.Y, Natural'Max (4, Line_Height / 4));
            Title_W : constant Natural :=
              (if QL.Width > Saturating_Multiply (Margin, 2)
               then QL.Width - Saturating_Multiply (Margin, 2) else QL.Width);
         begin
            Add_Drop_Shadow (QL.X, QL.Y, QL.Width, QL.Height);
            Add_Rect (QL.X, QL.Y, QL.Width, QL.Height, Pane_Color);
            Add_Border (QL.X, QL.Y, QL.Width, QL.Height, Border_Color);
            Add_Rect (QL.X, QL.Y, QL.Width, Natural'Min (3, QL.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, QL.X, QL.Y, QL.Width, QL.Height, Localized ("accessibility.quick_look"));
            --  Panel title: the previewed item's name, which also serves as the
            --  content marker tests assert on for every kind.
            Add_Text (Title_X, Title_Y, Title_W, Line_Height, Snapshot.Quick_Look_Name, Fit => True);

            case Snapshot.Quick_Look_Kind is
               when Files.Quick_Look.Image_Content =>
                  if Natural (Snapshot.Quick_Look_Image_Pixels.Length) > 0
                    and then Snapshot.Quick_Look_Image_Width > 0
                    and then Snapshot.Quick_Look_Image_Height > 0
                  then
                     declare
                        Img_Size : constant Natural :=
                          Natural'Min (QL.Content_Width, QL.Content_Height);
                        Img_X    : constant Natural :=
                          Saturating_Add
                            (QL.Content_X,
                             (if QL.Content_Width > Img_Size then (QL.Content_Width - Img_Size) / 2 else 0));
                        Img_Y    : constant Natural :=
                          Saturating_Add
                            (QL.Content_Y,
                             (if QL.Content_Height > Img_Size then (QL.Content_Height - Img_Size) / 2 else 0));
                     begin
                        if Img_Size > 0 then
                           --  Reuse the icon/thumbnail draw path: a single icon
                           --  command carrying the decoded pixels scaled to fit.
                           Result.Icons.Append
                             (Icon_Command'
                                (X                => Img_X,
                                 Y                => Img_Y,
                                 Size             => Img_Size,
                                 Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                                 Theme_Name       => Snapshot.Theme_Name,
                                 Asset_Path       => Null_Unbounded_String,
                                 Thumbnail_Width  => Snapshot.Quick_Look_Image_Width,
                                 Thumbnail_Height => Snapshot.Quick_Look_Image_Height,
                                 Thumbnail_Pixels => Snapshot.Quick_Look_Image_Pixels));
                        end if;
                     end;
                  else
                     Add_Text
                       (QL.Content_X, QL.Content_Y, QL.Content_Width, Line_Height,
                        Localized ("quick_look.empty"), Muted_Text_Color);
                  end if;
               when Files.Quick_Look.Text_Content =>
                  declare
                     Max_Lines : constant Natural :=
                       (if QL.Content_Height >= Line_Height then QL.Content_Height / Line_Height else 0);
                     Row       : Natural := 0;
                  begin
                     for Line of Snapshot.Quick_Look_Text_Lines loop
                        exit when Row >= Max_Lines;
                        Add_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height, Line, Fit => True);
                        Row := Row + 1;
                     end loop;
                     if Snapshot.Quick_Look_Text_Truncated and then Row < Max_Lines then
                        Add_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height,
                           Localized ("quick_look.truncated"), Muted_Text_Color, Italic => True);
                     end if;
                  end;
               when Files.Quick_Look.Info_Content =>
                  declare
                     Icon_Size : constant Natural :=
                       Natural'Min (Saturating_Multiply (Line_Height, 3), QL.Content_Width);
                     Row_Y     : Natural :=
                       Saturating_Add (QL.Content_Y, Saturating_Add (Icon_Size, Margin));
                     Size_Value : constant UString :=
                       (if Snapshot.Quick_Look_Size_Available
                        then To_Unbounded_String (Size_Text (Snapshot.Quick_Look_Size))
                        else Localized ("status.missing_metadata"));
                  begin
                     if Icon_Size > 0 then
                        Result.Icons.Append
                          (Icon_Command'
                             (X                => QL.Content_X,
                              Y                => QL.Content_Y,
                              Size             => Icon_Size,
                              Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                              Theme_Name       => Snapshot.Theme_Name,
                              Asset_Path       => Null_Unbounded_String,
                              Thumbnail_Width  => 0,
                              Thumbnail_Height => 0,
                              Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
                     end if;
                     Add_Text
                       (QL.Content_X, Row_Y, QL.Content_Width, Line_Height,
                        Snapshot.Quick_Look_Type, Muted_Text_Color, Fit => True);
                     Row_Y := Saturating_Add (Row_Y, Line_Height);
                     Add_Text
                       (QL.Content_X, Row_Y, QL.Content_Width, Line_Height,
                        Size_Value, Muted_Text_Color, Fit => True);
                  end;
            end case;

            Draw_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, Overlay => False);
         end;
      end if;

      if Snapshot.Label_Picker_Open then
         declare
            Picker  : constant Label_Picker_Layout :=
              Calculate_Label_Picker_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (Picker.X, Margin);
            Title_Y : constant Natural := Saturating_Add (Picker.Y, Natural'Max (4, Line_Height / 4));
            Title_W : constant Natural :=
              (if Picker.Width > Saturating_Multiply (Margin, 2)
               then Picker.Width - Saturating_Multiply (Margin, 2) else Picker.Width);
         begin
            Add_Drop_Shadow (Picker.X, Picker.Y, Picker.Width, Picker.Height);
            Add_Rect (Picker.X, Picker.Y, Picker.Width, Picker.Height, Pane_Color);
            Add_Border (Picker.X, Picker.Y, Picker.Width, Picker.Height, Border_Color);
            Add_Rect (Picker.X, Picker.Y, Picker.Width, Natural'Min (3, Picker.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, Picker.X, Picker.Y, Picker.Width, Picker.Height,
               Localized ("accessibility.label_picker"));
            Add_Text (Title_X, Title_Y, Title_W, Line_Height, Localized ("label_picker.title"), Fit => True);

            for Index in Picker.Swatches'Range loop
               declare
                  Swatch  : constant Label_Swatch_Bounds := Picker.Swatches (Index);
                  Label   : constant Files.Types.Color_Label := Label_For_Swatch (Index);
                  Hovered : constant Boolean :=
                    Has_Hover
                    and then Contains_Point (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Hover_X, Hover_Y);
                  Name    : constant UString :=
                    Localized
                      ((case Label is
                          when Files.Types.No_Label => "label.color.none",
                          when Files.Types.Red      => "label.color.red",
                          when Files.Types.Orange   => "label.color.orange",
                          when Files.Types.Yellow   => "label.color.yellow",
                          when Files.Types.Green    => "label.color.green",
                          when Files.Types.Blue     => "label.color.blue",
                          when Files.Types.Purple   => "label.color.purple",
                          when Files.Types.Gray     => "label.color.gray"));
               begin
                  if Label = Files.Types.No_Label then
                     --  The clear swatch is an empty bordered box rather than a
                     --  filled color, so it reads as "remove any label".
                     Add_Rect (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Pane_Color);
                  else
                     Add_Rect (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Label_Render_Color (Label));
                  end if;
                  Add_Border
                    (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height,
                     (if Hovered then Selection_Color else Border_Color));
                  Add_Accessibility_Node
                    (Role_Button, Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Name);
               end;
            end loop;

            Draw_Close_Button (Picker.X, Picker.Y, Picker.Width, Picker.Height, Overlay => False);
         end;
      end if;

      if Snapshot.Sort_Menu_Open and then Bottom.Sort_Button_Width > 0 then
         declare
            Row_Count : constant Natural := 5;
            Row_H     : constant Natural :=
              Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Bottom_Bar_Padding, 2));
            Rows_H    : constant Natural := Saturating_Multiply (Row_H, Row_Count);
            Menu_H    : constant Natural :=
              Saturating_Add (Rows_H, Saturating_Multiply (Files.UI.Sort_Menu_Padding, 2));
            Menu_X    : constant Natural := Bottom.Sort_Button_X;
            Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
            Menu_W    : constant Natural := Bottom.Sort_Button_Width;
            Rows_Y    : constant Natural := Saturating_Add (Menu_Y, Files.UI.Sort_Menu_Padding);
            Row_X     : constant Natural := Saturating_Add (Menu_X, 1);
            Row_W     : constant Natural := (if Menu_W > 2 then Menu_W - 2 else 0);
            Text_X    : constant Natural :=
              Saturating_Add (Row_X, Files.UI.Input_Field_Padding);
            Text_W    : constant Natural :=
              (if Row_W > Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
               then Row_W - Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
               else 0);

            type Sort_Field_Array is array (Positive range <>) of Files.Model.Sort_Field;
            Fields : constant Sort_Field_Array :=
              [Files.Model.Sort_Name,
               Files.Model.Sort_Size,
               Files.Model.Sort_Type,
               Files.Model.Sort_Created,
               Files.Model.Sort_Changed];
         begin
            Add_Overlay_Rect (Menu_X, Menu_Y, Menu_W, Menu_H, Overlay_Color);
            Add_Overlay_Rect (Menu_X, Menu_Y, Menu_W, 1, Border_Color);
            Add_Overlay_Rect (Menu_X, Menu_Y, 1, Menu_H, Border_Color);
            if Menu_H > 0 then
               Add_Overlay_Rect (Menu_X, Saturating_Add (Menu_Y, Menu_H - 1), Menu_W, 1, Border_Color);
            end if;
            if Menu_W > 0 then
               Add_Overlay_Rect (Saturating_Add (Menu_X, Menu_W - 1), Menu_Y, 1, Menu_H, Border_Color);
            end if;
            Add_Accessibility_Node
              (Role_List,
               Menu_X,
               Menu_Y,
               Menu_W,
               Menu_H,
               Localized ("command.sort.menu"));

            for Row in Fields'Range loop
               declare
                  Field     : constant Files.Model.Sort_Field := Fields (Row);
                  Row_Y     : constant Natural :=
                    Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                  Selected  : constant Boolean := Field = Snapshot.Sort_Field;
                  Hovered   : constant Boolean :=
                    Has_Hover and then Contains_Point (Menu_X, Row_Y, Menu_W, Row_H, Hover_X, Hover_Y);
                  Pressed   : constant Boolean := Is_Pressed (Menu_X, Row_Y, Menu_W, Row_H);
                  Label     : constant UString :=
                    To_Unbounded_String
                      (Sort_Field_Label (Field)
                       & (if Selected then " " & Direction_Text else ""));
               begin
                  Add_Overlay_Rect
                    (Row_X,
                     Row_Y,
                     Row_W,
                     Row_H,
                     (if Selected then Selection_Color
                      elsif Pressed then Pressed_Color
                      elsif Hovered then Hover_Color
                      else Overlay_Color));
                  if Row > Fields'First then
                     Add_Overlay_Rect (Row_X, Row_Y, Row_W, 1, Border_Color);
                  end if;
                  Add_Overlay_Text
                    (Text_X,
                     Saturating_Add (Row_Y, Files.UI.Bottom_Bar_Padding),
                     Text_W,
                     Line_Height,
                     Label,
                     (if Snapshot.Command_Enabled (Sort_Field_Command (Field))
                      then Text_Color
                      else Disabled_Text_Color),
                     Fit => False);
                  Add_Accessibility_Node
                    (Role_List_Item,
                     Menu_X,
                     Row_Y,
                     Menu_W,
                     Row_H,
                     Label,
                     Localized (Files.Commands.Description_Key (Sort_Field_Command (Field))),
                     Enabled  => Snapshot.Command_Enabled (Sort_Field_Command (Field)),
                     Selected => Selected);
               end;
            end loop;
         end;
      end if;

      if Snapshot.Root_Selector_Open then
         if Root_Selector.Width > 0 and then Root_Selector.Height > 0 then
            Add_Overlay_Rect
              (Saturating_Add (Root_Selector.X, 3),
               Saturating_Add (Root_Selector.Y, Root_Selector.Height),
               Root_Selector.Width,
               3,
               Pane_Color);
            Add_Overlay_Rect
              (Saturating_Add (Root_Selector.X, Root_Selector.Width),
               Saturating_Add (Root_Selector.Y, 3),
               3,
               Root_Selector.Height,
               Pane_Color);
            Add_Overlay_Rect
              (Root_Selector.X,
               Root_Selector.Y,
               Root_Selector.Width,
               Root_Selector.Height,
               Overlay_Color);
            Add_Overlay_Rect (Root_Selector.X, Root_Selector.Y, Root_Selector.Width, 1, Border_Color);
            Add_Overlay_Rect (Root_Selector.X, Root_Selector.Y, 1, Root_Selector.Height, Border_Color);
            Add_Overlay_Rect
              (Root_Selector.X,
               Saturating_Add (Root_Selector.Y, Root_Selector.Height - 1),
               Root_Selector.Width,
               1,
               Border_Color);
            Add_Overlay_Rect
              (Saturating_Add (Root_Selector.X, Root_Selector.Width - 1),
               Root_Selector.Y,
               1,
               Root_Selector.Height,
               Border_Color);
         end if;
         Add_Accessibility_Node
           (Role_List,
            Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Localized ("accessibility.root_selector"));

         for Index in 1 .. Natural (Root_Rows.Length) loop
            declare
               Row       : constant Root_Path_Layout := Root_Rows.Element (Positive (Index));
               Toolbar_Icon_Size : constant Natural :=
                 Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2));
               Row_Pad    : constant Natural := Natural'Min (Root_Selector_Padding, Row.Height);
               Inner_H    : constant Natural :=
                 (if Row.Height > Saturating_Multiply (Row_Pad, 2)
                  then Row.Height - Saturating_Multiply (Row_Pad, 2)
                  else Row.Height);
               Glyph_Size : constant Natural := Natural'Min (Toolbar_Icon_Size, Inner_H);
               Glyph_X    : constant Natural := Saturating_Add (Row.X, Row_Pad);
               Glyph_Y    : constant Natural :=
                  (if Row.Height > Glyph_Size
                  then Saturating_Add (Row.Y, (Row.Height - Glyph_Size) / 2)
                  else Row.Y);
               Text_X     : constant Natural :=
                 Saturating_Add (Glyph_X, Saturating_Add (Glyph_Size, Root_Selector_Padding));
               Text_H     : constant Natural :=
                 Natural'Min (Line_Height, Inner_H);
               Text_Y     : constant Natural :=
                 (if Row.Height > Text_H
                  then Saturating_Add (Row.Y, (Row.Height - Text_H) / 2)
                  else Row.Y);
               Text_W     : constant Natural :=
                 (if Row.Width > Saturating_Add (Glyph_Size, Saturating_Multiply (Root_Selector_Padding, 3))
                  then Row.Width - Saturating_Add (Glyph_Size, Saturating_Multiply (Root_Selector_Padding, 3))
                  else 0);
               Hovered    : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed    : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Overlay_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   else Overlay_Color));
               if Index > 1 then
                  Add_Overlay_Rect (Row.X, Row.Y, Row.Width, 1, Border_Color);
               end if;
               if Row.Selected then
                  Add_Overlay_Rect
                    (Row.X,
                     Row.Y,
                     Natural'Min (3, Row.Width),
                     Row.Height,
                     Border_Color);
               end if;
               if Glyph_Size > 0 then
                  Add_Overlay_Rect
                    (Glyph_X,
                     Saturating_Add (Glyph_Y, Glyph_Size / 4),
                     Glyph_Size,
                     Natural'Max (1, Glyph_Size / 2),
                     Icon_Directory_Color);
                  Add_Overlay_Rect
                    (Saturating_Add (Glyph_X, Glyph_Size / 4),
                     Glyph_Y,
                     Natural'Max (1, Glyph_Size / 2),
                     Natural'Max (1, Glyph_Size / 4),
                     Icon_Directory_Color);
               end if;
               Add_Overlay_Text
                 (Text_X,
                  Text_Y,
                  Text_W,
                  Text_H,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Fit => True);
               Add_Command_Tooltip
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Files.Commands.Open_Selected_Root_Command);
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Snapshot.Root_Paths.Element (Positive (Row.Root_Index)),
                  Enabled  => True,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;
         Draw_Close_Button
           (Root_Selector.X, Root_Selector.Y, Root_Selector.Width, Root_Selector.Height,
            Overlay => True);
      end if;

      if Snapshot.Tree_Panel_Open then
         if Tree_Panel.Width > 0 and then Tree_Panel.Height > 0 then
            Add_Overlay_Rect
              (Saturating_Add (Tree_Panel.X, Tree_Panel.Width),
               Saturating_Add (Tree_Panel.Y, 3),
               3,
               Tree_Panel.Height,
               Pane_Color);
            Add_Overlay_Rect
              (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Height, Overlay_Color);
            Add_Overlay_Rect (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, 1, Border_Color);
            Add_Overlay_Rect (Tree_Panel.X, Tree_Panel.Y, 1, Tree_Panel.Height, Border_Color);
            Add_Overlay_Rect
              (Tree_Panel.X,
               Saturating_Add (Tree_Panel.Y, Tree_Panel.Height - 1),
               Tree_Panel.Width,
               1,
               Border_Color);
            Add_Overlay_Rect
              (Saturating_Add (Tree_Panel.X, Tree_Panel.Width - 1),
               Tree_Panel.Y,
               1,
               Tree_Panel.Height,
               Border_Color);
            --  Title band.
            Add_Overlay_Rect
              (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Row_Height, Pane_Color);
            Add_Overlay_Rect
              (Tree_Panel.X,
               Saturating_Add (Tree_Panel.Y, Tree_Panel.Row_Height),
               Tree_Panel.Width,
               1,
               Border_Color);
            Add_Overlay_Text
              (Saturating_Add (Tree_Panel.X, Root_Selector_Padding),
               Saturating_Add
                 (Tree_Panel.Y,
                  (if Tree_Panel.Row_Height > Line_Height
                   then (Tree_Panel.Row_Height - Line_Height) / 2
                   else 0)),
               (if Tree_Panel.Width > Saturating_Multiply (Root_Selector_Padding, 2)
                then Tree_Panel.Width - Saturating_Multiply (Root_Selector_Padding, 2)
                else 0),
               Line_Height,
               (if Snapshot.Tree_Pick_Active
                then (if Snapshot.Tree_Pick_Moving
                      then Localized ("tree.pick.move")
                      else Localized ("tree.pick.copy"))
                else Localized ("tree.panel.title")),
               Fit => True);
         end if;

         Add_Accessibility_Node
           (Role_List,
            Tree_Panel.X,
            Tree_Panel.Y,
            Tree_Panel.Width,
            Tree_Panel.Height,
            Localized ("accessibility.tree_panel"));

         for I in 1 .. Natural (Tree_Rows_Layout.Length) loop
            declare
               Row      : constant Tree_Row_Layout := Tree_Rows_Layout.Element (Positive (I));
               Data     : constant Files.Folder_Tree.Visible_Row :=
                 Snapshot.Tree_Rows.Element (Positive (I));
               Label_X  : constant Natural :=
                 Saturating_Add (Row.Triangle_X, Line_Height);
               Label_W  : constant Natural :=
                 (if Saturating_Add (Row.X, Row.Width)
                     > Saturating_Add (Label_X, Root_Selector_Padding)
                  then Saturating_Add (Row.X, Row.Width)
                       - Saturating_Add (Label_X, Root_Selector_Padding)
                  else 0);
               Text_Y   : constant Natural :=
                 (if Row.Height > Line_Height
                  then Saturating_Add (Row.Y, (Row.Height - Line_Height) / 2)
                  else Row.Y);
               Hovered  : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed  : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Overlay_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   else Overlay_Color));
               if Row.Has_Children and then Row.Triangle_W > 0 then
                  Add_Overlay_Text
                    (Row.Triangle_X,
                     Text_Y,
                     Row.Triangle_W,
                     Line_Height,
                     To_Unbounded_String
                       (if Row.Expanded
                        then Tree_Expander_Expanded_Text
                        else Tree_Expander_Collapsed_Text),
                     Color => Muted_Text_Color);
               end if;
               Add_Overlay_Text
                 (Label_X,
                  Text_Y,
                  Label_W,
                  Line_Height,
                  Data.Name,
                  Color => Text_Color,
                  Fit   => True);
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Data.Name,
                  Data.Path,
                  Enabled  => True,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;

         --  Destination picker button bar (Choose / Cancel).
         if Snapshot.Tree_Pick_Active then
            declare
               Buttons : constant Tree_Pick_Button_Layout :=
                 Tree_Pick_Buttons (Tree_Panel, Line_Height);

               procedure Draw_Pick_Button (Button_X : Natural; Label_Key : String) is
                  Hovered : constant Boolean :=
                    Has_Hover
                    and then Contains_Point
                               (Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height,
                                Hover_X, Hover_Y);
                  Pressed : constant Boolean :=
                    Is_Pressed (Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height);
                  Inset   : constant Natural :=
                    (if Buttons.Height > Line_Height then (Buttons.Height - Line_Height) / 2 else 0);
               begin
                  Add_Overlay_Rect
                    (Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height,
                     (if Pressed then Pressed_Color elsif Hovered then Hover_Color else Pane_Color));
                  Add_Overlay_Rect (Button_X, Buttons.Y, Buttons.Button_Width, 1, Border_Color);
                  Add_Overlay_Rect (Button_X, Buttons.Y, 1, Buttons.Height, Border_Color);
                  if Buttons.Button_Width > 0 then
                     Add_Overlay_Rect
                       (Saturating_Add (Button_X, Buttons.Button_Width - 1), Buttons.Y, 1,
                        Buttons.Height, Border_Color);
                  end if;
                  Add_Overlay_Text
                    (Saturating_Add (Button_X, Files.UI.Input_Field_Padding),
                     Saturating_Add (Buttons.Y, Inset),
                     (if Buttons.Button_Width > Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                      then Buttons.Button_Width - Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                      else Buttons.Button_Width),
                     Line_Height, Localized (Label_Key), Text_Color, Fit => True);
                  Add_Accessibility_Node
                    (Role_Button, Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height,
                     Localized (Label_Key));
               end Draw_Pick_Button;
            begin
               if Buttons.Visible then
                  Draw_Pick_Button (Buttons.Choose_X, "tree.pick.choose");
                  Draw_Pick_Button (Buttons.Cancel_X, "tree.pick.cancel");
               end if;
            end;
         end if;

         Draw_Close_Button
           (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Height, Overlay => True);
      end if;

      if Snapshot.Context_Menu_Open then
         declare
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
         begin
            if Menu.Visible then
               Add_Overlay_Rect (Menu.X, Menu.Y, Menu.Width, Menu.Height, Pane_Color);
               Add_Overlay_Rect (Menu.X, Menu.Y, Menu.Width, 1, Border_Color);
               if Menu.Height > 0 then
                  Add_Overlay_Rect
                    (Menu.X, Menu.Y + Menu.Height - 1, Menu.Width, 1, Border_Color);
               end if;
               Add_Overlay_Rect (Menu.X, Menu.Y, 1, Menu.Height, Border_Color);
               if Menu.Width > 0 then
                  Add_Overlay_Rect
                    (Menu.X + Menu.Width - 1, Menu.Y, 1, Menu.Height, Border_Color);
               end if;

               Add_Accessibility_Node
                 (Role_List,
                  Menu.X, Menu.Y, Menu.Width, Menu.Height,
                  Localized ("command.palette.open"));

               declare
                  Row_Y : Natural := Menu.Y + Menu.Padding;
               begin
                  for Row in 1 .. Menu.Row_Count loop
                     if Menu.Row_Kinds (Row) = Separator_Row then
                        --  Draw a thin divider centered in the separator row so
                        --  the command groups above and below read as distinct.
                        declare
                           Line_Inset : constant Natural := Menu.Padding;
                           Line_Width : constant Natural :=
                             (if Menu.Width > 2 * Line_Inset
                              then Menu.Width - 2 * Line_Inset
                              else Menu.Width);
                           Line_Y     : constant Natural :=
                             Row_Y + Menu.Separator_Height / 2;
                        begin
                           Add_Overlay_Rect
                             (Menu.X + Line_Inset, Line_Y, Line_Width, 1,
                              Border_Color);
                        end;
                        Row_Y := Row_Y + Menu.Separator_Height;
                     else
                        declare
                           Command : constant Files.Commands.Command_Id :=
                             Menu.Commands (Row);
                           Enabled : constant Boolean :=
                             Command /= Files.Commands.No_Command
                             and then Snapshot.Command_Enabled (Command);
                           Hovered : constant Boolean :=
                             Has_Hover
                             and then Contains_Point
                               (Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                                Hover_X, Hover_Y);
                           Pressed : constant Boolean :=
                             Is_Pressed
                               (Menu.X, Row_Y, Menu.Width, Menu.Row_Height);
                           Text_X  : constant Natural :=
                             Menu.X + Files.UI.Input_Field_Padding;
                           Text_Y_Off : constant Natural :=
                             (if Menu.Row_Height > Line_Height
                              then (Menu.Row_Height - Line_Height) / 2
                              else 0);
                        begin
                           if Pressed then
                              Add_Overlay_Rect
                                (Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                                 Pressed_Color);
                           elsif Hovered and then Enabled then
                              Add_Overlay_Rect
                                (Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                                 Hover_Color);
                           end if;
                           Add_Overlay_Text
                             (Text_X,
                              Row_Y + Text_Y_Off,
                              (if Menu.Width > 2 * Files.UI.Input_Field_Padding
                               then Menu.Width - 2 * Files.UI.Input_Field_Padding
                               else 0),
                              Line_Height,
                              Command_Label (Command),
                              (if Enabled then Text_Color else Disabled_Text_Color),
                              Fit => True);
                           Add_Accessibility_Node
                             (Role_Button,
                              Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                              Command_Label (Command),
                              Localized (Files.Commands.Description_Key (Command)),
                              Enabled => Enabled);
                        end;
                        Row_Y := Row_Y + Menu.Row_Height;
                     end if;
                  end loop;
               end;
            end if;
         end;
      end if;

      if Snapshot.Paste_Conflict_Open then
         declare
            Dialog : constant Conflict_Dialog_Layout :=
              Calculate_Conflict_Dialog_Layout (Snapshot, Layout, Line_Height);
            Pad    : constant Natural := 12;
            Text_W : constant Natural :=
              (if Dialog.Width > Saturating_Multiply (Pad, 2) then Dialog.Width - Saturating_Multiply (Pad, 2)
               else Dialog.Width);

            procedure Draw_Button (Kind : Conflict_Hit_Kind; Button_X : Natural; Label_Key : String) is
               Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point
                            (Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
                             Hover_X, Hover_Y);
               Pressed : constant Boolean :=
                 Is_Pressed (Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height);
               Inset   : constant Natural :=
                 (if Dialog.Button_Height > Line_Height then (Dialog.Button_Height - Line_Height) / 2 else 0);
            begin
               Add_Overlay_Rect
                 (Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
                  (if Pressed then Pressed_Color elsif Hovered then Hover_Color else Overlay_Color));
               Add_Overlay_Rect (Button_X, Dialog.Button_Y, Dialog.Button_Width, 1, Border_Color);
               Add_Overlay_Rect (Button_X, Dialog.Button_Y, 1, Dialog.Button_Height, Border_Color);
               if Dialog.Button_Height > 0 then
                  Add_Overlay_Rect
                    (Button_X, Saturating_Add (Dialog.Button_Y, Dialog.Button_Height - 1),
                     Dialog.Button_Width, 1, Border_Color);
               end if;
               if Dialog.Button_Width > 0 then
                  Add_Overlay_Rect
                    (Saturating_Add (Button_X, Dialog.Button_Width - 1), Dialog.Button_Y, 1,
                     Dialog.Button_Height, Border_Color);
               end if;
               Add_Overlay_Text
                 (Saturating_Add (Button_X, Files.UI.Input_Field_Padding),
                  Saturating_Add (Dialog.Button_Y, Inset),
                  (if Dialog.Button_Width > Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                   then Dialog.Button_Width - Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                   else Dialog.Button_Width),
                  Line_Height, Localized (Label_Key), Text_Color, Fit => True);
               Add_Accessibility_Node
                 (Role_Button, Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
                  Localized (Label_Key));
               Result.Conflict_Hits.Append
                 (Conflict_Hit_Region'
                    (Kind   => Kind,
                     X      => Button_X,
                     Y      => Dialog.Button_Y,
                     Width  => Dialog.Button_Width,
                     Height => Dialog.Button_Height));
            end Draw_Button;
         begin
            --  Modal backdrop and panel body.
            Add_Overlay_Rect (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Overlay_Color);
            Add_Overlay_Rect (Dialog.X, Dialog.Y, Dialog.Width, 1, Border_Color);
            Add_Overlay_Rect (Dialog.X, Dialog.Y, 1, Dialog.Height, Border_Color);
            if Dialog.Height > 0 then
               Add_Overlay_Rect
                 (Dialog.X, Saturating_Add (Dialog.Y, Dialog.Height - 1), Dialog.Width, 1, Border_Color);
            end if;
            if Dialog.Width > 0 then
               Add_Overlay_Rect
                 (Saturating_Add (Dialog.X, Dialog.Width - 1), Dialog.Y, 1, Dialog.Height, Border_Color);
            end if;
            Add_Accessibility_Node
              (Role_Dialog, Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height,
               Localized ("dialog.paste_conflict.title"));

            --  Conflicting name and the "already exists" line.
            Add_Overlay_Text
              (Saturating_Add (Dialog.X, Pad), Saturating_Add (Dialog.Y, Pad), Text_W, Line_Height,
               Snapshot.Paste_Conflict_Name, Text_Color, Fit => True);
            Add_Overlay_Text
              (Saturating_Add (Dialog.X, Pad), Saturating_Add (Dialog.Y, Saturating_Add (Pad, Line_Height)),
               Text_W, Line_Height, Localized ("dialog.paste_conflict.exists"), Text_Color, Fit => True);

            --  "Apply to all remaining" toggle row.
            declare
               Box_Size : constant Natural := Natural'Min (Line_Height, Dialog.Apply_Height);
               Hovered  : constant Boolean :=
                 Has_Hover
                 and then Contains_Point
                            (Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height,
                             Hover_X, Hover_Y);
            begin
               if Hovered then
                  Add_Overlay_Rect
                    (Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height, Hover_Color);
               end if;
               Add_Overlay_Rect (Dialog.Apply_X, Dialog.Apply_Y, Box_Size, Box_Size, Border_Color);
               Add_Overlay_Rect
                 (Saturating_Add (Dialog.Apply_X, 1), Saturating_Add (Dialog.Apply_Y, 1),
                  (if Box_Size > 2 then Box_Size - 2 else 0), (if Box_Size > 2 then Box_Size - 2 else 0),
                  (if Snapshot.Paste_Conflict_Apply_All then Selection_Color else Overlay_Color));
               Add_Overlay_Text
                 (Saturating_Add (Dialog.Apply_X, Saturating_Add (Box_Size, Files.UI.Input_Field_Padding)),
                  Dialog.Apply_Y,
                  (if Dialog.Apply_Width > Saturating_Add (Box_Size, Files.UI.Input_Field_Padding)
                   then Dialog.Apply_Width - Saturating_Add (Box_Size, Files.UI.Input_Field_Padding)
                   else Dialog.Apply_Width),
                  Line_Height, Localized ("dialog.paste_conflict.apply_to_all"), Text_Color, Fit => True);
               Add_Accessibility_Node
                 (Role_Button, Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height,
                  Localized ("dialog.paste_conflict.apply_to_all"),
                  Selected => Snapshot.Paste_Conflict_Apply_All);
               Result.Conflict_Hits.Append
                 (Conflict_Hit_Region'
                    (Kind   => Conflict_Hit_Apply_All,
                     X      => Dialog.Apply_X,
                     Y      => Dialog.Apply_Y,
                     Width  => Dialog.Apply_Width,
                     Height => Dialog.Apply_Height));
            end;

            Draw_Button (Conflict_Hit_Replace, Dialog.Replace_X, "dialog.paste_conflict.button.replace");
            Draw_Button (Conflict_Hit_Skip, Dialog.Skip_X, "dialog.paste_conflict.button.skip");
            Draw_Button (Conflict_Hit_Rename, Dialog.Rename_X, "dialog.paste_conflict.button.rename");
            Draw_Button (Conflict_Hit_Cancel, Dialog.Cancel_X, "dialog.paste_conflict.button.cancel");

            --  Close button in the panel corner cancels the whole paste.
            Draw_Close_Button (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Overlay => True);
         end;
      end if;

      if Snapshot.Paste_Progress_Open then
         declare
            Panel  : constant Paste_Progress_Layout :=
              Calculate_Paste_Progress_Layout (Snapshot, Layout, Line_Height);
            Pad    : constant Natural := 12;
            Text_W : constant Natural :=
              (if Panel.Width > Saturating_Multiply (Pad, 2) then Panel.Width - Saturating_Multiply (Pad, 2)
               else Panel.Width);
            Verb_Key : constant String :=
              (if Snapshot.Paste_Progress_Moving
               then "dialog.paste_progress.moving"
               else "dialog.paste_progress.copying");
            Count_Line : constant UString :=
              Localized (Verb_Key)
              & To_Unbounded_String (" ")
              & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Done)))
              & To_Unbounded_String (" ")
              & Localized ("dialog.paste_progress.of")
              & To_Unbounded_String (" ")
              & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Total)));
            Filled : constant Natural :=
              (if Snapshot.Paste_Progress_Total = 0 then Panel.Bar_Width
               else (Panel.Bar_Width * Snapshot.Paste_Progress_Done) / Snapshot.Paste_Progress_Total);
            Cancel_Hovered : constant Boolean :=
              Has_Hover
              and then Contains_Point
                         (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
                          Hover_X, Hover_Y);
            Cancel_Pressed : constant Boolean :=
              Is_Pressed (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height);
            Cancel_Inset : constant Natural :=
              (if Panel.Cancel_Height > Line_Height then (Panel.Cancel_Height - Line_Height) / 2 else 0);
         begin
            --  Modal-lite panel body and border.
            Add_Overlay_Rect (Panel.X, Panel.Y, Panel.Width, Panel.Height, Overlay_Color);
            Add_Overlay_Rect (Panel.X, Panel.Y, Panel.Width, 1, Border_Color);
            Add_Overlay_Rect (Panel.X, Panel.Y, 1, Panel.Height, Border_Color);
            if Panel.Height > 0 then
               Add_Overlay_Rect
                 (Panel.X, Saturating_Add (Panel.Y, Panel.Height - 1), Panel.Width, 1, Border_Color);
            end if;
            if Panel.Width > 0 then
               Add_Overlay_Rect
                 (Saturating_Add (Panel.X, Panel.Width - 1), Panel.Y, 1, Panel.Height, Border_Color);
            end if;
            Add_Accessibility_Node
              (Role_Dialog, Panel.X, Panel.Y, Panel.Width, Panel.Height,
               Localized ("dialog.paste_progress.title"));

            --  "Copying/Moving N of M" plus the current item name.
            Add_Overlay_Text
              (Saturating_Add (Panel.X, Pad), Saturating_Add (Panel.Y, Pad), Text_W, Line_Height,
               Count_Line, Text_Color, Fit => True);
            Add_Overlay_Text
              (Saturating_Add (Panel.X, Pad),
               Saturating_Add (Panel.Y, Saturating_Add (Pad, Line_Height)),
               Text_W, Line_Height, Snapshot.Paste_Progress_Name, Muted_Text_Color, Fit => True);

            --  Progress bar: track, filled portion proportional to Done/Total, border.
            Add_Overlay_Rect (Panel.Bar_X, Panel.Bar_Y, Panel.Bar_Width, Panel.Bar_Height, Hover_Color);
            if Filled > 0 then
               Add_Overlay_Rect (Panel.Bar_X, Panel.Bar_Y, Filled, Panel.Bar_Height, Selection_Color);
            end if;
            Add_Overlay_Rect (Panel.Bar_X, Panel.Bar_Y, Panel.Bar_Width, 1, Border_Color);

            --  Cancel button.
            Add_Overlay_Rect
              (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
               (if Cancel_Pressed then Pressed_Color
                elsif Cancel_Hovered then Hover_Color else Overlay_Color));
            Add_Overlay_Rect (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, 1, Border_Color);
            Add_Overlay_Rect (Panel.Cancel_X, Panel.Cancel_Y, 1, Panel.Cancel_Height, Border_Color);
            if Panel.Cancel_Height > 0 then
               Add_Overlay_Rect
                 (Panel.Cancel_X, Saturating_Add (Panel.Cancel_Y, Panel.Cancel_Height - 1),
                  Panel.Cancel_Width, 1, Border_Color);
            end if;
            if Panel.Cancel_Width > 0 then
               Add_Overlay_Rect
                 (Saturating_Add (Panel.Cancel_X, Panel.Cancel_Width - 1), Panel.Cancel_Y, 1,
                  Panel.Cancel_Height, Border_Color);
            end if;
            Add_Overlay_Text
              (Saturating_Add (Panel.Cancel_X, Files.UI.Input_Field_Padding),
               Saturating_Add (Panel.Cancel_Y, Cancel_Inset),
               (if Panel.Cancel_Width > Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                then Panel.Cancel_Width - Saturating_Multiply (Files.UI.Input_Field_Padding, 2)
                else Panel.Cancel_Width),
               Line_Height, Localized ("dialog.paste_progress.button.cancel"), Text_Color, Fit => True);
            Add_Accessibility_Node
              (Role_Button, Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
               Localized ("dialog.paste_progress.button.cancel"));
            Result.Conflict_Hits.Append
              (Conflict_Hit_Region'
                 (Kind   => Conflict_Hit_Progress_Cancel,
                  X      => Panel.Cancel_X,
                  Y      => Panel.Cancel_Y,
                  Width  => Panel.Cancel_Width,
                  Height => Panel.Cancel_Height));
         end;
      end if;

      Add_Hover_Tooltip;

      return Result;
   end Build_Frame_Commands;

   function Default_Font_Path return String is
   begin
      return Files.Fonts.Default_Font_Path;
   end Default_Font_Path;

   function Font_Path_For_Frame
     (Frame : Frame_Commands)
      return String
   is
      Text : Unbounded_String;
   begin
      for Command of Frame.Text loop
         Append (Text, Command.Text);
         Append (Text, " ");
      end loop;

      for Command of Frame.Overlay_Text loop
         Append (Text, Command.Text);
         Append (Text, " ");
      end loop;

      return Files.Fonts.Font_Path_For_Text (To_String (Text));
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
      use type Textrender.Status_Code;
      Status : Textrender.Status_Code;
   begin
      Renderer.Loaded := False;
      Renderer.Font_Path := To_Unbounded_String ("");

      if Font_Path = "" then
         Textrender.Reset (The_Renderer);
         return Text_Render_Font_Load_Failed;
      end if;

      Status :=
        Textrender.Load_Font
          (R            => The_Renderer,
           Path         => Font_Path,
           Pixel_Size   => Pixel_Size,
           Cell_Width   => Cell_Width,
           Cell_Height  => Cell_Height,
           Atlas_Width  => Atlas_Width,
           Atlas_Height => Atlas_Height);

      if Status /= Textrender.Success then
         return Text_Render_Font_Load_Failed;
      end if;

      Renderer.Loaded := True;
      Renderer.Font_Path := To_Unbounded_String (Font_Path);
      Renderer.Cell_Width := Cell_Width;
      Renderer.Cell_Height := Cell_Height;
      Renderer.Atlas_Width := Atlas_Width;
      Renderer.Atlas_Height := Atlas_Height;
      return Text_Render_Success;
   end Initialize_Text;

   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result
   is
      use type Textrender.Status_Code;
      Result : Text_Render_Result;

      function Pixel_Snapped
        (Value : Float)
         return Float is
      begin
         if Value <= 0.0 then
            return 0.0;
         elsif Value >= Float (Integer'Last - 1) then
            return Float (Integer'Last - 1);
         else
            return Float (Integer (Value + 0.5));
         end if;
      end Pixel_Snapped;
   begin
      if not Renderer.Loaded then
         return Result;
      end if;

      Result.Status := Text_Render_Success;
      Result.Atlas_Width := Renderer.Atlas_Width;
      Result.Atlas_Height := Renderer.Atlas_Height;
      Result.Atlas_Bytes := Saturating_Multiply (Renderer.Atlas_Width, Renderer.Atlas_Height);

      declare
         procedure Append_Glyphs
           (Commands : Text_Command_Vectors.Vector;
            Glyphs   : in out Glyph_Command_Vectors.Vector)
         is
         begin
            for Text of Commands loop
               declare
                  Content : constant String := To_String (Text.Text);
                  Cell_X  : Float := Float (Text.X);
                  Cell_Y  : constant Float := Float (Text.Y);
                  Limit_X : constant Float := Float (Saturating_Add (Text.X, Text.Width));
                  Base_X  : Float := Float (Text.X);
                  Index   : Integer := Content'First;
               begin
                  while Index <= Content'Last loop
                     declare
                        Unit_Start : constant Integer := Index;
                        Decoded_Codepoint : Natural;
                        Codepoint : Textrender.Codepoint;
                        Metrics   : Textrender.Glyph_Metric;
                        Placement : Textrender.Glyph_Placement;
                        Status    : Textrender.Status_Code;
                        Unit_Width : Natural;
                     begin
                        Files.UTF8.Decode_Next_Display_Codepoint
                          (Content,
                           Index,
                           Decoded_Codepoint);
                        Unit_Width := Files.UTF8.Display_Units (Content (Unit_Start .. Index - 1));
                        if Unit_Width > 0
                          and then Cell_X + Float (Saturating_Multiply (Unit_Width, Renderer.Cell_Width)) > Limit_X
                        then
                           exit;
                        end if;

                        Codepoint := Textrender.Codepoint (Decoded_Codepoint);
                        Status := Textrender.Get_Glyph
                          (The_Renderer, Codepoint, Metrics,
                           Style => (if Text.Italic then Textrender.Italic else Textrender.Regular));

                        if Status /= Textrender.Success then
                           if Unit_Width > 0 then
                              Result.Missing_Glyph_Count :=
                                Saturating_Add (Result.Missing_Glyph_Count, 1);
                              Codepoint := Textrender.Codepoint (Character'Pos ('?'));
                              Status :=
                                Textrender.Get_Glyph
                                  (The_Renderer, Codepoint, Metrics,
                                   Style => (if Text.Italic then Textrender.Italic else Textrender.Regular));
                              if Status /= Textrender.Success then
                                 Metrics :=
                                   (X         => 0,
                                    Y         => 0,
                                    W         => 0,
                                    H         => 0,
                                    U0        => 0.0,
                                    V0        => 0.0,
                                    U1        => 0.0,
                                    V1        => 0.0,
                                    Advance_X => 0.0,
                                    Bearing_X => 0.0,
                                    Bearing_Y => 0.0);
                              end if;
                           else
                              if Files.UTF8.Is_Required_Zero_Width_Codepoint (Decoded_Codepoint) then
                                 Result.Missing_Glyph_Count :=
                                   Saturating_Add (Result.Missing_Glyph_Count, 1);
                              end if;
                              Metrics :=
                                (X         => 0,
                                 Y         => 0,
                                 W         => 0,
                                 H         => 0,
                                 U0        => 0.0,
                                 V0        => 0.0,
                                 U1        => 0.0,
                                 V1        => 0.0,
                                 Advance_X => 0.0,
                                 Bearing_X => 0.0,
                                 Bearing_Y => 0.0);
                           end if;
                        end if;

                        if Metrics.W > 0 and then Metrics.H > 0 then
                           declare
                              Origin_X : constant Float := (if Unit_Width = 0 then Base_X else Cell_X);
                              Scale    : constant Float :=
                                (if Text.Scale_To_Box
                                 then Float'Max
                                   (1.0,
                                    0.86
                                    * Float'Min
                                      (Float (Text.Width) / Float (Metrics.W),
                                       Float (Text.Height) / Float (Metrics.H)))
                                 else 1.0);
                              Scaled_W : constant Float := Float (Metrics.W) * Scale;
                              Scaled_H : constant Float := Float (Metrics.H) * Scale;
                              Draw_X   : Float;
                              Draw_Y   : Float;
                           begin
                              Placement :=
                                Textrender.Place_Glyph_In_Cell
                                  (The_Renderer,
                                   Metrics,
                                   Origin_X,
                                   Cell_Y);
                              if Text.Scale_To_Box then
                                 Draw_X := Float (Text.X) + (Float (Text.Width) - Scaled_W) / 2.0;
                                 Draw_Y := Float (Text.Y) + (Float (Text.Height) - Scaled_H) / 2.0;
                              elsif Decoded_Codepoint = 16#2026# then
                                 --  Snap the ellipsis glyph to the left edge of
                                 --  its cell so it hugs the preceding character
                                 --  instead of sitting centered with visible
                                 --  padding on its left.
                                 Draw_X := Origin_X;
                                 Draw_Y := Placement.Y;
                              else
                                 Draw_X := Placement.X;
                                 Draw_Y := Placement.Y;
                              end if;
                              Glyphs.Append
                                (Glyph_Command'
                                   (X         => Pixel_Snapped (Draw_X),
                                    Y         => Pixel_Snapped (Draw_Y),
                                    Width     => Pixel_Snapped (Scaled_W),
                                    Height    => Pixel_Snapped (Scaled_H),
                                    U0        => Metrics.U0,
                                    V0        => Metrics.V0,
                                    U1        => Metrics.U1,
                                    V1        => Metrics.V1,
                                    Color     => Text.Color,
                                    Codepoint => Natural (Codepoint)));
                           end;
                        end if;

                        if Unit_Width > 0 then
                           Base_X := Cell_X;
                           Cell_X :=
                             Cell_X + Float (Saturating_Multiply (Unit_Width, Renderer.Cell_Width));
                        end if;
                     end;
                  end loop;
               end;
            end loop;
         end Append_Glyphs;
      begin
         Append_Glyphs (Frame.Text, Result.Glyphs);
         if Result.Status = Text_Render_Success then
            Append_Glyphs (Frame.Overlay_Text, Result.Overlay_Glyphs);
         end if;
      end;

      Result.Atlas_Dirty := Textrender.Atlas_Dirty (The_Renderer);
      if Textrender.Atlas_Pixels (The_Renderer) /= null then
         Result.Atlas_Pixels := Textrender.Atlas_Pixels (The_Renderer).all'Address;
      end if;
      return Result;
   end Build_Text_Glyphs;

end Files.Rendering;

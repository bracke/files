with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

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
with Files.Platform.Metadata;
with Files.UTF8;
with Files.UI;

package body Files.Rendering is

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
        (if Inline then Files.Localization.Text ("info.permissions.separator") else (1 => ASCII.LF));

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
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Main_View : constant Main_View_Layout :=
        Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);

      --  Snapshot-derived inputs the component cannot compute itself: the detail
      --  column geometry (with the drawn-row padding) and the neutral item list.
      Geometry : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Details_Row_Padding);
      View : constant Guikit.Item_Grid.View_Kind := Grid_View (Snapshot.View_Mode);
      Columns : Guikit.Item_Grid.Detail_Column_Bounds;
      Items   : Guikit.Item_Grid.Layout_Item_Vectors.Vector;

      --  The two enums are identical (same six columns, same order).
      function As_Grid_Column (C : Files.Types.Detail_Column) return Guikit.Item_Grid.Detail_Column is
        (Guikit.Item_Grid.Detail_Column'Val (Files.Types.Detail_Column'Pos (C)));
   begin
      for C in Files.Types.Detail_Column loop
         Columns (As_Grid_Column (C)) := (X => Geometry (C).X, Width => Geometry (C).Width);
      end loop;

      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         declare
            It : Item_Snapshot renames Snapshot.Items.Element (Positive (Index));
         begin
            Items.Append
              (Guikit.Item_Grid.Layout_Item'
                 (Visible_Index => It.Visible_Index,
                  Group_Header  => It.Is_Group_Header,
                  Label         => It.Name));
         end;
      end loop;

      return Guikit.Item_Grid.Calculate_Layout
        (Items         => Items,
         View          => View,
         Content_X     => Content_X,
         Content_Y     => Content_Y,
         Content_W     => Content_W,
         Content_H     => Content_H,
         Columns       => Columns,
         Scroll_Pixels => Main_View.Scroll_Pixels,
         Line_Height   => Line_Height);
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
      Thumb        : constant Guikit.Layout.Scrollbar_Thumb :=
        Guikit.Layout.Calculate_Scrollbar_Thumb
          (Track_Length    => Viewport_H,
           Visible_Amount  => Viewport_H,
           Total_Amount    => Content_Total_H,
           Scroll_Position => Scroll_Px,
           Max_Scroll      => Max_Scroll,
           Min_Length      => Line_Height);
      Visible      : constant Boolean := Bar_W > 0 and then Thumb.Length > 0;
      Thumb_H      : constant Natural := Thumb.Length;
      Track_Top    : constant Natural :=
        Saturating_Add (Saturating_Add (Layout.Main_Y, Padding), Header_H);
      Thumb_Y      : constant Natural := Saturating_Add (Track_Top, Thumb.Offset);
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
           Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2);
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
   is
      use type Files.Types.Detail_Column;
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
      return Guikit.Layout.Calculate_Palette_Layout
        (Command_X      => Layout.Command_X,
         Command_Y      => Layout.Command_Y,
         Command_Width  => Layout.Command_Width,
         Command_Height => Layout.Command_Height,
         Line_Height    => Line_Height);
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
   is
      Result       : Breadcrumb_Segment_Layout_Vectors.Vector;
      Toolbar      : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Field_Margin : constant Natural := 6;
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Path_W       : constant Natural :=
        (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
         then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
         else 0);
      Input_Y      : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Input_H      : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      Pad          : constant Natural := Guikit.Layout.Input_Field_Padding;
      Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
      Advance      : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Inner_X      : constant Natural := Saturating_Add (Saturating_Add (Path_X, Pad), Star_Reserve);
      Inner_W      : constant Natural :=
        (if Path_W > Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         then Path_W - Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         else 0);
      --  Separator occupies three cells: one blank cell, the '>' glyph, one
      --  blank cell -- a full character width of separation on each side.
      Sep_Cells    : constant Natural := 3;

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
   is
      Rows : Natural := 0;
   begin
      --  Field 0 (Name) is omitted: the name rides on every value as a suffix.
      --  Field 2 (Filesize) is omitted for folders: they carry no byte size and
      --  show Contents instead. Field 5 (Permissions) is drawn as the matrix
      --  below, not as text. Field 7 (Kind) is omitted: it duplicates Filetype.
      --  Field 6 (Metadata Error) only appears when metadata actually failed.
      for Field in 1 .. 8 loop
         if Field /= 5
           and then Field /= 7
           and then not (Field = 2 and then Info.Is_Directory)
           and then not (Field = 6 and then not Info.Metadata_Error)
         then
            Rows :=
              Saturating_Add
                (Rows,
                 Saturating_Add
                    (2,
                    Wrapped_Line_Count (Info_Field_Postfixed_Value (Info, Field), Text_W, Line_Height)));
         end if;
      end loop;

      --  Permissions render as a matrix whenever the item's mode was read.
      if Info.Mode_Available then
         Rows := Saturating_Add (Rows, Permission_Grid_Rows);
      end if;

      --  Owner/Group stay bare: they are interactive (inline editing + caret).
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
                (2, Wrapped_Line_Count
                      (Folder_Contents_Text (Info) & Info_Postfix (Info), Text_W, Line_Height)));
      end if;

      return Rows;
   end Info_Section_Row_Count;

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
   is
      Sections : Coalesced_Section_Vectors.Vector;

      --  Collect the value of Field across every selected item, using the
      --  display form for the wrapped extra field (8).
      function Field_Values (Field : Natural) return Info_Value_Vectors.Vector is
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if Field = 8 then
               Values.Append (Info_Field_Display_Value (Info, Field));
            else
               Values.Append (Info_Field_Value (Info, Field));
            end if;
         end loop;
         return Values;
      end Field_Values;

      --  Postfix each per-item value with " (<name>)" so a coalesced row shows
      --  which selected item it describes. Values are one-per-item in the same
      --  order as Selected_Info. The Name section is left bare (it is the roster).
      function Qualified (Values : Info_Value_Vectors.Vector) return Info_Value_Vectors.Vector is
         Result : Info_Value_Vectors.Vector;
         Index  : Positive := 1;
      begin
         for Info of Snapshot.Selected_Info loop
            Result.Append (Values.Element (Index) & " (" & Info.Name & ")");
            Index := Index + 1;
         end loop;
         return Result;
      end Qualified;

      procedure Add_Field_Section (Key : String; Field : Natural) is
      begin
         Sections.Append
           (Coalesced_Section'
              (Key    => To_Unbounded_String (Key),
               Values => Qualified (Field_Values (Field))));
      end Add_Field_Section;

      Any_Directory : Boolean := False;
      Any_Ownership : Boolean := False;
      Any_Error     : Boolean := False;
   begin
      for Info of Snapshot.Selected_Info loop
         Any_Directory := Any_Directory or else Info.Is_Directory;
         Any_Ownership := Any_Ownership or else Info.Ownership_Available;
         Any_Error     := Any_Error or else Info.Metadata_Error;
      end loop;

      --  No dedicated Name section: every value below is postfixed with the item
      --  name, which serves as the per-row identifier.
      Add_Field_Section ("info.filetype", 1);

      --  Filesize applies only to files: a folder carries no byte size, so it
      --  contributes no row. When every selected item is a folder the section is
      --  omitted entirely (folders show Contents instead).
      declare
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if not Info.Is_Directory then
               Values.Append (Info_Field_Value (Info, 2) & Info_Postfix (Info));
            end if;
         end loop;
         if not Values.Is_Empty then
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.size"), Values => Values));
         end if;
      end;

      if Any_Directory then
         declare
            Values : Info_Value_Vectors.Vector;
            Rows   : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Is_Directory and then Info.Folder_Size_Available then
                  Values.Append (Folder_Contents_Text (Info));
               else
                  Values.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Rows := Qualified (Values);
            --  The combined selection total is the section's last line (not tied
            --  to any one item, so it carries no name postfix).
            Rows.Append
              (To_Unbounded_String
                 (Files.Localization.Text ("info.contents.total") & ": "
                  & Size_Text (Snapshot.Selection_Total_Bytes)
                  & (if Snapshot.Selection_Total_Pending then " ..." else "")));
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.folder_size"), Values => Rows));
         end;
      end if;

      Add_Field_Section ("info.created", 3);
      Add_Field_Section ("info.modified", 4);

      --  Permissions inline (readable, writable, ... on one line) so each item
      --  occupies a single coalesced row rather than one row per permission.
      declare
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if Length (Info.Permissions) = 0 then
               Values.Append (To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
            else
               Values.Append
                 (To_Unbounded_String (Permission_Text (To_String (Info.Permissions), Inline => True)));
            end if;
         end loop;
         Sections.Append
           (Coalesced_Section'(Key => To_Unbounded_String ("info.permissions"), Values => Qualified (Values)));
      end;

      if Any_Ownership then
         declare
            Owners : Info_Value_Vectors.Vector;
            Groups : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Ownership_Available then
                  Owners.Append (Info_Field_Value (Info, 9));
                  Groups.Append (Info_Field_Value (Info, 10));
               else
                  Owners.Append (To_Unbounded_String (Coalesced_Placeholder));
                  Groups.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.owner"), Values => Qualified (Owners)));
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.group"), Values => Qualified (Groups)));
         end;
      end if;

      --  Kind (field 7) is omitted: it duplicates the Filetype section.
      Add_Field_Section ("info.extra", 8);

      if Any_Error then
         declare
            Values : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Metadata_Error then
                  Values.Append (Info_Field_Value (Info, 6));
               else
                  Values.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.metadata_error"), Values => Qualified (Values)));
         end;
      end if;

      return Sections;
   end Coalesced_Info_Sections;

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
   is
      function Total_Info_Rows return Natural is
         Rows   : Natural := 0;
         Text_W : constant Natural :=
           Info_Text_Width (Layout, Scrollbar_W => Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width));
      begin
         --  A multi-item selection is drawn field-major (one label per section,
         --  a value row per item); a single selection keeps the per-item block.
         if Natural (Snapshot.Selected_Info.Length) >= 2 then
            return Coalesced_Info_Rows (Coalesced_Info_Sections (Snapshot), Text_W, Line_Height);
         end if;

         for Info of Snapshot.Selected_Info loop
            Rows :=
              Saturating_Add
                (Rows,
                 Info_Section_Row_Count (Info, Text_W, Line_Height));
         end loop;

         return Rows;
      end Total_Info_Rows;

      Pane_X        : constant Natural := Layout.Main_Width;
      Bar_W         : constant Natural := Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width);
      Text_W        : constant Natural := Info_Text_Width (Layout, Bar_W);
      --  The combined selection total is now the last line of the Contents
      --  section (counted by Total_Info_Rows), so no header rows are reserved.
      Content_Rows  : constant Natural := Total_Info_Rows;
      Raw_Content_H : constant Natural := Saturating_Multiply (Content_Rows, Line_Height);
      Content_H     : constant Natural :=
        (if Raw_Content_H > 0
         then Saturating_Add (Raw_Content_H, Saturating_Multiply (Info_Pane_Padding, 2))
         else 0);
      Max_Scroll_Px : constant Natural :=
        (if Content_H > Layout.Main_Height then Content_H - Layout.Main_Height else 0);
      Requested_Px  : constant Natural := Saturating_Multiply (Snapshot.Info_Pane_Scroll_Lines, Line_Height);
      Scroll_Px     : constant Natural := Natural'Min (Requested_Px, Max_Scroll_Px);
      Scroll_Lines  : constant Natural := Scroll_Px / Line_Height;
      Thumb         : constant Guikit.Layout.Scrollbar_Thumb :=
        Guikit.Layout.Calculate_Scrollbar_Thumb
          (Track_Length    => Layout.Main_Height,
           Visible_Amount  => Layout.Main_Height,
           Total_Amount    => Content_H,
           Scroll_Position => Scroll_Px,
           Max_Scroll      => Max_Scroll_Px,
           Min_Length      => Line_Height);
      Visible       : constant Boolean :=
        Snapshot.Info_Pane_Open
        and then Layout.Info_Pane_Width > 0
        and then Bar_W > 0
        and then Thumb.Length > 0;
      Thumb_H       : constant Natural := Thumb.Length;
      Thumb_Y       : constant Natural := Saturating_Add (Layout.Main_Y, Thumb.Offset);
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

with Ada.Calendar.Formatting;
with Ada.Strings;

with Files.Localization;
with Files.Rendering.Labels;
with Ada.Strings.Unbounded;
with Guikit.Utf8.Editing;

package body Files.Rendering.Geometry is

   use Ada.Strings.Unbounded;
   use Files.Rendering.Labels;

   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean is
     (Guikit.Layout.Within_Rect (Point_X, Point_Y, X, Y, Box_W, Box_H));

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
            Cached_Time_Width := Guikit.Layout.Saturating_Add (Widest, 3 * Details_Column_Padding (Line_Height));
         end;
         Cached_Time_Width_Height := Line_Height;
         Cached_Time_Width_Locale := Ada.Strings.Unbounded.To_Unbounded_String (Locale);
      end if;
      return Cached_Time_Width;
   end Time_Column_Width;

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

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural is
   begin
      return
        Guikit.Layout.Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

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

   function Wrapped_Line_Last
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer;
      Capacity     : Natural)
      return Integer
 is separate;

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
            Row := Guikit.Layout.Saturating_Add (Row, 1);
            return;
         end if;
         Start := Skip_Wrap_Whitespace (Text, First, Last);
         if Start > Last then
            Visit (Row, First, First - 1);
            Row := Guikit.Layout.Saturating_Add (Row, 1);
            return;
         end if;
         loop
            declare
               Line_Last : constant Integer := Wrapped_Line_Last (Text, Start, Last, Capacity);
            begin
               Visit (Row, Start, Line_Last);
               Row := Guikit.Layout.Saturating_Add (Row, 1);
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
         Rows := Natural'Max (Rows, Guikit.Layout.Saturating_Add (Row, 1));
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
        Guikit.Layout.Saturating_Add (Scrollbar_W, Saturating_Multiply (Info_Pane_Padding (Layout.Line_Height), 2));
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
      Now         : Ada.Calendar.Time)
      return Natural
 is separate;

   function Coalesced_Info_Rows
     (Sections    : Coalesced_Section_Vectors.Vector;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      Rows : Natural := 0;
   begin
      for Section of Sections loop
         Rows := Guikit.Layout.Saturating_Add (Rows, 2);
         for Value of Section.Values loop
            Rows := Guikit.Layout.Saturating_Add (Rows, Wrapped_Line_Count (Value, Text_W, Line_Height));
         end loop;
      end loop;
      return Rows;
   end Coalesced_Info_Rows;

end Files.Rendering.Geometry;

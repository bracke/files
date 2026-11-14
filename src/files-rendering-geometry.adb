with Ada.Calendar.Formatting;
with Ada.Strings;

with Files.Localization;
with Files.UI;
with Guikit.Utf8.Editing;

package body Files.Rendering.Geometry is

   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean is
     (Guikit.Layout.Within_Rect (Point_X, Point_Y, X, Y, Box_W, Box_H));

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
            Cached_Time_Width := Guikit.Layout.Saturating_Add (Widest, 3 * Details_Column_Padding (Line_Height));
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
        Guikit.Layout.Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

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

   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle is
      Padding : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding (Layout), 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding (Layout), 2)
         then Main_Content_Padding (Layout)
         else 0);
   begin
      return
        (X      => Guikit.Layout.Saturating_Add (Layout.Main_X, Padding),
         Y      => Guikit.Layout.Saturating_Add (Layout.Main_Y, Padding),
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
          (Guikit.Layout.Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding (Line_Height), 2)),
           Content_H);
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

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
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
         return Guikit.Layout.Saturating_Add (Menu.X, Menu.Column_Width);
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
      return Guikit.Layout.Saturating_Add (Star.Width, Guikit.Layout.Caret_Advance_Width (Line_Height));
   end Path_Bar_Content_Offset;

   function Info_Metadata_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString
   is
   begin
      if not Available then
         return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
      end if;

      return
        To_Unbounded_String (Humanized_Time_Text (Value, Now));
   end Info_Metadata_Text;

   function Info_Field_Value
     (Info  : Info_Snapshot;
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
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
            return Info_Metadata_Text (Info.Creation_Available, Info.Creation_Time, Now);
         when Info_Modified =>
            return Info_Metadata_Text (Info.Modified_Available, Info.Modified_Time, Now);
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
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
      return UString
   is
      Value : constant UString := Info_Field_Value (Info, Field, Now);
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

   function Info_Postfix (Info : Info_Snapshot) return String is
   begin
      return " (" & To_String (Info.Name) & ")";
   end Info_Postfix;

   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive;
      Now         : Ada.Calendar.Time)
      return Natural
 is separate;

   function Build_Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector
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

with Ada.Calendar.Arithmetic;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Util.Dates;
with Util.Dates.Formats;
with Util.Properties;

with Files.Localization;
with Humanize.Bytes;
with Humanize.Datetimes;
with Humanize.Status;

package body Files.Display_Text is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;

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
      return String
   is
      --  Util's Time overload splits at UTC. A file manager shows local
      --  time, at the offset in force on that date, not today's.
      Local  : Util.Dates.Date_Record;
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Util.Dates.Split (Local, Value, Ada.Calendar.Time_Zones.UTC_Time_Offset (Value));
      Util.Dates.Formats.Format (Result, Format, Local, Date_Bundle);
      return Ada.Strings.Unbounded.To_String (Result);
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

   --  A time the calendar cannot handle around Now (a modification time
   --  centuries away: "-" overflows Duration past about 292 years, a split
   --  past the year range) is shown as its full date, or not at all: one
   --  file's odd stamp must not raise out of the frame being built.
   function Calendar_Days_Ago (Value, Now : Ada.Calendar.Time) return Integer is
      Whole_Days : Ada.Calendar.Arithmetic.Day_Count;
      Seconds    : Duration;
      Leap       : Ada.Calendar.Arithmetic.Leap_Seconds_Count;
   begin
      --  Whole days between the two local midnights, rounded: across a
      --  daylight-saving change a day is 23 or 25 hours, and counting
      --  86,400-second steps missed "yesterday" and the weekdays.
      Ada.Calendar.Arithmetic.Difference (Day_Start (Now), Day_Start (Value), Whole_Days, Seconds, Leap);
      return Integer (Whole_Days) + (if Seconds >= 43_200.0 then 1 elsif Seconds <= -43_200.0 then -1 else 0);
   end Calendar_Days_Ago;

   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time := Ada.Calendar.Clock)
      return String
   is
      function Within_A_Minute return Boolean is
        (Value > Now - 60.0 and then Value < Now + 60.0);

      function Relative return String;

      function Relative return String is
         Locale   : constant String := Files.Localization.System_Time_Locale;
      begin
         if Within_A_Minute then
            return Files.Localization.Text ("time.relative.now", Locale);
         elsif Files.Localization.Humanize_Available then
            --  CLDR's wording in every locale: "today 2:30 PM", "gestern 09:05",
            --  the weekday within a week, the date beyond it, the time in the
            --  region's own hour cycle.
            declare
               use type Humanize.Status.Status_Code;

               --  Local time, at the offset in force on that date.
               function Civil (Moment : Ada.Calendar.Time) return Humanize.Datetimes.Civil_Date_Time is
                  Year       : Ada.Calendar.Year_Number;
                  Month      : Ada.Calendar.Month_Number;
                  Day        : Ada.Calendar.Day_Number;
                  Hour       : Ada.Calendar.Formatting.Hour_Number;
                  Minute     : Ada.Calendar.Formatting.Minute_Number;
                  Second     : Ada.Calendar.Formatting.Second_Number;
                  Sub_Second : Ada.Calendar.Formatting.Second_Duration;
               begin
                  Ada.Calendar.Formatting.Split
                    (Moment, Year, Month, Day, Hour, Minute, Second, Sub_Second,
                     Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (Moment));
                  return
                    (Year => Year, Month => Month, Day => Day,
                     Hour => Humanize.Datetimes.Hour_Number (Hour),
                     Minute => Humanize.Datetimes.Minute_Number (Minute),
                     Second => Humanize.Datetimes.Second_Number (Second));
               end Civil;

               Result : constant Humanize.Status.Text_Result :=
                 Humanize.Datetimes.Calendar_Clock_Label
                   (Files.Localization.Humanize_Context (Locale), Civil (Value), Civil (Now));
            begin
               if Result.Status = Humanize.Status.Ok then
                  return To_String (Result.Text);
               end if;
            end;
         end if;

         declare
            Days_Ago : constant Integer := Calendar_Days_Ago (Value, Now);
         begin
            if Days_Ago = 0 then
               return Files.Localization.Text ("time.relative.today", Locale) & " " & Clock_Time_Text (Value);
            elsif Days_Ago = 1 then
               return Files.Localization.Text ("time.relative.yesterday", Locale) & " " & Clock_Time_Text (Value);
            elsif Days_Ago in 2 .. 6 then
               return Files.Localization.Text (Weekday_Key (Value), Locale) & " " & Clock_Time_Text (Value);
            end if;
         end;

         --  Older than a week: fall back to the full absolute date. Computed here
         --  (lazily) so recent files, which return above, never build it.
         return Full_Time_Text (Value);
      end Relative;
   begin
      return Relative;
   exception
      when Ada.Calendar.Time_Error | Constraint_Error =>
         begin
            return Full_Time_Text (Value);
         exception
            when Ada.Calendar.Time_Error | Constraint_Error =>
               return "";
         end;
   end Humanized_Time_Text;

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

   function Group_Separator return String is
   begin
      return Number_Symbol ("number.group", ",");
   end Group_Separator;

   function Grouped_Integer_Text (Value : Long_Long_Integer) return String is
      Text        : constant String := Integer_Text (Value);
      --  The sign is not a digit: "-123" must not read "-,123".
      Signed      : constant Boolean := Text'Length > 0 and then Text (Text'First) = '-';
      Number_Text : constant String := (if Signed then Text (Text'First + 1 .. Text'Last) else Text);
      Separator  : constant String := Group_Separator;
      First_Size : Natural := Number_Text'Length mod 3;
      Result     : Unbounded_String;
   begin
      if Separator'Length = 0 or else Number_Text'Length <= 3 then
         return Text;
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

      return (if Signed then "-" else "") & To_String (Result);
   end Grouped_Integer_Text;

   --  A size as humanize writes it in the number locale: decimal units in
   --  CLDR's names ("4.5 MB", "4,5 Mo", "2 кБ"), one decimal at most.
   function Size_Text (Value : Long_Long_Integer) return String is
   begin
      if Value >= 0 and then Files.Localization.Humanize_Available then
         declare
            Result : constant Humanize.Status.Text_Result :=
              Humanize.Bytes.Format
                (Files.Localization.Humanize_Context (Files.Localization.System_Number_Locale),
                 Humanize.Bytes.Byte_Count (Value),
                 Humanize.Bytes.Decimal_Byte_Options);
            use type Humanize.Status.Status_Code;
         begin
            if Result.Status = Humanize.Status.Ok then
               return To_String (Result.Text);
            end if;
         end;
      end if;
      return
        Grouped_Integer_Text (Value) & " "
        & Files.Localization.Text ("details.size.unit.bytes", Files.Localization.System_Number_Locale);
   end Size_Text;

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

end Files.Display_Text;

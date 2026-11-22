with I18N.Date_Time_Format;
with I18N.Number_Format;
with Files.Grouping;
with Ada.Calendar.Arithmetic;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Localization;
with Humanize.Bytes;
with Humanize.Datetimes;
with Humanize.Status;
with Files.Text_Basics;

package body Files.Rendering.Display_Text is

   --  @param Value The time.
   --  @param With_Date Whether the date is written before the time.
   --  @return Value in CLDR's medium form in the time locale.
   function Formatted_Time_Text (Value : Ada.Calendar.Time; With_Date : Boolean) return String;

   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;

   --  Value's local wall-clock time, at the offset in force on that date, in
   --  ISO 8601: "2026-11-22T14:05:09", or the time alone.
   function Local_Iso_Text (Value : Ada.Calendar.Time; With_Date : Boolean) return String is
      Year       : Ada.Calendar.Year_Number;
      Month      : Ada.Calendar.Month_Number;
      Day        : Ada.Calendar.Day_Number;
      Hour       : Ada.Calendar.Formatting.Hour_Number;
      Minute     : Ada.Calendar.Formatting.Minute_Number;
      Second     : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;

      function Two (Number : Natural) return String is
        ([Character'Val (Character'Pos ('0') + Number / 10 mod 10),
          Character'Val (Character'Pos ('0') + Number mod 10)]);
   begin
      Ada.Calendar.Formatting.Split
        (Value, Year, Month, Day, Hour, Minute, Second, Sub_Second,
         Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (Value));
      declare
         Clock : constant String := Two (Hour) & ":" & Two (Minute) & ":" & Two (Second);
      begin
         if not With_Date then
            return Clock;
         end if;
         return Two (Year / 100) & Two (Year mod 100) & "-" & Two (Month) & "-" & Two (Day) & "T" & Clock;
      end;
   end Local_Iso_Text;

   function Formatted_Time_Text
     (Value     : Ada.Calendar.Time;
      With_Date : Boolean)
      return String
   is
      Iso      : constant String := Local_Iso_Text (Value, With_Date);
      Locale   : constant String := Files.Localization.System_Time_Locale;
      Target   : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
      Last     : Natural;
      Ok       : Boolean;
      Overflow : Boolean;
   begin
      --  CLDR's medium form: the locale's own order, month names and hour
      --  cycle ("Nov 22, 2026, 2:05:09 PM", "22.11.2026, 14:05:09").
      if With_Date then
         --  The text is already local wall-clock time: given as UTC and
         --  written in UTC, it is not shifted to the locale's default zone.
         I18N.Date_Time_Format.Format_Date_Time_Into (Iso & "Z", Locale, "medium,UTC", Target, Last, Ok, Overflow);
      else
         I18N.Date_Time_Format.Format_Time_Into (Iso, Locale, "medium", Target, Last, Ok, Overflow);
      end if;
      if Ok and then not Overflow and then Last >= Target'First then
         return Target (Target'First .. Last);
      end if;
      --  Without the CLDR data: ISO 8601, which reads the same everywhere.
      return (if With_Date then Iso (Iso'First .. Iso'First + 9) & " " & Iso (Iso'First + 11 .. Iso'Last) else Iso);
   end Formatted_Time_Text;

   function Clock_Time_Text (Value : Ada.Calendar.Time) return String is
   begin
      return Formatted_Time_Text (Value, With_Date => False);
   end Clock_Time_Text;

   function Full_Time_Text (Value : Ada.Calendar.Time) return String is
   begin
      return Formatted_Time_Text (Value, With_Date => True);
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
      Ada.Calendar.Arithmetic.Difference
        (Files.Grouping.Day_Start (Now), Files.Grouping.Day_Start (Value), Whole_Days, Seconds, Leap);
      return Integer (Whole_Days) + (if Seconds >= 43_200.0 then 1 elsif Seconds <= -43_200.0 then -1 else 0);
   end Calendar_Days_Ago;

   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time)
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

   function Digits_Text (Value : Natural) return String is
      Locale : constant String := Files.Localization.System_Number_Locale;
      Latin  : constant String := Files.Text_Basics.Integer_Text (Long_Long_Integer (Value));
      Result : Unbounded_String;
   begin
      for Digit of Latin loop
         Append (Result, I18N.Number_Format.Digit_Text (Locale, Digit));
      end loop;
      return To_String (Result);
   end Digits_Text;

   function Grouped_Integer_Text (Value : Long_Long_Integer) return String is
      Text      : constant String := Files.Text_Basics.Integer_Text (Value);
      --  CLDR's form, in the number locale: its digits (Arabic-Indic in
      --  Arabic, as sizes have them), its grouping and when it starts.
      Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
      Last      : Natural;
      Ok        : Boolean;
      Overflow  : Boolean;
   begin
      I18N.Number_Format.Format_Into
        (Text, Files.Localization.System_Number_Locale, "", Formatted, Last, Ok, Overflow);
      if Ok and then not Overflow and then Last >= Formatted'First then
         return Formatted (Formatted'First .. Last);
      end if;
      --  Without the CLDR data: the plain digits, which no locale misreads.
      return Text;
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

end Files.Rendering.Display_Text;

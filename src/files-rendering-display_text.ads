with Ada.Calendar;

--  The words and numbers the views show for a time, a size and a set of
--  permissions, in the user's locale. Kept out of Files.Rendering so they can
--  be tested on their own, under several time zones (a day is 23 or 25 hours
--  across a daylight-saving change). Used from the render only: the date
--  bundle is cached here unguarded.
package Files.Rendering.Display_Text is

   --  @param Value The time.
   --  @return Its clock time ("14:30", "2:30 PM").
   function Clock_Time_Text (Value : Ada.Calendar.Time) return String;

   --  @param Value The time.
   --  @return Its full date and time; "" for a time the calendar cannot
   --    split at its local offset (the edge of Ada.Calendar's range).
   function Full_Time_Text (Value : Ada.Calendar.Time) return String;

   --  @param Value The time.
   --  @return The localization key of its weekday.
   function Weekday_Key (Value : Ada.Calendar.Time) return String;

   --  A time as a listing shows it: today or yesterday and the clock time,
   --  the weekday within a week, the date beyond it.
   --
   --  @param Value The time to show.
   --  @param Now The present.
   --  @return Its text.
   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time)
      return String;

   --  @param Value A number.
   --  @return It with the locale's digit grouping ("12,345").
   function Grouped_Integer_Text (Value : Long_Long_Integer) return String;

   --  A whole number in the number locale's digits, ungrouped: a measure
   --  such as an image's 1920 pixels, which no locale groups.
   --
   --  @param Value The number.
   --  @return Its digits as the locale writes them (Arabic-Indic in Arabic).
   function Digits_Text (Value : Natural) return String;

   --  @param Value A byte count.
   --  @return It as a size ("1.2 MB").
   function Size_Text (Value : Long_Long_Integer) return String;

   --  @param Permissions "rwx"-style text for one class.
   --  @param Inline True to join the parts on one line.
   --  @return The readable, writable and executable words, or "none".
   function Permission_Text (Permissions : String; Inline : Boolean := False) return String;

private

   --  How many calendar days before Now's Value falls: 0 today, 1 yesterday,
   --  negative in the future, counted from local midnights so a 23- or
   --  25-hour day still counts as one.
   --
   --  @param Value The earlier time.
   --  @param Now The present.
   --  @return The number of calendar days.
   function Calendar_Days_Ago (Value, Now : Ada.Calendar.Time) return Integer;

end Files.Rendering.Display_Text;

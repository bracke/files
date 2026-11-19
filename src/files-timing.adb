with Ada.Calendar.Formatting;

package body Files.Timing is

   function Elapsed
     (Now      : Ada.Real_Time.Time;
      Since    : Ada.Real_Time.Time;
      Interval : Ada.Real_Time.Time_Span)
      return Boolean
   is
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
   begin
      if Interval <= Ada.Real_Time.Time_Span_Zero then
         return True;
      elsif Since > Ada.Real_Time.Time_Last - Interval then
         return False;
      else
         return Now >= Since + Interval;
      end if;
   end Elapsed;

   function Time_Since
     (Now   : Ada.Real_Time.Time;
      Since : Ada.Real_Time.Time)
      return Duration
   is
      use type Ada.Real_Time.Time;
   begin
      if Now <= Since then
         return 0.0;
      end if;
      return Ada.Real_Time.To_Duration (Ada.Real_Time."-" (Now, Since));
   exception
      when Constraint_Error =>
         return Duration'Last;
   end Time_Since;

   function Time_Since
     (Now   : Ada.Calendar.Time;
      Since : Ada.Calendar.Time)
      return Duration
   is
      use type Ada.Calendar.Time;
   begin
      if Now <= Since then
         return 0.0;
      end if;
      return Ada.Calendar."-" (Now, Since);
   exception
      --  The two are further apart than Duration reaches.
      when Ada.Calendar.Time_Error | Constraint_Error =>
         return Duration'Last;
   end Time_Since;

   function Until_Due
     (Now   : Ada.Real_Time.Time;
      Due   : Ada.Real_Time.Time;
      Limit : Duration)
      return Duration
   is
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
      use type Ada.Real_Time.Seconds_Count;
      Longest : constant Duration := Duration'Max (Limit, 0.0);
      Now_Seconds, Due_Seconds   : Ada.Real_Time.Seconds_Count;
      Now_Fraction, Due_Fraction : Ada.Real_Time.Time_Span;
   begin
      if Due <= Now then
         return 0.0;
      end if;
      --  Whole seconds and the fractions apart: neither difference can
      --  overflow, wherever in the clock's range the two times lie.
      Ada.Real_Time.Split (Now, Now_Seconds, Now_Fraction);
      Ada.Real_Time.Split (Due, Due_Seconds, Due_Fraction);
      if Due_Seconds - Now_Seconds > Ada.Real_Time.Seconds_Count (Longest) + 1 then
         return Longest;
      end if;
      return Duration'Max
        (0.0,
         Duration'Min
           (Longest,
            Duration (Due_Seconds - Now_Seconds) + Ada.Real_Time.To_Duration (Due_Fraction - Now_Fraction)));
   end Until_Due;

   function Elapsed
     (Now      : Ada.Calendar.Time;
      Since    : Ada.Calendar.Time;
      Interval : Duration)
      return Boolean
   is
      use type Ada.Calendar.Time;
   begin
      if Interval <= 0.0 then
         return True;
      end if;
      return Now >= Since + Interval;
   exception
      --  Since + Interval is past the calendar's end: not yet.
      when Ada.Calendar.Time_Error =>
         return False;
   end Elapsed;

   function Minute_Start (T : Ada.Calendar.Time) return Ada.Calendar.Time is
      Year       : Ada.Calendar.Year_Number;
      Month      : Ada.Calendar.Month_Number;
      Day        : Ada.Calendar.Day_Number;
      Hour       : Ada.Calendar.Formatting.Hour_Number;
      Minute     : Ada.Calendar.Formatting.Minute_Number;
      Second     : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;
   begin
      Ada.Calendar.Formatting.Split (T, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);
      return Ada.Calendar.Formatting.Time_Of (Year, Month, Day, Hour, Minute, 0, 0.0, Time_Zone => 0);
   exception
      when Ada.Calendar.Time_Error =>
         return T;
   end Minute_Start;

end Files.Timing;

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

end Files.Timing;

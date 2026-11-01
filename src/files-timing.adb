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

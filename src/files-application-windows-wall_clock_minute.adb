with Ada.Calendar.Arithmetic;

separate (Files.Application.Windows)
   function Wall_Clock_Minute return Natural is
      Days         : Ada.Calendar.Arithmetic.Day_Count;
      Seconds      : Duration;
      Leap_Seconds : Ada.Calendar.Arithmetic.Leap_Seconds_Count;
      Whole        : Long_Long_Integer;
   begin
      --  Days and seconds apart, which cannot overflow as one Duration can.
      Ada.Calendar.Arithmetic.Difference
        (Ada.Calendar.Clock, Ada.Calendar.Time_Of (2000, 1, 1), Days, Seconds, Leap_Seconds);
      --  Whole seconds, rounded down: a conversion rounds to nearest.
      Whole := Long_Long_Integer (Seconds);
      if Duration (Whole) > Seconds then
         Whole := Whole - 1;
      end if;
      return Natural ((Long_Long_Integer (Days) * 1_440 + Whole / 60) mod Long_Long_Integer (Natural'Last));
   end Wall_Clock_Minute;

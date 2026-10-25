with Ada.Calendar;

separate (Files.Application.Windows)
   function Wall_Clock_Minute return Natural is
   begin
      return
        Natural
          ((Long_Long_Integer
              (Ada.Calendar."-" (Ada.Calendar.Clock, Ada.Calendar.Time_Of (2000, 1, 1)))
            / 60) mod Long_Long_Integer (Natural'Last));
   end Wall_Clock_Minute;

separate (Files_Suite.Startup)
   procedure Test_Timing_At_Clock_Ends (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
      use type Ada.Calendar.Time;
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Second : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
      Today  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      Assert
        (Files.Timing.Elapsed (Now, Ada.Real_Time.Time_First, Second),
         "an interval since Time_First (never) has elapsed, without overflow");
      Assert
        (not Files.Timing.Elapsed (Now, Ada.Real_Time.Time_Last, Second),
         "an interval from Time_Last has not elapsed, without overflow");
      Assert
        (not Files.Timing.Elapsed (Now, Now + Second, Second),
         "an interval from a later time (the clock moved back) has not elapsed");
      Assert
        (Files.Timing.Elapsed (Now + Second, Now, Second)
         and then not Files.Timing.Elapsed (Now + Ada.Real_Time.Milliseconds (999), Now, Second),
         "an interval elapses exactly at its end");
      Assert
        (Files.Timing.Elapsed (Now, Now, Ada.Real_Time.Time_Span_Zero)
         and then Files.Timing.Elapsed (Now, Ada.Real_Time.Time_Last, -Second),
         "an empty or negative interval has always elapsed");
      Assert
        (Files.Timing.Elapsed (Today, Ada.Calendar.Time_Of (1901, 1, 1), 2.0)
         and then not Files.Timing.Elapsed (Today, Ada.Calendar.Time_Of (2399, 12, 31), Duration'Last),
         "calendar intervals at the calendar's ends answer without raising");
      Assert
        (not Files.Timing.Elapsed (Today, Today, 2.0) and then Files.Timing.Elapsed (Today + 2.0, Today, 2.0),
         "a calendar interval elapses at its end");
   end Test_Timing_At_Clock_Ends;

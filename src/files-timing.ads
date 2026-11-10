with Ada.Calendar;
with Ada.Real_Time;

--  Timer decisions as pure functions, safe at the ends of the clock's range.
--  Clock - Since overflows when Since is Time_First (a "never" that many
--  timers start from); that once raised on every pass of the event loop and
--  froze every window. check_all refuses Clock subtraction in src/: a timer
--  asks Elapsed instead.
package Files.Timing is

   --  @param Now The current time.
   --  @param Since When the interval started; Time_First for "never".
   --  @param Interval How long must pass; zero or less has always passed.
   --  @return True when Interval has passed since Since. Never raises: a
   --  Since so late that Since + Interval would overflow has not elapsed.
   function Elapsed
     (Now      : Ada.Real_Time.Time;
      Since    : Ada.Real_Time.Time;
      Interval : Ada.Real_Time.Time_Span)
      return Boolean;

   --  Elapsed for calendar times, such as file modification times, which
   --  may be anywhere in the calendar's range.
   --
   --  @param Now The current time.
   --  @param Since When the interval started.
   --  @param Interval How long must pass; zero or less has always passed.
   --  @return True when Interval has passed since Since. Never raises.
   function Elapsed
     (Now      : Ada.Calendar.Time;
      Since    : Ada.Calendar.Time;
      Interval : Duration)
      return Boolean;

   --  How long the program waits, at exit, for a worker task to take a stop
   --  request, and then for it to finish: a stuck task cannot hold the exit
   --  for longer than about two seconds in all.
   Stop_Request_Wait  : constant Duration := 0.2;
   Stop_Poll_Interval : constant Duration := 0.01;
   Stop_Polls         : constant := 180;

end Files.Timing;

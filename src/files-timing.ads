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

   --  How long has passed since Since, on a monotonic clock.
   --
   --  @param Now The current time.
   --  @param Since An earlier moment (a process's start, say).
   --  @return Now - Since, or 0.0 when Since is not earlier. Never raises:
   --  a span too long for Duration answers Duration'Last.
   function Time_Since
     (Now   : Ada.Real_Time.Time;
      Since : Ada.Real_Time.Time)
      return Duration;

   --  How long until Due, at most Limit.
   --
   --  @param Now The current time.
   --  @param Due When something becomes due.
   --  @param Limit The longest answer.
   --  @return Due - Now clamped to 0.0 .. Limit. Never raises.
   function Until_Due
     (Now   : Ada.Real_Time.Time;
      Due   : Ada.Real_Time.Time;
      Limit : Duration)
      return Duration;

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

   --  The start of the wall-clock minute T falls in (seconds dropped, in
   --  UTC, so a time zone change cannot move it). What a view snapshot keeps
   --  of the time it shows a folder at: two built in the same minute agree.
   --
   --  @param T A time.
   --  @return The start of its minute; T itself when it cannot be split.
   function Minute_Start (T : Ada.Calendar.Time) return Ada.Calendar.Time;

   --  How long the program waits, at exit, for a worker task to take a stop
   --  request, and then for it to finish: a stuck task cannot hold the exit
   --  for longer than about two seconds in all.
   Stop_Request_Wait  : constant Duration := 0.2;
   Stop_Poll_Interval : constant Duration := 0.01;
   Stop_Polls         : constant := 180;

end Files.Timing;

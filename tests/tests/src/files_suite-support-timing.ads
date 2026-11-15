with Ada.Iterator_Interfaces;
with Ada.Real_Time;

--  Timing for the tests: the monotonic clock, bounds scaled for slow
--  runners, timed assertions and bounded polling waits.
package Files_Suite.Support.Timing is

   --  A point on the monotonic clock (Ada.Real_Time): timing assertions
   --  measure with it rather than with Ada.Calendar's wall clock, which an
   --  NTP step or a daylight-saving change can move by any amount.
   subtype Instant is Ada.Real_Time.Time;

   --  A span of monotonic time.
   subtype Span is Ada.Real_Time.Time_Span;

   --  @return The monotonic clock now.
   function Now return Instant;

   --  @param Since An earlier reading of Now.
   --  @return How long ago Since was.
   function Elapsed (Since : Instant) return Span;

   --  @param Taken A span.
   --  @return Taken in seconds.
   function Seconds (Taken : Span) return Duration;

   --  The factor every timing bound is multiplied by: the decimal in
   --  FILES_TEST_TIME_SCALE (CI sets 2 on its slow shared macOS and Windows
   --  runners), or 1.0 when it is unset, unreadable or below 1.0, so a slow
   --  host can be given room without editing the tests, and no host can be
   --  made stricter than the defaults below.
   --
   --  @return The scale, at least 1.0.
   function Time_Scale return Duration;

   --  @param Bound A default bound, in seconds.
   --  @return Bound multiplied by Time_Scale.
   function Scaled (Bound : Duration) return Span;

   --  How long a call may take and still count as not waiting for a stalled
   --  helper (which never finishes): long enough for a loaded CI runner to
   --  spawn a process, far short of anything that would wait.
   Prompt_Seconds : constant Duration := 1.0;

   --  How long a call that starts a helper process may take: a spawn alone
   --  can exceed a quarter second on a busy Windows runner, and a call that
   --  inspected the stalled target itself would block far longer.
   Launch_Seconds : constant Duration := 2.0;

   --  How long cancelling a stalled helper may take to report it detached:
   --  the helper's bounded grace period plus the reaping after it.
   Detach_Seconds : constant Duration := 3.5;

   --  @return Prompt_Seconds, scaled.
   function Prompt_Limit return Span is (Scaled (Prompt_Seconds));

   --  @return Launch_Seconds, scaled.
   function Launch_Limit return Span is (Scaled (Launch_Seconds));

   --  @return Detach_Seconds, scaled.
   function Detach_Limit return Span is (Scaled (Detach_Seconds));

   --  Assert that Taken is under Limit; the failure message says both, in
   --  seconds, so a slow-runner failure tells by how much it missed.
   --
   --  @param Taken Measured span.
   --  @param Limit Bound it must stay under.
   --  @param Message What the check is about.
   procedure Assert_Within (Taken : Span; Limit : Span; Message : String);

   --  Assert_Within (Elapsed (Since), Limit, Message). Call it straight after
   --  the measured call, before any other check, so only that call is timed.
   --
   --  @param Since Reading of Now taken just before the measured call.
   --  @param Limit Bound it must stay under.
   --  @param Message What the check is about.
   procedure Assert_Within (Since : Instant; Limit : Span; Message : String);

   --  How long a test waits for something it expects to happen (a helper
   --  starting, a job finishing) before giving up. Generous, because a wait
   --  only runs this long when the test is already failing.
   Poll_Limit : constant Duration := 30.0;

   --  @return Poll_Limit scaled by Time_Scale, in seconds.
   function Scaled_Poll_Limit return Duration;

   type Poll_Cursor is new Natural;

   --  @param Position A polling cursor.
   --  @return True while the wait has time left.
   function Has_Poll (Position : Poll_Cursor) return Boolean is (Position /= 0);

   package Poll_Iterators is new Ada.Iterator_Interfaces (Poll_Cursor, Has_Poll);

   --  Iterate until a deadline: "for Attempt in Polling loop ... exit when
   --  Done; end loop;" runs the body, sleeps Interval, and runs it again
   --  until the body exits or Limit has passed. The caller asserts the
   --  condition afterwards, as with any bounded wait.
   --
   --  @param Limit Bound on the whole wait, on the monotonic clock
   --  (Ada.Real_Time); by default Poll_Limit scaled by Time_Scale, as every
   --  other test bound is.
   --  @param Interval Sleep between attempts.
   --  @return An iterator over the attempts.
   function Polling
     (Limit    : Duration := Scaled_Poll_Limit;
      Interval : Duration := 0.001)
      return Poll_Iterators.Forward_Iterator'Class;

private

   type Poll_Iterator is new Poll_Iterators.Forward_Iterator with record
      Deadline : Ada.Real_Time.Time;
      Interval : Duration;
   end record;

   overriding function First (Object : Poll_Iterator) return Poll_Cursor is (1);

   overriding function Next (Object : Poll_Iterator; Position : Poll_Cursor) return Poll_Cursor;

end Files_Suite.Support.Timing;

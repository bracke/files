with Ada.Exceptions;

--  A trace for failures the program deliberately carries on past: a handler
--  that keeps going (best-effort cleanup, an optional probe) records what it
--  caught here instead of discarding it. Silent unless FILES_DIAGNOSTICS is
--  set, so behaviour is unchanged; with it set, every such exception is
--  written to standard error with where it was caught.
package Files.Diagnostics is

   --  Record an exception a handler is about to carry on past.
   --
   --  @param Occurrence The caught exception.
   --  @param Where The unit that caught it.
   procedure Note
     (Occurrence : Ada.Exceptions.Exception_Occurrence;
      Where      : String);

   --  Note an exception the event loop carries on past (a window's step, a
   --  whole pass, a window-system callback), and count it: a pass that fails
   --  every time leaves windows undrawn while the program looks alive, so the
   --  smokes and the unit suite fail on any.
   --
   --  @param Occurrence The caught exception.
   procedure Note_Event_Loop (Occurrence : Ada.Exceptions.Exception_Occurrence);

   --  @return How many exceptions Note_Event_Loop has counted in this process.
   function Event_Loop_Failures return Natural;

   --  Record a step worth following when something goes missing on a host
   --  that cannot be debugged directly (a screen reader's request on a CI
   --  runner). Silent unless FILES_DIAGNOSTICS is set; marked files-trace:,
   --  apart from Note's files-diagnostics:, which reports a failure.
   --
   --  @param Where The unit the step is in.
   --  @param Message What happened.
   procedure Trace (Where : String; Message : String);

end Files.Diagnostics;

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

   --  Record a step worth following when something goes missing on a host
   --  that cannot be debugged directly (a screen reader's request on a CI
   --  runner). Silent unless FILES_DIAGNOSTICS is set.
   --
   --  @param Where The unit the step is in.
   --  @param Message What happened.
   procedure Trace (Where : String; Message : String);

end Files.Diagnostics;

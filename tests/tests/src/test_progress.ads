with AUnit.Test_Filters;
with AUnit.Tests;

--  A test filter that runs everything (or, when FILES_TEST_ONLY is set, the
--  routines whose name contains it) and, when FILES_TEST_PROGRESS is not empty,
--  names each routine on standard error before it runs -- so a run that dies
--  without a report (a crash on Windows) says which test it was in.
package Test_Progress is

   type Progress_Filter is new AUnit.Test_Filters.Test_Filter with null record;

   overriding function Is_Active
     (Filter : Progress_Filter;
      T      : AUnit.Tests.Test'Class)
      return Boolean;

   Filter : aliased Progress_Filter;

   --  @return FILES_TEST_ONLY, or "" when every routine runs.
   function Only return String;

   --  How many routines matched FILES_TEST_ONLY and so ran (0 when it is
   --  unset), so a filter that matches nothing can fail the run.
   --
   --  @return The count of distinct routines the filter let through.
   function Matched return Natural;

end Test_Progress;

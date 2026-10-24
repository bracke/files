with AUnit.Test_Filters;
with AUnit.Tests;

--  A test filter that runs everything and, when FILES_TEST_PROGRESS is not empty,
--  names each routine on standard error before it runs -- so a run that dies
--  without a report (a crash on Windows) says which test it was in.
package Test_Progress is

   type Progress_Filter is new AUnit.Test_Filters.Test_Filter with null record;

   overriding function Is_Active
     (Filter : Progress_Filter;
      T      : AUnit.Tests.Test'Class)
      return Boolean;

   Filter : aliased Progress_Filter;

end Test_Progress;

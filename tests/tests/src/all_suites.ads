with AUnit.Test_Suites;

package All_Suites is

   --  Return all AUnit suites for the tests executable.
   --
   --  @return Aggregate test suite.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end All_Suites;

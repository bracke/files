with AUnit.Test_Suites;

package Files_Suite is

   --  Return the complete files AUnit suite.
   --
   --  @return Test suite containing files vertical-slice tests.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Files_Suite;

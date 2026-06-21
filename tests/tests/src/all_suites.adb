with Files_Suite;

package body All_Suites is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Files_Suite.Suite);
      return Result;
   end Suite;

end All_Suites;

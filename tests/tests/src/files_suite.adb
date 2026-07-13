with AUnit.Test_Suites;

with Files_Suite.Startup;
with Files_Suite.Model;
with Files_Suite.Commands;
with Files_Suite.Settings;
with Files_Suite.Operations;
with Files_Suite.Rendering;
with Files_Suite.Interaction;
with Files_Suite.Watch;

package body Files_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (Files_Suite.Startup.Suite);
      Result.Add_Test (Files_Suite.Model.Suite);
      Result.Add_Test (Files_Suite.Commands.Suite);
      Result.Add_Test (Files_Suite.Settings.Suite);
      Result.Add_Test (Files_Suite.Operations.Suite);
      Result.Add_Test (Files_Suite.Rendering.Suite);
      Result.Add_Test (Files_Suite.Interaction.Suite);
      Result.Add_Test (Files_Suite.Watch.Suite);
      return Result;
   end Suite;

end Files_Suite;

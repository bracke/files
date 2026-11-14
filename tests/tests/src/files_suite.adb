
with Files_Suite.Startup;
with Files_Suite.Model;
with Files_Suite.Commands;
with Files_Suite.Settings;
with Files_Suite.Operations;
with Files_Suite.Transfer;
with Files_Suite.Recovery;
with Files_Suite.History;
with Files_Suite.Trash;
with Files_Suite.Search;
with Files_Suite.Thumbnails;
with Files_Suite.Archives;
with Files_Suite.Info;
with Files_Suite.Names;
with Files_Suite.Refresh;
with Files_Suite.Open_Actions;
with Files_Suite.Rendering;
with Files_Suite.Interaction;

package body Files_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (Files_Suite.Startup.Suite);
      Result.Add_Test (Files_Suite.Model.Suite);
      Result.Add_Test (Files_Suite.Commands.Suite);
      Result.Add_Test (Files_Suite.Settings.Suite);
      Result.Add_Test (Files_Suite.Operations.Suite);
      Result.Add_Test (Files_Suite.Transfer.Suite);
      Result.Add_Test (Files_Suite.Recovery.Suite);
      Result.Add_Test (Files_Suite.History.Suite);
      Result.Add_Test (Files_Suite.Trash.Suite);
      Result.Add_Test (Files_Suite.Search.Suite);
      Result.Add_Test (Files_Suite.Thumbnails.Suite);
      Result.Add_Test (Files_Suite.Archives.Suite);
      Result.Add_Test (Files_Suite.Info.Suite);
      Result.Add_Test (Files_Suite.Names.Suite);
      Result.Add_Test (Files_Suite.Refresh.Suite);
      Result.Add_Test (Files_Suite.Open_Actions.Suite);
      Result.Add_Test (Files_Suite.Rendering.Suite);
      Result.Add_Test (Files_Suite.Interaction.Suite);
      return Result;
   end Suite;

end Files_Suite;

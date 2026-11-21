with Files.Preference_Types;
with Files_Suite.Support.Models;
separate (Files_Suite.Model)
   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
   begin
      Files.Model.Set_View_Mode (Model, Files.Preference_Types.Large_Icons);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Preference_Types.Large_Icons,
         "large icons can be selected");
      Files_Suite.Support.Models.Run_Command (Files.Commands.Select_Details_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Preference_Types.Details,
         "details command selects details");
      Files_Suite.Support.Models.Run_Command (Files.Commands.Select_Small_Icons_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Preference_Types.Small_Icons,
         "small command clears prior mode");
   end Test_View_Mode_State;

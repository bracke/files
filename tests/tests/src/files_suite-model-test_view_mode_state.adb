separate (Files_Suite.Model)
   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Large_Icons,
         "large icons can be selected");
      Files.Commands.Execute (Files.Commands.Select_Details_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details command selects details");
      Files.Commands.Execute (Files.Commands.Select_Small_Icons_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "small command clears prior mode");
   end Test_View_Mode_State;

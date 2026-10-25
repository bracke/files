separate (Files_Suite.Commands)
   procedure Test_Close_Command_Closes_Settings_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "controller opens the settings pane");
      Result := Files.Controller.Execute_Command (Files.Commands.Close_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Controller.Controller_Command_Executed, "the close command runs over the settings pane");
      Files_Suite.Support.Assert_Equal
        (Result.Command, Files.Commands.Close_Command_Palette_Command, "the close command reports itself");
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "the close command closes the settings pane rather than only dropping focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "closing the settings pane releases its keyboard focus");
   end Test_Close_Command_Closes_Settings_Pane;

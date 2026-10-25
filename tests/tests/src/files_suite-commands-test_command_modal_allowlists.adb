separate (Files_Suite.Commands)
   procedure Test_Command_Modal_Allowlists (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.No_Command),
         Files.Commands.No_Placement,
         "no-command has no toolbar or palette placement");
      Assert
        (not Files.Commands.Requires_Settings_Path (Files.Commands.No_Command),
         "no-command does not require a settings path");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Select_Drive_Command),
         "drive selector is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Open_Selected_Root_Command),
         "selected-root activation is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Eject_Selected_Root_Command),
         "selected-root eject is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Open_Command_Palette_Command),
         "palette open is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Close_Command_Palette_Command),
         "palette close is allowed while root selector is open");
      Assert
        (not Files.Commands.Allowed_With_Root_Selector (Files.Commands.Toggle_Settings_Pane_Command),
         "settings pane is blocked while root selector is open");
      Assert
        (not Files.Commands.Allowed_With_Root_Selector (Files.Commands.Delete_Selected_Items_Command),
         "delete is blocked while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Toggle_Settings_Pane_Command),
         "settings toggle is allowed while settings pane is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Open_Command_Palette_Command),
         "palette open is allowed while settings pane is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Close_Command_Palette_Command),
         "palette close is allowed while settings pane is open");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Select_Drive_Command),
         "drive selector is blocked while settings pane is open");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Navigate_Back_Command),
         "background navigation is blocked while settings pane is open");
      Assert
        (not Files.Commands.Command_Palette_Visible (Files.Commands.No_Command),
         "no-command is hidden from the command palette");
   end Test_Command_Modal_Allowlists;

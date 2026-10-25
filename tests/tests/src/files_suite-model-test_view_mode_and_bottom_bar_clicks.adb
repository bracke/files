separate (Files_Suite.Model)
   procedure Test_View_Mode_And_Bottom_Bar_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      --  Start from an open info pane with nothing selected.
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files.Model.Clear_Selection (Model);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_2, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Large_Icons_Command,
         "Control+2 routes large-icons command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Large_Icons,
         "large mode shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_3, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Details_Command,
         "Control+3 routes details command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_1, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Small_Icons_Command,
         "Control+1 routes small-icons command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "small mode shortcut works");

      --  The info pane can always be toggled, even with no selection: the click
      --  now closes the currently open pane rather than being ignored.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "info-pane click routes command with no selection");
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "info-pane click closes the pane with no selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "enabled info-pane click routes command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info-pane click toggles open");
      --  Restore the closed state expected by the following command click
      --  checks.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second info-pane click closes the pane again");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.Select_Details_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Details_Command,
         "details click routes command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details click changes view mode");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.No_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "empty command click is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.No_Command,
         "empty command click reports no command");
   end Test_View_Mode_And_Bottom_Bar_Clicks;

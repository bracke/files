with Files.Commands.Status;
separate (Files_Suite.Commands)
   procedure Test_Filter_Return_And_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files.Model.Focus_Filter_Input (Model);
      Files.Model.Select_Visible (Model, 2);
      Files.Controller.Replace_Focused_Text (Model, "beta");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "filter Return executes focus command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Filter_Input_Command,
         "Return commits filter input");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "filter Return reports successful state-only commit");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "filter Return clears focus");
      Files_Suite.Support.Assert_Equal (Files.Model.Filter_Text (Model), "beta", "filter Return preserves text");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Root, "filter Return does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl_Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "clear-filter executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Clear_Filter_Command,
         "clear-filter command is routed");
      Files_Suite.Support.Assert_Equal (Files.Model.Filter_Text (Model), "", "clear-filter command clears text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         3,
         "clear-filter restores visible projection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Beta.txt",
         "clear-filter preserves selected visible item");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear-filter disables after clearing");
   end Test_Filter_Return_And_Clear;

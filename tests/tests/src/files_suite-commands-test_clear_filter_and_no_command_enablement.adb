with Files.Commands.Status;
separate (Files_Suite.Commands)
   procedure Test_Clear_Filter_And_No_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.No_Command, Model), "no-command is never enabled");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Create_File_Command, Model),
              "create is enabled initially");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Focus_Filter_Input_Command, Model),
         "filter focus is enabled initially");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear filter is disabled without filter text");
      Result := Files.Controller.Execute_Command (Files.Commands.Clear_Filter_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "disabled clear-filter command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "disabled clear-filter returns operation data");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.filter.empty",
         "disabled clear-filter records error");
      Files.Model.Set_Filter (Model, "alpha");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear filter is enabled with filter text");
      Result := Files.Controller.Execute_Command (Files.Commands.Clear_Filter_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Clear_Filter_Command,
         "clear-filter command is reported");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "enabled clear-filter reports successful state-only operation");
      Files_Suite.Support.Assert_Equal (Files.Model.Filter_Text (Model), "", "clear-filter command clears filter text");
      Model := Sample_Model;
      Files_Suite.Support.Run_Command (Files.Commands.No_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "no-command execution does not change path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "no-command execution preserves view");
   end Test_Clear_Filter_And_No_Command_Enablement;

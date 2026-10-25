separate (Files_Suite.Operations)
   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      --  Exercise the genuine missing-action contract deterministically by
      --  opting out of the host opener fallback that would otherwise resolve.
      Settings.Use_System_Default_Opener := False;
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Missing_Open_Action,
         "prepare reports missing action");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Gamma.md"),
         "prepare missing action reports file path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.open_action.missing",
         "prepare missing action records error");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Missing_Open_Action,
         "missing action is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Gamma.md"),
         "missing action reports selected file path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.open_action.missing",
         "missing action sets error state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "missing file action does not navigate");
   end Test_Missing_Open_Action_Reports_Error;

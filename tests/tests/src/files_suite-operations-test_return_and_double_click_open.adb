separate (Files_Suite.Operations)
   procedure Test_Return_And_Double_Click_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
      Routed    : Files.Controller.Controller_Result;
   begin
      --  Keep the configured-action contracts deterministic; the host opener
      --  fallback would otherwise resolve unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Arguments.Append (To_Unbounded_String ("--readonly"));
      Arguments.Append (To_Unbounded_String ("{path}"));
      Arguments.Append (To_Unbounded_String ("{name}"));
      Modifiers (Guikit.Input.Control_Key) := True;
      Files.Model.Select_Visible (Model, 1);

      Files.Model.Set_Error (Model, "error.open_action.missing");
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action (No_Op_Executable, Arguments));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "modifier-specific action can be prepared");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (2)),
         Join (Root, "Alpha.txt"),
         "prepared modifier-specific action expands path");
      Routed := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Open_Selected_Items_Command,
         "Return routes file open command");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Action_Executed,
         "Return executes configured open action");
      Files_Suite.Support.Assert_Equal
        (To_String (Routed.Operation.Action.Arguments.Element (2)),
         Join (Root, "Alpha.txt"),
         "Return open preserves modifier-specific action lookup");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), "", "Return open clears stale error state");

      Files.Model.Select_Visible (Model, 2);
      Routed :=
        Files.Controller.Handle_Item_Click
          (Model, Settings, Visible_Index => 1, Activate => True, Modifiers => Modifiers);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Open_Selected_Items_Command,
         "double-click file routes open command");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Action_Executed,
         "double-click file executes configured action");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "double-click selects activated file");
   end Test_Return_And_Double_Click_Open;

separate (Files_Suite.Operations)
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
   begin
      --  Exercise the configured-action and missing-action contracts
      --  deterministically; the host opener fallback would otherwise resolve
      --  unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Arguments.Append (To_Unbounded_String ("--readonly"));
      Arguments.Append (To_Unbounded_String ("{path}"));
      Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action (No_Op_Executable, Arguments));
      Modifiers (Guikit.Input.Control_Key) := True;
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Set_Error (Model, "error.open_action.missing");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "file open action can be prepared without spawn");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "prepared action reports selected file path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "prepared action clears stale error state");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Executable),
         No_Op_Executable,
         "prepared action uses configured executable");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action_Executable),
         No_Op_Executable,
         "prepared result exposes executable text");
      Files_Suite.Support.Assert_Equal (Result.Action_Arguments, 3, "prepared result exposes argument count");
      Assert (not Result.Execution_Attempted, "prepared action does not execute");
      Assert (not Result.Action.Use_Shell, "prepared action preserves non-shell execution");
      Files_Suite.Support.Assert_Equal
        (Natural (Result.Action.Arguments.Length),
         3,
         "prepared action preserves argument vector");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (1)),
         "--readonly",
         "literal argument is preserved");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (2)),
         Join (Root, "Alpha.txt"),
         "path placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (3)),
         "Alpha.txt",
         "name placeholder expands");

      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "file open executes an action; got "
         & Files.Operations.Operation_Status'Image (Result.Status)
         & " with executable " & To_String (Result.Action_Executable));
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "file open returns selected file path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "executed open action clears stale error state");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Executable),
         No_Op_Executable,
         "executed action uses configured executable");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action_Executable),
         No_Op_Executable,
         "executed result exposes executable text");
      Files_Suite.Support.Assert_Equal (Result.Action_Arguments, 3, "executed result exposes argument count");
      Assert (Result.Execution_Attempted, "executed result records process attempt");
      Assert (Result.Executable_Found, "executed result records executable discovery");
      Assert (not Result.Action.Use_Shell, "executed non-shell action does not request shell execution");
      Files_Suite.Support.Assert_Equal
        (Natural (Result.Action.Arguments.Length),
         3,
         "executed action preserves argument vector");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (2)),
         Join (Root, "Alpha.txt"),
         "path placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (3)),
         "Alpha.txt",
         "name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "opening a non-directory does not navigate");
      declare
         Lifecycle : constant Files.Operations.Open_Action_Lifecycle :=
           Files.Operations.Open_Action_Lifecycle_Of (Result);
      begin
         --  Open_Selected launches detached, so the action is spawned and let go.
         --  "Completed" would claim we watched it finish, and we did not.
         Assert
           (Lifecycle.State = Files.Operations.Open_Action_Spawned,
            "open-action lifecycle records a spawned action");
         Files_Suite.Support.Assert_Equal
           (To_String (Lifecycle.Executable),
            No_Op_Executable,
            "lifecycle records executable");
         Files_Suite.Support.Assert_Equal (Lifecycle.Argument_Count, 3, "lifecycle records argument count");
         Assert (not Lifecycle.Exit_Status_Known, "lifecycle records no exit status for a detached launch");
      end;

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (No_Op_Executable, Files.Settings.String_Vectors.Empty_Vector));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "zero-argument open action executes");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action_Executable),
         No_Op_Executable,
         "zero-argument action exposes executable");
      Files_Suite.Support.Assert_Equal
        (Result.Action_Arguments,
         0,
         "zero-argument action exposes empty argument vector");
      Assert (Result.Execution_Attempted, "zero-argument action records process attempt");
      Assert (Result.Executable_Found, "zero-argument action records executable discovery");
      Assert (not Result.Exit_Status_Known, "zero-argument detached action records no exit status");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Set_Error (Model, "error.open_action.execution");
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "multi-file open action can be prepared");
      Assert (not Result.Execution_Attempted, "multi-file open preparation does not execute actions");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "multi-file open preparation reports first selected path");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action_Executable),
         No_Op_Executable,
         "multi-file open preparation exposes first executable");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "multi-file open preparation clears stale error state");
      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "multi-file open executes actions");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "multi-file open reports first selected path");
      Assert (Result.Execution_Attempted, "multi-file open records process attempts");
      Assert (Result.Executable_Found, "multi-file open records executable discovery");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action_Executable),
         No_Op_Executable,
         "multi-file open exposes first action executable");
      Files_Suite.Support.Assert_Equal
        (Result.Action_Arguments,
         3,
         "multi-file open exposes first action argument count");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (2)),
         Join (Root, "Alpha.txt"),
         "multi-file open exposes first expanded action path");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Spawned,
         "multi-file open lifecycle records a spawned action");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "multi-file open clears stale error state");
   end Test_Open_Selected_File_Prepares_Action;

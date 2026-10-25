separate (Files_Suite.Operations)
   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Policy    : constant Files.Operations.Open_Action_Execution_Policy :=
        Files.Operations.Open_Action_Policy;
   begin
      Assert (Policy.Uses_Argument_Vector, "open-action policy requires argument vectors");
      Assert (Policy.Shell_Requires_Explicit_Opt_In, "open-action policy requires explicit shell opt-in");
      Assert (Policy.Checks_Executable_Before_Spawn, "open-action policy checks executables before spawn");
      Assert (Policy.Tracks_Execution_Attempt, "open-action policy tracks execution attempts");
      Assert (Policy.Tracks_Exit_Status, "open-action policy tracks exit status");
      Assert (Policy.Runs_Asynchronously, "open-action policy records asynchronous detached launches");
      Assert (not Policy.Supports_Cancellation, "open-action policy records cancellation limit");
      Assert
        (Policy.Rejects_Unsafe_Placeholders,
         "open-action policy records unsafe placeholder rejection");
      Assert (Policy.Reports_Missing_Action, "open-action policy records missing-action diagnostics");
      Assert
        (Policy.Reports_Missing_Executable,
         "open-action policy records missing-executable diagnostics");
      Assert
        (Policy.Captures_Executable_Discovery,
         "open-action policy records executable discovery capture");
      Assert (Policy.Captures_Process_Result, "open-action policy records process result capture");
      Assert (Policy.Quotes_Shell_Arguments, "open-action policy records shell argument quoting");
      Assert
        (Policy.Preserves_Vector_Boundaries,
         "open-action policy records argument vector boundary preservation");
      Assert (Policy.Multi_File_Deterministic, "open-action policy records deterministic multi-file execution");
      declare
         Generic_Failure : constant Files.Operations.Operation_Result :=
           (Status              => Files.Operations.Operation_Failed,
            Error_Key           => To_Unbounded_String ("error.directory.load"),
            Path                => To_Unbounded_String (Root),
            Action              =>
              Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            Action_Executable   => Null_Unbounded_String,
            Action_Arguments    => 0,
            Action_Uses_Shell   => False,
            Execution_Attempted => False,
            Executable_Found    => False,
            Exit_Status_Known   => False,
            Exit_Status         => 0);
      begin
         Assert
           (Files.Operations.Open_Action_Lifecycle_Of (Generic_Failure).State =
            Files.Operations.Open_Action_Not_Started,
            "generic failed operations are not classified as open-action preflight failures");
      end;
   end Test_Open_Action_Policy;

separate (Files_Suite.Operations)
   procedure Test_Open_Executable_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
      Lookup    : Files.Settings.Action_Lookup_Result;
   begin
      --  Keep the configured-action contracts deterministic; the host opener
      --  fallback would otherwise resolve unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Arguments.Append (To_Unbounded_String ("--readonly"));
      Arguments.Append (To_Unbounded_String ("{path}"));
      Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Model.Select_Visible (Model, 1);

      Files.Settings.Add_Open_Action
           (Settings,
            "text/plain",
            Files.Settings.Make_Action (Failing_Executable, Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "detached open action launches without surfacing app exit codes");
      Assert (Result.Execution_Attempted, "detached process result records execution attempt");
      Assert (Result.Executable_Found, "detached process result records executable discovery");
      --  This action's executable fails, and that is the point: a detached launch is
      --  reported as launched, and the application's own exit code is never seen.
      --  What used to be asserted here -- a known, zero exit status -- was the
      --  wrapper shell's, which succeeded in backgrounding a program that then went
      --  on to fail. Nothing waits for it now, so there is no status at all.
      Assert (not Result.Exit_Status_Known, "a detached process reports no exit status");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State = Files.Operations.Open_Action_Spawned,
         "detached process lifecycle records it as spawned, not completed");
      Assert
        (not Files.Operations.Open_Action_Lifecycle_Of (Result).Exit_Status_Known,
         "detached process lifecycle exposes no exit status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "detached open action clears localized error key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("/tmp/files_missing_open_action_executable", Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "missing open executable is represented");
      Assert (not Result.Execution_Attempted, "missing executable result does not attempt execution");
      Assert (not Result.Executable_Found, "missing executable result records failed lookup");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Preflight_Failed,
         "missing executable lifecycle records preflight failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.open_action.executable_missing",
         "missing open executable returns a specific diagnostic key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.open_action.executable_missing",
         "missing open executable stores specific diagnostic key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (Root, Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "directory open executable is represented");
      Assert (not Result.Execution_Attempted, "directory executable result does not attempt execution");
      Assert (not Result.Executable_Found, "directory executable result records failed lookup");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.open_action.executable_missing",
         "directory executable returns the missing executable diagnostic key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.open_action.executable_missing",
         "directory executable stores the missing executable diagnostic key");

      declare
         Unsafe_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Unsafe_Arguments.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-argument",
            Files.Settings.Make_Action (No_Op_Executable, Unsafe_Arguments));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-argument", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects embedded placeholders before operation preparation");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Error_Key),
            "error.open_action.missing",
            "rejected embedded-placeholder action is absent from lookup");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Current_Path (Model),
            Root,
            "unsafe open action does not navigate");

         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-executable",
            Files.Settings.Make_Action ("{path}", Files.Types.String_Vectors.Empty_Vector));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-executable", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects executable placeholders before operation preparation");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Error_Key),
            "error.open_action.missing",
            "rejected executable-placeholder action is absent from lookup");
      end;
   end Test_Open_Executable_Preflight;

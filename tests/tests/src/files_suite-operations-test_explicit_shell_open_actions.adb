separate (Files_Suite.Operations)
   procedure Test_Explicit_Shell_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shell_Arguments : Files.Settings.String_Vectors.Vector;
      Injected_Argument : Unbounded_String;

      --  How this host's shell separates two commands: cmd uses "&", sh uses ";".
      Shell_Command_Separator : constant String :=
        (if Files.Platform.Current_API_Profile.Adapter = Files.File_System.Native_Adapter_Windows
         then "&"
         else ";");
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
   begin
      --  Keep the configured-action contracts deterministic; the host opener
      --  fallback would otherwise resolve unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Files.Model.Select_Visible (Model, 1);

      --  An argument that tries to be a second command. Each shell has its own way
      --  of spelling that -- ";" for sh, "&" for cmd -- and the executable has to be
      --  one that exists on the host, which "true" is not on Windows. If the quoting
      --  holds, the whole thing stays one argument to Noop, which ignores it and
      --  exits zero; if it leaks, the shell runs "exit 9" and we see a 9.
      Injected_Argument :=
        To_Unbounded_String
          ("literal" & Shell_Command_Separator & " exit 9");
      Shell_Arguments.Append (Injected_Argument);
      Shell_Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (No_Op_Executable, Shell_Arguments, True));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "unmodified action fallback can be prepared");
      Assert (Result.Action.Use_Shell, "prepared fallback action preserves explicit shell execution");
      Assert (Result.Action_Uses_Shell, "prepared result exposes explicit shell flag");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Action.Arguments.Element (1)),
         To_String (Injected_Argument),
         "explicit shell action keeps the separator argument as one vector value");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "file open quotes explicit shell arguments before execution");
      Assert (Result.Action.Use_Shell, "explicit shell action remains explicit after execution");
      Assert (Result.Action_Uses_Shell, "executed shell result exposes explicit shell flag");
      Assert (Result.Execution_Attempted, "executed shell action records process attempt");
      Assert (not Result.Exit_Status_Known, "a detached shell action reports no exit status");

      --  The quoting is the point of this action. An exit code is the only way to
      --  see it hold, and a detached launch has none, so ask for the same action
      --  synchronously: it goes through the same quoting on the way in.
      declare
         Exit_Status : Integer := -1;
         Ran         : constant Boolean :=
           Files.Operations.Execute_Open_Action (Result.Action, Exit_Status);
      begin
         Assert (Ran, "the quoted shell action runs to completion when awaited");
         Files_Suite.Support.Assert_Equal
           (Exit_Status,
            0,
            "the separator stays inside one argument rather than running as a command; exit was "
            & Exit_Status'Image);
      end;

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, True));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "explicit shell action can execute shell builtins");
      Assert (Result.Action.Use_Shell, "shell builtin action preserves explicit shell execution");
      Assert (Result.Execution_Attempted, "shell builtin action records shell execution attempt");
      Assert (Result.Executable_Found, "shell builtin action records shell discovery");
      Assert (not Result.Exit_Status_Known, "a detached shell builtin reports no exit status");

      declare
         Exit_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Exit_Arguments.Append (To_Unbounded_String ("7"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/plain",
            Files.Settings.Make_Action ("exit", Exit_Arguments, True));
      end;
      --  "exit 7" is launched and let go, so its non-zero exit code is not surfaced.
      --  That was true before as well, but for a worse reason: the backgrounding
      --  wrapper shell exited zero and we reported *that*. Now nothing is reported.
      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Action_Executed,
         "detached explicit shell builtin launches fire-and-forget");
      Assert
        (Result.Execution_Attempted,
         "detached explicit shell builtin records a launch");
      Assert
        (Result.Executable_Found,
         "detached explicit shell builtin records successful shell lookup");
      Assert
        (not Result.Exit_Status_Known,
         "a detached launch does not surface the command's own exit code");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "detached explicit shell builtin clears stale error state");
   end Test_Explicit_Shell_Open_Actions;

separate (Files_Suite.Operations)
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Shell_Arguments : Files.Settings.String_Vectors.Vector;
      Injected_Argument : Unbounded_String;

      --  How this host's shell separates two commands: cmd uses "&", sh uses ";".
      Shell_Command_Separator : constant String :=
        (if Files.Platform.Current_API_Profile.Adapter = Files.File_System.Native_Adapter_Windows
         then "&"
         else ";");
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
      Routed    : Files.Controller.Controller_Result;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Policy    : constant Files.Operations.Open_Action_Execution_Policy :=
        Files.Operations.Open_Action_Policy;
   begin
      --  Exercise the configured-action and missing-action contracts
      --  deterministically; the host opener fallback would otherwise resolve
      --  unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
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
      Files.Model.Select_Visible (Model, 1);

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-preflight-marker");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         --  An action that leaves a trace if it runs, so the assertions below can
         --  prove nothing ran rather than take the result's word for it.
         --
         --  This was "/bin/sh -c touch <path>" -- two POSIX assumptions in one line.
         --  Windows has no /bin/sh, so this action failed on its own missing
         --  executable before the preflight reached the item the test is about.
         Preflight_Args.Append (To_Unbounded_String (Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action (Marker_Executable, Preflight_Args));
         --  Keep the missing-action preflight deterministic by opting out of
         --  the host opener fallback for the unmapped second selection.
         Preflight_Settings.Use_System_Default_Opener := False;
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result :=
           Files.Operations.Prepare_Open_Selected_Action (Preflight_Model, Preflight_Settings);
         Files_Suite.Support.Assert_Equal
           (Preflight_Result.Status,
            Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preparation preflights all actions");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file open preparation failure records no process attempt");
         Files_Suite.Support.Assert_Equal
           (To_String (Preflight_Result.Path),
            Join (Root, "Gamma.md"),
            "multi-file open preparation failure reports missing-action path");
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Files_Suite.Support.Assert_Equal
           (Preflight_Result.Status,
            Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preflights all actions before spawning");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
           "multi-file preflight failure does not execute earlier selected action");
      end;

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-executable-marker");
         Missing_Executable : constant String := Join (Root, "missing-open-executable");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         --  An action that leaves a trace if it runs, so the assertions below can
         --  prove nothing ran rather than take the result's word for it.
         --
         --  This was "/bin/sh -c touch <path>" -- two POSIX assumptions in one line.
         --  Windows has no /bin/sh, so this action failed on its own missing
         --  executable before the preflight reached the item the test is about.
         Preflight_Args.Append (To_Unbounded_String (Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action (Marker_Executable, Preflight_Args));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/markdown",
            Files.Settings.Make_Action (Missing_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Files_Suite.Support.Assert_Equal
           (Preflight_Result.Status,
            Files.Operations.Operation_Failed,
            "multi-file open preflights missing executables before spawning");
         Files_Suite.Support.Assert_Equal
           (To_String (Preflight_Result.Error_Key),
            "error.open_action.executable_missing",
            "multi-file executable preflight reports executable diagnostic");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file executable preflight failure records no process attempt");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
            "multi-file executable preflight failure does not execute earlier selected action");
      end;

      declare
         Detached_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Detached_Model    : Files.Model.Window_Model := Sample_Model;
         Detached_Result   : Files.Operations.Operation_Result;
      begin
         --  Open actions are now launched detached (fire-and-forget) through a
         --  backgrounding shell wrapper, so a launched application's own exit
         --  code is no longer observable: even /bin/false reports success
         --  because the wrapper shell itself exits zero after backgrounding.
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/plain",
            Files.Settings.Make_Action (No_Op_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/markdown",
            Files.Settings.Make_Action (Failing_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Detached_Model, 1);
         Files.Model.Toggle_Visible_Selection (Detached_Model, 3);
         Detached_Result := Files.Operations.Open_Selected (Detached_Model, Detached_Settings);
         Files_Suite.Support.Assert_Equal
           (Detached_Result.Status,
            Files.Operations.Operation_Action_Executed,
            "multi-file detached open succeeds without surfacing app exit codes");
         Files_Suite.Support.Assert_Equal
           (To_String (Detached_Result.Path),
            Join (Root, "Alpha.txt"),
            "multi-file detached open reports first selected path");
         Files_Suite.Support.Assert_Equal
           (To_String (Detached_Result.Action_Executable),
            No_Op_Executable,
            "multi-file detached open exposes first action executable");
         Assert
           (Detached_Result.Execution_Attempted,
            "multi-file detached open records process attempt");
         Assert
           (Detached_Result.Executable_Found,
            "multi-file detached open records executable discovery");
         --  There is no exit status to record. The launch does not wait, so what
         --  used to be asserted here was the wrapper shell's zero -- a number that
         --  said nothing whatever about the application.
         Assert
           (not Detached_Result.Exit_Status_Known,
            "a detached open has no exit status to report");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Detached_Model),
            "",
            "multi-file detached open clears stale error state");
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then
              Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then
              Ada.Environment_Variables.Value ("SHELL") else ""));

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", "/bin/custom-sh");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            --  The shell family follows the host, so a SHELL left over from
            --  MSYS2 or Cygwin does not switch Windows away from cmd.
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Executable,
               "cmd.exe",
               "Windows without COMSPEC falls back to cmd");
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Command_Option,
               "/C",
               "the cmd fallback uses the Windows command option");
         else
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Executable,
               "/bin/custom-sh",
               "explicit shell uses SHELL fallback");
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Command_Option,
               "-c",
               "SHELL fallback uses POSIX command option");
         end if;
         Ada.Environment_Variables.Set ("COMSPEC", "C:\Windows\System32\cmd.exe");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Executable,
               "C:\Windows\System32\cmd.exe",
               "explicit shell uses COMSPEC on Windows");
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Command_Option,
               "/C",
               "COMSPEC shell uses Windows command option");
         else
            --  COMSPEC is set on Linux machines that run Wine; it must not
            --  switch a POSIX host to cmd and its quoting.
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Executable,
               "/bin/custom-sh",
               "a COMSPEC in a POSIX environment does not replace the POSIX shell");
            Files_Suite.Support.Assert_Equal
              (Files.Operations.Shell_Command_Option,
               "-c",
               "a POSIX host keeps the POSIX command option");
         end if;
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then
              Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then
              Ada.Environment_Variables.Value ("SHELL") else ""));
         Missing_Shell_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Missing_Shell_Model    : Files.Model.Window_Model := Sample_Model;
         Missing_Shell_Action   : Files.Operations.Operation_Result;

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         --  The host decides which variable names the shell: COMSPEC on
         --  Windows, SHELL elsewhere. Point the host's own one at nothing.
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Ada.Environment_Variables.Set ("COMSPEC", Join (Root, "missing-shell"));
         else
            Ada.Environment_Variables.Clear ("COMSPEC");
            Ada.Environment_Variables.Set ("SHELL", Join (Root, "missing-shell"));
         end if;
         Files.Settings.Add_Open_Action
           (Missing_Shell_Settings,
            "text/plain",
            Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, Use_Shell => True));
         Files.Model.Select_Visible (Missing_Shell_Model, 1);
         Missing_Shell_Action := Files.Operations.Open_Selected (Missing_Shell_Model, Missing_Shell_Settings);
         Files_Suite.Support.Assert_Equal
           (Missing_Shell_Action.Status,
            Files.Operations.Operation_Failed,
            "explicit shell action fails preflight when shell executable is missing");
         Assert
           (not Missing_Shell_Action.Execution_Attempted,
            "missing shell executable is rejected before spawn");
         Assert
           (not Missing_Shell_Action.Executable_Found,
            "missing shell executable records failed executable lookup");
         Files_Suite.Support.Assert_Equal
           (To_String (Missing_Shell_Action.Error_Key),
            "error.open_action.executable_missing",
            "missing shell executable reports executable diagnostic");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Missing_Shell_Model),
            "error.open_action.executable_missing",
            "missing shell executable records model diagnostic");
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      Files.Model.Select_Visible (Model, 2);
      Files.Model.Focus_Filter_Input (Model);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Selection_Moved,
         "click selects item without opening");
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.No_Command,
         "selection click does not execute a command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "click selection updates selected visible index");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "item click clears text input focus");
      Routed := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Selection_Moved,
         "arrow key moves after item click");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "arrow key uses main view after item click");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/typed-path");
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 0);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Ignored,
         "outside item click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "outside item click preserves selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "outside item click preserves focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/typed-path",
         "outside item click preserves edited text");
      Files.Model.Cancel_Focus_Or_Edit (Model);
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
   end Test_Open_Selected_File_Prepares_Action;

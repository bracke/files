separate (Files_Suite.Operations)
   procedure Test_Multi_File_Open_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
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
   end Test_Multi_File_Open_Preflight;

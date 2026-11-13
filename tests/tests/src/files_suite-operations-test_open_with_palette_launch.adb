with Files.Model.Command_Palette;
separate (Files_Suite.Operations)
   procedure Test_Open_With_Palette_Launch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check is
      begin
         declare
            Model      : Files.Model.Window_Model;
            Targets    : Files.Types.String_Vectors.Vector;
            Routed     : Files.Controller.Controller_Result;
            Marker_One : constant String := Join (Root, "open-with-first-marker");
            Marker_Two : constant String := Join (Root, "open-with-second-marker");
         begin
            Targets.Append (To_Unbounded_String (Marker_One));
            Targets.Append (To_Unbounded_String (Marker_Two));
            Files.Model.Initialize
              (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
            Files.Model.Command_Palette.Open (Model);
            Files.Model.Command_Palette.Set_Open_With_Targets (Model, Targets);
            --  What the Open With command does: list the applications once.
            Files.Model.Command_Palette.Set_Open_With_Applications
              (Model, Files.Desktop_Applications.Available_Applications);
            Files.Model.Command_Palette.Set_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Command_Palette.Set_Query (Model, "Multi Target Marker");
            Files.Model.Command_Palette.Select_First (Model);

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Files_Suite.Support.Assert_Equal
              (Routed.Operation.Status,
               Files.Operations.Operation_Action_Executed,
               "Open With launches a single-target application for multiple selections: "
               & "status=" & Files.Operations.Operation_Status'Image (Routed.Operation.Status)
               & " attempted=" & Boolean'Image (Routed.Operation.Execution.Attempted)
               & " found=" & Boolean'Image (Routed.Operation.Execution.Executable_Found)
               & " exit=" & Integer'Image (Routed.Operation.Execution.Exit_Status)
               & " executable=" & To_String (Routed.Operation.Action.Executable) & ": status");
            Assert
              (Routed.Operation.Execution.Attempted,
               "Open With launches a single-target application for multiple selections: "
               & "status=" & Files.Operations.Operation_Status'Image (Routed.Operation.Status)
               & " attempted=" & Boolean'Image (Routed.Operation.Execution.Attempted)
               & " found=" & Boolean'Image (Routed.Operation.Execution.Executable_Found)
               & " exit=" & Integer'Image (Routed.Operation.Execution.Exit_Status)
               & " executable=" & To_String (Routed.Operation.Action.Executable) & ": attempted");
            Assert
              (Routed.Operation.Execution.Executable_Found,
               "Open With launches a single-target application for multiple selections: "
               & "status=" & Files.Operations.Operation_Status'Image (Routed.Operation.Status)
               & " attempted=" & Boolean'Image (Routed.Operation.Execution.Attempted)
               & " found=" & Boolean'Image (Routed.Operation.Execution.Executable_Found)
               & " exit=" & Integer'Image (Routed.Operation.Execution.Exit_Status)
               & " executable=" & To_String (Routed.Operation.Action.Executable) & ": executable found");
            Files_Suite.Support.Assert_Equal
              (To_String (Routed.Operation.Path),
               Marker_One,
               "a multi-launch result retains the first target's action metadata: path");
            Files_Suite.Support.Assert_Equal
              (Natural (Routed.Operation.Action.Arguments.Length),
               1,
               "a multi-launch result retains the first target's action metadata: argument count");
            Files_Suite.Support.Assert_Equal
              (To_String (Routed.Operation.Action.Arguments.First_Element),
               Marker_One,
               "a multi-launch result retains the first target's action metadata: first argument");

            for Attempt in Files_Suite.Support.Polling loop
               exit when Ada.Directories.Exists (Marker_One)
                 and then Ada.Directories.Exists (Marker_Two);
            end loop;
            Assert
              (Ada.Directories.Exists (Marker_One)
               and then Ada.Directories.Exists (Marker_Two),
               "Open With executes one %f launch for every selected target");
         end;

         declare
            Model   : Files.Model.Window_Model;
            Targets : Files.Types.String_Vectors.Vector;
            Routed  : Files.Controller.Controller_Result;
         begin
            Files.Model.Initialize
              (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Files.Model.Command_Palette.Open (Model);
            Files.Model.Command_Palette.Set_Open_With_Targets (Model, Targets);
            --  What the Open With command does: list the applications once.
            Files.Model.Command_Palette.Set_Open_With_Applications
              (Model, Files.Desktop_Applications.Available_Applications);
            Files.Model.Command_Palette.Set_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Command_Palette.Select_Last (Model);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Command_Palette.Selected_Id (Model),
               Natural (Files.Model.Command_Palette.Open_With_Applications (Model).Length),
               "the missing executable fixture, listed last, is selected from the Open With palette");

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Assert
              (Routed.Operation.Status = Files.Operations.Operation_Failed
               and then To_String (Routed.Operation.Error_Key) =
                 "error.open_action.executable_missing",
               "Open With reports a missing application executable as failure");
            Assert
              (not Routed.Operation.Execution.Attempted
               and then not Routed.Operation.Execution.Executable_Found,
               "Open With rejects the application before attempting a process");
            Assert
              (To_String (Routed.Operation.Path) = "/tmp/a file.txt"
               and then Natural (Routed.Operation.Action.Arguments.Length) = 1,
               "the failed Open With result retains its target and action metadata");
            Assert
              (Files.Model.Last_Error_Key (Model) =
                 "error.open_action.executable_missing"
               and then not Files.Model.Command_Palette.Is_Open (Model),
               "Open With exposes the diagnostic and closes the handled picker");
         end;
      end Check;
   begin
      With_Desktop_Application_Fixture (Check'Access);
   end Test_Open_With_Palette_Launch;

separate (Files_Suite.Operations)
   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Closing, Remaining : Files.Model.Window_Model;
      Closing_Watch, Remaining_Watch : Files.Refresh_Jobs.Watch_Session;
      Empty : Files.Process_Jobs.Session;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Started, Other_Started : Unbounded_String;
      Before : Instant;
      Step : Files.Operations.Operation_Result;
      Finished, Cancelled : Boolean;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      type Scenario_Kind is (Operation_Job, Transfer_Job, Refresh_Job);

      procedure Cleanup is
      begin
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Files.Application.Windows.Release_Window_Jobs (Remaining, Remaining_Watch);
      end Cleanup;

      procedure Await_Started (Path : String) is
      begin
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Path);
         end loop;
         Assert (Ada.Directories.Exists (Path), "the helper enters stalled work before window closure: " & Path);
      end Await_Started;

      procedure Attach_Operation (Model : in out Files.Model.Window_Model; Marker : out Unbounded_String) is
         Job : Files.Process_Jobs.Session;
      begin
         Files.Process_Jobs.Reserve (Job);
         Marker := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
         Files.Process_Jobs.Launch (Job, "--files-test-blocked");
         Await_Started (To_String (Marker));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
         Files.Model.Set_Background_Operation (Model, Job, "command.file.duplicate");
         Files.Process_Jobs.Reset (Job); --  The window is now its helper's only owner.
      end Attach_Operation;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TEST_STALL_READS");
      Files_Suite.Support.Save (Environment, "FILES_TEST_STALL_TRANSFERS");
      for Scenario in Scenario_Kind loop
         Reset_Root;
         Write_Binary_File (Join (Root, "source.txt"), "source bytes");
         Files.Model.Initialize (Closing, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Initialize (Remaining, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Set_Background_Transfers (Closing, True);
         Files.Model.Set_Background_Transfers (Remaining, True);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
                           (To_Unbounded_String (Join (Root, "source.txt")),
                            To_Unbounded_String (Join (Root, "destination.txt")), False, False));
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", "1");
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_TRANSFERS", Join (Root, "transfer-started"));
         Attach_Operation (Remaining, Other_Started);
         case Scenario is
            when Operation_Job => Attach_Operation (Closing, Started);
            when Transfer_Job =>
               Files.Model.Begin_Paste_Execution (Closing, Actions, Files.File_System.Drop_Copy);
               Step := Files.Operations.Advance_Paste_Execution (Closing, Settings, 1);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Files.Model.Paste_Execution_Is_Active (Closing), "start the stalled transfer");
               Await_Started (Join (Root, "transfer-started"));
               declare
                  Marker : Ada.Text_IO.File_Type;
               begin
                  Ada.Text_IO.Open (Marker, Ada.Text_IO.In_File, Join (Root, "transfer-started"));
                  Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (Marker), "started"));
                  Ada.Text_IO.Close (Marker);
               end;
               Await_Started (To_String (Started));
            when Refresh_Job =>
               Step := Files.Operations.Refresh (Closing, Settings);
               declare
                  Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Closing);
               begin
                  Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
                  Await_Started (To_String (Started));
               end;
         end case;
         Files.Refresh_Jobs.Watch_Path (Closing_Watch, Root);
         Before := Now;
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Assert_Within (Before, Prompt_Limit, "repeated window closure never joins stalled helpers");
         Assert
           (not Files.Model.Paste_Execution_Is_Active (Closing),
            "repeated window closure releases all of the window's jobs: paste released");
         Assert
           (not Files.Process_Jobs.Active (Files.Model.Background_Operation (Closing)),
            "repeated window closure releases all of the window's jobs: operation job released");
         Assert
           (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Closing)),
            "repeated window closure releases all of the window's jobs: refresh job released");
         declare
            Other : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Remaining);
         begin
            Files.Process_Jobs.Poll (Other, Finished, Cancelled);
            Assert (not Finished, "closing one window leaves the surviving window and its helper active: not finished");
            Assert
              (not Cancelled,
               "closing one window leaves the surviving window and its helper active: not cancelled");
            Assert
              (Files.Model.Paste_Execution_Is_Active (Remaining),
               "closing one window leaves the surviving window and its helper active: surviving paste active");
            Assert
              (Ada.Directories.Exists (To_String (Other_Started)),
               "closing one window leaves the surviving window and its helper active: surviving helper still running");
         end;
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Started));
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Started)),
                 "the closed window's helper is terminated and reaped while another window stays open");
         Assert (File_Has_Bytes (Join (Root, "source.txt"), "source bytes")
                 and then not Ada.Directories.Exists (Join (Root, "destination.txt")),
                 "a stopped stalled transfer never writes after its window closes");
         Files.Application.Windows.Release_Window_Jobs (Remaining, Remaining_Watch);
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Other_Started));
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Other_Started)),
                 "the surviving helper also closes independently");
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Window_Job_Shutdown;

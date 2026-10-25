separate (Files_Suite.Operations)
   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Watch : Files.Refresh_Jobs.Watch_Session;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Before : Instant;
      Started : Unbounded_String;
      Paths, Sources : Files.Types.String_Vectors.Vector;
      Action : Files.Model.Undo_Entry;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_OPERATIONS");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "");
      Old_Xdg : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      --  The stalled helper never finishes, so a command that waited for it
      --  would hang; the limit bounds only the launch, a process spawn that
      --  takes about half a second on the slow Windows and macOS Intel runners.
      type Kind is (Trash_Job, Delete_Job, Restore_Job, Empty_Job, Undo_Job, Redo_Job);
      procedure Restore is
      begin
         Files.Application.Windows.Release_Window_Jobs (Model, Watch);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
         end if;
      end Restore;
   begin
      for Job_Kind in Kind loop
         Reset_Root;
         Write_Binary_File (Join (Root, "victim.txt"), "victim bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, True);
         Select_Name (Model, "victim.txt");
         Paths.Clear;
         Sources.Clear;
         Paths.Append (To_Unbounded_String (Join (Root, "victim.txt")));
         if Job_Kind = Undo_Job then
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Paths, Sources, Redoable => False);
         elsif Job_Kind = Redo_Job then
            Sources := Paths;
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Join (Root, "new-copy.txt")));
            Action := (Kind => Files.Model.Undo_Delete_Created, From => Paths, Forward => Sources,
                       Create_Kind => Files.Model.Create_Copy, others => <>);
            Files.Model.Push_Redo (Model, Action);
         end if;
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
         Before := Now;
         Step :=
           (case Job_Kind is
               when Trash_Job => Files.Operations.Delete_Selected (Model, Settings),
               when Delete_Job => Files.Operations.Delete_Selected_Permanently (Model, Settings),
               when Restore_Job => Files.Operations.Restore_Selected_From_Trash (Model, Settings),
               when Empty_Job => Files.Operations.Empty_Trash (Model, Settings),
               when Undo_Job => Files.Operations.Undo_Last (Model, Settings),
               when Redo_Job => Files.Operations.Redo_Last (Model, Settings));
         --  Three checks, each naming itself: a failure on a slow runner
         --  has to say which one it was and how long the launch took.
         declare
            Taken : constant Span := Elapsed (Before);
         begin
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               Kind'Image (Job_Kind) & " command did not launch: "
               & Files.Operations.Operation_Status'Image (Step.Status)
               & " " & To_String (Step.Error_Key));
            Assert_Within (Taken, Prompt_Limit, Kind'Image (Job_Kind) & " command returns before its helper finishes");
            Assert (Files.Model.Paste_Execution_Is_Active (Model),
                    Kind'Image (Job_Kind) & " command left no background job running");
         end;
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
         begin
            Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
         end;
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (To_String (Started));
         end loop;
         Assert (Ada.Directories.Exists (To_String (Started)), "the destructive helper reaches stalled work");
         if Job_Kind = Undo_Job then
            Files.Operations.Cancel_Paste_Execution (Model);
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
         else
            Before := Now;
            Files.Application.Windows.Release_Window_Jobs (Model, Watch);
            Assert_Within (Before, Prompt_Limit, "window closure never joins a stalled destructive helper");
         end if;
         Assert (File_Has_Bytes (Join (Root, "victim.txt"), "victim bytes")
                 and then not Ada.Directories.Exists (Join (Root, "new-copy.txt"))
                 and then Files.Model.Undo_Available (Model) = (Job_Kind = Undo_Job)
                 and then Files.Model.Redo_Available (Model) = (Job_Kind = Redo_Job),
                 "cancellation before execution preserves source bytes and both history stacks");
         Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
      end loop;
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "private-trash"));
      Write_Binary_File (Join (Root, "victim.txt"), "victim bytes");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Clear_Undo (Model);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success and then Files.Model.Undo_Available (Model)
              and then not Ada.Directories.Exists (Join (Root, "victim.txt")),
              "background trash records complete Undo");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then File_Has_Bytes (Join (Root, "victim.txt"), "victim bytes"),
              "background Undo restores trash bytes");
      Select_Name (Model, "victim.txt");
      Ada.Directories.Delete_File (Join (Root, "victim.txt"));
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      for Index in 1 .. Files.Model.Item_Count (Model) loop
         Assert (Files.Model.Visible_Item (Model, Index).Name /= To_Unbounded_String ("victim.txt"),
                 "a failed destructive operation relists the vanished source without invalidating its own refresh");
      end loop;
      Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Last_Error_Key (Model) /= "",
              "the failed operation's error survives its successful background refresh");
      Write_Binary_File (Join (Root, "victim.txt"), "restorable bytes");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Paths := Files.Model.Undo_From_Paths (Model);
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Navigate_To (Model, Files.File_System.Trash_Files_Directory, Load.Items);
      Select_Name (Model, Ada.Directories.Simple_Name (To_String (Paths.First_Element)));
      Step := Complete_Operation (Model, Settings, Files.Operations.Restore_Selected_From_Trash (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then File_Has_Bytes (Join (Root, "victim.txt"), "restorable bytes"),
              "the background restore command restores the complete original");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected_Permanently (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (Join (Root, "victim.txt")),
              "background permanent deletion removes its selected source");
      Write_Binary_File (Join (Root, "victim.txt"), "empty trash bytes");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Paths := Files.Model.Undo_From_Paths (Model);
      Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (To_String (Paths.First_Element)),
              "background empty trash purges only the private test trash backend");
      Files.Model.Set_Background_Transfers (Model, False);
      Files.Model.Clear_Undo (Model);
      Write_Binary_File (Join (Root, "checkpoint-target"), "preserve original bytes");
      Paths.Clear;
      Sources.Clear;
      Paths.Append (To_Unbounded_String (Join (Root, "checkpoint-target")));
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Paths, Sources, Redoable => False);
      Write_Binary_File (Join (Root, "blocked-transport"), "a file cannot hold a checkpoint");
      Files.Job_Context.Initialize (Join (Root, "blocked-transport"));
      Step := Files.Operations.Undo_Last (Model, Settings);
      Files.Job_Context.Initialize ("");
      Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
              and then File_Has_Bytes (Join (Root, "checkpoint-target"), "preserve original bytes"),
              "a checkpoint failure before mutation retains both the original and its retriable Undo action");
      Step := Files.Operations.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (Join (Root, "checkpoint-target")),
              "Undo retries successfully once checkpoint transport is available");
      Restore;
   exception
      when others => Files.Job_Context.Initialize (""); Restore; raise;
   end Test_Destructive_Helper_Lifecycle;

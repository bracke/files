separate (Files_Suite.Operations)
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Other    : constant String := Join (Root, "other-view");
      Had_Stall : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_OPERATIONS");
      Old_Stall : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "");
      Had_Kind_Fault : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH");
      Old_Kind_Fault : constant String :=
        Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH", "");
      Had_Recent_Fault : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH");
      Old_Recent_Fault : constant String :=
        Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH", "");

      procedure Restore_Stall is
      begin
         if Had_Stall then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", Old_Stall);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
         end if;
      end Restore_Stall;

      procedure Restore_Kind_Fault is
      begin
         if Had_Kind_Fault then
            Ada.Environment_Variables.Set
              ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH", Old_Kind_Fault);
         else
            Ada.Environment_Variables.Clear
              ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH");
         end if;
      end Restore_Kind_Fault;

      procedure Restore_Recent_Fault is
      begin
         if Had_Recent_Fault then
            Ada.Environment_Variables.Set
              ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH",
               Old_Recent_Fault);
         else
            Ada.Environment_Variables.Clear
              ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH");
         end if;
      end Restore_Recent_Fault;

      procedure Finish is
      begin
         Assert (Files.Model.Paste_Execution_Is_Active (Model),
                 "a long operation returns with its progress overlay open");
         for Attempt in Files_Suite.Support.Polling loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
         end loop;
         Assert (not Files.Model.Paste_Execution_Is_Active (Model),
                 "the UI collects the helper result without blocking");
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "the background operation completes successfully");
      end Finish;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "needle");
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Join (Root, "nested"), "needle-name.txt"), "needle");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "a.txt");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Finish;
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Root, "a (copy).txt")),
         "needle",
         "background duplicate copies bytes");
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
              "a (copy).txt")),
              "background duplicate records Undo on the owning window");
      for Format in Files.Operations.Archive_Format loop
         Select_Name (Model, "a.txt");
         Step := Files.Operations.Compress_Selected (Model, Settings, Format);
         Finish;
         declare
            Archive : constant String :=
              (if Format = Files.Operations.Zip_Archive then "a.zip" else "a.7z");
         begin
            Assert (Ada.Directories.Exists (Join (Root, Archive)),
                    "background compression publishes a complete archive");
            Select_Name (Model, Archive);
            Step := Files.Operations.Extract_Selected (Model, Settings);
            Finish;
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File (Join (Join (Root, "a"), "a.txt")),
               "needle",
               "background extraction publishes the complete directory");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
                    "a")),
                    "background extraction is undoable");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (Join (Root, Archive)),
                    "background archive creation is undoable: " & Archive
                    & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                    & " error=" & To_String (Step.Error_Key)
                    & " exists=" & Boolean'Image (Ada.Directories.Exists (Join (Root, Archive))));
         end;
      end loop;
      Files.Model.Set_Filter (Model, "needle");
      Step := Files.Operations.Run_Recursive_Search (Model, Settings);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
              "background name search returns recursive results");
      Step := Files.Operations.Run_Content_Search (Model, Settings);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 2
                and then Files.Model.Visible_Count (Model) = 2,
              "background content search returns matches regardless of filename");
      Files.Model.Set_Filter (Model, "");
      Step := Files.Operations.Refresh (Model, Settings);
      Select_Name (Model, "a.txt");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Marker : constant String := Files.Process_Jobs.Path (Job, "started");
      begin
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Marker);
         end loop;
         Assert (Ada.Directories.Exists (Marker),
                 "the duplicate helper reaches the pre-work cancellation point");
      end;
      Restore_Stall;
      Files.Operations.Cancel_Paste_Execution (Model);
      Finish;
      Assert (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
              "cancellation before work publishes no duplicate");

      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "a.txt");
      Ada.Directories.Create_Directory (Other);
      Write_Binary_File (Join (Other, "other.txt"), "other");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the duplicate result is ready before the view changes");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Finish;
      Assert
        (Files.Model.Current_Path (Model) = Other
         and then Files.Model.Item_Count (Model) = 1
         and then To_String (Files.Model.Visible_Item (Model, 1).Name) = "other.txt",
         "a completed operation cannot replace a newer directory view with its old snapshot");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "the stale-view duplicate still publishes its file and recoverable history");
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (not Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Current_Path (Model) = Other
         and then Files.Model.Item_Count (Model) = 1,
         "undoing the stale-view operation leaves the newer directory view intact");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);

      Select_Name (Model, "a.txt");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the duplicate result is ready before the round-trip navigation");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Finish;
      Assert
        (Files.Model.Current_Path (Model) = Root
         and then Files.Model.Temporary_Item_Is_Active (Model)
         and then Files.Model.Last_Error_Key (Model) =
           "error.trash.restore_exists",
         "an old result cannot overwrite a newer incarnation of the same directory view");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "the round-trip stale result retains its file and Undo history");
      Files.Model.Cancel_Create_File (Model);
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
         "the round-trip stale operation remains safely undoable");

      Select_Name (Model, "a.txt");
      Step := Files.Operations.Delete_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the destructive result is ready before the view changes");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Finish;
      Assert
        (Files.Model.Current_Path (Model) = Other
         and then Files.Model.Temporary_Item_Is_Active (Model)
         and then Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists"
         and then not Files.Process_Jobs.Active
           (Files.Model.Background_Refresh (Model)),
         "an old destructive result cannot refresh or alter newer view state");
      Assert
        (not Ada.Directories.Exists (Join (Root, "a.txt"))
         and then Files.Model.Undo_Available (Model),
         "the stale-view destructive result retains its mutation and Undo history");
      Files.Model.Cancel_Create_File (Model);
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (Ada.Directories.Exists (Join (Root, "a.txt"))
         and then Files.Model.Current_Path (Model) = Other
         and then Files.Model.Item_Count (Model) = 1,
         "undoing the stale destructive result leaves the newer view intact");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);

      Step := Files.Operations.Refresh (Model, Settings);
      Files.Model.Clear_Search_Results (Model);
      Select_Name (Model, "a.txt");
      Ada.Environment_Variables.Set
        ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH", "1");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Restore_Kind_Fault;
      Assert
        (not Files.Model.Paste_Execution_Is_Active (Model)
         and then Step.Status = Files.Operations.Operation_Failed
         and then not Files.Model.Search_Results_Are_Active (Model),
         "a helper result whose operation kind differs from its request is rejected");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "kind-mismatch recovery retains the committed duplicate and its Undo");
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      --  Flaked once on macOS Intel CI with nothing beside it: name what failed.
      Assert
        (Step.Status = Files.Operations.Operation_Success
         and then not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
         "the recovered duplicate can still be undone safely: "
         & Files.Operations.Operation_Status'Image (Step.Status) & " " & To_String (Step.Error_Key)
         & (if Ada.Directories.Exists (Join (Root, "a (copy).txt")) then " copy-present" else " copy-gone"));

      Select_Name (Model, "a.txt");
      Ada.Environment_Variables.Set
        ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH", "1");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Restore_Recent_Fault;
      Assert
        (not Files.Model.Paste_Execution_Is_Active (Model)
         and then Step.Status = Files.Operations.Operation_Failed
         and then not Files.Model.In_Recent_View (Model),
         "a helper result whose Recent-view flag differs from its request is rejected");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "Recent-mismatch recovery retains the committed duplicate and its Undo");
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Step.Status = Files.Operations.Operation_Success
         and then not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
         "the duplicate recovered from a Recent mismatch remains safely undoable");
   exception
      when others =>
         Restore_Stall;
         Restore_Kind_Fault;
         Restore_Recent_Fault;
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Background_Operations;

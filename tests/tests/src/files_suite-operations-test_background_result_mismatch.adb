separate (Files_Suite.Operations)
   procedure Test_Background_Result_Mismatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
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
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "needle");
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Join (Root, "nested"), "needle-name.txt"), "needle");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
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
         Restore_Kind_Fault;
         Restore_Recent_Fault;
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Background_Result_Mismatch;

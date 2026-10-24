separate (Files_Suite.Operations)
   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Applied  : Boolean;

      procedure Await_Job (Job : Files.Process_Jobs.Session; What : String) is
         Finished, Cancelled : Boolean := False;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled, What);
      end Await_Job;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);

      --  An operation that finishes after an edit in the same view (here a new
      --  diagnostic) cannot apply its old snapshot, but must still relist.
      Select_Name (Model, "a.txt");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Await_Job (Files.Model.Background_Operation (Model), "the duplicate helper finishes");
      Files.Model.Set_Error (Model, "error.undo.failed");
      for Attempt in Files_Suite.Support.Polling loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Assert (Step.Status = Files.Operations.Operation_Success, "the duplicate completes");
      Await_View (Model, Settings);
      Assert (Files.Model.Item_Count (Model) = 2,
              "an operation outliving an edit in its own view still relists that view");

      --  A forced refresh outdated by an edit is discarded but owed, and the
      --  owed reload keeps the newer diagnostic.
      Write_Binary_File (Join (Root, "late.txt"), "late");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Job (Files.Model.Background_Refresh (Model), "the refresh helper finishes");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Applied := Files.Refresh_Jobs.Advance (Model, Settings);
      Assert (not Applied and then Files.Model.Item_Count (Model) = 2,
              "a read outdated by an edit is not applied");
      Assert (Files.Model.Refresh_Is_Owed (Model) and then Files.Model.Owed_Refresh_Force (Model),
              "the discarded forced read leaves a forced reload owed");
      Files.Refresh_Jobs.Resume_Owed (Model, Settings);
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
              and then not Files.Model.Refresh_Is_Owed (Model),
              "resuming relaunches the owed reload and settles the debt");
      Await_View (Model, Settings);
      Assert (Files.Model.Item_Count (Model) = 3
              and then Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists",
              "the owed reload lists the new file and keeps the newer diagnostic");

      --  Navigation loads the new view itself, so it cancels the debt.
      Write_Binary_File (Join (Root, "later.txt"), "later");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Job (Files.Model.Background_Refresh (Model), "the second refresh helper finishes");
      Files.Model.Set_Error (Model, "");
      Applied := Files.Refresh_Jobs.Advance (Model, Settings);
      Assert (Files.Model.Refresh_Is_Owed (Model), "the outdated read is owed again");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Assert (not Files.Model.Refresh_Is_Owed (Model),
              "navigating, even to the same path, makes an owed reload moot");
   exception
      when others =>
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Owed_Reloads;

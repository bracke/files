with Files_Suite.Listings;
with Files.Model.Jobs;
with Files.Operation_Results;
with Files_Suite.Support.Timing;
with Files_Suite.Support.Models;
separate (Files_Suite.Refresh)
   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Applied  : Boolean;

      procedure Await_Job (Job : Files.Jobs.Process.Session; What : String) is
         Finished, Cancelled : Boolean := False;
      begin
         for Attempt in Files_Suite.Support.Timing.Polling loop
            Files.Jobs.Process.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled, What);
      end Await_Job;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Jobs.Set_Background_Transfers (Model, True);

      --  An operation that finishes after an edit in the same view (here a new
      --  diagnostic) cannot apply its old snapshot, but must still relist.
      Select_Name (Model, "a.txt");
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      Await_Job (Files.Model.Jobs.Background_Operation (Model), "the duplicate helper finishes");
      Files.Model.Set_Error (Model, "error.undo.failed");
      Step := Files_Suite.Support.Models.Finish_Paste (Model, Settings);
      Files_Suite.Support.Assert_Equal (Step.Status, Files.Operation_Results.Operation_Success,
                                        "the duplicate completes");
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         2,
         "an operation outliving an edit in its own view still relists that view");

      --  A forced refresh outdated by an edit is discarded but owed, and the
      --  owed reload keeps the newer diagnostic.
      Write_Binary_File (Join (Root, "late.txt"), "late");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Job (Files.Model.Jobs.Background_Refresh (Model), "the refresh helper finishes");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Applied := Files.Refresh.Advance (Model, Settings);
      Assert (not Applied and then Files.Model.Item_Count (Model) = 2,
              "a read outdated by an edit is not applied");
      Assert (Files.Model.Refresh_Is_Owed (Model) and then Files.Model.Owed_Refresh_Force (Model),
              "the discarded forced read leaves a forced reload owed");
      Files.Refresh.Resume_Owed (Model, Settings);
      Assert (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model))
              and then not Files.Model.Refresh_Is_Owed (Model),
              "resuming relaunches the owed reload and settles the debt");
      Await_View (Model, Settings);
      Assert (Files.Model.Item_Count (Model) = 3
              and then Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists",
              "the owed reload lists the new file and keeps the newer diagnostic");

      --  A modal job starting while a read runs cancels the read, and owes it:
      --  the job's own result need not cover it.
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Job (Files.Model.Jobs.Background_Refresh (Model), "the refresh helper finishes before the job");
      declare
         Idle : Files.Jobs.Process.Session;
      begin
         Files.Model.Jobs.Begin_Operation_Job (Model, Idle, "operation.duplicate");
      end;
      Applied := Files.Refresh.Advance (Model, Settings);
      Assert (not Applied and then Files.Model.Refresh_Is_Owed (Model),
              "a read cancelled by a modal job is owed");
      Files.Model.Jobs.End_Foreground_Job (Model);
      Files.Refresh.Resume_Owed (Model, Settings);
      Await_View (Model, Settings);
      Assert (not Files.Model.Refresh_Is_Owed (Model), "the owed read runs once the job is done");

      --  Navigation loads the new view itself, so it cancels the debt.
      Write_Binary_File (Join (Root, "later.txt"), "later");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Job (Files.Model.Jobs.Background_Refresh (Model), "the second refresh helper finishes");
      Files.Model.Set_Error (Model, "");
      Applied := Files.Refresh.Advance (Model, Settings);
      Assert (Files.Model.Refresh_Is_Owed (Model), "the outdated read is owed again");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Assert (not Files.Model.Refresh_Is_Owed (Model),
              "navigating, even to the same path, makes an owed reload moot");
   exception
      when others =>
         Files.Refresh.Cancel (Model);
         raise;
   end Test_Owed_Reloads;

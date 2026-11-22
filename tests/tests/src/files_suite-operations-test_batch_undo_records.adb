with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Operations.Undo_Recording;
with Files.Operations.Undo_Recording.Testing;
with Ada.Exceptions;
with Files.File_System.Testing;
with Files_Suite.Support.Guards;
with Files.Text_Basics;

separate (Files_Suite.Operations)
   --  A batch records its Undo entry at once and then at most once a second,
   --  not once per item; a trash and a link batch too, and it undoes completely. A batch
   --  none of whose items can be verified for Undo still succeeds, but says
   --  so ("undo.unavailable"), and does not retry the record on every item.
   --  The throttle's clock is the suite's fake one, so "a second has passed"
   --  is the test's to decide, however long the runner takes.
   procedure Test_Batch_Undo_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Count       : constant := 12;
      Trash_Home  : constant String := Root & "_batch_undo_xdg";
      Model       : Files.Model.Window_Model;
      Step        : Files.Operation_Results.Operation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;

      function Name (Index : Positive) return String is
        ("item-" & Files.Text_Basics.Natural_Text (Index) & ".txt");

      --  Restores the real clock and the counters, and removes the trash
      --  the test made; never raises, so it can run on the failure path.
      procedure Cleanup is
      begin
         Files.Operations.Testing.Fake_Checkpoint_Clock (False);
         Files.Operations.Undo_Recording.Testing.Count_Undo_Records (False);
         Files.File_System.Testing.Refuse_Creation_Matches (False);
         Project_Tools.Files.Delete_Tree (Trash_Home);
      exception
         when Cleanup_Failed : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "batch undo cleanup: " & Ada.Exceptions.Exception_Information (Cleanup_Failed));
      end Cleanup;

      --  The batch read the fake clock once per item and once at its end,
      --  so the clock the throttle used is the fake one.
      procedure Assert_Clock_Read (What : String) is
      begin
         Files_Suite.Support.Assert_Equal
           (Files.Operations.Testing.Checkpoint_Clock_Readings, Count + 1,
            What & " reads the throttle's clock once per item and once at its end");
      end Assert_Clock_Read;

      --  A fresh folder of Count small files, all selected, and no history.
      --  Advance_At is the clock reading (one per item) at which a second
      --  passes, or zero for none during the batch.
      procedure Prepare (Advance_At : Natural := 0) is
         Load : Files.File_System.Directory_Load_Result;
      begin
         Reset_Root;
         for Index in 1 .. Count loop
            Write_Binary_File (Join (Root, Name (Index)), "bytes");
         end loop;
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Selection.Select_All_Visible (Model);
         Files.Operations.Undo_Recording.Testing.Count_Undo_Records (True);
         Files.Operations.Testing.Fake_Checkpoint_Clock (True, Advance_At);
      end Prepare;

      function Copies_Present return Natural is
         Present : Natural := 0;
      begin
         for Index in 1 .. Count loop
            if Ada.Directories.Exists
                (Join (Root, "item-" & Files.Text_Basics.Natural_Text (Index) & " (copy).txt"))
            then
               Present := Present + 1;
            end if;
         end loop;
         return Present;
      end Copies_Present;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");

      --  Duplicate: twelve copies within one second of the throttle's
      --  clock are recorded exactly twice -- at the first copy, so an Undo
      --  exists from the start, and at the end, for the rest.
      Prepare;
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the duplicate succeeds");
      Files_Suite.Support.Assert_Equal (Copies_Present, Count, "every item is duplicated");
      Assert_Clock_Read ("the duplicate");
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Undo_Recording.Testing.Undo_Records, 2,
         "the duplicate records its entry at its first item and at its end, not once per item");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "the duplicate is one Undo entry");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_From_Paths (Model).Length), Count, "the entry covers every copy");
      Assert (Files.Model.Last_Error_Key (Model) = "", "a recorded Undo shows no notice");
      Step := Operation_Commands.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the duplicate undoes");
      Files_Suite.Support.Assert_Equal (Copies_Present, 0, "Undo removes every copy");

      --  A second passing mid-batch (at the sixth copy) adds exactly one
      --  record there; the entry still ends up one, covering every copy.
      Prepare (Advance_At => 6);
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the slower duplicate succeeds");
      Files_Suite.Support.Assert_Equal (Copies_Present, Count, "every item is duplicated again");
      Assert_Clock_Read ("the slower duplicate");
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Undo_Recording.Testing.Undo_Records, 3,
         "a second passing mid-batch adds exactly one record");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "the slower duplicate is one Undo entry");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_From_Paths (Model).Length), Count, "that entry covers every copy");
      Step := Operation_Commands.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the slower duplicate undoes");
      Files_Suite.Support.Assert_Equal (Copies_Present, 0, "Undo removes every copy again");

      --  Trash: the same throttle, and one Undo brings every item back.
      Prepare;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Step := Operation_Commands.Delete_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the trash batch succeeds");
      for Index in 1 .. Count loop
         Assert (not Ada.Directories.Exists (Join (Root, Name (Index))), "item" & Index'Image & " is trashed");
      end loop;
      Assert_Clock_Read ("the trash batch");
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Undo_Recording.Testing.Undo_Records, 2,
         "the trash batch records its entry at its first item and at its end");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "the trash batch is one Undo entry");
      Step := Operation_Commands.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the trash batch undoes");
      for Index in 1 .. Count loop
         Assert (File_Has_Bytes (Join (Root, Name (Index)), "bytes"), "item" & Index'Image & " is restored");
      end loop;
      Assert (not Files.Model.History.Undo_Available (Model), "one Undo restored the whole batch");
      Project_Tools.Files.Delete_Tree (Trash_Home);

      --  No copy can be verified: the duplicate stands, without Undo, and
      --  says so; the refused record is not retried on every item.
      Prepare;
      Files.File_System.Testing.Refuse_Creation_Matches (True);
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "an unverifiable duplicate still succeeds");
      Files_Suite.Support.Assert_Equal (Copies_Present, Count, "every unverifiable copy stays");
      Assert (not Files.Model.History.Undo_Available (Model), "no Undo is recorded for unverifiable copies");
      Assert (Files.Model.Last_Error_Key (Model) = "undo.unavailable",
              "the missing Undo is reported, not passed over: " & Files.Model.Last_Error_Key (Model));
      Assert_Clock_Read ("the unverifiable duplicate");
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Undo_Recording.Testing.Undo_Records, 2,
         "a refused record is tried at the first item and retried only at the end");
      Files.File_System.Testing.Refuse_Creation_Matches (False);

      --  Links are such a batch too: recorded at the first link and at the
      --  end, undone whole, and a missing Undo said as for the others. (Hard
      --  links: every runner may make them.)
      Prepare;
      Step := Files.Operations.Create_Hardlink_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "the links are made");
      Assert_Clock_Read ("the link batch");
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Undo_Recording.Testing.Undo_Records, 2,
         "a link batch is recorded at its first link and at its end");
      Assert (Files.Model.History.Undo_Available (Model), "the links can be undone");
      Prepare;
      Files.File_System.Testing.Refuse_Creation_Matches (True);
      Step := Files.Operations.Create_Hardlink_Selected (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success, "unverifiable links still stand");
      Assert (not Files.Model.History.Undo_Available (Model), "no Undo is recorded for unverifiable links");
      Assert (Files.Model.Last_Error_Key (Model) = "undo.unavailable",
              "a link batch's missing Undo is reported: " & Files.Model.Last_Error_Key (Model));
      Cleanup;
      Reset_Root;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Batch_Undo_Records;

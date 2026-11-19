with Files.Model.Testing;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files_Suite.Support.Guards;
separate (Files_Suite.Transfer)
   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "exec-src");
      Dest_Dir : constant String := Join (Root, "exec-dest");
      Count    : constant := 5;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Step     : Files.Operation_Results.Operation_Result;

      function Src (N : Positive) return String is (Numbered_File (Src_Dir, N));
      function Dest (N : Positive) return String is (Numbered_File (Dest_Dir, N));
   begin
      Arm_Numbered_Paste (Model, Settings, Src_Dir, Dest_Dir, Count);
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "arming a paste execution activates it");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Total (Model),
         Count,
         "the total counts every write action");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Done (Model),
         0,
         "nothing is done before the first advance");

      --  Max_Items = 2 over 5 actions => completes after ceil(5 / 2) = 3 calls.
      Step := Files.Foreground_Jobs.Advance (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "the first batch reports success");
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "the execution is still in progress after one batch");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Done (Model),
         2,
         "the first batch completes two writes");

      Step := Files.Foreground_Jobs.Advance (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "the second batch reports success");
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "the execution is still in progress after two batches");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Done (Model),
         4,
         "progress advances to four writes");

      Step := Files.Foreground_Jobs.Advance (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "the third batch reports success");
      Assert (not Files.Model.Foreground_Job_Is_Active (Model), "the third batch finalizes the execution");

      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Dest (N)), "every source is copied to the destination");
         Assert (Ada.Directories.Exists (Src (N)), "a copy leaves the sources in place");
      end loop;

      Assert (Files.Model.History.Undo_Available (Model), "the completed paste records an undo");
      Assert
        (Files.Model.Testing.Undo_Kind_Of (Model) = Files.Undo_History.Undo_Delete_Created,
         "a copy paste is undone by deleting the created copies");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_From_Paths (Model).Length),
         Count,
         "one undo covers the whole completed set");

      Step := Complete_Operation
                       (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Step.Status, Files.Operation_Results.Operation_Success,
                                        "undo of the paste succeeds");
      for N in 1 .. Count loop
         Assert (not Ada.Directories.Exists (Dest (N)), "undo removes each pasted copy");
      end loop;
   end Test_Paste_Execution_Batches;

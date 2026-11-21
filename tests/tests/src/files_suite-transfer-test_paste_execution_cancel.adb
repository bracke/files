with Files.Model.Testing;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files_Suite.Support.Guards;
separate (Files_Suite.Transfer)
   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "cancel-src");
      Dest_Dir : constant String := Join (Root, "cancel-dest");
      Count    : constant := 4;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Step     : Files.Operation_Results.Operation_Result;

      function Src (N : Positive) return String is (Numbered_File (Src_Dir, N));
      function Dest (N : Positive) return String is (Numbered_File (Dest_Dir, N));
   begin
      Arm_Numbered_Paste (Model, Settings, Src_Dir, Dest_Dir, Count);

      Step := Files.Jobs.Foreground.Advance (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "the first batch reports success");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Done (Model),
         2,
         "two writes complete before cancelling");

      Files.Jobs.Foreground.Cancel (Model);
      Step := Files.Jobs.Foreground.Advance (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "a cancelled paste finalizes without an error");
      Assert (not Files.Model.Foreground_Job_Is_Active (Model), "a cancelled paste finalizes on the next advance");

      Assert (Ada.Directories.Exists (Dest (1)), "the first completed copy is kept");
      Assert (Ada.Directories.Exists (Dest (2)), "the second completed copy is kept");
      Assert (not Ada.Directories.Exists (Dest (3)), "cancelling writes none of the remaining sources");
      Assert (not Ada.Directories.Exists (Dest (4)), "cancelling writes none of the remaining sources");
      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Src (N)), "all sources remain after a cancelled copy");
      end loop;

      Assert
        (Files.Model.History.Undo_Available (Model), "a cancelled paste still records an undo for completed items");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_From_Paths (Model).Length),
         2,
         "the undo covers only the two completed writes");

      Step := Complete_Operation
                       (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "undo of the cancelled paste succeeds");
      Assert (not Ada.Directories.Exists (Dest (1)), "undo removes the first completed copy");
      Assert (not Ada.Directories.Exists (Dest (2)), "undo removes the second completed copy");
   end Test_Paste_Execution_Cancel;

with Files.Operations.History.Testing;
with Files.Model.Jobs;
with Files.Operations.History;
with Files_Suite.Listings;
with Files.Undo.Journal.Testing;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.History)
   --  A finished helper's journal that is unreadable keeps the job,
   --  transport and all, for later polls, each reading it once and none
   --  waiting: once it can be read the history comes back whole. One that
   --  never can be read is given up after a grace of about two seconds, not
   --  after a number of polls: the operation still reports what it did (a
   --  success stays a success) together with the notice that it may not be
   --  undoable, and what it created is still recorded for Undo from the
   --  helper's own record of its creations.
   procedure Test_An_Unreadable_Journal_Waits_Then_Reports (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      --  How long the last Duplicate_With_Refused_Reads took to finish.
      Taken    : Duration;

      --  Duplicate a.txt with the window's next Refused journal reads
      --  refused, and poll the job until it finishes.
      procedure Duplicate_With_Refused_Reads (Refused : Natural) is
         Started : Files_Suite.Support.Timing.Instant;
         Polls   : Natural := 0;
      begin
         Reset_Root;
         Write_Binary_File (Join (Root, "a.txt"), "a bytes");
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Assert (Files.Model.Selection.Select_By_Name (Model, "a.txt"), "the file is listed");
         Files.Model.Jobs.Set_Background_Transfers (Model, True);
         Step := Operation_Commands.Duplicate_Selected (Model, Settings);
         Files.Undo.Journal.Testing.Refuse_Reads (Refused);
         Started := Files_Suite.Support.Timing.Now;
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when not Files.Model.Jobs.Foreground_Job_Is_Active (Model);
            Step := Files.Job_Drivers.Foreground.Advance (Model, Settings, 1);
            Polls := Polls + 1;
         end loop;
         Taken := Files_Suite.Support.Timing.Seconds (Files_Suite.Support.Timing.Elapsed (Started));
         Assert (not Files.Model.Jobs.Foreground_Job_Is_Active (Model), "the job finishes");
         Assert
           (Refused - Files.Undo.Journal.Testing.Refusals_Left <= Polls,
            "each poll reads the journal at most once, without waiting between reads");
         Files.Undo.Journal.Testing.Refuse_Reads (0);
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operation_Results.Operation_Success, "the duplicate succeeds");
         Assert (Ada.Directories.Exists (Join (Root, "a (copy).txt")), "and is made");
      end Duplicate_With_Refused_Reads;
   begin
      --  Refused on several polls: a later poll takes it back.
      Duplicate_With_Refused_Reads (5);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1,
         "its history is taken back on a later poll");
      Assert (Files.Model.History.Undo_Entries (Model).Last_Element.Redoable, "whole, its Redo included");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), "", "and nothing is reported");

      --  Never readable: given up, reported, and its creation still undoable.
      Duplicate_With_Refused_Reads (10_000);
      Assert (Taken >= 1.5, "given up only once its grace has passed, however many polls ran meanwhile");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.operation.undo_unavailable",
         "a history given up is reported beside the operation's own outcome");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1,
         "what the helper created is still recorded for Undo");
      Reset_Root;
   exception
      when others =>
         Files.Undo.Journal.Testing.Refuse_Reads (0);
         raise;
   end Test_An_Unreadable_Journal_Waits_Then_Reports;

with Files_Suite.Listings;
with Files.Undo.Journal.Testing;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
separate (Files_Suite.History)
   --  A background Undo that did its step but whose helper's journal is
   --  never readable leaves the step's entry off the Undo stack: Undo is
   --  not offered again for a step already undone (nor Redo, whose record
   --  was lost with the journal), and the loss is reported. A newer step
   --  undone before it, waiting on the Redo stack, is retired too: redoing
   --  it with the older step undone would replay the history out of order.
   procedure Test_Lost_Journal_Undo_Leaves_The_Stack (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Copy     : constant String := Join (Root, "a (copy).txt");
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.Clear_Undo (Model);
      Assert (Files.Model.Selection.Select_By_Name (Model, "a.txt"), "the file is listed");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Complete_Operation (Model, Settings, Operation_Commands.Duplicate_Selected (Model, Settings));
      Await_View (Model, Settings);
      Assert (Ada.Directories.Exists (Copy), "the duplicate is made");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "and recorded for Undo");
      Assert (Files.Model.Selection.Select_By_Name (Model, "a.txt"), "the file is listed again");
      Step := Complete_Operation (Model, Settings, Operation_Commands.Duplicate_Selected (Model, Settings));
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 2, "a second duplicate is recorded");
      Step := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Redo_Entries (Model).Length), 1, "the newer duplicate is undone, for Redo");
      Assert (Ada.Directories.Exists (Copy), "the older duplicate is still there");

      Step := Operation_Commands.Undo_Last (Model, Settings);
      Files.Undo.Journal.Testing.Refuse_Reads (10_000);
      Step := Complete_Operation (Model, Settings, Step);
      Files.Undo.Journal.Testing.Refuse_Reads (0);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "the Undo succeeds");
      Assert (not Ada.Directories.Exists (Copy), "and removes the duplicate");
      Assert
        (Files.Model.History.Undo_Entries (Model).Is_Empty,
         "the undone step is not offered for Undo again");
      Assert
        (Files.Model.History.Redo_Entries (Model).Is_Empty,
         "nor for Redo, its record lost, and the newer step waiting there is retired");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.operation.undo_unavailable", "the lost history is reported");
      Reset_Root;
   exception
      when others =>
         Files.Undo.Journal.Testing.Refuse_Reads (0);
         raise;
   end Test_Lost_Journal_Undo_Leaves_The_Stack;

with Files.Model.Jobs;
with Files.Operations.History;
with Files_Suite.Listings;
with Files.Undo.Journal.Testing;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
separate (Files_Suite.History)
   --  A finished helper's journal that cannot be read the moment the window
   --  takes it back -- another process holding it, a transient refusal -- is
   --  read again before the helper's history is given up: the duplicate it
   --  made stays undoable.
   procedure Test_A_Briefly_Unreadable_Journal_Is_Read_Again (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.History.Clear_Undo (Model);
      Assert (Files.Model.Selection.Select_By_Name (Model, "a.txt"), "the file is listed");
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      --  The window's next two reads of the helper's journal are refused.
      Files.Undo.Journal.Testing.Refuse_Reads (2);
      Step := Complete_Operation (Model, Settings, Step);
      Files.Undo.Journal.Testing.Refuse_Reads (0);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "the duplicate succeeds");
      Assert (Ada.Directories.Exists (Join (Root, "a (copy).txt")), "and is made");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1,
         "its history is taken back once the journal can be read");
      Reset_Root;
   exception
      when others =>
         Files.Undo.Journal.Testing.Refuse_Reads (0);
         raise;
   end Test_A_Briefly_Unreadable_Journal_Is_Read_Again;

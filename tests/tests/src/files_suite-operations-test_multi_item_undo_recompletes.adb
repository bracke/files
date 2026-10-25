separate (Files_Suite.Operations)
   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Orig_A   : constant String := Join (Root, "recomplete-orig-a.txt");
      Orig_B   : constant String := Join (Root, "recomplete-orig-b.txt");
      Moved_A  : constant String := Join (Root, "recomplete-moved-a.txt");
      Moved_B  : constant String := Join (Root, "recomplete-moved-b.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      From_V   : Files.Types.String_Vectors.Vector;
      To_V     : Files.Types.String_Vectors.Vector;
   begin
      Reset_Root;
      --  Simulate a completed two-item move: the files now live at Moved_*, and
      --  the recorded undo would move them back to Orig_*.
      Write_File (Moved_A, "a");
      Write_File (Moved_B, "b");
      From_V.Append (To_Unbounded_String (Moved_A));
      From_V.Append (To_Unbounded_String (Moved_B));
      To_V.Append (To_Unbounded_String (Orig_A));
      To_V.Append (To_Unbounded_String (Orig_B));

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.Record_Undo (Model, Files.Model.Undo_Move, From_V, To_V);
      Assert (Files.Model.Undo_Available (Model), "the multi-item move records an undo entry");

      --  Occupy the second item's destination so its move-back cannot apply yet.
      Write_File (Orig_B, "occupied");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "a partially-blocked multi-item undo reports failure");
      Assert
        (Ada.Directories.Exists (Orig_A) and then not Ada.Directories.Exists (Moved_A),
         "the unblocked item is moved back on the first pass");
      Assert (Ada.Directories.Exists (Moved_B), "the blocked item stays put");
      Assert
        (Files.Model.Undo_Available (Model),
         "the partially-applied entry stays on the undo stack");

      --  Free the destination and retry. The regression this covers: the
      --  already-restored item (Moved_A now gone) used to force failure forever,
      --  so the entry could never re-complete; it now counts as already-undone.
      Ada.Directories.Delete_File (Orig_B);
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "re-running the undo completes the previously-blocked item");
      Assert
        (Ada.Directories.Exists (Orig_B) and then not Ada.Directories.Exists (Moved_B),
         "the previously-blocked item is now moved back");
      Assert (Ada.Directories.Exists (Orig_A), "the already-restored item is untouched by the retry");
      Assert
        (not Files.Model.Undo_Available (Model),
         "the fully-applied entry finally leaves the undo stack");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "a retried Undo retains the full action for Redo");
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "Undo after Redo reverses both items in a fresh cycle: status");
      Assert (Ada.Directories.Exists (Orig_A), "Undo after Redo reverses both items in a fresh cycle: a restored");
      Assert (Ada.Directories.Exists (Orig_B), "Undo after Redo reverses both items in a fresh cycle: b restored");
      Assert (not Ada.Directories.Exists (Moved_A),
              "Undo after Redo reverses both items in a fresh cycle: a moved back");
      Assert (not Ada.Directories.Exists (Moved_B),
              "Undo after Redo reverses both items in a fresh cycle: b moved back");
   end Test_Multi_Item_Undo_Recompletes;

with Files.Undo.Journal.Testing;
separate (Files_Suite.History)
   --  A history.tmp a crash left behind does not refuse any later save.
   procedure Test_History_Save_Replaces_Leftover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      History_Directory : constant String := Join (Root, "history-leftover");
      Model : Files.Model.Window_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (History_Directory);
      Write_Binary_File (Join (History_Directory, "history.tmp"), "half a journal");
      Files.Undo.Journal.Testing.Save_Stacks
        (History_Directory,
         Files.Undo.History.Undo_Entry_Vectors.Empty_Vector,
         Files.Undo.History.Undo_Entry_Vectors.Empty_Vector,
         Mode => Files.Undo.Journal.Must_Commit);
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.Model.Testing.Restore_Journal (History_Directory, Model), "the journal is saved over the leftover");
      Assert (File_Is (Join (History_Directory, "history.tmp"), "half a journal"),
              "the leftover is passed over, not followed or removed");
      Assert (not Ada.Directories.Exists (Join (History_Directory, "history.tmp-2")),
              "and the save's own temporary is not left");
      Reset_Root;
   end Test_History_Save_Replaces_Leftover;

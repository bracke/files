separate (Files_Suite.Operations)
   --  A history.tmp a crash left behind does not refuse every later save.
   procedure Test_History_Save_Replaces_Leftover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      History_Directory : constant String := Join (Root, "history-leftover");
      Model : Files.Model.Window_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (History_Directory);
      Write_File (Join (History_Directory, "history.tmp"), "half a journal");
      Files.History_Journal.Save_Stacks
        (History_Directory,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Required => True);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Assert (Files.History_Journal.Restore (History_Directory, Model), "the journal is saved over the leftover");
      Assert (not Ada.Directories.Exists (Join (History_Directory, "history.tmp")), "and no temporary is left");
      Reset_Root;
   end Test_History_Save_Replaces_Leftover;

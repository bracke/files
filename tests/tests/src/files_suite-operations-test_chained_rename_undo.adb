separate (Files_Suite.Operations)
   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      A        : constant String := Join (Root, "a.txt");
      B        : constant String := Join (Root, "b.txt");
      C        : constant String := Join (Root, "c.txt");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Write_Binary_File (A, "A");
      Write_Binary_File (B, "B");
      Assert (Files.File_System.Rename_Item (B, C).Success and then Files.File_System.Rename_Item (A, B).Success,
              "rename b to c, then a to b");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Rename,
         From => [To_Unbounded_String (C), To_Unbounded_String (B)],
         To   => [To_Unbounded_String (B), To_Unbounded_String (A)]);
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "one Undo reverses the chained batch");
      Assert (Project_Tools.Files.Read_Raw_File (A) = "A" and then Project_Tools.Files.Read_Raw_File (B) = "B"
              and then not Path_Exists (C),
              "both renames are undone");
      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success
              and then Project_Tools.Files.Read_Raw_File (C) = "B" and then Project_Tools.Files.Read_Raw_File (B) = "A",
              "Redo replays the batch in its own order");
   end Test_Chained_Rename_Undo;

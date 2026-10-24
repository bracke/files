separate (Files_Suite.Operations)
   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Path : constant String := Join (Root, "recent-trash-undo.txt");
      Applied : Boolean := False;
   begin
      Reset_Root;
      Write_Binary_File (Path, "original recent bytes");
      Files.Settings.Note_Recent (Settings, Path);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Step := Files.Operations.Navigate_Recent (Model, Settings);
      Files.Model.Select_All_Visible (Model);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then Files.Model.Item_Count (Model) = 0
              and then not Ada.Directories.Exists (Path), "trashing the Recent item removes it from the view");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then File_Has_Bytes (Path, "original recent bytes"),
              "Undo restores the trashed bytes before the asynchronous listing is ready");
      for Attempt in Files_Suite.Support.Polling loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
      end loop;
      Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
              and then Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1
              and then Files.Model.Visible_Item (Model, 1).Full_Path = To_Unbounded_String (Path)
              and then Files.Model.Last_Error_Key (Model) = "",
              "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback");
   end Test_Recent_Trash_Undo_Refresh;

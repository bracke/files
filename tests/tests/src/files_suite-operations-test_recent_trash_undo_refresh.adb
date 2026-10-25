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
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "trashing the Recent item removes it from the view: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         0,
         "trashing the Recent item removes it from the view: item count");
      Assert (not Ada.Directories.Exists (Path), "trashing the Recent item removes it from the view: path trashed");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then File_Has_Bytes (Path, "original recent bytes"),
              "Undo restores the trashed bytes before the asynchronous listing is ready");
      for Attempt in Files_Suite.Support.Polling loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
      end loop;
      Assert
        (Applied,
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": applied");
      Assert
        (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": refresh finished");
      Assert
        (Files.Model.In_Recent_View (Model),
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": still in Recent");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": item count");
      Assert
        (Files.Model.Visible_Item (Model, 1).Full_Path = To_Unbounded_String (Path),
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": restored item listed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": no error");
   end Test_Recent_Trash_Undo_Refresh;

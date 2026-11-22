with Files.Operations.Navigation;
with Files.Model.Recent;
with Files.Model.Jobs;
with Files.Operation_Results;
with Files.Settings.Path_References;
separate (Files_Suite.Trash)
   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operation_Results.Operation_Result;
      Path : constant String := Join (Root, "recent-trash-undo.txt");
      Applied : Boolean := False;
   begin
      Reset_Root;
      Write_Binary_File (Path, "original recent bytes");
      Files.Settings.Path_References.Note_Recent (Settings, Path);
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Step := Files.Operations.Navigation.Navigate_Recent (Model, Settings);
      Files.Model.Selection.Select_All_Visible (Model);
      Step := Complete_Operation
                       (Model, Settings, Operation_Commands.Delete_Selected (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "trashing the Recent item removes it from the view: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         0,
         "trashing the Recent item removes it from the view: item count");
      Assert (not Ada.Directories.Exists (Path), "trashing the Recent item removes it from the view: path trashed");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Complete_Operation
                       (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operation_Results.Operation_Success and then File_Is (Path, "original recent bytes"),
              "Undo restores the trashed bytes before the asynchronous listing is ready");
      Await_View (Model, Settings, Applied);
      Assert
        (Applied,
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": applied");
      Assert
        (not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)),
         "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback"
         & ": refresh finished");
      Assert
        (Files.Model.Recent.In_Recent_View (Model),
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

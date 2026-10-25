separate (Files_Suite.Operations)
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Paths    : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Guard_Name : constant String := "files-aunit-recent-create-must-not-write-7f62b1";
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_File (Model, "created.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "create commit succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "created.txt"),
         "create commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created.txt")), "create commit creates the file");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "successful create clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create commit clears temporary state");
      Assert (not Files.Model.Rename_Is_Active (Model), "create commit clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "create commit reloads the directory model");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "created.txt",
         "created item is selected after reload");

      Items := Files.Model.Selected_Items (Model);
      Files.Model.Navigate_Recent (Model, Items);
      Result := Files.Operations.Open_Terminal (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "direct terminal launch is rejected before resolving an empty recent-view path");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "recent-renamed-must-not-write-7f62b1");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.rename.disabled"
         and then Ada.Directories.Exists (Join (Root, "created.txt"))
         and then not Ada.Directories.Exists ("recent-renamed-must-not-write-7f62b1"),
         "direct recent-view rename cannot move an item into the process directory");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Begin_Create_File (Model, Guard_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.file.parent_missing",
         "direct create commit rejects the virtual recent view");
      Assert
        (not Ada.Directories.Exists (Guard_Name),
         "a rejected recent-view create does not write relative to the process directory");

      Paths.Append (To_Unbounded_String (Join (Root, "created.txt")));
      Result := Files.Operations.Begin_Paste (Model, Settings, Paths);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.drop.invalid_destination",
         "direct paste rejects the virtual recent view's empty destination");

      Files.Model.Set_Filter (Model, "created");
      Files.Model.Set_Background_Transfers (Model, True);
      Result := Files.Operations.Run_Recursive_Search (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.directory.load"
         and then not Files.Process_Jobs.Active (Files.Model.Background_Operation (Model)),
         "recent-view name search is rejected before a background helper starts");
      Result := Files.Operations.Run_Content_Search (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.directory.load"
         and then not Files.Process_Jobs.Active (Files.Model.Background_Operation (Model)),
         "recent-view content search is rejected before a background helper starts");
   end Test_Commit_Create_File;

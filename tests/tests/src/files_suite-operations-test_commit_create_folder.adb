separate (Files_Suite.Operations)
   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_Folder (Model, "created-folder");
      Assert (Files.Model.Temporary_Item_Is_Directory (Model), "create-folder marks temporary item as directory");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "create-folder commit succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "created-folder"),
         "create-folder commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created-folder")), "create-folder commit creates the entry");
      Assert
        (Ada.Directories.Kind (Join (Root, "created-folder")) = Ada.Directories.Directory,
         "create-folder commit creates a directory");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "successful create-folder clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create-folder commit clears temporary state");
      Assert (not Files.Model.Temporary_Item_Is_Directory (Model), "create-folder commit clears directory flag");
      Assert (not Files.Model.Rename_Is_Active (Model), "create-folder commit clears rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "create-folder commit reloads the directory model");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "created-folder",
         "created folder is selected after reload");
   end Test_Commit_Create_Folder;

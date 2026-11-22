with Files.File_Types;
with Files.Operations.Editing;
with Files.Operations.Opening;
with Files.Operations.Paste;
with Files.Model.Filtering;
with Files.Model.Creation;
with Files.UI_Types;
with Files.Model.Jobs;
with Files.Operation_Results;
separate (Files_Suite.Names)
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      Paths    : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operation_Results.Operation_Result;
      Guard_Name : constant String := "files-aunit-recent-create-must-not-write-7f62b1";
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Creation.Begin_Create_File (Model, "created.txt", Files.File_Types.Default_Classification);
      Result := Files.Operations.Editing.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operation_Results.Operation_Success,
                                        "create commit succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "created.txt"),
         "create commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created.txt")), "create commit creates the file");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "successful create clears stale error state");
      Assert (not Files.Model.Creation.Temporary_Item_Is_Active (Model), "create commit clears temporary state");
      Assert (not Files.Model.Rename.Is_Active (Model), "create commit clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "create commit reloads the directory model");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model),
         "created.txt",
         "created item is selected after reload");

      Items := Files.Model.Selection.Selected_Items (Model);
      Files.Model.Navigate_Recent (Model, Items);
      Result := Files.Operations.Opening.Open_Terminal (Model);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Disabled,
         "direct terminal launch is rejected before resolving an empty recent-view path");
      Files.Model.Selection.Select_Visible (Model, 1);
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "recent-renamed-must-not-write-7f62b1");
      Result := Files.Operations.Editing.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Disabled,
         "direct recent-view rename cannot move an item into the process directory: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "direct recent-view rename cannot move an item into the process directory: error key");
      Assert
        (Ada.Directories.Exists (Join (Root, "created.txt")),
         "direct recent-view rename cannot move an item into the process directory: source kept");
      Assert
        (not Ada.Directories.Exists ("recent-renamed-must-not-write-7f62b1"),
         "direct recent-view rename cannot move an item into the process directory: nothing written");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Creation.Begin_Create_File (Model, Guard_Name, Files.File_Types.Default_Classification);
      Result := Files.Operations.Editing.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operation_Results.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.file.parent_missing",
         "direct create commit rejects the virtual recent view");
      Assert
        (not Ada.Directories.Exists (Guard_Name),
         "a rejected recent-view create does not write relative to the process directory");

      Paths.Append (To_Unbounded_String (Join (Root, "created.txt")));
      Result := Files.Operations.Paste.Begin_Paste (Model, Settings, Paths);
      Assert
        (Result.Status = Files.Operation_Results.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.drop.invalid_destination",
         "direct paste rejects the virtual recent view's empty destination");

      Files.Model.Filtering.Set_Filter (Model, "created");
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Disabled,
         "recent-view name search is rejected before a background helper starts: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "recent-view name search is rejected before a background helper starts: error key");
      Assert
        (not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Operation (Model)),
         "recent-view name search is rejected before a background helper starts: no helper");
      Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Contents);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Disabled,
         "recent-view content search is rejected before a background helper starts: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "recent-view content search is rejected before a background helper starts: error key");
      Assert
        (not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Operation (Model)),
         "recent-view content search is rejected before a background helper starts: no helper");
   end Test_Commit_Create_File;

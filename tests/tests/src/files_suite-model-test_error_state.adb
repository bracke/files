separate (Files_Suite.Model)
   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Operations.Operation_Result;
      Item     : Files.File_System.Directory_Item;
   begin
      Item := Files.Model.Selected_Item (Model);
      Files_Suite.Support.Assert_Equal (To_String (Item.Name), "", "empty selection returns an empty selected item");
      Files_Suite.Support.Assert_Equal (To_String (Item.Full_Path), "", "empty selection selected item has empty path");
      Assert (Item.Kind = Files.Types.Unknown_Item, "empty selection selected item has unknown kind");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "empty selection is not temporary");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "empty open is represented as disabled");
      Files_Suite.Support.Assert_Equal (To_String (Result.Path), "", "disabled empty open has no target path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "empty open records an error");
      Result := Files.Operations.Navigate_Back (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "empty back history is disabled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.history.back_unavailable",
         "empty back history records an error");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "create commit without temporary item is disabled");
      Files_Suite.Support.Assert_Equal (To_String (Result.Path), "", "disabled create commit has no target path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.create.no_temporary_item",
         "missing temporary item records an error");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "rename commit outside rename mode is disabled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "disabled rename records an error");

      Files.Model.Select_Visible (Model, 1);
      Result := Files.Operations.Delete_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "trash failure is represented as data");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "trash failure reports selected path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.trash.failed",
         "trash failure is recorded as data; key was "
         & Files.Model.Last_Error_Key (Model));
   end Test_Error_State;

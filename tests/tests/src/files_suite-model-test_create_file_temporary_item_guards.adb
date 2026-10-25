separate (Files_Suite.Model)
   procedure Test_Create_File_Temporary_Item_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Operation : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 2.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      --  Open a gap in the untitled names before creating.
      Ada.Directories.Delete_File (Join (Root, "untitled 2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success,
         "create command opens a temporary item at the first name gap (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 2.txt",
         "create command uses first name gap");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "temporary item appears despite active filter");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Visible_Item (Model, 1).Name),
         "untitled 2.txt",
         "temporary item is the visible item while pending");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "create command selects temporary item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "temporary item counts as a selected visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "untitled 2.txt",
         "temporary selection exposes pending name");
      Assert (Files.Model.Selected_Item_Is_Temporary (Model), "model identifies selected temporary item");
      Assert (not Files.Model.Rename_Is_Enabled (Model), "temporary item is not a real rename target");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "active temporary rename can still be cancelled through the command");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "selected temporary item does not enable delete");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
         "selected temporary item does not enable open");
      Operation := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be opened directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "temporary open records disabled state");
      Operation := Files.Operations.Delete_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be deleted directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "temporary delete records disabled state");
      Operation := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be renamed directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "temporary rename records disabled state");
   end Test_Create_File_Temporary_Item_Guards;

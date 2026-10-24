separate (Files_Suite.Operations)
   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "open-dir");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Join (Root, "other-dir"));
      Write_File (Join (Dir, "child.txt"));
      Items.Append (Files.File_System.Make_Item (Root, "open-dir", Files.Types.Directory_Item, "inode/directory"));
      Items.Append (Files.File_System.Make_Item (Root, "other-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled,
         "pending create selection blocks direct open preparation");
      Assert
        (To_String (Result.Error_Key) = "error.selection.empty",
         "pending create open preparation reports disabled selection");
      Assert (Files.Model.Current_Path (Model) = Root, "preparing directory open does not navigate");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.selection.empty",
         "preparing pending create open records disabled state");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "pending create item cannot be opened directly");
      Assert (Files.Model.Current_Path (Model) = Root, "disabled pending create open keeps path");

      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert
        (To_String (Routed.Operation.Path) = Ada.Directories.Full_Name (Dir),
         "directory open returns loaded path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "directory open changes path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "directory open clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "directory open clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "directory open clears rename state");
      Assert (Files.Model.Rename_Text (Model) = "", "directory open clears stale rename text");
      Assert (Files.Model.Temporary_Item_Name (Model) = "", "directory open clears stale temporary name");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "directory open clears rename focus");
      Assert (Files.Model.Item_Count (Model) = 1, "directory open loads destination items");
      Assert (Files.Model.Visible_Item (Model, 1).Name = To_Unbounded_String ("child.txt"), "child item is loaded");

      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "multi-directory open is rejected");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.multi_directory",
         "multi-directory open reports localized diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.multi_directory",
         "multi-directory open records localized diagnostic key");
      Assert (Files.Model.Current_Path (Model) = Root, "multi-directory open does not navigate");

      Files.Model.Initialize (Model, Root, Items, Root);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "double-click changes path");
   end Test_Open_Selected_Directory_Loads_Items;

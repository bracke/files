with Files.Commands.Status;
separate (Files_Suite.Commands)
   procedure Test_Recent_View_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Empty    : Files.File_System.Item_Vectors.Vector;
      Clipboard : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Model.Select_Visible (Model, 1);
      Clipboard.Append (To_Unbounded_String (Join (Root, "Alpha.txt")));
      Files.Model.Set_Clipboard (Model, Clipboard, Files.Model.Clipboard_Copy);
      Files.Model.Navigate_Recent (Model, Empty);
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Create_File_Command, Model)
         and then not Files.Commands.Status.Is_Enabled (Files.Commands.New_Folder_Command, Model),
         "create commands are disabled in the virtual recent view");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Paste_Items_Command, Model),
         "paste is disabled in the virtual recent view even with clipboard items");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "rename is disabled in the virtual recent view without a destination directory");
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Disabled,
         "disabled recent-view create reports the recent view without starting an edit (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.command.recent_view",
         "disabled recent-view create reports the recent view without starting an edit (error key)");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "disabled recent-view create reports the recent view without starting an edit (no edit started)");
      Result := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.command.recent_view",
         "disabled recent-view paste reports the recent view");
      Files.Model.Set_Filter (Model, "alpha");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Search_Recursive_Command, Model)
         and then not Files.Commands.Status.Is_Enabled (Files.Commands.Search_Contents_Command, Model),
         "filesystem searches are disabled when the current view has no directory root");
      Result :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled
         and then Files.Model.Last_Error_Key (Model) = "error.command.recent_view",
         "disabled recent-view search reports the recent view");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/next", Empty);
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Navigate_Back_Command, Model),
              "back enabled after navigation");
   end Test_Recent_View_Command_Enablement;

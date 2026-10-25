separate (Files_Suite.Operations)
   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Load := Files.File_System.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Write_File (Join (First, "fresh.txt"));
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Scroll_Info_Pane (Model, Lines => 4);
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "refresh operation succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "refresh operation reports current path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "refresh loads newly created item");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "refresh clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "refresh clears rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "refresh clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "refresh clears command palette");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "refresh clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "refresh resets info pane scroll");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Write_File (Join (First, "later.txt"));
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "second refresh operation succeeds");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "second refresh loads later item");
      Assert
        (Files.Model.Selected_Count (Model) = 2
         and then Files.Model.Selected_Name (Model) = "one.txt",
         "synchronous refresh preserves a multi-selection and its primary item by path");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed refresh is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "failed refresh reports current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (First),
         "failed refresh preserves path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "failed refresh preserves loaded items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "failed refresh records load error");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed refresh preserves command palette");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));
      Write_File (Join (First, "later.txt"));
   end Test_Controller_Refresh_Loading;

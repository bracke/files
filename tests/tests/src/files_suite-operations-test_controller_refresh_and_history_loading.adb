separate (Files_Suite.Operations)
   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Second   : constant String := Join (Root, "second");
      Branch   : constant String := Join (Root, "branch");
      Missing_Home : constant String := Join (Root, "missing-home");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Ada.Directories.Create_Path (Second);
      Ada.Directories.Create_Path (Branch);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (Second, "two.txt"));
      Write_File (Join (Branch, "branch.txt"));
      Load := Files.File_System.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, Missing_Home);
      Files.Model.Begin_Create_File (Model, "failed-home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed home load is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Missing_Home,
         "failed home reports attempted home path");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.path.missing",
         "failed home reports path diagnostic");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), First, "failed home preserves current path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "failed home preserves loaded items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "failed home records path error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed home preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed home preserves rename state");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed home preserves command palette");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Files.Model.Begin_Create_File (Model, "home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "home load succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "home operation reports normalized home path");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "home clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "home clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "home clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "home clears command palette");
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

      Load := Files.File_System.Load_Directory (Second, Settings);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Navigate_To (Model, Second, Load.Items);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct navigation clears stale root selector entries");
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "back operation reloads target");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "back operation reports restored path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (First),
         "back restores first path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "back loads first path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "back clears rename focus");
      Files.Model.Begin_Create_File (Model, "forward-history-pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "forward operation reloads target");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Second),
         "forward operation reports restored path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Second),
         "forward restores second path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "forward loads second path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "forward clears rename focus");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Begin_Create_File (Model, "failed-history-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed back reload is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "failed back reports attempted path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Second),
         "failed back rolls path back");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "failed back records load error");
      Assert (Files.Model.Can_Go_Back (Model), "failed back preserves back history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed back preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves rename state");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "second back operation succeeds");
      Project_Tools.Files.Delete_Tree (Second);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "one-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed forward preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves normal rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "one-renamed.txt",
         "failed forward preserves rename text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Rename_Input,
         "failed forward restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Begin_Create_File (Model, "failed-forward-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed forward reload is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Second),
         "failed forward reports attempted path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (First),
         "failed forward rolls path back");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "failed forward records load error");
      Assert (Files.Model.Can_Go_Forward (Model), "failed forward preserves forward history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed forward preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves rename state");
      Ada.Directories.Create_Path (Second);
      Write_File (Join (Second, "two.txt"));
      Files.Model.Cancel_Create_File (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "second forward operation succeeds");
      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "two-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "failed back preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves normal rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "two-renamed.txt",
         "failed back preserves rename text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Rename_Input,
         "failed back restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_L, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Path_Input_Command,
         "Control+L focuses path for branch");
      Files.Controller.Replace_Focused_Text (Model, Branch);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "path input navigates to branch");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Branch),
         "branch path input reports normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Branch),
         "branch navigation loads path");
      Assert (not Files.Model.Can_Go_Forward (Model), "new controller navigation clears forward history");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "branch navigation carries loaded directory items");
   end Test_Controller_Refresh_And_History_Loading;

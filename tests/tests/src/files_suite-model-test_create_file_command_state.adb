with Files.Commands.Status;
separate (Files_Suite.Model)
   procedure Test_Create_File_Command_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 2.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Begin_Create_File (Model, "draft.txt");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "direct create adds temporary item");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "direct create closes stale root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct create clears stale root selector entries");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "direct create closes stale command palette");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Scroll_Main_View (Model, 4);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Create_File_Command,
         "create command routes through controller");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "create command reports successful temporary-item operation");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "create command clears stale error state");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "create command adds temporary item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 3.txt",
         "temporary item name is deterministic");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "create command scrolls temporary item into view");
      Assert (Files.Model.Rename_Is_Active (Model), "create command starts rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Rename_Input,
         "create command focuses rename input");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Create_File_Command, Model),
         "create command is disabled while a temporary item exists");
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "second create command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "second create command reports disabled operation");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.create.pending",
         "second create command reports pending-create error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.create.pending",
         "second create records error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 3.txt",
         "ignored create keeps pending name");
   end Test_Create_File_Command_State;

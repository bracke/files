separate (Files_Suite.Operations)
   procedure Test_Controller_Home_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Missing_Home : constant String := Join (Root, "missing-home");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
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
   end Test_Controller_Home_Loading;

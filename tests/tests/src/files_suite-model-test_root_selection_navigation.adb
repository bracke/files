separate (Files_Suite.Model)
   procedure Test_Root_Selection_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      --  An empty listing at Root with every overlay closed.
      Files.Model.Navigate_To (Model, Root, Files.File_System.Item_Vectors.Empty_Vector);

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after palette Escape");
      Files.Model.Begin_Create_File (Model, "root-pending.txt");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);

      Result := Files.Controller.Select_Root (Model, Settings, Join (Root, "missing-root"));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "invalid root selection executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "invalid root selection reports drive command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "invalid root selection fails as data");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.path.missing",
         "invalid root selection reports path diagnostic");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "invalid root selection does not navigate");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "invalid root selection keeps selector open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "invalid root selection records error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid root selection preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid root selection preserves rename state");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "outside root row click is ignored");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "outside root row click keeps selector open");

      Result := Files.Controller.Select_Root (Model, Settings, Target);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "root selection executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "root selection reports drive command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root selection navigates");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Target),
         "root selection operation carries normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "selected root is loaded");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "root selection clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "root selection clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "root selection clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "selected root directory items are loaded");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "root selection closes selector");
      Assert (Files.Model.Can_Go_Back (Model), "root selection updates back history");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "closed root selector row click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "closed root selector row click does not navigate");
   end Test_Root_Selection_Navigation;

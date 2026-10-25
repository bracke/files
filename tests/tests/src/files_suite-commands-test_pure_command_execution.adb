separate (Files_Suite.Commands)
   procedure Test_Pure_Command_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Empty : Files.File_System.Item_Vectors.Vector;
   begin
      Files.Commands.Execute (Files.Commands.Select_Drive_Command, Model);
      Assert
        (not Files.Model.Root_Selector_Is_Open (Model),
         "pure drive selector command does not inspect filesystem roots");
      Files.Commands.Execute (Files.Commands.Create_File_Command, Model);
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "pure create command does not inspect filesystem names");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Commands.Execute (Files.Commands.Select_Details_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "pure command execution respects root-selector modal disablement");
      Files.Commands.Execute (Files.Commands.Close_Command_Palette_Command, Model);
      Assert
        (not Files.Model.Root_Selector_Is_Open (Model),
         "pure context cancel can close root selector");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/direct-next", Empty);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "direct back can be enabled");
      Files.Commands.Execute (Files.Commands.Navigate_Back_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/direct-next",
         "pure back command does not reload or navigate history");
      Files.Commands.Execute (Files.Commands.Navigate_Forward_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/direct-next",
         "pure forward command does not reload or navigate history");
      Model := Sample_Model;
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "delete enabled with selection");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Toggle_Info_Pane_Command, Model),
         "info toggle enabled with selection");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink enabled with a selection in a real directory");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link enabled with a selection in a real directory");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Open_Terminal_Command, Model),
         "open-terminal enabled in a real directory");
      Files.Commands.Execute (Files.Commands.Open_Selected_Items_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "pure open command does not load selected items");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "rename enabled with one selected item");
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while rename is active");
      Files.Model.Cancel_Focus_Or_Edit (Model);
   end Test_Pure_Command_Execution;

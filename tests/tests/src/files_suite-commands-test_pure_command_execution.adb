separate (Files_Suite.Commands)
   procedure Test_Pure_Command_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Empty : Files.File_System.Item_Vectors.Vector;
   begin
      --  The model-only executor (Files.Commands.Execute) takes only pure
      --  commands, so the type keeps it from ever running one that inspects
      --  the filesystem, loads a directory or walks the history.
      Assert
        (Files.Commands.Select_Drive_Command not in Files.Commands.Pure_Command_Id,
         "the drive selector inspects filesystem roots, so it is not a pure command");
      Assert
        (Files.Commands.Create_File_Command not in Files.Commands.Pure_Command_Id,
         "create inspects filesystem names, so it is not a pure command");
      Assert
        (Files.Commands.Navigate_Back_Command not in Files.Commands.Pure_Command_Id,
         "back reloads a directory from history, so it is not a pure command");
      Assert
        (Files.Commands.Navigate_Forward_Command not in Files.Commands.Pure_Command_Id,
         "forward reloads a directory from history, so it is not a pure command");
      Assert
        (Files.Commands.Open_Selected_Items_Command not in Files.Commands.Pure_Command_Id,
         "open loads the selected items, so it is not a pure command");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files_Suite.Support.Run_Command (Files.Commands.Select_Details_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "command execution respects root-selector modal disablement");
      Files_Suite.Support.Run_Command (Files.Commands.Close_Command_Palette_Command, Model);
      Assert
        (not Files.Model.Root_Selector_Is_Open (Model),
         "context cancel can close root selector");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/direct-next", Empty);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "direct back can be enabled");
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
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "rename enabled with one selected item");
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while rename is active");
      Files.Model.Cancel_Focus_Or_Edit (Model);
   end Test_Pure_Command_Execution;

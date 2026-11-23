with Files.File_System.Roots.Testing;
with Files.Model.Filtering;
with Files.Operation_Results;
with Files.Model.Command_Palette;
with Files.Model.Root_Selector;
with Files_Suite.Support.Models;
separate (Files_Suite.Model)
   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Assert (not Files.Model.Rename.Is_Enabled (Model), "rename disabled with no selection");
      Files.Model.Selection.Select_Visible (Model, 2);
      Files.Model.Root_Selector.Open (Model, Files.File_System.Roots.Testing.Available_Roots);
      Files.Model.Command_Palette.Open (Model);
      Files.Model.Rename.Toggle (Model);
      Assert (Files.Model.Rename.Is_Active (Model), "direct rename enters rename mode");
      Assert (not Files.Model.Root_Selector.Is_Open (Model), "direct rename closes stale root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selector.Count (Model),
         0,
         "direct rename clears stale root selector entries");
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "direct rename closes stale command palette");
      Files.Model.Rename.Toggle (Model);
      Assert (not Files.Model.Rename.Is_Active (Model), "direct rename can be cancelled after overlay cleanup");
      Files.Model.Selection.Select_Visible (Model, 1);
      Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Rename.Is_Enabled (Model), "rename enabled with multi-selection");
      Files.Model.Rename.Toggle (Model);
      Assert (Files.Model.Rename.Is_Active (Model), "multi-selection rename enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Rename_Field_Count (Model),
         2,
         "multi-selection rename opens one field per item");
      Files.Model.Rename.Toggle (Model);
      Assert (not Files.Model.Rename.Is_Active (Model), "toggling rename again cancels multi rename");
      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Models.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (Files.Model.Rename.Is_Active (Model), "rename command enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename.Text (Model),
         "Beta.txt",
         "rename text is selected file name");
      Files.Model.Selection.Select_Visible (Model, 1);
      Assert (not Files.Model.Rename.Is_Active (Model), "selection change cancels stale rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_None,
         "selection change clears stale rename focus");

      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Models.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Selection.Toggle_Visible_Selection (Model, 1);
      Assert
        (Files.Model.Rename.Is_Active (Model),
         "extending the selection keeps the still-selected rename field active");

      Files.Model.Selection.Select_Visible (Model, 3);
      Files_Suite.Support.Models.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Filtering.Set_Filter (Model, "Alpha");
      Assert (not Files.Model.Rename.Is_Active (Model), "filter hiding rename target cancels rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model),
         "Alpha.txt",
         "filter reconciliation selects visible item");
      Files.Model.Filtering.Clear_Filter (Model);
      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Models.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files_Suite.Support.Models.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (not Files.Model.Rename.Is_Active (Model), "F2 while renaming cancels rename mode");

      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes rename through controller");
      Assert (Files.Model.Rename.Is_Active (Model), "controller F2 enters rename mode");
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Overlay_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "rename Escape reports successful state-only cancel");
      Assert (not Files.Model.Rename.Is_Active (Model), "Escape cancels focused rename mode");

      Files_Suite.Support.Discard (Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_F2));
      Assert (Files.Model.Rename.Is_Active (Model), "rename can be entered again");
      Files_Suite.Support.Discard (Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Focus_Path_Input_Command, Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_Path_Input,
         "path focus can move away from rename");
      Assert (Files.Model.Rename.Is_Active (Model), "path focus does not implicitly cancel rename");
      Files_Suite.Support.Discard (Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Escape));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_None,
         "Escape clears focused path input");
      Assert (not Files.Model.Rename.Is_Active (Model), "Escape cancels rename state after path focus");

      Files_Suite.Support.Discard (Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_F2));
      Assert (Files.Model.Rename.Is_Active (Model), "rename can be entered after path focus Escape");
      Files_Suite.Support.Discard (Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Focus_Filter_Input_Command, Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_Filter_Input,
         "focus can move away from rename");
      Assert (Files.Model.Rename.Is_Active (Model), "moving focus does not implicitly cancel rename");
      Files_Suite.Support.Discard (Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Escape));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_None,
         "first Escape clears focused filter input");
      Assert (not Files.Model.Rename.Is_Active (Model), "Escape cancels pending rename state after focus moved");
   end Test_Rename_Mode;

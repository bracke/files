with Files.File_System.Testing;
with Files.Model.Command_Palette;
with Files.Model.Root_Selector;
separate (Files_Suite.Model)
   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Assert (not Files.Model.Rename.Rename_Is_Enabled (Model), "rename disabled with no selection");
      Files.Model.Selection.Select_Visible (Model, 2);
      Files.Model.Root_Selector.Open (Model, Files.File_System.Testing.Available_Roots);
      Files.Model.Command_Palette.Open (Model);
      Files.Model.Rename.Toggle_Rename (Model);
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "direct rename enters rename mode");
      Assert (not Files.Model.Root_Selector.Is_Open (Model), "direct rename closes stale root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selector.Count (Model),
         0,
         "direct rename clears stale root selector entries");
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "direct rename closes stale command palette");
      Files.Model.Rename.Toggle_Rename (Model);
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "direct rename can be cancelled after overlay cleanup");
      Files.Model.Root_Selector.Open (Model, Files.File_System.Testing.Available_Roots);
      Files.Model.Command_Palette.Open (Model);
      Files.Model.Rename.Resume_Rename (Model, "renamed.txt");
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "resume rename enters rename mode");
      Assert (not Files.Model.Root_Selector.Is_Open (Model), "resume rename closes stale root selector");
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "resume rename closes stale command palette");
      Files.Model.Rename.Toggle_Rename (Model);
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "resume rename state can be cancelled");
      Files.Model.Selection.Select_Visible (Model, 1);
      Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Rename.Rename_Is_Enabled (Model), "rename enabled with multi-selection");
      Files.Model.Rename.Toggle_Rename (Model);
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "multi-selection rename enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Rename_Field_Count (Model),
         2,
         "multi-selection rename opens one field per item");
      Files.Model.Rename.Toggle_Rename (Model);
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "toggling rename again cancels multi rename");
      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "rename command enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename.Rename_Text (Model),
         "Beta.txt",
         "rename text is selected file name");
      Files.Model.Selection.Select_Visible (Model, 1);
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "selection change cancels stale rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "selection change clears stale rename focus");

      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Selection.Toggle_Visible_Selection (Model, 1);
      Assert
        (Files.Model.Rename.Rename_Is_Active (Model),
         "extending the selection keeps the still-selected rename field active");

      Files.Model.Selection.Select_Visible (Model, 3);
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Set_Filter (Model, "Alpha");
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "filter hiding rename target cancels rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model),
         "Alpha.txt",
         "filter reconciliation selects visible item");
      Files.Model.Clear_Filter (Model);
      Files.Model.Selection.Select_Visible (Model, 2);
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Files_Suite.Support.Run_Command (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "F2 while renaming cancels rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes rename through controller");
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "controller F2 enters rename mode");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "rename Escape reports successful state-only cancel");
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "Escape cancels focused rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "rename can be entered again");
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path focus can move away from rename");
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "path focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Escape clears focused path input");
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "Escape cancels rename state after path focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "rename can be entered after path focus Escape");
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Focus_Filter_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "focus can move away from rename");
      Assert (Files.Model.Rename.Rename_Is_Active (Model), "moving focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "first Escape clears focused filter input");
      Assert (not Files.Model.Rename.Rename_Is_Active (Model), "Escape cancels pending rename state after focus moved");
   end Test_Rename_Mode;

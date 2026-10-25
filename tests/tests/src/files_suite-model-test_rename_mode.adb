separate (Files_Suite.Model)
   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
      Policy   : constant Files.Model.Rename_Policy := Files.Model.Rename_Behavior;
   begin
      Assert (not Policy.Single_Item_Only, "rename policy is no longer single-item only");
      Assert (Policy.Synchronized_Multi, "rename policy claims synchronized multi-rename");
      Assert (not Policy.Atomic_Multi_Rename, "rename policy does not claim atomic multi-rename");
      Assert (not Policy.Requires_One_Selection, "rename policy does not require exactly one selected item");
      Assert (not Files.Model.Rename_Is_Enabled (Model), "rename disabled with no selection");
      Files.Model.Select_Visible (Model, 2);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "direct rename enters rename mode");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "direct rename closes stale root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct rename clears stale root selector entries");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "direct rename closes stale command palette");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "direct rename can be cancelled after overlay cleanup");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Resume_Rename (Model, "renamed.txt");
      Assert (Files.Model.Rename_Is_Active (Model), "resume rename enters rename mode");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "resume rename closes stale root selector");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "resume rename closes stale command palette");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "resume rename state can be cancelled");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Rename_Is_Enabled (Model), "rename enabled with multi-selection");
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "multi-selection rename enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Field_Count (Model),
         2,
         "multi-selection rename opens one field per item");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "toggling rename again cancels multi rename");
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (Files.Model.Rename_Is_Active (Model), "rename command enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "Beta.txt",
         "rename text is selected file name");
      Files.Model.Select_Visible (Model, 1);
      Assert (not Files.Model.Rename_Is_Active (Model), "selection change cancels stale rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "selection change clears stale rename focus");

      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Assert
        (Files.Model.Rename_Is_Active (Model),
         "extending the selection keeps the still-selected rename field active");

      Files.Model.Select_Visible (Model, 3);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Set_Filter (Model, "Alpha");
      Assert (not Files.Model.Rename_Is_Active (Model), "filter hiding rename target cancels rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "filter reconciliation selects visible item");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 while renaming cancels rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes rename through controller");
      Assert (Files.Model.Rename_Is_Active (Model), "controller F2 enters rename mode");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "rename Escape reports successful state-only cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels focused rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered again");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "path focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Escape clears focused path input");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels rename state after path focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered after path focus Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Filter_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "moving focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "first Escape clears focused filter input");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels pending rename state after focus moved");
   end Test_Rename_Mode;

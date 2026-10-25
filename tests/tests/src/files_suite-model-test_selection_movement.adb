separate (Files_Suite.Model)
   procedure Test_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result     : Files.Controller.Controller_Result;
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Shift      : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Shift (Guikit.Input.Shift_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "first movement selects first visible item");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Left);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "left from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "right from last wraps to first");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Up);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "up from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "right from last wraps to first after up wrap");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 2, "down advances selection");
      declare
         Grid_Items : Files.File_System.Item_Vectors.Vector := Sample_Items;
         Grid_Model : Files.Model.Window_Model;
      begin
         Grid_Items.Append
           (Files.File_System.Make_Item (Root, "Kappa.txt", Files.Types.Regular_File_Item, "text/plain"));
         Grid_Items.Append
           (Files.File_System.Make_Item (Root, "Lambda.txt", Files.Types.Regular_File_Item, "text/plain"));
         Files.Model.Initialize
           (Grid_Model,
            Directory_Path    => Root,
            Items             => Grid_Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         Files.Model.Set_Selection_Grid_Columns (Grid_Model, 2);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection_Grid_Columns (Grid_Model),
            2,
            "model records rendered grid columns");
         Files.Model.Select_Visible (Grid_Model, 1);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            3,
            "down moves to same column in next grid row");
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Up);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            1,
            "up moves to same column in previous grid row");
         Files.Model.Select_Visible (Grid_Model, 5);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            1,
            "down from last grid item wraps to first");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "toggle adds a second deterministic selection");
      Assert (Files.Model.Is_Selected (Model, 1), "first toggled item is selected");
      Assert (Files.Model.Is_Selected (Model, 2), "primary item remains selected");
      declare
         Selected_Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Selected_Items.Length),
            2,
            "selected items API returns all selected items");
         Files_Suite.Support.Assert_Equal
           (To_String (Selected_Items.Element (1).Name),
            "Alpha.txt",
            "selected items use item order");
         Files_Suite.Support.Assert_Equal
           (To_String (Selected_Items.Element (2).Name),
            "Beta.txt",
            "selected items include primary item");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 1, "toggle removes selected item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "primary selection falls back to remaining selected item");
      Files.Model.Clear_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "clear selection empties deterministic selection set");
      Files.Model.Select_Visible (Model, 2);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "controller arrow moves selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "controller down advances selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "shift-down expands selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "shift-down moves primary selection to target item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "shift-down keeps anchor and target selected");
      Assert (Files.Model.Is_Selected (Model, 1), "shift-down keeps anchor item selected");
      Assert (Files.Model.Is_Selected (Model, 2), "shift-down selects target item");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "second shift-down expands selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "second shift-down moves primary selection to next item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "second shift-down preserves range anchor");
      Assert (Files.Model.Is_Selected (Model, 1), "second shift-down keeps original anchor selected");
      Assert (Files.Model.Is_Selected (Model, 3), "second shift-down selects new target item");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Modifiers => Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "control-click toggles selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 2, "control-click adds to selection");
      Assert (Files.Model.Is_Selected (Model, 1), "control-click selects clicked item");
      Assert (Files.Model.Is_Selected (Model, 3), "control-click preserves existing selection");
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "second control-click removes selected item");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "range selection selects every visible item");
      Assert (Files.Model.Is_Selected (Model, 1), "range selection includes anchor");
      Assert (Files.Model.Is_Selected (Model, 2), "range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "range selection includes target");
      Files.Model.Select_Visible_Range (Model, 3, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "reverse range selection selects every visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "reverse range selection makes target primary");
      Assert (Files.Model.Is_Selected (Model, 1), "reverse range selection includes target");
      Assert (Files.Model.Is_Selected (Model, 2), "reverse range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "reverse range selection includes anchor");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "select-all selects every visible loaded item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "select-all keeps first visible item primary");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "select-all respects visible filter projection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "filtered select-all selects visible item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_All_Command,
         "Control+A routes select-all command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "Control+A selects all visible loaded items");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_Visible (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "invert test starts with a single selection");
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "invert selects the previously unselected visible items");
      Assert (not Files.Model.Is_Selected (Model, 1), "invert unselects the previously selected item");
      Assert (Files.Model.Is_Selected (Model, 2), "invert selects a previously unselected item");
      Assert (Files.Model.Is_Selected (Model, 3), "invert selects the remaining unselected item");
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "second invert restores the original selection count");
      Assert (Files.Model.Is_Selected (Model, 1), "second invert restores the original selected item");
      Assert (not Files.Model.Is_Selected (Model, 2), "second invert clears the intermediate selection");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Clear_Selection (Model);
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "invert only touches visible filtered items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "invert selects the visible filtered item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_I, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Invert_Selection_Command,
         "Control+I routes invert-selection command");
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "deselect test starts from a full selection");
      Files.Model.Deselect_All (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "deselect all clears the selection");
      Files.Model.Select_All_Visible (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl_Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Deselect_All_Command,
         "Control+Shift+A routes deselect-all command");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "Control+Shift+A clears the selection");
      Files.Model.Select_Visible (Model, 1);
      declare
         Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Shift (Guikit.Input.Shift_Key) := True;
         Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Shift);
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "shift-click selects a deterministic visible range");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "shift-click makes the clicked item primary");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Focus_Path_Input (Model);
      declare
         Before_Focused_Key : constant Natural := Files.Model.Selected_Index (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "focused input suppresses arrow selection");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            Before_Focused_Key,
            "focused input keeps selection unchanged");
      end;
   end Test_Selection_Movement;

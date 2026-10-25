separate (Files_Suite.Commands)
   procedure Test_Command_Placements (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Select_Drive_Command),
         Files.Commands.Toolbar_Left,
         "drive selector is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Navigate_Home_Command),
         Files.Commands.Toolbar_Left,
         "home command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Navigate_Back_Command),
         Files.Commands.Toolbar_Left,
         "back command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Navigate_Forward_Command),
         Files.Commands.Toolbar_Left,
         "forward command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Navigate_Parent_Command),
         Files.Commands.Toolbar_Left,
         "parent command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Create_File_Command),
         Files.Commands.Toolbar_Left,
         "create-file command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Delete_Selected_Items_Command),
         Files.Commands.Toolbar_Left,
         "delete command is placed in left toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Focus_Path_Input_Command),
         Files.Commands.Toolbar_Middle,
         "path input command is placed in middle toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Focus_Filter_Input_Command),
         Files.Commands.Toolbar_Right,
         "filter input command is placed in right toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Clear_Filter_Command),
         Files.Commands.Toolbar_Right,
         "clear-filter command is placed in right toolbar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Refresh_Directory_Command),
         Files.Commands.Command_Palette_Only,
         "refresh command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Select_Small_Icons_Command),
         Files.Commands.Bottom_Bar,
         "small view command is placed in bottom bar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Select_Large_Icons_Command),
         Files.Commands.Bottom_Bar,
         "large view command is placed in bottom bar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Select_Details_Command),
         Files.Commands.Bottom_Bar,
         "view mode command is placed in bottom bar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Toggle_Info_Pane_Command),
         Files.Commands.Bottom_Bar,
         "info-pane command is placed in bottom bar");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Rename_Selected_Items_Command),
         Files.Commands.Command_Palette_Only,
         "rename command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Open_Selected_Items_Command),
         Files.Commands.Command_Palette_Only,
         "open-selected command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Select_All_Command),
         Files.Commands.Command_Palette_Only,
         "select-all command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Invert_Selection_Command),
         Files.Commands.Placement_For (Files.Commands.Select_All_Command),
         "invert-selection placement matches select-all");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Deselect_All_Command),
         Files.Commands.Placement_For (Files.Commands.Select_All_Command),
         "deselect-all placement matches select-all");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Invert_Selection_Command),
            (True, Guikit.Input.Key_I, Ctrl)),
         "invert-selection uses Control+I");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Deselect_All_Command),
            (True, Guikit.Input.Key_A, Ctrl_Shift)),
         "deselect-all uses Control+Shift+A");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_I, Ctrl),
         Files.Commands.Invert_Selection_Command,
         "Control+I resolves to invert-selection command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_A, Ctrl_Shift),
         Files.Commands.Deselect_All_Command,
         "Control+Shift+A resolves to deselect-all command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Delete_Selected_Permanently_Command),
         Files.Commands.Command_Palette_Only,
         "permanent delete command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Generate_Thumbnails_Command),
         Files.Commands.Command_Palette_Only,
         "thumbnail generation command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Search_Recursive_Command),
         Files.Commands.Command_Palette_Only,
         "recursive search command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Close_Command_Palette_Command),
         Files.Commands.Command_Palette_Only,
         "context-close command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Open_Selected_Root_Command),
         Files.Commands.Command_Palette_Only,
         "open-selected-root command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Eject_Selected_Root_Command),
         Files.Commands.Command_Palette_Only,
         "eject-selected-root command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Open_Command_Palette_Command),
         Files.Commands.Command_Palette_Only,
         "palette toggle is not duplicated in toolbar metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Reset_Settings_Command),
         Files.Commands.Command_Palette_Only,
         "settings reset command is palette-only metadata");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Save_Settings_Command),
         Files.Commands.Command_Palette_Only,
         "settings save command is palette-only metadata");
   end Test_Command_Placements;

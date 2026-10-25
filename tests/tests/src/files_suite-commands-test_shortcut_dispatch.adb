separate (Files_Suite.Commands)
   procedure Test_Shortcut_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Alt        : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Shift      : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Alt (Guikit.Input.Alt_Key) := True;
      Shift (Guikit.Input.Shift_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_1, Ctrl),
         Files.Commands.Select_Small_Icons_Command,
         "control+1 dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_2, Ctrl),
         Files.Commands.Select_Large_Icons_Command,
         "control+2 dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_3, Ctrl),
         Files.Commands.Select_Details_Command,
         "control+3 dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_4, Ctrl),
         Files.Commands.Toggle_Info_Pane_Command,
         "control+4 dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Comma, Ctrl),
         Files.Commands.Toggle_Settings_Pane_Command,
         "control+comma dispatches settings pane command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_L, Ctrl),
         Files.Commands.Focus_Path_Input_Command,
         "control+l dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Home, Alt),
         Files.Commands.Navigate_Home_Command,
         "alt+home dispatches home command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Left, Alt),
         Files.Commands.Navigate_Back_Command,
         "alt+left dispatches back command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Right, Alt),
         Files.Commands.Navigate_Forward_Command,
         "alt+right dispatches forward command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Up, Alt),
         Files.Commands.Navigate_Parent_Command,
         "alt+up dispatches parent command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Up, Guikit.Input.No_Modifiers),
         Files.Commands.No_Command,
         "plain up is not a command shortcut so grid navigation keeps it");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_N, Ctrl),
         Files.Commands.Create_File_Command,
         "control+n dispatches create-file command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_A, Ctrl),
         Files.Commands.Select_All_Command,
         "control+a dispatches select-all command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_P, Ctrl),
         Files.Commands.Open_Command_Palette_Command,
         "control+p dispatches through registry");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F, Ctrl),
         Files.Commands.Focus_Filter_Input_Command,
         "control+f dispatches filter focus command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_D, Ctrl),
         Files.Commands.Select_Drive_Command,
         "control+d dispatches drive selector command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F, Ctrl_Shift),
         Files.Commands.Clear_Filter_Command,
         "control+shift+f dispatches clear-filter command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_R, Ctrl),
         Files.Commands.Refresh_Directory_Command,
         "control+r dispatches refresh command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F5, Guikit.Input.No_Modifiers),
         Files.Commands.Refresh_Directory_Command,
         "F5 also dispatches refresh command as a secondary accelerator");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_For (Files.Commands.Refresh_Directory_Command).Key,
         Guikit.Input.Key_R,
         "refresh keeps control+r as its displayed primary shortcut");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_N, Ctrl_Shift),
         Files.Commands.New_Folder_Command,
         "control+shift+n dispatches new-folder command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_C, Ctrl_Shift),
         Files.Commands.Copy_Path_Command,
         "control+shift+c dispatches copy-path command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl),
         Files.Commands.Toggle_Favorite_Command,
         "control+b dispatches toggle-favorite command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_S, Ctrl_Shift),
         Files.Commands.Search_Recursive_Command,
         "control+shift+s dispatches recursive search command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_C, Ctrl),
         Files.Commands.Copy_Selected_Items_Command,
         "plain control+c still dispatches copy, distinct from copy-path");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_S, Ctrl),
         Files.Commands.Save_Settings_Command,
         "control+s dispatches settings save command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Delete, Guikit.Input.No_Modifiers),
         Files.Commands.Delete_Selected_Items_Command,
         "delete dispatches delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Backspace, Guikit.Input.No_Modifiers),
         Files.Commands.Delete_Selected_Items_Command,
         "backspace dispatches delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Delete, Shift),
         Files.Commands.Delete_Selected_Permanently_Command,
         "shift+delete dispatches permanent delete command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F2, Guikit.Input.No_Modifiers),
         Files.Commands.Rename_Selected_Items_Command,
         "F2 dispatches rename command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Escape, Guikit.Input.No_Modifiers),
         Files.Commands.Close_Command_Palette_Command,
         "escape dispatches context-cancel command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Return, Guikit.Input.No_Modifiers),
         Files.Commands.Open_Selected_Items_Command,
         "return dispatches open-selected command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Z, Ctrl),
         Files.Commands.Undo_Command,
         "Ctrl+Z dispatches the undo command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Z, Ctrl_Shift),
         Files.Commands.Redo_Command,
         "Ctrl+Shift+Z dispatches the redo command distinct from undo");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Y, Ctrl),
         Files.Commands.Redo_Command,
         "Ctrl+Y is a secondary redo accelerator alongside Ctrl+Shift+Z");
   end Test_Shortcut_Dispatch;

separate (Files.Commands)
   function Default_Shortcut_For
     (Id : Command_Id)
      return Shortcut
   is
      Ctrl       : constant Guikit.Input.Modifier_Set := Control_Modifier;
      Alt        : constant Guikit.Input.Modifier_Set := Alt_Modifier;
      Ctrl_Shift : constant Guikit.Input.Modifier_Set := Control_Shift_Modifier;
   begin
      case Id is
         when Select_Small_Icons_Command =>
            return (True, Guikit.Input.Key_1, Ctrl);
         when Select_Large_Icons_Command =>
            return (True, Guikit.Input.Key_2, Ctrl);
         when Select_Details_Command =>
            return (True, Guikit.Input.Key_3, Ctrl);
         when Toggle_Info_Pane_Command =>
            return (True, Guikit.Input.Key_4, Ctrl);
         when Toggle_Settings_Pane_Command =>
            return (True, Guikit.Input.Key_Comma, Ctrl);
         when Toggle_Sort_Menu_Command
            | Sort_By_Name_Command
            | Sort_By_Size_Command
            | Sort_By_Type_Command
            | Sort_By_Created_Command
            | Sort_By_Changed_Command =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
         when Focus_Path_Input_Command =>
            return (True, Guikit.Input.Key_L, Ctrl);
         when Navigate_Home_Command =>
            return (True, Guikit.Input.Key_Home, Alt);
         when Navigate_Back_Command =>
            return (True, Guikit.Input.Key_Left, Alt);
         when Navigate_Forward_Command =>
            return (True, Guikit.Input.Key_Right, Alt);
         when Navigate_Parent_Command =>
            return (True, Guikit.Input.Key_Up, Alt);
         when Create_File_Command =>
            return (True, Guikit.Input.Key_N, Ctrl);
         when New_Folder_Command =>
            return (True, Guikit.Input.Key_N, Ctrl_Shift);
         when Copy_Path_Command =>
            return (True, Guikit.Input.Key_C, Ctrl_Shift);
         when Select_All_Command =>
            return (True, Guikit.Input.Key_A, Ctrl);
         when Invert_Selection_Command =>
            return (True, Guikit.Input.Key_I, Ctrl);
         when Deselect_All_Command =>
            return (True, Guikit.Input.Key_A, Ctrl_Shift);
         when Open_Command_Palette_Command =>
            return (True, Guikit.Input.Key_P, Ctrl);
         when Focus_Filter_Input_Command =>
            return (True, Guikit.Input.Key_F, Ctrl);
         when Select_Drive_Command =>
            return (True, Guikit.Input.Key_D, Ctrl);
         when Clear_Filter_Command =>
            return (True, Guikit.Input.Key_F, Ctrl_Shift);
         when Search_Recursive_Command =>
            return (True, Guikit.Input.Key_S, Ctrl_Shift);
         when Refresh_Directory_Command =>
            return (True, Guikit.Input.Key_R, Ctrl);
         when Save_Settings_Command =>
            return (True, Guikit.Input.Key_S, Ctrl);
         when Reset_Settings_Command =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
         when Toggle_Favorite_Command =>
            return (True, Guikit.Input.Key_B, Ctrl);
         when Open_Selected_Root_Command | Eject_Selected_Root_Command =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
         when Delete_Selected_Items_Command =>
            return (True, Guikit.Input.Key_Delete, Guikit.Input.No_Modifiers);
         when Delete_Selected_Permanently_Command =>
            return (True, Guikit.Input.Key_Delete, [Guikit.Input.Shift_Key => True, others => False]);
         when Generate_Thumbnails_Command =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
         when Rename_Selected_Items_Command =>
            return (True, Guikit.Input.Key_F2, Guikit.Input.No_Modifiers);
         when Copy_Selected_Items_Command =>
            return (True, Guikit.Input.Key_C, Ctrl);
         when Cut_Selected_Items_Command =>
            return (True, Guikit.Input.Key_X, Ctrl);
         when Paste_Items_Command =>
            return (True, Guikit.Input.Key_V, Ctrl);
         when Close_Command_Palette_Command =>
            return (True, Guikit.Input.Key_Escape, Guikit.Input.No_Modifiers);
         when Open_Selected_Items_Command =>
            return (True, Guikit.Input.Key_Return, Guikit.Input.No_Modifiers);
         when Undo_Command =>
            return (True, Guikit.Input.Key_Z, Ctrl);
         when Redo_Command =>
            return (True, Guikit.Input.Key_Z, Ctrl_Shift);
         when Toggle_Quick_Look_Command =>
            return (True, Guikit.Input.Key_Space, Guikit.Input.No_Modifiers);
         when others =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
      end case;
   end Default_Shortcut_For;

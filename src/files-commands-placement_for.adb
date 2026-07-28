separate (Files.Commands)
   function Placement_For
     (Id : Command_Id)
      return Command_Placement is
   begin
      case Id is
         when No_Command =>
            return No_Placement;
         when Select_Drive_Command
            | Navigate_Home_Command
            | Navigate_Back_Command
            | Navigate_Forward_Command
            | Navigate_Parent_Command
            | Create_File_Command
            | New_Folder_Command
            | Delete_Selected_Items_Command =>
            return Toolbar_Left;
         when Focus_Path_Input_Command =>
            return Toolbar_Middle;
         when Focus_Filter_Input_Command | Clear_Filter_Command =>
            return Toolbar_Right;
         when Select_Small_Icons_Command
            | Select_Large_Icons_Command
            | Select_Details_Command
            | Toggle_Sort_Menu_Command
            | Toggle_Info_Pane_Command =>
            return Bottom_Bar;
         when Toggle_Settings_Pane_Command =>
            return Command_Palette_Only;
         when Save_Settings_Command
            | Reset_Settings_Command
            | Eject_Selected_Root_Command =>
            return Command_Palette_Only;
         when Select_All_Command
            | Invert_Selection_Command
            | Deselect_All_Command
            | Copy_Selected_Items_Command
            | Cut_Selected_Items_Command
            | Duplicate_Selected_Command
            | Paste_Items_Command =>
            return Command_Palette_Only;
         when others =>
            return Command_Palette_Only;
      end case;
   end Placement_For;

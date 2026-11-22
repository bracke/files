package body Files.Commands.Context_Menus is

   function Context_Menu_Rows_For
     (Target : Files.UI_Types.Context_Menu_Target)
      return Context_Menu_Rows
   is
      Result : Context_Menu_Rows;

      procedure Add (Command : Command_Id) is
      begin
         Result.Count := Result.Count + 1;
         Result.Rows (Result.Count) := (Kind => Menu_Command, Command => Command);
      end Add;

      procedure Separator is
      begin
         Result.Count := Result.Count + 1;
         Result.Rows (Result.Count) := (Kind => Menu_Separator, Command => No_Command);
      end Separator;
   begin
      case Target is
         when Files.UI_Types.Context_Menu_Item =>
            Add (Open_Selected_Items_Command);
            Add (Open_With_Command);
            Add (Open_Containing_Folder_Command);
            Separator;
            Add (Toggle_Favorite_Command);
            Add (Set_Color_Label_Command);
            Separator;
            Add (Copy_Selected_Items_Command);
            Add (Cut_Selected_Items_Command);
            Add (Copy_Path_Command);
            Add (Copy_To_Command);
            Add (Move_To_Command);
            Add (Duplicate_Selected_Command);
            Separator;
            Add (Compress_Zip_Command);
            Add (Compress_7z_Command);
            Add (Extract_Archive_Command);
            Separator;
            Add (Create_Symlink_Command);
            Add (Create_Hardlink_Command);
            Separator;
            Add (Rename_Selected_Items_Command);
            Add (Delete_Selected_Items_Command);
            Add (Restore_From_Trash_Command);
         when Files.UI_Types.Context_Menu_Empty =>
            Add (Create_File_Command);
            Add (New_Folder_Command);
            Add (Paste_Items_Command);
            Separator;
            Add (Open_Terminal_Command);
            Add (Refresh_Directory_Command);
            Separator;
            Add (Empty_Trash_Command);
            Add (Clear_Recent_Command);
         when Files.UI_Types.Context_Menu_Header =>
            Add (Toggle_Column_Modified_Command);
            Add (Toggle_Column_Size_Command);
            Add (Toggle_Column_Type_Command);
            Add (Toggle_Column_Created_Command);
            Add (Toggle_Column_Permissions_Command);
            Separator;
            Add (Cycle_Group_By_Command);
         when Files.UI_Types.Context_Menu_None =>
            null;
      end case;

      return Result;
   end Context_Menu_Rows_For;

end Files.Commands.Context_Menus;

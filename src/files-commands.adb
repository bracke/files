with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Files.Commands is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;

   function Control_Modifier return Guikit.Input.Modifier_Set is
      Result : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Result (Guikit.Input.Control_Key) := True;
      return Result;
   end Control_Modifier;

   function Alt_Modifier return Guikit.Input.Modifier_Set is
      Result : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Result (Guikit.Input.Alt_Key) := True;
      return Result;
   end Alt_Modifier;

   function Control_Shift_Modifier return Guikit.Input.Modifier_Set is
      Result : Guikit.Input.Modifier_Set := Control_Modifier;
   begin
      Result (Guikit.Input.Shift_Key) := True;
      return Result;
   end Control_Shift_Modifier;

   function Allowed_With_Root_Selector (Id : Command_Id) return Boolean is
   begin
      case Id is
         when Select_Drive_Command
            | Open_Selected_Root_Command
            | Eject_Selected_Root_Command
            | Open_Command_Palette_Command
            | Close_Command_Palette_Command =>
            return True;
         when others =>
            return False;
      end case;
   end Allowed_With_Root_Selector;

   function Allowed_With_Settings_Pane (Id : Command_Id) return Boolean is
   begin
      case Id is
         when Toggle_Settings_Pane_Command
            | Save_Settings_Command
            | Reset_Settings_Command
            | Toggle_Hidden_Files_Command
            | Toggle_Show_Extensions_Command
            | Toggle_Free_Space_Display_Command
            | Open_Command_Palette_Command
            | Close_Command_Palette_Command
            | Toggle_Column_Modified_Command
            | Toggle_Column_Size_Command
            | Toggle_Column_Type_Command
            | Toggle_Column_Created_Command
            | Toggle_Column_Permissions_Command
            | Cycle_Group_By_Command
            | Toggle_Favorite_Command
            | Clear_Recent_Command =>
            return True;
         when others =>
            return False;
      end case;
   end Allowed_With_Settings_Pane;

   function Identifier
     (Id : Command_Id)
      return String is
   begin
      case Id is
         when No_Command =>
            return "";
         when Select_Small_Icons_Command =>
            return "view.small";
         when Select_Large_Icons_Command =>
            return "view.large";
         when Select_Details_Command =>
            return "view.details";
         when Toggle_Info_Pane_Command =>
            return "info.toggle";
         when Toggle_Hidden_Files_Command =>
            return "view.toggle_hidden";
         when Toggle_Show_Extensions_Command =>
            return "view.toggle_extensions";
         when Toggle_Free_Space_Display_Command =>
            return "status.free_space_toggle";
         when Toggle_Settings_Pane_Command =>
            return "settings.toggle";
         when Toggle_Sort_Menu_Command =>
            return "sort.menu.toggle";
         when Sort_By_Name_Command =>
            return "sort.name";
         when Sort_By_Size_Command =>
            return "sort.size";
         when Sort_By_Type_Command =>
            return "sort.type";
         when Sort_By_Created_Command =>
            return "sort.created";
         when Sort_By_Changed_Command =>
            return "sort.changed";
         when Focus_Path_Input_Command =>
            return "path.focus";
         when Navigate_Home_Command =>
            return "navigate.home";
         when Navigate_Back_Command =>
            return "navigate.back";
         when Navigate_Forward_Command =>
            return "navigate.forward";
         when Navigate_Parent_Command =>
            return "navigate.parent";
         when Create_File_Command =>
            return "file.create";
         when New_Folder_Command =>
            return "file.new_folder";
         when Delete_Selected_Items_Command =>
            return "file.delete_selected";
         when Delete_Selected_Permanently_Command =>
            return "file.delete_permanently";
         when Rename_Selected_Items_Command =>
            return "file.rename";
         when Copy_Selected_Items_Command =>
            return "file.copy";
         when Cut_Selected_Items_Command =>
            return "file.cut";
         when Duplicate_Selected_Command =>
            return "file.duplicate";
         when Paste_Items_Command =>
            return "file.paste";
         when Open_Selected_Items_Command =>
            return "file.open_selected";
         when Open_With_Command =>
            return "file.open_with";
         when Compress_Zip_Command =>
            return "file.compress_zip";
         when Compress_7z_Command =>
            return "file.compress_7z";
         when Extract_Archive_Command =>
            return "file.extract";
         when Generate_Thumbnails_Command =>
            return "file.generate_thumbnails";
         when Focus_Filter_Input_Command =>
            return "filter.focus";
         when Open_Command_Palette_Command =>
            return "palette.open";
         when Close_Command_Palette_Command =>
            return "palette.close";
         when Select_Drive_Command =>
            return "drive.select";
         when Open_Selected_Root_Command =>
            return "drive.open_selected";
         when Eject_Selected_Root_Command =>
            return "drive.eject_selected";
         when Clear_Filter_Command =>
            return "filter.clear";
         when Select_All_Command =>
            return "selection.select_all";
         when Invert_Selection_Command =>
            return "selection.invert";
         when Deselect_All_Command =>
            return "selection.deselect_all";
         when Search_Recursive_Command =>
            return "directory.search_recursive";
         when Search_Contents_Command =>
            return "search.contents";
         when Refresh_Directory_Command =>
            return "directory.refresh";
         when Save_Settings_Command =>
            return "settings.save";
         when Reset_Settings_Command =>
            return "settings.reset";
         when Toggle_Favorite_Command =>
            return "favorite.toggle";
         when Navigate_Trash_Command =>
            return "trash.open";
         when Restore_From_Trash_Command =>
            return "trash.restore";
         when Empty_Trash_Command =>
            return "trash.empty";
         when Open_Terminal_Command =>
            return "terminal.open";
         when Create_Symlink_Command =>
            return "link.symbolic";
         when Create_Hardlink_Command =>
            return "link.hard";
         when Undo_Command =>
            return "edit.undo";
         when Redo_Command =>
            return "edit.redo";
         when Toggle_Column_Modified_Command =>
            return "columns.toggle_modified";
         when Toggle_Column_Size_Command =>
            return "columns.toggle_size";
         when Toggle_Column_Type_Command =>
            return "columns.toggle_type";
         when Toggle_Column_Created_Command =>
            return "columns.toggle_created";
         when Toggle_Column_Permissions_Command =>
            return "columns.toggle_permissions";
         when Cycle_Group_By_Command =>
            return "columns.cycle_group_by";
         when Toggle_Folder_Tree_Command =>
            return "tree.toggle";
         when Copy_To_Command =>
            return "file.copy_to";
         when Move_To_Command =>
            return "file.move_to";
         when Copy_Path_Command =>
            return "edit.copy_path";
         when Open_Containing_Folder_Command =>
            return "navigate.containing";
         when Toggle_Quick_Look_Command =>
            return "view.quick_look";
         when Set_Color_Label_Command =>
            return "label.set";
         when Navigate_Recent_Command =>
            return "navigate.recent";
         when Clear_Recent_Command =>
            return "recent.clear";
      end case;
   end Identifier;

   function Name_Key
     (Id : Command_Id)
      return String is
   begin
      case Id is
         when No_Command =>
            return "";
         when Select_Small_Icons_Command =>
            return "command.view.small";
         when Select_Large_Icons_Command =>
            return "command.view.large";
         when Select_Details_Command =>
            return "command.view.details";
         when Toggle_Info_Pane_Command =>
            return "command.info.toggle";
         when Toggle_Hidden_Files_Command =>
            return "command.view.toggle_hidden";
         when Toggle_Show_Extensions_Command =>
            return "command.view.toggle_extensions";
         when Toggle_Free_Space_Display_Command =>
            return "command.status.free_space_toggle";
         when Toggle_Settings_Pane_Command =>
            return "command.settings.toggle";
         when Toggle_Sort_Menu_Command =>
            return "command.sort.menu";
         when Sort_By_Name_Command =>
            return "command.sort.name";
         when Sort_By_Size_Command =>
            return "command.sort.size";
         when Sort_By_Type_Command =>
            return "command.sort.type";
         when Sort_By_Created_Command =>
            return "command.sort.created";
         when Sort_By_Changed_Command =>
            return "command.sort.changed";
         when Focus_Path_Input_Command =>
            return "command.path.focus";
         when Navigate_Home_Command =>
            return "command.navigate.home";
         when Navigate_Back_Command =>
            return "command.navigate.back";
         when Navigate_Forward_Command =>
            return "command.navigate.forward";
         when Navigate_Parent_Command =>
            return "command.navigate.parent";
         when Create_File_Command =>
            return "command.file.create";
         when New_Folder_Command =>
            return "command.file.new_folder";
         when Delete_Selected_Items_Command =>
            return "command.file.delete";
         when Delete_Selected_Permanently_Command =>
            return "command.file.delete_permanently";
         when Rename_Selected_Items_Command =>
            return "command.file.rename";
         when Copy_Selected_Items_Command =>
            return "command.file.copy";
         when Cut_Selected_Items_Command =>
            return "command.file.cut";
         when Duplicate_Selected_Command =>
            return "command.file.duplicate";
         when Paste_Items_Command =>
            return "command.file.paste";
         when Open_Selected_Items_Command =>
            return "command.file.open";
         when Open_With_Command =>
            return "command.file.open_with";
         when Compress_Zip_Command =>
            return "command.file.compress_zip";
         when Compress_7z_Command =>
            return "command.file.compress_7z";
         when Extract_Archive_Command =>
            return "command.file.extract";
         when Generate_Thumbnails_Command =>
            return "command.file.generate_thumbnails";
         when Focus_Filter_Input_Command =>
            return "command.filter.focus";
         when Open_Command_Palette_Command =>
            return "command.palette.open";
         when Close_Command_Palette_Command =>
            return "command.palette.close";
         when Select_Drive_Command =>
            return "command.drive.select";
         when Open_Selected_Root_Command =>
            return "command.drive.open_selected";
         when Eject_Selected_Root_Command =>
            return "command.drive.eject_selected";
         when Clear_Filter_Command =>
            return "command.filter.clear";
         when Select_All_Command =>
            return "command.selection.select_all";
         when Invert_Selection_Command =>
            return "command.selection.invert";
         when Deselect_All_Command =>
            return "command.selection.deselect_all";
         when Search_Recursive_Command =>
            return "command.directory.search_recursive";
         when Search_Contents_Command =>
            return "command.search.contents";
         when Refresh_Directory_Command =>
            return "command.directory.refresh";
         when Save_Settings_Command =>
            return "command.settings.save";
         when Reset_Settings_Command =>
            return "command.settings.reset";
         when Toggle_Favorite_Command =>
            return "command.favorite.toggle";
         when Navigate_Trash_Command =>
            return "command.trash.open";
         when Restore_From_Trash_Command =>
            return "command.trash.restore";
         when Empty_Trash_Command =>
            return "command.trash.empty";
         when Open_Terminal_Command =>
            return "command.terminal.open";
         when Create_Symlink_Command =>
            return "command.link.symbolic";
         when Create_Hardlink_Command =>
            return "command.link.hard";
         when Undo_Command =>
            return "command.edit.undo";
         when Redo_Command =>
            return "command.edit.redo";
         when Toggle_Column_Modified_Command =>
            return "command.columns.toggle_modified";
         when Toggle_Column_Size_Command =>
            return "command.columns.toggle_size";
         when Toggle_Column_Type_Command =>
            return "command.columns.toggle_type";
         when Toggle_Column_Created_Command =>
            return "command.columns.toggle_created";
         when Toggle_Column_Permissions_Command =>
            return "command.columns.toggle_permissions";
         when Cycle_Group_By_Command =>
            return "command.columns.cycle_group_by";
         when Toggle_Folder_Tree_Command =>
            return "command.tree.toggle";
         when Copy_To_Command =>
            return "command.copy_to";
         when Move_To_Command =>
            return "command.move_to";
         when Copy_Path_Command =>
            return "command.edit.copy_path";
         when Open_Containing_Folder_Command =>
            return "command.navigate.containing";
         when Toggle_Quick_Look_Command =>
            return "command.view.quick_look";
         when Set_Color_Label_Command =>
            return "command.label.set";
         when Navigate_Recent_Command =>
            return "command.navigate.recent";
         when Clear_Recent_Command =>
            return "command.recent.clear";
      end case;
   end Name_Key;

   function Description_Key
     (Id : Command_Id)
      return String is
   begin
      case Id is
         when No_Command =>
            return "";
         when Select_Small_Icons_Command =>
            return "command.view.small.description";
         when Select_Large_Icons_Command =>
            return "command.view.large.description";
         when Select_Details_Command =>
            return "command.view.details.description";
         when Toggle_Info_Pane_Command =>
            return "command.info.toggle.description";
         when Toggle_Hidden_Files_Command =>
            return "command.view.toggle_hidden.description";
         when Toggle_Show_Extensions_Command =>
            return "command.view.toggle_extensions.description";
         when Toggle_Free_Space_Display_Command =>
            return "command.status.free_space_toggle.description";
         when Toggle_Settings_Pane_Command =>
            return "command.settings.toggle.description";
         when Toggle_Sort_Menu_Command =>
            return "command.sort.menu.description";
         when Sort_By_Name_Command =>
            return "command.sort.name.description";
         when Sort_By_Size_Command =>
            return "command.sort.size.description";
         when Sort_By_Type_Command =>
            return "command.sort.type.description";
         when Sort_By_Created_Command =>
            return "command.sort.created.description";
         when Sort_By_Changed_Command =>
            return "command.sort.changed.description";
         when Focus_Path_Input_Command =>
            return "command.path.focus.description";
         when Navigate_Home_Command =>
            return "command.navigate.home.description";
         when Navigate_Back_Command =>
            return "command.navigate.back.description";
         when Navigate_Forward_Command =>
            return "command.navigate.forward.description";
         when Navigate_Parent_Command =>
            return "command.navigate.parent.description";
         when Create_File_Command =>
            return "command.file.create.description";
         when New_Folder_Command =>
            return "command.file.new_folder.description";
         when Delete_Selected_Items_Command =>
            return "command.file.delete.description";
         when Delete_Selected_Permanently_Command =>
            return "command.file.delete_permanently.description";
         when Rename_Selected_Items_Command =>
            return "command.file.rename.description";
         when Copy_Selected_Items_Command =>
            return "command.file.copy.description";
         when Cut_Selected_Items_Command =>
            return "command.file.cut.description";
         when Duplicate_Selected_Command =>
            return "command.file.duplicate.description";
         when Paste_Items_Command =>
            return "command.file.paste.description";
         when Open_Selected_Items_Command =>
            return "command.file.open.description";
         when Open_With_Command =>
            return "command.file.open_with.description";
         when Compress_Zip_Command =>
            return "command.file.compress_zip.description";
         when Compress_7z_Command =>
            return "command.file.compress_7z.description";
         when Extract_Archive_Command =>
            return "command.file.extract.description";
         when Generate_Thumbnails_Command =>
            return "command.file.generate_thumbnails.description";
         when Focus_Filter_Input_Command =>
            return "command.filter.focus.description";
         when Open_Command_Palette_Command =>
            return "command.palette.open.description";
         when Close_Command_Palette_Command =>
            return "command.palette.close.description";
         when Select_Drive_Command =>
            return "command.drive.select.description";
         when Open_Selected_Root_Command =>
            return "command.drive.open_selected.description";
         when Eject_Selected_Root_Command =>
            return "command.drive.eject_selected.description";
         when Clear_Filter_Command =>
            return "command.filter.clear.description";
         when Select_All_Command =>
            return "command.selection.select_all.description";
         when Invert_Selection_Command =>
            return "command.selection.invert.description";
         when Deselect_All_Command =>
            return "command.selection.deselect_all.description";
         when Search_Recursive_Command =>
            return "command.directory.search_recursive.description";
         when Search_Contents_Command =>
            return "command.search.contents.description";
         when Refresh_Directory_Command =>
            return "command.directory.refresh.description";
         when Save_Settings_Command =>
            return "command.settings.save.description";
         when Reset_Settings_Command =>
            return "command.settings.reset.description";
         when Toggle_Favorite_Command =>
            return "command.favorite.toggle.description";
         when Navigate_Trash_Command =>
            return "command.trash.open.description";
         when Restore_From_Trash_Command =>
            return "command.trash.restore.description";
         when Empty_Trash_Command =>
            return "command.trash.empty.description";
         when Open_Terminal_Command =>
            return "command.terminal.open.description";
         when Create_Symlink_Command =>
            return "command.link.symbolic.description";
         when Create_Hardlink_Command =>
            return "command.link.hard.description";
         when Undo_Command =>
            return "command.edit.undo.description";
         when Redo_Command =>
            return "command.edit.redo.description";
         when Toggle_Column_Modified_Command =>
            return "command.columns.toggle_modified.description";
         when Toggle_Column_Size_Command =>
            return "command.columns.toggle_size.description";
         when Toggle_Column_Type_Command =>
            return "command.columns.toggle_type.description";
         when Toggle_Column_Created_Command =>
            return "command.columns.toggle_created.description";
         when Toggle_Column_Permissions_Command =>
            return "command.columns.toggle_permissions.description";
         when Cycle_Group_By_Command =>
            return "command.columns.cycle_group_by.description";
         when Toggle_Folder_Tree_Command =>
            return "command.tree.toggle.description";
         when Copy_To_Command =>
            return "command.copy_to.description";
         when Move_To_Command =>
            return "command.move_to.description";
         when Copy_Path_Command =>
            return "command.edit.copy_path.description";
         when Open_Containing_Folder_Command =>
            return "command.navigate.containing.description";
         when Toggle_Quick_Look_Command =>
            return "command.view.quick_look.description";
         when Set_Color_Label_Command =>
            return "command.label.set.description";
         when Navigate_Recent_Command =>
            return "command.navigate.recent.description";
         when Clear_Recent_Command =>
            return "command.recent.clear.description";
      end case;
   end Description_Key;

   function Default_Shortcut_For
     (Id : Command_Id)
      return Shortcut
 is separate;

   --  ----- shortcut overrides (user-editable keymap) ---------------------------

   Overrides    : array (Command_Id) of Shortcut := [others => (others => <>)];
   Override_Set : array (Command_Id) of Boolean := [others => False];

   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut) is
   begin
      Overrides (Id)    := Value;
      Override_Set (Id) := True;
   end Set_Shortcut_Override;

   procedure Clear_Shortcut_Override (Id : Command_Id) is
   begin
      Override_Set (Id) := False;
   end Clear_Shortcut_Override;

   procedure Reset_Shortcut_Overrides is
   begin
      Override_Set := [others => False];
   end Reset_Shortcut_Overrides;

   function Shortcut_Override (Id : Command_Id; Is_Set : out Boolean) return Shortcut is
   begin
      Is_Set := Override_Set (Id);
      return Overrides (Id);
   end Shortcut_Override;

   --  The effective primary shortcut: the override when set, else the default.
   function Shortcut_For
     (Id : Command_Id)
      return Shortcut is
   begin
      if Override_Set (Id) then
         return Overrides (Id);
      end if;
      return Default_Shortcut_For (Id);
   end Shortcut_For;

   function Secondary_Shortcut_For
     (Id : Command_Id)
      return Shortcut is
      Ctrl : constant Guikit.Input.Modifier_Set := Control_Modifier;
   begin
      case Id is
         when Delete_Selected_Items_Command =>
            return (True, Guikit.Input.Key_Backspace, Guikit.Input.No_Modifiers);
         when Refresh_Directory_Command =>
            --  F5 is the universal refresh accelerator, offered in addition to
            --  the displayed Control+R primary shortcut.
            return (True, Guikit.Input.Key_F5, Guikit.Input.No_Modifiers);
         when Redo_Command =>
            --  Control+Y is the Windows/Office redo accelerator, offered
            --  alongside the displayed Control+Shift+Z primary shortcut.
            return (True, Guikit.Input.Key_Y, Ctrl);
         when others =>
            return (False, Guikit.Input.Key_Unknown, Guikit.Input.No_Modifiers);
      end case;
   end Secondary_Shortcut_For;

   function Key_Text
     (Key : Guikit.Input.Key_Code)
      return String is separate;

   function Shortcut_Text
     (Value : Shortcut)
      return String
 is separate;

   function Text_To_Key (Text : String) return Guikit.Input.Key_Code is
   begin
      if Text = "" then
         return Guikit.Input.Key_Unknown;
      end if;
      for K in Guikit.Input.Key_Code'Range loop
         if Key_Text (K) = Text then
            return K;
         end if;
      end loop;
      return Guikit.Input.Key_Unknown;
   end Text_To_Key;

   function Parse_Shortcut (Text : String) return Shortcut is separate;

   function Shortcut_Search_Text
     (Id : Command_Id)
      return String
 is separate;

   function Placement_For
     (Id : Command_Id)
      return Command_Placement is separate;

   function Command_Palette_Visible
     (Id : Command_Id)
      return Boolean is
   begin
      return Id /= No_Command;
   end Command_Palette_Visible;

   function Requires_Settings_Path
     (Id : Command_Id)
      return Boolean is
   begin
      case Id is
         when Save_Settings_Command
            | Toggle_Hidden_Files_Command
            | Toggle_Show_Extensions_Command
            | Toggle_Free_Space_Display_Command
            | Toggle_Column_Modified_Command
            | Toggle_Column_Size_Command
            | Toggle_Column_Type_Command
            | Toggle_Column_Created_Command
            | Toggle_Column_Permissions_Command
            | Cycle_Group_By_Command
            | Toggle_Favorite_Command
            | Clear_Recent_Command =>
            return True;
         when others =>
            return False;
      end case;
   end Requires_Settings_Path;

   function Persists_Global_Ui_State
     (Id : Command_Id)
      return Boolean is
   begin
      case Id is
         when Select_Small_Icons_Command
            | Select_Large_Icons_Command
            | Select_Details_Command
            | Sort_By_Name_Command
            | Sort_By_Size_Command
            | Sort_By_Type_Command
            | Sort_By_Created_Command
            | Sort_By_Changed_Command
            | Toggle_Info_Pane_Command =>
            return True;
         when others =>
            return False;
      end case;
   end Persists_Global_Ui_State;

   function Command_Count return Natural is
   begin
      return Command_Id'Pos (Registered_Command_Id'Last)
        - Command_Id'Pos (Registered_Command_Id'First)
        + 1;
   end Command_Count;

   function Contains
     (Identifier_Text : String)
      return Boolean is
   begin
      for Id in Registered_Command_Id loop
         if Identifier (Id) = Identifier_Text then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   function Id_For_Identifier
     (Identifier_Text : String)
      return Command_Id is
   begin
      for Id in Registered_Command_Id loop
         if Identifier (Id) = Identifier_Text then
            return Id;
         end if;
      end loop;

      return No_Command;
   end Id_For_Identifier;

   --  Normalize a path for trash-location comparison, falling back to the raw
   --  text when the path cannot be validated.
   function Normalized_Path (Path : String) return String is
      Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Path);
   begin
      if Result.Status = Files.File_System.Path_Valid then
         return To_String (Result.Directory_Path);
      else
         return Path;
      end if;
   exception
      when others =>
         return Path;
   end Normalized_Path;

   --  Return whether a simple file name ends, case-insensitively, in a
   --  recognized archive extension (.zip or .7z).
   function Name_Is_Archive (Name : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
        or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
   end Name_Is_Archive;

   --  Return whether at least one selected item is a recognized archive.
   function Selection_Has_Archive (Model : Files.Model.Window_Model) return Boolean is
      Items : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
   begin
      for Item of Items loop
         if Name_Is_Archive (To_String (Item.Name)) then
            return True;
         end if;
      end loop;

      return False;
   end Selection_Has_Archive;

   --  Return whether the model currently shows the platform trash payload
   --  directory rather than an ordinary directory.
   function In_Trash_View (Model : Files.Model.Window_Model) return Boolean is
      Trash_Dir : constant String := Files.File_System.Trash_Files_Directory;
   begin
      return Trash_Dir /= ""
        and then Normalized_Path (Files.Model.Current_Path (Model)) = Normalized_Path (Trash_Dir);
   end In_Trash_View;

   function Joined_Full_Paths
     (Items : Files.File_System.Item_Vectors.Vector)
      return String
   is
      Result : Unbounded_String;
      First  : Boolean := True;
   begin
      for Item of Items loop
         if not First then
            Append (Result, ASCII.LF);
         end if;
         Append (Result, Item.Full_Path);
         First := False;
      end loop;

      return To_String (Result);
   end Joined_Full_Paths;

   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean is separate;

   function Find_By_Shortcut
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id is
   begin
      for Id in Registered_Command_Id loop
         declare
            Candidate : constant Shortcut := Shortcut_For (Id);
            Secondary : constant Shortcut := Secondary_Shortcut_For (Id);
         begin
            if (Candidate.Present
                and then Candidate.Key = Key
                and then Candidate.Modifiers = Modifiers)
              or else
                (Secondary.Present
                 and then Secondary.Key = Key
                 and then Secondary.Modifiers = Modifiers)
            then
               return Id;
            end if;
         end;
      end loop;

      return No_Command;
   end Find_By_Shortcut;

   procedure Execute
     (Id    : Command_Id;
      Model : in out Files.Model.Window_Model)
 is separate;

end Files.Commands;

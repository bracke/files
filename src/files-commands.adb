with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;

package body Files.Commands is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Key_Code;
   use type Files.Types.Modifier_Set;

   function Control_Modifier return Files.Types.Modifier_Set is
      Result : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
   begin
      Result (Files.Types.Control_Key) := True;
      return Result;
   end Control_Modifier;

   function Alt_Modifier return Files.Types.Modifier_Set is
      Result : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
   begin
      Result (Files.Types.Alt_Key) := True;
      return Result;
   end Alt_Modifier;

   function Control_Shift_Modifier return Files.Types.Modifier_Set is
      Result : Files.Types.Modifier_Set := Control_Modifier;
   begin
      Result (Files.Types.Shift_Key) := True;
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
            | Open_Command_Palette_Command
            | Close_Command_Palette_Command =>
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
         when Search_Recursive_Command =>
            return "directory.search_recursive";
         when Refresh_Directory_Command =>
            return "directory.refresh";
         when Save_Settings_Command =>
            return "settings.save";
         when Reset_Settings_Command =>
            return "settings.reset";
         when Toggle_Bookmark_Command =>
            return "bookmark.toggle";
         when Navigate_Trash_Command =>
            return "trash.open";
         when Restore_From_Trash_Command =>
            return "trash.restore";
         when Undo_Command =>
            return "edit.undo";
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
         when Search_Recursive_Command =>
            return "command.directory.search_recursive";
         when Refresh_Directory_Command =>
            return "command.directory.refresh";
         when Save_Settings_Command =>
            return "command.settings.save";
         when Reset_Settings_Command =>
            return "command.settings.reset";
         when Toggle_Bookmark_Command =>
            return "command.bookmark.toggle";
         when Navigate_Trash_Command =>
            return "command.trash.open";
         when Restore_From_Trash_Command =>
            return "command.trash.restore";
         when Undo_Command =>
            return "command.edit.undo";
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
         when Search_Recursive_Command =>
            return "command.directory.search_recursive.description";
         when Refresh_Directory_Command =>
            return "command.directory.refresh.description";
         when Save_Settings_Command =>
            return "command.settings.save.description";
         when Reset_Settings_Command =>
            return "command.settings.reset.description";
         when Toggle_Bookmark_Command =>
            return "command.bookmark.toggle.description";
         when Navigate_Trash_Command =>
            return "command.trash.open.description";
         when Restore_From_Trash_Command =>
            return "command.trash.restore.description";
         when Undo_Command =>
            return "command.edit.undo.description";
      end case;
   end Description_Key;

   function Shortcut_For
     (Id : Command_Id)
      return Shortcut
   is
      Ctrl       : constant Files.Types.Modifier_Set := Control_Modifier;
      Alt        : constant Files.Types.Modifier_Set := Alt_Modifier;
      Ctrl_Shift : constant Files.Types.Modifier_Set := Control_Shift_Modifier;
   begin
      case Id is
         when Select_Small_Icons_Command =>
            return (True, Files.Types.Key_1, Ctrl);
         when Select_Large_Icons_Command =>
            return (True, Files.Types.Key_2, Ctrl);
         when Select_Details_Command =>
            return (True, Files.Types.Key_3, Ctrl);
         when Toggle_Info_Pane_Command =>
            return (True, Files.Types.Key_4, Ctrl);
         when Toggle_Settings_Pane_Command =>
            return (True, Files.Types.Key_Comma, Ctrl);
         when Toggle_Sort_Menu_Command
            | Sort_By_Name_Command
            | Sort_By_Size_Command
            | Sort_By_Type_Command
            | Sort_By_Created_Command
            | Sort_By_Changed_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Focus_Path_Input_Command =>
            return (True, Files.Types.Key_L, Ctrl);
         when Navigate_Home_Command =>
            return (True, Files.Types.Key_Home, Alt);
         when Navigate_Back_Command =>
            return (True, Files.Types.Key_Left, Alt);
         when Navigate_Forward_Command =>
            return (True, Files.Types.Key_Right, Alt);
         when Create_File_Command =>
            return (True, Files.Types.Key_N, Ctrl);
         when Select_All_Command =>
            return (True, Files.Types.Key_A, Ctrl);
         when Open_Command_Palette_Command =>
            return (True, Files.Types.Key_P, Ctrl);
         when Focus_Filter_Input_Command =>
            return (True, Files.Types.Key_F, Ctrl);
         when Select_Drive_Command =>
            return (True, Files.Types.Key_D, Ctrl);
         when Clear_Filter_Command =>
            return (True, Files.Types.Key_F, Ctrl_Shift);
         when Search_Recursive_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Refresh_Directory_Command =>
            return (True, Files.Types.Key_R, Ctrl);
         when Save_Settings_Command =>
            return (True, Files.Types.Key_S, Ctrl);
         when Reset_Settings_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Toggle_Bookmark_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Open_Selected_Root_Command | Eject_Selected_Root_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Delete_Selected_Items_Command =>
            return (True, Files.Types.Key_Delete, Files.Types.No_Modifiers);
         when Delete_Selected_Permanently_Command =>
            return (True, Files.Types.Key_Delete, [Files.Types.Shift_Key => True, others => False]);
         when Generate_Thumbnails_Command =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
         when Rename_Selected_Items_Command =>
            return (True, Files.Types.Key_F2, Files.Types.No_Modifiers);
         when Copy_Selected_Items_Command =>
            return (True, Files.Types.Key_C, Ctrl);
         when Cut_Selected_Items_Command =>
            return (True, Files.Types.Key_X, Ctrl);
         when Paste_Items_Command =>
            return (True, Files.Types.Key_V, Ctrl);
         when Close_Command_Palette_Command =>
            return (True, Files.Types.Key_Escape, Files.Types.No_Modifiers);
         when Open_Selected_Items_Command =>
            return (True, Files.Types.Key_Return, Files.Types.No_Modifiers);
         when others =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
      end case;
   end Shortcut_For;

   function Secondary_Shortcut_For
     (Id : Command_Id)
      return Shortcut is
   begin
      case Id is
         when Delete_Selected_Items_Command =>
            return (True, Files.Types.Key_Backspace, Files.Types.No_Modifiers);
         when others =>
            return (False, Files.Types.Key_Unknown, Files.Types.No_Modifiers);
      end case;
   end Secondary_Shortcut_For;

   function Key_Text
     (Key : Files.Types.Key_Code)
      return String is
   begin
      case Key is
         when Files.Types.Key_1 =>
            return "1";
         when Files.Types.Key_2 =>
            return "2";
         when Files.Types.Key_3 =>
            return "3";
         when Files.Types.Key_4 =>
            return "4";
         when Files.Types.Key_A =>
            return "a";
         when Files.Types.Key_C =>
            return "c";
         when Files.Types.Key_D =>
            return "d";
         when Files.Types.Key_F =>
            return "f";
         when Files.Types.Key_L =>
            return "l";
         when Files.Types.Key_N =>
            return "n";
         when Files.Types.Key_P =>
            return "p";
         when Files.Types.Key_R =>
            return "r";
         when Files.Types.Key_S =>
            return "s";
         when Files.Types.Key_V =>
            return "v";
         when Files.Types.Key_X =>
            return "x";
         when Files.Types.Key_Comma =>
            return ",";
         when Files.Types.Key_Backspace =>
            return "backspace";
         when Files.Types.Key_Delete =>
            return "delete";
         when Files.Types.Key_F2 =>
            return "f2";
         when Files.Types.Key_Escape =>
            return "escape";
         when Files.Types.Key_Return =>
            return "return";
         when Files.Types.Key_Left =>
            return "left";
         when Files.Types.Key_Right =>
            return "right";
         when Files.Types.Key_Up =>
            return "up";
         when Files.Types.Key_Down =>
            return "down";
         when Files.Types.Key_Home =>
            return "home";
         when Files.Types.Key_End =>
            return "end";
         when Files.Types.Key_Page_Up =>
            return "pageup";
         when Files.Types.Key_Page_Down =>
            return "pagedown";
         when Files.Types.Key_Space =>
            return "space";
         when Files.Types.Key_Unknown =>
            return "";
      end case;
   end Key_Text;

   function Shortcut_Text
     (Value : Shortcut)
      return String
   is
      Result : Unbounded_String;
      Key    : constant String := Key_Text (Value.Key);
   begin
      if not Value.Present or else Key = "" then
         return "";
      end if;

      if Value.Modifiers (Files.Types.Shift_Key) then
         Append (Result, "shift+");
      end if;
      if Value.Modifiers (Files.Types.Control_Key) then
         Append (Result, "control+");
      end if;
      if Value.Modifiers (Files.Types.Alt_Key) then
         Append (Result, "alt+");
      end if;
      if Value.Modifiers (Files.Types.Meta_Key) then
         Append (Result, "meta+");
      end if;
      Append (Result, Key);
      return To_String (Result);
   end Shortcut_Text;

   function Shortcut_Search_Text
     (Id : Command_Id)
      return String
   is
      Primary   : constant String := Shortcut_Text (Shortcut_For (Id));
      Secondary : constant String := Shortcut_Text (Secondary_Shortcut_For (Id));

      function Search_Aliases (Text : String) return String is
         Shift_Control_Prefix : constant String := "shift+control+";
         Result : Unbounded_String := To_Unbounded_String (Text);

         procedure Add_Control_Alias is
         begin
            if Text'Length > 8
              and then Text (Text'First .. Text'First + 7) = "control+"
            then
               Append (Result, ASCII.HT);
               Append (Result, "ctrl+");
               Append (Result, Text (Text'First + 8 .. Text'Last));
            end if;
         end Add_Control_Alias;

         procedure Add_Alt_Alias is
         begin
            if Text'Length > 4
              and then Text (Text'First .. Text'First + 3) = "alt+"
            then
               Append (Result, ASCII.HT);
               Append (Result, "option+");
               Append (Result, Text (Text'First + 4 .. Text'Last));
            end if;
         end Add_Alt_Alias;

         procedure Add_Shift_Control_Aliases is
         begin
            if Text'Length > Shift_Control_Prefix'Length
              and then Text (Text'First .. Text'First + Shift_Control_Prefix'Length - 1) =
                Shift_Control_Prefix
            then
               declare
                  Suffix : constant String :=
                    Text (Text'First + Shift_Control_Prefix'Length .. Text'Last);
               begin
                  Append (Result, ASCII.HT);
                  Append (Result, "shift+ctrl+");
                  Append (Result, Suffix);
                  Append (Result, ASCII.HT);
                  Append (Result, "control+shift+");
                  Append (Result, Suffix);
                  Append (Result, ASCII.HT);
                  Append (Result, "ctrl+shift+");
                  Append (Result, Suffix);
               end;
            end if;
         end Add_Shift_Control_Aliases;

         procedure Add_Key_Alias
           (Canonical : String;
            Alias     : String)
         is
            Position : constant Natural := Ada.Strings.Fixed.Index (Text, Canonical);
         begin
            if Position > 0 then
               Append (Result, ASCII.HT);
               if Position > Text'First then
                  Append (Result, Text (Text'First .. Position - 1));
               end if;
               Append (Result, Alias);
            end if;
         end Add_Key_Alias;
      begin
         Add_Control_Alias;
         Add_Alt_Alias;
         Add_Shift_Control_Aliases;
         Add_Key_Alias ("delete", "del");
         Add_Key_Alias ("escape", "esc");
         Add_Key_Alias ("return", "enter");
         return To_String (Result);
      end Search_Aliases;
   begin
      if Primary = "" then
         return Search_Aliases (Secondary);
      elsif Secondary = "" then
         return Search_Aliases (Primary);
      else
         return Search_Aliases (Primary) & " " & Search_Aliases (Secondary);
      end if;
   end Shortcut_Search_Text;

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
            | Copy_Selected_Items_Command
            | Cut_Selected_Items_Command
            | Duplicate_Selected_Command
            | Paste_Items_Command =>
            return Command_Palette_Only;
         when others =>
            return Command_Palette_Only;
      end case;
   end Placement_For;

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
            | Toggle_Hidden_Files_Command =>
            return True;
         when others =>
            return False;
      end case;
   end Requires_Settings_Path;

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

   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean is
   begin
      if Files.Model.Root_Selector_Is_Open (Model)
        and then not Allowed_With_Root_Selector (Id)
      then
         return False;
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Allowed_With_Settings_Pane (Id)
      then
         return False;
      end if;

      case Id is
         when No_Command =>
            return False;
         when Navigate_Back_Command =>
            return Files.Model.Can_Go_Back (Model);
         when Navigate_Forward_Command =>
            return Files.Model.Can_Go_Forward (Model);
         when Delete_Selected_Items_Command | Open_Selected_Items_Command
            | Open_With_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model);
         when Compress_Zip_Command | Compress_7z_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model);
         when Extract_Archive_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then Selection_Has_Archive (Model);
         when Delete_Selected_Permanently_Command | Generate_Thumbnails_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model);
         when Copy_Selected_Items_Command | Cut_Selected_Items_Command
            | Duplicate_Selected_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model);
         when Paste_Items_Command =>
            return Files.Model.Clipboard_Has_Items (Model)
              and then not Files.Model.Temporary_Item_Is_Active (Model);
         when Create_File_Command | New_Folder_Command =>
            return not Files.Model.Temporary_Item_Is_Active (Model);
         when Toggle_Info_Pane_Command =>
            --  The info pane can always be toggled, even with no selection: an
            --  empty selection simply shows an empty pane.
            return True;
         when Rename_Selected_Items_Command =>
            return Files.Model.Rename_Is_Enabled (Model) or else Files.Model.Rename_Is_Active (Model);
         when Close_Command_Palette_Command =>
            return Files.Model.Context_Menu_Is_Open (Model)
              or else Files.Model.Command_Palette_Is_Open (Model)
              or else Files.Model.Root_Selector_Is_Open (Model)
              or else Files.Model.Sort_Menu_Is_Open (Model)
              or else Files.Model.Settings_Pane_Is_Open (Model)
              or else Files.Model.Focus (Model) /= Files.Types.Focus_None
              or else Files.Model.Rename_Is_Active (Model);
         when Open_Selected_Root_Command =>
            return Files.Model.Root_Selector_Is_Open (Model)
              and then Files.Model.Root_Selected_Index (Model) > 0
              and then Files.Model.Root_Selected_Index (Model) <= Files.Model.Root_Count (Model);
         when Eject_Selected_Root_Command =>
            return Files.Model.Root_Selector_Is_Open (Model)
              and then Files.Model.Root_Selected_Index (Model) > 0
              and then Files.Model.Root_Selected_Index (Model) <= Files.Model.Root_Count (Model)
              and then Files.Model.Root_Is_Removable (Model, Files.Model.Root_Selected_Index (Model));
         when Clear_Filter_Command =>
            return Files.Model.Filter_Text (Model) /= "";
         when Search_Recursive_Command =>
            return Files.Model.Filter_Text (Model) /= "";
         when Select_All_Command =>
            return Files.Model.Visible_Count (Model) > 0
              and then not Files.Model.Temporary_Item_Is_Active (Model);
         when Save_Settings_Command
            | Reset_Settings_Command =>
            return Files.Model.Settings_Pane_Is_Open (Model);
         when Navigate_Trash_Command =>
            return Files.File_System.Trash_Files_Directory /= "";
         when Restore_From_Trash_Command =>
            declare
               Trash_Dir : constant String := Files.File_System.Trash_Files_Directory;
            begin
               return Trash_Dir /= ""
                 and then Normalized_Path (Files.Model.Current_Path (Model)) = Normalized_Path (Trash_Dir)
                 and then Files.Model.Selected_Count (Model) > 0
                 and then not Files.Model.Selection_Includes_Temporary (Model);
            end;
         when Undo_Command =>
            return Files.Model.Undo_Available (Model);
         when others =>
            return True;
      end case;
   end Is_Enabled;

   function Find_By_Shortcut
     (Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set)
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
   is
   begin
      if not Is_Enabled (Id, Model) then
         return;
      end if;

      case Id is
         when No_Command =>
            null;
         when Select_Small_Icons_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
         when Select_Large_Icons_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
         when Select_Details_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Details);
         when Toggle_Info_Pane_Command =>
            Files.Model.Toggle_Info_Pane (Model);
         when Toggle_Hidden_Files_Command =>
            null;
         when Toggle_Settings_Pane_Command =>
            if Files.Model.Settings_Pane_Is_Open (Model) then
               Files.Model.Toggle_Settings_Pane (Model);
            end if;
         when Toggle_Sort_Menu_Command =>
            Files.Model.Toggle_Sort_Menu (Model);
         when Sort_By_Name_Command =>
            Files.Model.Select_Sort_Field (Model, Files.Model.Sort_Name);
         when Sort_By_Size_Command =>
            Files.Model.Select_Sort_Field (Model, Files.Model.Sort_Size);
         when Sort_By_Type_Command =>
            Files.Model.Select_Sort_Field (Model, Files.Model.Sort_Type);
         when Sort_By_Created_Command =>
            Files.Model.Select_Sort_Field (Model, Files.Model.Sort_Created);
         when Sort_By_Changed_Command =>
            Files.Model.Select_Sort_Field (Model, Files.Model.Sort_Changed);
         when Focus_Path_Input_Command =>
            Files.Model.Focus_Path_Input (Model);
         when Navigate_Home_Command =>
            null;
         when Navigate_Back_Command =>
            null;
         when Navigate_Forward_Command =>
            null;
         when Create_File_Command =>
            null;
         when New_Folder_Command =>
            null;
         when Delete_Selected_Items_Command =>
            null;
         when Delete_Selected_Permanently_Command =>
            null;
         when Rename_Selected_Items_Command =>
            Files.Model.Toggle_Rename (Model);
         when Copy_Selected_Items_Command =>
            null;
         when Cut_Selected_Items_Command =>
            null;
         when Duplicate_Selected_Command =>
            null;
         when Paste_Items_Command =>
            null;
         when Open_Selected_Items_Command =>
            null;
         when Open_With_Command =>
            null;
         when Compress_Zip_Command | Compress_7z_Command =>
            null;
         when Extract_Archive_Command =>
            null;
         when Generate_Thumbnails_Command =>
            null;
         when Focus_Filter_Input_Command =>
            Files.Model.Focus_Filter_Input (Model);
         when Open_Command_Palette_Command =>
            Files.Model.Toggle_Command_Palette (Model);
         when Close_Command_Palette_Command =>
            if Files.Model.Context_Menu_Is_Open (Model) then
               Files.Model.Close_Context_Menu (Model);
            elsif Files.Model.Command_Palette_Is_Open (Model) then
               Files.Model.Close_Command_Palette (Model);
            elsif Files.Model.Root_Selector_Is_Open (Model) then
               Files.Model.Close_Root_Selector (Model);
            elsif Files.Model.Sort_Menu_Is_Open (Model) then
               Files.Model.Close_Sort_Menu (Model);
            elsif Files.Model.Settings_Pane_Is_Open (Model) then
               Files.Model.Toggle_Settings_Pane (Model);
            else
               Files.Model.Cancel_Focus_Or_Edit (Model);
            end if;
         when Select_Drive_Command =>
            null;
         when Open_Selected_Root_Command =>
            null;
         when Eject_Selected_Root_Command =>
            null;
         when Clear_Filter_Command =>
            Files.Model.Clear_Filter (Model);
         when Select_All_Command =>
            Files.Model.Select_All_Visible (Model);
         when Search_Recursive_Command =>
            null;
         when Refresh_Directory_Command =>
            null;
         when Save_Settings_Command =>
            null;
         when Reset_Settings_Command =>
            null;
         when Toggle_Bookmark_Command =>
            null;
         when Navigate_Trash_Command =>
            null;
         when Restore_From_Trash_Command =>
            null;
         when Undo_Command =>
            null;
      end case;
   end Execute;

end Files.Commands;

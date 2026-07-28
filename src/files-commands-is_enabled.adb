separate (Files.Commands)
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
         when Navigate_Parent_Command =>
            --  Enabled only in an ordinary directory view that has a parent;
            --  disabled at a filesystem root and in the trash and recent views.
            return not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model)
              and then Files.File_System.Parent_Directory
                         (Files.Model.Current_Path (Model)) /= "";
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
         when Copy_To_Command | Move_To_Command =>
            --  Choosing a destination copies/moves the current selection, so at
            --  least one real (non-temporary) item must be selected in an
            --  ordinary directory rather than the trash payload view.
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model);
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
              or else Files.Model.Label_Picker_Is_Open (Model)
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
         when Search_Recursive_Command | Search_Contents_Command =>
            return Files.Model.Filter_Text (Model) /= "";
         when Select_All_Command =>
            return Files.Model.Visible_Count (Model) > 0
              and then not Files.Model.Temporary_Item_Is_Active (Model);
         when Invert_Selection_Command =>
            return Files.Model.Visible_Count (Model) > 0
              and then not Files.Model.Temporary_Item_Is_Active (Model);
         when Deselect_All_Command =>
            return Files.Model.Selected_Count (Model) > 0;
         when Save_Settings_Command
            | Reset_Settings_Command =>
            return Files.Model.Settings_Pane_Is_Open (Model);
         when Toggle_Favorite_Command =>
            --  Favoriting works on the selection when present, otherwise on the
            --  current directory. Enabled in an ordinary directory view (not the
            --  trash payload) whenever there is a selection or a navigable path.
            return not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model)
              and then (Files.Model.Selected_Count (Model) > 0
                        or else Files.Model.Current_Path (Model) /= "");
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
         when Empty_Trash_Command =>
            --  Emptying is only meaningful in the trash payload view and only
            --  when at least one trashed entry is present to purge.
            return In_Trash_View (Model)
              and then Files.Model.Item_Count (Model) > 0;
         when Navigate_Recent_Command =>
            --  The recent-items view is always reachable; an empty list simply
            --  opens onto an empty view.
            return True;
         when Clear_Recent_Command =>
            --  Clearing is only meaningful in the recent view and only when at
            --  least one recent entry is present to purge.
            return Files.Model.In_Recent_View (Model)
              and then Files.Model.Item_Count (Model) > 0;
         when Undo_Command =>
            return Files.Model.Undo_Available (Model);
         when Redo_Command =>
            return Files.Model.Redo_Available (Model);
         when Open_Terminal_Command =>
            --  A terminal can be opened for any real directory view, but not the
            --  trash payload directory or the virtual recent view.
            return not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model);
         when Create_Symlink_Command | Create_Hardlink_Command =>
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model);
         when Copy_Path_Command =>
            --  Copying paths to the system clipboard needs at least one real
            --  (non-temporary) item selected in an ordinary directory rather
            --  than the trash payload view.
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model);
         when Open_Containing_Folder_Command =>
            --  Reveal navigates to a single item's parent directory. It is
            --  enabled for exactly one real selected item in an ordinary
            --  directory view and is a safe no-op when that parent is already
            --  the current directory.
            return Files.Model.Selected_Count (Model) = 1
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model);
         when Toggle_Quick_Look_Command =>
            --  Quick Look previews exactly one real (non-temporary) item in an
            --  ordinary directory view; it never opens in the trash payload view
            --  or on an empty/multi selection.
            return Files.Model.Selected_Count (Model) = 1
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model);
         when Set_Color_Label_Command =>
            --  Color labels apply to the current selection, so at least one real
            --  (non-temporary) item must be selected in an ordinary directory
            --  rather than the trash payload or virtual recent view.
            return Files.Model.Selected_Count (Model) > 0
              and then not Files.Model.Selection_Includes_Temporary (Model)
              and then not In_Trash_View (Model)
              and then not Files.Model.In_Recent_View (Model);
         when others =>
            return True;
      end case;
   end Is_Enabled;

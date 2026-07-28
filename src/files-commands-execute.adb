separate (Files.Commands)
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
         when Toggle_Show_Extensions_Command =>
            null;
         when Toggle_Free_Space_Display_Command =>
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
         when Navigate_Parent_Command =>
            --  Navigating to the parent loads a directory from the filesystem,
            --  so it is routed through Files.Controller rather than this pure
            --  model-only executor.
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
            if Files.Model.Label_Picker_Is_Open (Model) then
               Files.Model.Close_Label_Picker (Model);
            elsif Files.Model.Context_Menu_Is_Open (Model) then
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
         when Invert_Selection_Command =>
            Files.Model.Invert_Selection (Model);
         when Deselect_All_Command =>
            Files.Model.Deselect_All (Model);
         when Search_Recursive_Command =>
            null;
         when Search_Contents_Command =>
            --  Walking the subtree and reading each file's bounded bytes needs
            --  filesystem access, so content search is routed through
            --  Files.Controller rather than this pure model-only executor.
            null;
         when Refresh_Directory_Command =>
            null;
         when Save_Settings_Command =>
            null;
         when Reset_Settings_Command =>
            null;
         when Toggle_Favorite_Command =>
            null;
         when Navigate_Trash_Command =>
            null;
         when Restore_From_Trash_Command =>
            null;
         when Empty_Trash_Command =>
            --  Permanently purging every trashed entry loads and mutates the
            --  filesystem trash directory, so it is routed through
            --  Files.Controller rather than this pure model-only executor.
            null;
         when Open_Terminal_Command =>
            null;
         when Create_Symlink_Command =>
            null;
         when Create_Hardlink_Command =>
            null;
         when Undo_Command =>
            null;
         when Redo_Command =>
            null;
         when Toggle_Column_Modified_Command
            | Toggle_Column_Size_Command
            | Toggle_Column_Type_Command
            | Toggle_Column_Created_Command
            | Toggle_Column_Permissions_Command
            | Cycle_Group_By_Command =>
            --  Detail-column and grouping toggles mutate persisted settings, so
            --  they are routed through Files.Interaction (which owns the settings
            --  path) rather than this pure model-only executor.
            null;
         when Toggle_Folder_Tree_Command =>
            --  Opening the tree seeds its roots from the filesystem, so the live
            --  toggle is routed through Files.Controller. This pure fallback only
            --  flips the panel flag for callers that never open an empty tree.
            Files.Model.Toggle_Tree_Panel (Model);
         when Copy_To_Command | Move_To_Command =>
            --  Capturing the selection and seeding the destination tree needs
            --  filesystem-backed roots, so these are routed through
            --  Files.Controller rather than this pure model-only executor.
            null;
         when Copy_Path_Command =>
            --  Building the newline-joined selection paths is pure; the shell
            --  reads the recorded request and writes the system clipboard.
            Files.Model.Set_System_Clipboard_Request
              (Model, Joined_Full_Paths (Files.Model.Selected_Items (Model)));
            Files.Model.Set_Error (Model, "");
         when Open_Containing_Folder_Command =>
            --  Revealing an item navigates to its parent directory and selects
            --  it, which loads a directory from the filesystem, so it is routed
            --  through Files.Controller rather than this pure model-only executor.
            null;
         when Toggle_Quick_Look_Command =>
            --  The pure toggle previews the selected item as a metadata-only info
            --  card (no filesystem read). The live shell routes this command
            --  through Files.Controller, which reads the bounded text or image so
            --  richer text/image previews are prepared.
            Files.Model.Toggle_Quick_Look (Model);
            Files.Model.Set_Error (Model, "");
         when Set_Color_Label_Command =>
            --  Opening the swatch picker is pure model state; the chosen label is
            --  applied and persisted through the settings-write seam when the
            --  user clicks a swatch.
            Files.Model.Open_Label_Picker (Model);
            Files.Model.Set_Error (Model, "");
         when Navigate_Recent_Command =>
            --  Building the recent listing stats the stored paths, so it is
            --  routed through Files.Controller rather than this pure executor.
            null;
         when Clear_Recent_Command =>
            --  Clearing mutates persisted settings, so it is routed through
            --  Files.Interaction (which owns the settings path) rather than this
            --  pure model-only executor.
            null;
      end case;
   end Execute;

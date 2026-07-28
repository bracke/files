separate (Files.Controller)
   function Execute_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
   is
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      if Files.Model.Root_Selector_Is_Open (Model)
        and then not Files.Commands.Allowed_With_Root_Selector (Id)
      then
         return Make_Result (Controller_Ignored, Id);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Files.Commands.Allowed_With_Settings_Pane (Id)
      then
         return Make_Result (Controller_Ignored, Id);
      elsif not Files.Commands.Is_Enabled (Id, Model) then
         return Disabled_Command_Result (Id, Model);
      end if;

      case Id is
         when Files.Commands.Navigate_Home_Command =>
            Operation := Files.Operations.Navigate_Home (Model, Settings);
         when Files.Commands.Navigate_Parent_Command =>
            Operation := Files.Operations.Navigate_Parent (Model, Settings);
         when Files.Commands.Navigate_Trash_Command =>
            Operation := Files.Operations.Navigate_Trash (Model, Settings);
         when Files.Commands.Navigate_Recent_Command =>
            Operation := Files.Operations.Navigate_Recent (Model, Settings);
         when Files.Commands.Restore_From_Trash_Command =>
            Operation := Files.Operations.Restore_Selected_From_Trash (Model, Settings);
         when Files.Commands.Empty_Trash_Command =>
            Operation := Files.Operations.Empty_Trash (Model, Settings);
         when Files.Commands.Undo_Command =>
            Operation := Files.Operations.Undo_Last (Model, Settings);
         when Files.Commands.Redo_Command =>
            Operation := Files.Operations.Redo_Last (Model, Settings);
         when Files.Commands.Navigate_Back_Command =>
            Operation := Files.Operations.Navigate_Back (Model, Settings);
         when Files.Commands.Navigate_Forward_Command =>
            Operation := Files.Operations.Navigate_Forward (Model, Settings);
         when Files.Commands.Open_Selected_Items_Command =>
            Operation := Files.Operations.Open_Selected (Model, Settings, Modifiers);
         when Files.Commands.Open_With_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Targets : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Targets.Append (Item.Full_Path);
               end loop;
               --  Open_Command_Palette resets palette mode and targets, so
               --  capture the selection into the model only afterwards.
               Files.Model.Open_Command_Palette (Model);
               Files.Model.Set_Open_With_Targets (Model, Targets);
               Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Delete_Selected_Items_Command =>
            Operation := Files.Operations.Delete_Selected (Model, Settings);
         when Files.Commands.Delete_Selected_Permanently_Command =>
            Operation := Files.Operations.Delete_Selected_Permanently (Model, Settings);
         when Files.Commands.Copy_Selected_Items_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Set_Clipboard
                 (Model, Paths, Files.Model.Clipboard_Copy);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Cut_Selected_Items_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Set_Clipboard
                 (Model, Paths, Files.Model.Clipboard_Cut);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Duplicate_Selected_Command =>
            Operation := Files.Operations.Duplicate_Selected (Model, Settings);
         when Files.Commands.Create_Symlink_Command =>
            Operation := Files.Operations.Create_Symlink_Selected (Model, Settings);
         when Files.Commands.Create_Hardlink_Command =>
            Operation := Files.Operations.Create_Hardlink_Selected (Model, Settings);
         when Files.Commands.Open_Terminal_Command =>
            Operation := Files.Operations.Open_Terminal (Model, Settings);
         when Files.Commands.Compress_Zip_Command =>
            Operation :=
              Files.Operations.Compress_Selected
                (Model, Settings, Files.Operations.Zip_Archive);
         when Files.Commands.Compress_7z_Command =>
            Operation :=
              Files.Operations.Compress_Selected
                (Model, Settings, Files.Operations.Seven_Zip_Archive);
         when Files.Commands.Extract_Archive_Command =>
            Operation := Files.Operations.Extract_Selected (Model, Settings);
         when Files.Commands.Paste_Items_Command =>
            declare
               use type Files.Model.Clipboard_Mode;
               Paths : constant Files.Types.String_Vectors.Vector :=
                 Files.Model.Clipboard_Paths (Model);
               Mode  : constant Files.Model.Clipboard_Mode :=
                 Files.Model.Clipboard_Mode_Of (Model);
               Drop_Mode : constant Files.File_System.Drop_Import_Mode :=
                 (if Mode = Files.Model.Clipboard_Cut
                  then Files.File_System.Drop_Move
                  else Files.File_System.Drop_Copy);
            begin
               --  Begin_Paste executes immediately when no destination name
               --  collides, or arms the conflict dialog when one does. The cut
               --  clipboard is cleared by the operation once the move actually
               --  runs (immediately, or after the last conflict is resolved).
               Operation :=
                 Files.Operations.Begin_Paste (Model, Settings, Paths, Drop_Mode);
            end;
         when Files.Commands.Generate_Thumbnails_Command =>
            Operation := Files.Operations.Generate_Selected_Thumbnails (Model, Settings);
         when Files.Commands.Search_Recursive_Command =>
            Operation := Files.Operations.Run_Recursive_Search (Model, Settings);
         when Files.Commands.Search_Contents_Command =>
            Operation := Files.Operations.Run_Content_Search (Model, Settings);
         when Files.Commands.Refresh_Directory_Command =>
            Operation := Files.Operations.Refresh (Model, Settings);
         when Files.Commands.Open_Containing_Folder_Command =>
            return Reveal_Selected_Item (Model, Settings);
         when Files.Commands.Open_Selected_Root_Command =>
            return Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         when Files.Commands.Eject_Selected_Root_Command =>
            Operation := Files.Operations.Eject_Selected_Root (Model);
         when Files.Commands.Create_File_Command =>
            Files.Model.Begin_Create_File
              (Model,
               Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model)));
            Files.Model.Set_Error (Model, "");
         when Files.Commands.New_Folder_Command =>
            Files.Model.Begin_Create_Folder
              (Model,
               Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model)));
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Select_Drive_Command =>
            if Files.Model.Root_Selector_Is_Open (Model) then
               Files.Model.Close_Root_Selector (Model);
            else
               declare
                  Roots : Files.File_System.Root_Entry_Vectors.Vector :=
                    Files.File_System.Available_Root_Entries;
               begin
                  for Path of Settings.Favorite_Paths loop
                     Roots.Append
                       (Files.File_System.Root_Entry'
                          (Path        => Path,
                           --  Use the "root.favorite|<name>" label token so the
                           --  selector renders the star prefix and base name
                           --  rather than the full path.
                           Label       =>
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Files.File_System.Root_Label
                                  (Ada.Strings.Unbounded.To_String (Path),
                                   Files.File_System.Root_Favorite)),
                           Kind        => Files.File_System.Root_Favorite,
                           Volume_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
                           Ready       => Files.File_System.Root_Ready,
                           Removable   => False));
                  end loop;
                  Files.Model.Open_Root_Selector (Model, Roots);
               end;
            end if;
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Toggle_Folder_Tree_Command =>
            if Files.Model.Tree_Panel_Is_Open (Model) then
               Files.Model.Close_Tree_Panel (Model);
            else
               Seed_Tree_If_Needed (Model, Settings);
               Files.Model.Open_Tree_Panel (Model);
            end if;
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Copy_To_Command | Files.Commands.Move_To_Command =>
            --  Capture the current selection, then open the folder tree as a
            --  destination picker seeded with the same roots the toggle uses.
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
               Mode  : constant Files.Model.Tree_Pick_Mode :=
                 (if Id = Files.Commands.Move_To_Command
                  then Files.Model.Pick_Move
                  else Files.Model.Pick_Copy);
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Begin_Tree_Pick
                 (Model, Mode, Paths, Files.Model.Current_Path (Model));
               Seed_Tree_If_Needed (Model, Settings);
               Files.Model.Open_Tree_Panel (Model);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Toggle_Quick_Look_Command =>
            --  Toggle the Quick Look overlay. Opening reads the bounded preview
            --  bytes (or classifies the image) so the overlay shows text/image
            --  content rather than the metadata-only pure fallback.
            if Files.Model.Quick_Look_Is_Open (Model) then
               Files.Model.Close_Quick_Look (Model);
            else
               Files.Model.Open_Quick_Look
                 (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
            end if;
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operations.Operation_Success;
         when Files.Commands.Reset_Settings_Command =>
            Files.Model.Set_Settings_Draft (Model, Files.Settings.Reset_Draft_To_Defaults);
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operations.Operation_Success;
         when Files.Commands.Close_Command_Palette_Command =>
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
            else
               Files.Model.Cancel_Focus_Or_Edit (Model);
            end if;
         when others =>
            if Id = Files.Commands.Toggle_Settings_Pane_Command
              and then not Files.Model.Settings_Pane_Is_Open (Model)
            then
               Files.Model.Begin_Settings_Edit (Model, Files.Settings.Make_Draft (Settings));
            else
               Files.Commands.Execute (Id, Model);
            end if;
            case Id is
               when Files.Commands.Focus_Path_Input_Command
                  | Files.Commands.Focus_Filter_Input_Command
                  | Files.Commands.Open_Command_Palette_Command =>
                  Files.Model.Set_Error (Model, "");
               when others =>
                  null;
            end case;
      end case;

      if Operation.Status = Files.Operations.Operation_Disabled
        and then Length (Operation.Error_Key) = 0
        and then not Files.Commands.Requires_Settings_Path (Id)
      then
         Operation.Status := Files.Operations.Operation_Success;
      end if;

      return Make_Result (Controller_Command_Executed, Id, Operation);
   end Execute_Command;

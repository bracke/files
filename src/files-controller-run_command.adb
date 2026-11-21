with Files.Settings_Form;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files.Commands.Execution;
with Files.Model.Clipboard;
with Files.Model.Quick_Look;
separate (Files.Controller)
   function Run_Command
     (Id        : Files.Commands.Non_Settings_Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result
   is
      --  Every branch that carries out the command itself says so (Success).
      --  An operation it hands the command to may instead decline without a
      --  reason -- a job is already running, so nothing new starts -- and
      --  that is reported as done too: there is no failure to show.
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation;

      function Settled
        (Result : Files.Operation_Results.Operation_Result) return Files.Operation_Results.Operation_Result is
        (if Result.Status = Files.Operation_Results.Operation_Disabled and then Length (Result.Error_Key) = 0
         then (Result with delta Status => Files.Operation_Results.Operation_Success)
         else Result);

      function Selected_Paths return Files.Types.String_Vectors.Vector is
        (Files.Model.Selection.Selected_Paths (Model));
   begin
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
            Operation := Files.Operation_Commands.Restore_Selected_From_Trash (Model, Settings);
         when Files.Commands.Empty_Trash_Command =>
            Operation := Files.Operation_Commands.Empty_Trash (Model, Settings);
         when Files.Commands.Undo_Command =>
            Operation := Files.Operation_Commands.Undo_Last (Model, Settings);
         when Files.Commands.Redo_Command =>
            Operation := Files.Operation_Commands.Redo_Last (Model, Settings);
         when Files.Commands.Navigate_Back_Command =>
            Operation := Files.Operations.Navigate_Back (Model, Settings);
         when Files.Commands.Navigate_Forward_Command =>
            Operation := Files.Operations.Navigate_Forward (Model, Settings);
         when Files.Commands.Open_Selected_Items_Command =>
            Operation := Files.Operations.Open_Selected (Model, Settings, Modifiers);
         when Files.Commands.Open_With_Command =>
            Files.Operations.Begin_Open_With (Model);
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Delete_Selected_Items_Command =>
            Operation := Files.Operation_Commands.Delete_Selected (Model, Settings);
         when Files.Commands.Delete_Selected_Permanently_Command =>
            Operation := Files.Operation_Commands.Delete_Selected_Permanently (Model, Settings);
         when Files.Commands.Copy_Selected_Items_Command =>
            Files.Model.Clipboard.Set (Model, Selected_Paths, Files.Model.Clipboard_Copy);
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Cut_Selected_Items_Command =>
            Files.Model.Clipboard.Set (Model, Selected_Paths, Files.Model.Clipboard_Cut);
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Duplicate_Selected_Command =>
            Operation := Files.Operation_Commands.Duplicate_Selected (Model, Settings);
         when Files.Commands.Create_Symlink_Command =>
            Operation := Files.Operations.Create_Symlink_Selected (Model, Settings);
         when Files.Commands.Create_Hardlink_Command =>
            Operation := Files.Operations.Create_Hardlink_Selected (Model, Settings);
         when Files.Commands.Open_Terminal_Command =>
            Operation := Files.Operations.Open_Terminal (Model);
         when Files.Commands.Compress_Zip_Command =>
            Operation :=
              Files.Operation_Commands.Compress_Selected
                (Model, Settings, Files.Operations.Zip_Archive);
         when Files.Commands.Compress_7z_Command =>
            Operation :=
              Files.Operation_Commands.Compress_Selected
                (Model, Settings, Files.Operations.Seven_Zip_Archive);
         when Files.Commands.Extract_Archive_Command =>
            Operation := Files.Operation_Commands.Extract_Selected (Model, Settings);
         when Files.Commands.Paste_Items_Command =>
            declare
               use type Files.Model.Clipboard_Mode;
               Paths : constant Files.Types.String_Vectors.Vector :=
                 Files.Model.Clipboard.Paths (Model);
               Mode  : constant Files.Model.Clipboard_Mode :=
                 Files.Model.Clipboard.Mode_Of (Model);
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
            Operation := Files.Operation_Commands.Run_Search (Model, Settings, Files.Types.Search_Names);
         when Files.Commands.Search_Contents_Command =>
            Operation := Files.Operation_Commands.Run_Search (Model, Settings, Files.Types.Search_Contents);
         when Files.Commands.Refresh_Directory_Command =>
            Operation := Files.Operations.Refresh (Model, Settings);
         when Files.Commands.Open_Containing_Folder_Command =>
            return Reveal_Selected_Item (Model, Settings);
         when Files.Commands.Open_Selected_Root_Command =>
            if not Files.Model.Root_Selector.Is_Open (Model)
              or else Files.Model.Root_Selector.Selected_Index (Model)
                not in 1 .. Files.Model.Root_Selector.Count (Model)
            then
               return Make_Result (Controller_Ignored);
            end if;
            return Open_Root (Model, Settings, Files.Model.Root_Selector.Selected_Index (Model));
         when Files.Commands.Eject_Selected_Root_Command =>
            Operation := Files.Operations.Eject_Selected_Root (Model);
         when Files.Commands.Create_File_Command =>
            Files.Operations.Begin_Create_Item (Model, Folder => False);
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.New_Folder_Command =>
            Files.Operations.Begin_Create_Item (Model, Folder => True);
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Select_Drive_Command =>
            if Files.Model.Root_Selector.Is_Open (Model) then
               Files.Model.Root_Selector.Close (Model);
            else
               Files.Model.Root_Selector.Open (Model, Files.Operations.Root_Entries_With_Favorites (Settings));
            end if;
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Toggle_Folder_Tree_Command =>
            if Files.Model.Tree_Panel.Pick_Is_Active (Model) then
               --  The picker's Cancel: leave the tree as it was before.
               Files.Model.Tree_Panel.End_Pick (Model);
            elsif Files.Model.Tree_Panel.Is_Open (Model) then
               Files.Model.Tree_Panel.Close (Model);
            else
               Files.Operations.Seed_Tree (Model, Settings);
               Files.Model.Tree_Panel.Open (Model);
            end if;
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Copy_To_Command | Files.Commands.Move_To_Command =>
            --  Capture the current selection, then open the folder tree as a
            --  destination picker seeded with the same roots the toggle uses.
            declare
               Mode  : constant Files.Model.Tree_Pick_Mode :=
                 (if Id = Files.Commands.Move_To_Command
                  then Files.Model.Pick_Move
                  else Files.Model.Pick_Copy);
            begin
               Files.Model.Tree_Panel.Begin_Pick
                 (Model, Mode, Selected_Paths, Files.Model.Current_Path (Model));
               Files.Operations.Seed_Tree (Model, Settings);
               Files.Model.Tree_Panel.Open (Model);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operation_Results.Operation_Success;
            end;
         when Files.Commands.Toggle_Quick_Look_Command =>
            --  Toggle the Quick Look overlay. Opening reads the bounded preview
            --  bytes (or classifies the image) so the overlay shows text/image
            --  content rather than the metadata-only pure fallback.
            if Files.Model.Quick_Look.Is_Open (Model) then
               Files.Model.Quick_Look.Close (Model);
            else
               Files.Model.Quick_Look.Open
                 (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selection.Selected_Item (Model)));
            end if;
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Close_Overlay_Command =>
            return Close_Top_Or_Cancel (Model);
         when Files.Commands.Toggle_Settings_Pane_Command =>
            if Files.Model.Settings_Pane.Is_Open (Model) then
               Files.Model.Settings_Pane.Close (Model);
            else
               Files.Settings_Form.Begin_Edit (Model, Settings);
            end if;
            Operation.Status := Files.Operation_Results.Operation_Success;
         when Files.Commands.Pure_Command_Id =>
            declare
               Had_Results : constant Boolean := Files.Model.Search_Results_Are_Active (Model);
            begin
               Files.Commands.Execution.Execute (Id, Model);
               Operation.Status := Files.Operation_Results.Operation_Success;
               --  Clearing the filter ends a search: the folder's own listing
               --  replaces the results, as when the scope chip goes back.
               if Id = Files.Commands.Clear_Filter_Command and then Had_Results then
                  Operation := Files.Operations.Refresh (Model, Settings);
               end if;
            end;
      end case;

      return Make_Result (Controller_Command_Executed, Id, Settled (Operation));
   end Run_Command;

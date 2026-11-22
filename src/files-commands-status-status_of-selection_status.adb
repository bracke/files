separate (Files.Commands.Status.Status_Of)
   function Selection_Status (Command : Selection_Command) return Command_Status is
   begin
      case Command is
         when Delete_Selected_Items_Command
            | Cut_Selected_Items_Command
            | Duplicate_Selected_Command
            | Compress_Zip_Command
            | Compress_7z_Command =>
            return All_Of (Real_Selection, Not_Trash_View);
         when Open_Selected_Items_Command
            | Open_With_Command
            | Delete_Selected_Permanently_Command
            | Generate_Thumbnails_Command
            | Copy_Selected_Items_Command =>
            return Real_Selection;
         when Extract_Archive_Command =>
            --  The selection is scanned for an archive only once the cheap
            --  checks pass: an actual is evaluated whether or not it is needed.
            declare
               Base : constant Command_Status := All_Of (Real_Selection, Not_Trash_View);
            begin
               return
                 (if not Base.Enabled then Base
                  else Require (Files.Model.Selection.Has_Archive (Model), Not_Archive_Reason));
            end;
         when Copy_To_Command
            | Move_To_Command
            | Create_Symlink_Command
            | Create_Hardlink_Command
            | Copy_Path_Command
            | Set_Color_Label_Command =>
            --  These act on the current selection in an ordinary directory:
            --  copying/moving or linking the trash payload or the virtual recent
            --  list is not offered.
            return All_Of (Real_Selection, Ordinary_View);
         when Select_All_Command | Invert_Selection_Command =>
            return All_Of (Require (Files.Model.Visible_Count (Model) > 0), No_Pending_Create);
         when Deselect_All_Command =>
            return Require (Files.Model.Selection.Selected_Count (Model) > 0);
         when Toggle_Favorite_Command =>
            --  Favoriting works on the selection when present, otherwise on the
            --  current directory, in an ordinary directory view. A temporary
            --  create row counts as selected but has no real path; do not
            --  mistake it for the empty-selection folder fallback.
            return
              All_Of
                (Ordinary_View,
                 Require (not Files.Model.Selection.Includes_Temporary (Model), Create_Pending_Reason),
                 Require
                   (Files.Model.Selection.Selected_Count (Model) > 0
                  or else Files.Model.Current_Path (Model) /= ""));
         when Restore_From_Trash_Command =>
            --  Offered only in the trash view, where it acts on the selection.
            return All_Of (Require (In_Trash_View (Model)), Real_Selection);
         when Open_Containing_Folder_Command =>
            --  Reveal navigates to a single item's parent directory. It is a
            --  safe no-op when that parent is already the current directory.
            return All_Of (Single_Real_Selection, Not_Trash_View);
         when Toggle_Quick_Look_Command =>
            --  Quick Look previews exactly one real item outside the trash
            --  payload view. Closing an open preview is always allowed, even
            --  after a reload emptied the selection.
            if Files.Model.Quick_Look.Is_Open (Model) then
               return Enabled;
            end if;
            return All_Of (Single_Real_Selection, Not_Trash_View);
      end case;
   end Selection_Status;

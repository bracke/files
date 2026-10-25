separate (Files.Commands)
   function Status_Of
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Command_Status
   is
      Enabled : constant Command_Status := (Enabled => True, Reason => No_Reason);

      --  Disabled, with Reason as what the user is told (No_Reason: nothing).
      function Disabled (Reason : Disabled_Reason := No_Reason) return Command_Status is
        ((Enabled => False, Reason => Reason));

      --  Enabled when Condition holds, otherwise disabled for Reason.
      function Require
        (Condition : Boolean;
         Reason    : Disabled_Reason := No_Reason)
         return Command_Status is
        (if Condition then Enabled else Disabled (Reason));

      --  The first of the checks that fails, or Enabled when none does. The
      --  checks are listed in the order their reasons should be reported.
      function All_Of
        (First  : Command_Status;
         Second : Command_Status := Enabled;
         Third  : Command_Status := Enabled;
         Fourth : Command_Status := Enabled)
         return Command_Status is
        (if not First.Enabled then First
         elsif not Second.Enabled then Second
         elsif not Third.Enabled then Third
         else Fourth);

      --  The shared predicates the per-command rules are built from.

      --  At least one real item is selected: a temporary create row counts as
      --  selected but has no file behind it yet.
      function Real_Selection return Command_Status is
        (if Files.Model.Selected_Count (Model) = 0 then Disabled (Selection_Empty_Reason)
         elsif Files.Model.Selection_Includes_Temporary (Model) then Disabled (Create_Pending_Reason)
         else Enabled);

      --  Exactly one real item is selected (a multi-selection says nothing).
      function Single_Real_Selection return Command_Status is
        (All_Of (Real_Selection, Require (Files.Model.Selected_Count (Model) = 1)));

      --  No inline file or folder creation is pending.
      function No_Pending_Create return Command_Status is
        (Require (not Files.Model.Temporary_Item_Is_Active (Model), Create_Pending_Reason));

      --  The view is not the trash payload directory.
      function Not_Trash_View return Command_Status is
        (Require (not In_Trash_View (Model), Trash_View_Reason));

      --  The view is not the virtual recent-items list.
      function Not_Recent_View return Command_Status is
        (Require (not Files.Model.In_Recent_View (Model), Recent_View_Reason));

      --  An ordinary directory view: neither the trash nor the recent list.
      function Ordinary_View return Command_Status is
        (All_Of (Not_Trash_View, Not_Recent_View));

      --  The view has a real directory path (only virtual views lack one).
      function Has_Directory return Command_Status is
        (Require (Files.Model.Current_Path (Model) /= ""));

      function Valid_Root_Selected return Boolean is
        (Files.Model.Root_Selector_Is_Open (Model)
         and then Files.Model.Root_Selected_Index (Model) > 0
         and then Files.Model.Root_Selected_Index (Model) <= Files.Model.Root_Count (Model));
   begin
      --  A modal overlay owns the keyboard; it blocks other commands silently.
      if Files.Model.Root_Selector_Is_Open (Model)
        and then not Allowed_With_Root_Selector (Id)
      then
         return Disabled;
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Allowed_With_Settings_Pane (Id)
      then
         return Disabled;
      end if;

      case Id is
         when No_Command =>
            return Disabled;
         when Navigate_Back_Command =>
            return Require (Files.Model.Can_Go_Back (Model), Back_Unavailable_Reason);
         when Navigate_Forward_Command =>
            return Require (Files.Model.Can_Go_Forward (Model), Forward_Unavailable_Reason);
         when Navigate_Parent_Command =>
            --  Enabled only in an ordinary directory view that has a parent;
            --  disabled at a filesystem root and in the trash and recent views.
            return
              All_Of
                (Ordinary_View,
                 Require (Files.File_System.Parent_Directory (Files.Model.Current_Path (Model)) /= ""));
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
            return
              All_Of
                (Real_Selection, Not_Trash_View, Require (Selection_Has_Archive (Model), Not_Archive_Reason));
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
         when Paste_Items_Command =>
            return
              All_Of
                (Require (Files.Model.Clipboard_Has_Items (Model), Clipboard_Empty_Reason),
                 No_Pending_Create, Ordinary_View, Has_Directory);
         when Create_File_Command | New_Folder_Command =>
            return All_Of (No_Pending_Create, Ordinary_View, Has_Directory);
         when Toggle_Info_Pane_Command =>
            --  The info pane can always be toggled, even with no selection: an
            --  empty selection simply shows an empty pane.
            return Enabled;
         when Rename_Selected_Items_Command =>
            return
              All_Of
                (Ordinary_View,
                 Require
                   (Files.Model.Rename_Is_Enabled (Model) or else Files.Model.Rename_Is_Active (Model),
                    Rename_Unavailable_Reason));
         when Close_Command_Palette_Command =>
            --  Nothing open to close: Escape just does nothing.
            declare
               Overlay : Files.Model.Input_Overlay;
            begin
               return
                 Require
                   (Files.Model.Escape_Overlay (Model, Overlay)
                    or else Files.Model.Focus (Model) /= Files.Types.Focus_None
                    or else Files.Model.Rename_Is_Active (Model));
            end;
         when Open_Selected_Root_Command =>
            return Require (Valid_Root_Selected, Root_Unselected_Reason);
         when Eject_Selected_Root_Command =>
            return
              All_Of
                (Require (Valid_Root_Selected, Root_Unselected_Reason),
                 Require
                   (Valid_Root_Selected
                    and then Files.Model.Root_Is_Removable (Model, Files.Model.Root_Selected_Index (Model)),
                    Eject_Unavailable_Reason));
         when Clear_Filter_Command =>
            return Require (Files.Model.Filter_Text (Model) /= "", Filter_Empty_Reason);
         when Search_Recursive_Command | Search_Contents_Command =>
            return
              All_Of
                (Require (Files.Model.Filter_Text (Model) /= "", Filter_Empty_Reason),
                 Not_Recent_View, Has_Directory);
         when Select_All_Command | Invert_Selection_Command =>
            return All_Of (Require (Files.Model.Visible_Count (Model) > 0), No_Pending_Create);
         when Deselect_All_Command =>
            return Require (Files.Model.Selected_Count (Model) > 0);
         when Save_Settings_Command
            | Reset_Settings_Command =>
            return Require (Files.Model.Settings_Pane_Is_Open (Model), Settings_Closed_Reason);
         when Toggle_Favorite_Command =>
            --  Favoriting works on the selection when present, otherwise on the
            --  current directory, in an ordinary directory view. A temporary
            --  create row counts as selected but has no real path; do not
            --  mistake it for the empty-selection folder fallback.
            return
              All_Of
                (Ordinary_View,
                 Require (not Files.Model.Selection_Includes_Temporary (Model), Create_Pending_Reason),
                 Require (Files.Model.Selected_Count (Model) > 0 or else Files.Model.Current_Path (Model) /= ""));
         when Navigate_Trash_Command =>
            return Require (Files.File_System.Trash_Files_Directory /= "", Trash_Unavailable_Reason);
         when Restore_From_Trash_Command =>
            --  Offered only in the trash view, where it acts on the selection.
            return All_Of (Require (In_Trash_View (Model)), Real_Selection);
         when Empty_Trash_Command =>
            --  Emptying is only meaningful in the trash payload view and only
            --  when at least one trashed entry is present to purge.
            return Require (In_Trash_View (Model) and then Files.Model.Item_Count (Model) > 0);
         when Navigate_Recent_Command =>
            --  The recent-items view is always reachable; an empty list simply
            --  opens onto an empty view.
            return Enabled;
         when Clear_Recent_Command =>
            --  Stale recent paths are omitted from the virtual listing, so an
            --  empty view can still have persisted entries that need clearing.
            return Require (Files.Model.In_Recent_View (Model));
         when Undo_Command =>
            return Require (Files.Model.Undo_Available (Model));
         when Redo_Command =>
            return Require (Files.Model.Redo_Available (Model));
         when Open_Terminal_Command =>
            --  A terminal can be opened for any real directory view, but not the
            --  trash payload directory or the virtual recent view.
            return All_Of (Ordinary_View, Has_Directory);
         when Open_Containing_Folder_Command =>
            --  Reveal navigates to a single item's parent directory. It is a
            --  safe no-op when that parent is already the current directory.
            return All_Of (Single_Real_Selection, Not_Trash_View);
         when Toggle_Quick_Look_Command =>
            --  Quick Look previews exactly one real item outside the trash
            --  payload view. Closing an open preview is always allowed, even
            --  after a reload emptied the selection.
            if Files.Model.Quick_Look_Is_Open (Model) then
               return Enabled;
            end if;
            return All_Of (Single_Real_Selection, Not_Trash_View);
         when others =>
            return Enabled;
      end case;
   end Status_Of;

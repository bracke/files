with Files.Model.Recent;
with Files.Model.Filtering;
with Files.Model.Creation;
with Files.Command_Reasons; use Files.Command_Reasons;
with Files.Model.Clipboard;
with Files.Model.Quick_Look;
with Files.Model.Root_Selector;
with Files.Model.Settings_Pane;
separate (Files.Commands.Status)
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
        (if Files.Model.Selection.Selected_Count (Model) = 0 then Disabled (Selection_Empty_Reason)
         elsif Files.Model.Selection.Includes_Temporary (Model) then Disabled (Create_Pending_Reason)
         else Enabled);

      --  Exactly one real item is selected (a multi-selection says nothing).
      function Single_Real_Selection return Command_Status is
        (All_Of (Real_Selection, Require (Files.Model.Selection.Selected_Count (Model) = 1)));

      --  No inline file or folder creation is pending.
      function No_Pending_Create return Command_Status is
        (Require (not Files.Model.Creation.Temporary_Item_Is_Active (Model), Create_Pending_Reason));

      --  The view is not the trash payload directory.
      function Not_Trash_View return Command_Status is
        (Require (not In_Trash_View (Model), Trash_View_Reason));

      --  The view is not the virtual recent-items list.
      function Not_Recent_View return Command_Status is
        (Require (not Files.Model.Recent.In_Recent_View (Model), Recent_View_Reason));

      --  An ordinary directory view: neither the trash nor the recent list.
      function Ordinary_View return Command_Status is
        (All_Of (Not_Trash_View, Not_Recent_View));

      --  The view has a real directory path (only virtual views lack one).
      function Has_Directory return Command_Status is
        (Require (Files.Model.Current_Path (Model) /= ""));

      function Valid_Root_Selected return Boolean is
        (Files.Model.Root_Selector.Is_Open (Model)
         and then Files.Model.Root_Selector.Selected_Index (Model) > 0
         and then Files.Model.Root_Selector.Selected_Index (Model) <= Files.Model.Root_Selector.Count (Model));

      --  The commands that act on the selection.
      subtype Selection_Command is Command_Id
        with Static_Predicate =>
          Selection_Command in Delete_Selected_Items_Command
            | Cut_Selected_Items_Command
            | Duplicate_Selected_Command
            | Compress_Zip_Command
            | Compress_7z_Command
            | Open_Selected_Items_Command
            | Open_With_Command
            | Delete_Selected_Permanently_Command
            | Generate_Thumbnails_Command
            | Copy_Selected_Items_Command
            | Extract_Archive_Command
            | Copy_To_Command
            | Move_To_Command
            | Create_Symlink_Command
            | Create_Hardlink_Command
            | Copy_Path_Command
            | Set_Color_Label_Command
            | Select_All_Command
            | Invert_Selection_Command
            | Deselect_All_Command
            | Toggle_Favorite_Command
            | Restore_From_Trash_Command
            | Open_Containing_Folder_Command
            | Toggle_Quick_Look_Command;

      --  Whether a selection command can run on the current selection.
      function Selection_Status (Command : Selection_Command) return Command_Status is separate;

      --  The commands that move between views or act on the view itself:
      --  history, the parent, the trash and recent views, a terminal.
      subtype Navigation_Command is Command_Id
        with Static_Predicate =>
          Navigation_Command in Navigate_Back_Command
            | Navigate_Forward_Command
            | Navigate_Parent_Command
            | Navigate_Trash_Command
            | Empty_Trash_Command
            | Navigate_Recent_Command
            | Clear_Recent_Command
            | Open_Terminal_Command;

      --  Whether a navigation command can run from the current view.
      function Navigation_Status (Command : Navigation_Command) return Command_Status is separate;

      --  The commands that answer an open overlay or a field: Escape, the
      --  root selector's rows, the filter and its searches, the settings
      --  pane's buttons.
      subtype Overlay_Command is Command_Id
        with Static_Predicate =>
          Overlay_Command in Close_Overlay_Command
            | Open_Selected_Root_Command
            | Eject_Selected_Root_Command
            | Clear_Filter_Command
            | Search_Recursive_Command
            | Search_Contents_Command
            | Save_Settings_Command
            | Reset_Settings_Command;

      --  Whether an overlay or field command has something to act on.
      function Overlay_Status (Command : Overlay_Command) return Command_Status is separate;
   begin
      --  A modal overlay owns the keyboard; it blocks other commands silently.
      if Files.Model.Root_Selector.Is_Open (Model)
        and then not Allowed_With_Root_Selector (Id)
      then
         return Disabled;
      elsif Files.Model.Settings_Pane.Is_Open (Model)
        and then not Allowed_With_Settings_Pane (Id)
      then
         return Disabled;
      end if;

      case Id is
         when Selection_Command =>
            return Selection_Status (Id);
         when No_Command =>
            return Disabled;
         when Navigation_Command =>
            return Navigation_Status (Id);
         when Overlay_Command =>
            return Overlay_Status (Id);
         when Paste_Items_Command =>
            return
              All_Of
                (Require (Files.Model.Clipboard.Has_Items (Model), Clipboard_Empty_Reason),
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
                   (Files.Model.Rename.Is_Enabled (Model) or else Files.Model.Rename.Is_Active (Model),
                    Rename_Unavailable_Reason));
         when Undo_Command =>
            return Require (Files.Model.History.Undo_Available (Model));
         when Redo_Command =>
            return Require (Files.Model.History.Redo_Available (Model));
         when Select_Small_Icons_Command
            | Select_Large_Icons_Command
            | Select_Details_Command
            | Toggle_Hidden_Files_Command
            | Toggle_Show_Extensions_Command
            | Toggle_Free_Space_Display_Command
            | Toggle_Settings_Pane_Command
            | Toggle_Sort_Menu_Command
            | Sort_By_Name_Command
            | Sort_By_Size_Command
            | Sort_By_Type_Command
            | Sort_By_Created_Command
            | Sort_By_Changed_Command
            | Focus_Path_Input_Command
            | Navigate_Home_Command
            | Focus_Filter_Input_Command
            | Open_Command_Palette_Command
            | Select_Drive_Command
            | Refresh_Directory_Command
            | Toggle_Column_Modified_Command
            | Toggle_Column_Size_Command
            | Toggle_Column_Type_Command
            | Toggle_Column_Created_Command
            | Toggle_Column_Permissions_Command
            | Cycle_Group_By_Command
            | Toggle_Folder_Tree_Command =>
            --  View, sort, focus and window commands: always available. A new
            --  command must be placed here or given its own condition.
            return Enabled;
      end case;
   end Status_Of;

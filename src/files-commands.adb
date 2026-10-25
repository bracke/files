with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Files.Commands is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;

   package GI renames Guikit.Input;

   None       : GI.Modifier_Set renames GI.No_Modifiers;
   Ctrl       : constant GI.Modifier_Set := [GI.Control_Key => True, others => False];
   Alt        : constant GI.Modifier_Set := [GI.Alt_Key => True, others => False];
   Shift      : constant GI.Modifier_Set := [GI.Shift_Key => True, others => False];
   Ctrl_Shift : constant GI.Modifier_Set := [GI.Control_Key | GI.Shift_Key => True, others => False];

   function "+" (Text : String) return Unbounded_String renames To_Unbounded_String;

   --  Everything about a command that is a per-command constant, in one row
   --  per command. The functions below read this table instead of keeping
   --  their own case statements over Command_Id.
   type Command_Traits is record
      --  Stable identifier: the palette search token and the [shortcuts] key.
      Identifier         : Unbounded_String;
      --  Localization key of the display name, set only where it is not the
      --  default (Name_Key_Prefix & Identifier): a few older keys predate it.
      Name_Key           : Unbounded_String;
      Placement          : Command_Placement := Command_Palette_Only;
      --  Built-in primary shortcut (user overrides replace it at run time),
      --  and a fixed alternative accelerator.
      Primary            : Shortcut;
      Secondary          : Shortcut;
      --  May run while the root selector / the settings pane is open.
      With_Root_Selector : Boolean := False;
      With_Settings_Pane : Boolean := False;
      --  Its shortcut may run while a text field owns the keyboard.
      With_Text_Focus    : Boolean := False;
      --  Changes view, sort or info-pane state that is mirrored into settings.
      Persists_UI_State  : Boolean := False;
   end record;

   Traits : constant array (Command_Id) of Command_Traits :=
     [No_Command =>
        (Identifier => +"", Placement => No_Placement, others => <>),
      Select_Small_Icons_Command =>
        (Identifier => +"view.small", Placement => Bottom_Bar, Primary => (True, GI.Key_1, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Select_Large_Icons_Command =>
        (Identifier => +"view.large", Placement => Bottom_Bar, Primary => (True, GI.Key_2, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Select_Details_Command =>
        (Identifier => +"view.details", Placement => Bottom_Bar, Primary => (True, GI.Key_3, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Toggle_Info_Pane_Command =>
        (Identifier => +"info.toggle", Placement => Bottom_Bar, Primary => (True, GI.Key_4, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Toggle_Hidden_Files_Command =>
        (Identifier => +"view.toggle_hidden", With_Settings_Pane | With_Text_Focus => True, others => <>),
      Toggle_Show_Extensions_Command =>
        (Identifier => +"view.toggle_extensions", With_Settings_Pane | With_Text_Focus => True, others => <>),
      Toggle_Free_Space_Display_Command =>
        (Identifier => +"status.free_space_toggle", With_Settings_Pane | With_Text_Focus => True, others => <>),
      Toggle_Settings_Pane_Command =>
        (Identifier => +"settings.toggle", Primary => (True, GI.Key_Comma, Ctrl),
         With_Settings_Pane | With_Text_Focus => True, others => <>),
      Toggle_Sort_Menu_Command =>
        (Identifier => +"sort.menu.toggle", Name_Key => +"command.sort.menu", Placement => Bottom_Bar, others => <>),
      Sort_By_Name_Command =>
        (Identifier => +"sort.name", Persists_UI_State => True, others => <>),
      Sort_By_Size_Command =>
        (Identifier => +"sort.size", Persists_UI_State => True, others => <>),
      Sort_By_Type_Command =>
        (Identifier => +"sort.type", Persists_UI_State => True, others => <>),
      Sort_By_Created_Command =>
        (Identifier => +"sort.created", Persists_UI_State => True, others => <>),
      Sort_By_Changed_Command =>
        (Identifier => +"sort.changed", Persists_UI_State => True, others => <>),
      Focus_Path_Input_Command =>
        (Identifier => +"path.focus", Placement => Toolbar_Middle, Primary => (True, GI.Key_L, Ctrl),
         With_Text_Focus => True, others => <>),
      Navigate_Home_Command =>
        (Identifier => +"navigate.home", Placement => Toolbar_Left, Primary => (True, GI.Key_Home, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Back_Command =>
        (Identifier => +"navigate.back", Placement => Toolbar_Left, Primary => (True, GI.Key_Left, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Forward_Command =>
        (Identifier => +"navigate.forward", Placement => Toolbar_Left, Primary => (True, GI.Key_Right, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Parent_Command =>
        (Identifier => +"navigate.parent", Placement => Toolbar_Left, Primary => (True, GI.Key_Up, Alt),
         With_Text_Focus => True, others => <>),
      Create_File_Command =>
        (Identifier => +"file.create", Placement => Toolbar_Left, Primary => (True, GI.Key_N, Ctrl), others => <>),
      New_Folder_Command =>
        (Identifier => +"file.new_folder", Placement => Toolbar_Left, Primary => (True, GI.Key_N, Ctrl_Shift),
         others => <>),
      Delete_Selected_Items_Command =>
        (Identifier => +"file.delete_selected", Name_Key => +"command.file.delete", Placement => Toolbar_Left,
         Primary => (True, GI.Key_Delete, None), Secondary => (True, GI.Key_Backspace, None), others => <>),
      Delete_Selected_Permanently_Command =>
        (Identifier => +"file.delete_permanently", Primary => (True, GI.Key_Delete, Shift), others => <>),
      Rename_Selected_Items_Command =>
        (Identifier => +"file.rename", Primary => (True, GI.Key_F2, None), others => <>),
      Copy_Selected_Items_Command =>
        (Identifier => +"file.copy", Primary => (True, GI.Key_C, Ctrl), others => <>),
      Cut_Selected_Items_Command =>
        (Identifier => +"file.cut", Primary => (True, GI.Key_X, Ctrl), others => <>),
      Duplicate_Selected_Command =>
        (Identifier => +"file.duplicate", others => <>),
      Paste_Items_Command =>
        (Identifier => +"file.paste", Primary => (True, GI.Key_V, Ctrl), others => <>),
      Open_Selected_Items_Command =>
        (Identifier => +"file.open_selected", Name_Key => +"command.file.open",
         Primary => (True, GI.Key_Return, None), others => <>),
      Open_With_Command =>
        (Identifier => +"file.open_with", others => <>),
      Compress_Zip_Command =>
        (Identifier => +"file.compress_zip", others => <>),
      Compress_7z_Command =>
        (Identifier => +"file.compress_7z", others => <>),
      Extract_Archive_Command =>
        (Identifier => +"file.extract", others => <>),
      Generate_Thumbnails_Command =>
        (Identifier => +"file.generate_thumbnails", others => <>),
      Focus_Filter_Input_Command =>
        (Identifier => +"filter.focus", Placement => Toolbar_Right, Primary => (True, GI.Key_F, Ctrl),
         With_Text_Focus => True, others => <>),
      Open_Command_Palette_Command =>
        (Identifier => +"palette.open", Primary => (True, GI.Key_P, Ctrl),
         With_Root_Selector | With_Settings_Pane | With_Text_Focus => True, others => <>),
      Close_Command_Palette_Command =>
        (Identifier => +"palette.close", Primary => (True, GI.Key_Escape, None),
         With_Root_Selector | With_Settings_Pane | With_Text_Focus => True, others => <>),
      Select_Drive_Command =>
        (Identifier => +"drive.select", Placement => Toolbar_Left, Primary => (True, GI.Key_D, Ctrl),
         With_Root_Selector => True, others => <>),
      Open_Selected_Root_Command =>
        (Identifier => +"drive.open_selected", With_Root_Selector => True, others => <>),
      Eject_Selected_Root_Command =>
        (Identifier => +"drive.eject_selected", With_Root_Selector => True, others => <>),
      Clear_Filter_Command =>
        (Identifier => +"filter.clear", Placement => Toolbar_Right, Primary => (True, GI.Key_F, Ctrl_Shift),
         With_Text_Focus => True, others => <>),
      Select_All_Command =>
        (Identifier => +"selection.select_all", Primary => (True, GI.Key_A, Ctrl), others => <>),
      Invert_Selection_Command =>
        (Identifier => +"selection.invert", Primary => (True, GI.Key_I, Ctrl), others => <>),
      Deselect_All_Command =>
        (Identifier => +"selection.deselect_all", Primary => (True, GI.Key_A, Ctrl_Shift), others => <>),
      Search_Recursive_Command =>
        (Identifier => +"directory.search_recursive", Primary => (True, GI.Key_S, Ctrl_Shift),
         With_Text_Focus => True, others => <>),
      Search_Contents_Command =>
        (Identifier => +"search.contents", With_Text_Focus => True, others => <>),
      Refresh_Directory_Command =>
        (Identifier => +"directory.refresh", Primary => (True, GI.Key_R, Ctrl),
         Secondary => (True, GI.Key_F5, None), With_Text_Focus => True, others => <>),
      Save_Settings_Command =>
        (Identifier => +"settings.save", Primary => (True, GI.Key_S, Ctrl),
         With_Settings_Pane | With_Text_Focus => True, others => <>),
      Reset_Settings_Command =>
        (Identifier => +"settings.reset", With_Settings_Pane => True, others => <>),
      Toggle_Favorite_Command =>
        (Identifier => +"favorite.toggle", Primary => (True, GI.Key_B, Ctrl), With_Settings_Pane => True,
         others => <>),
      Navigate_Trash_Command =>
        (Identifier => +"trash.open", others => <>),
      Restore_From_Trash_Command =>
        (Identifier => +"trash.restore", others => <>),
      Empty_Trash_Command =>
        (Identifier => +"trash.empty", others => <>),
      Open_Terminal_Command =>
        (Identifier => +"terminal.open", others => <>),
      Create_Symlink_Command =>
        (Identifier => +"link.symbolic", others => <>),
      Create_Hardlink_Command =>
        (Identifier => +"link.hard", others => <>),
      Undo_Command =>
        (Identifier => +"edit.undo", Primary => (True, GI.Key_Z, Ctrl), others => <>),
      Redo_Command =>
        (Identifier => +"edit.redo", Primary => (True, GI.Key_Z, Ctrl_Shift), Secondary => (True, GI.Key_Y, Ctrl),
         others => <>),
      Toggle_Column_Modified_Command =>
        (Identifier => +"columns.toggle_modified", With_Settings_Pane => True, others => <>),
      Toggle_Column_Size_Command =>
        (Identifier => +"columns.toggle_size", With_Settings_Pane => True, others => <>),
      Toggle_Column_Type_Command =>
        (Identifier => +"columns.toggle_type", With_Settings_Pane => True, others => <>),
      Toggle_Column_Created_Command =>
        (Identifier => +"columns.toggle_created", With_Settings_Pane => True, others => <>),
      Toggle_Column_Permissions_Command =>
        (Identifier => +"columns.toggle_permissions", With_Settings_Pane => True, others => <>),
      Cycle_Group_By_Command =>
        (Identifier => +"columns.cycle_group_by", With_Settings_Pane => True, others => <>),
      Toggle_Folder_Tree_Command =>
        (Identifier => +"tree.toggle", With_Text_Focus => True, others => <>),
      Copy_To_Command =>
        (Identifier => +"file.copy_to", Name_Key => +"command.copy_to", others => <>),
      Move_To_Command =>
        (Identifier => +"file.move_to", Name_Key => +"command.move_to", others => <>),
      Copy_Path_Command =>
        (Identifier => +"edit.copy_path", Primary => (True, GI.Key_C, Ctrl_Shift), others => <>),
      Open_Containing_Folder_Command =>
        (Identifier => +"navigate.containing", others => <>),
      Toggle_Quick_Look_Command =>
        (Identifier => +"view.quick_look", Primary => (True, GI.Key_Space, None), others => <>),
      Set_Color_Label_Command =>
        (Identifier => +"label.set", others => <>),
      Navigate_Recent_Command =>
        (Identifier => +"navigate.recent", others => <>),
      Clear_Recent_Command =>
        (Identifier => +"recent.clear", With_Settings_Pane => True, others => <>)];

   --  Name_Key's default prefix. Spelled in two parts because check_all reads
   --  every literal in this file that starts with the prefix as a catalog key.
   Name_Key_Prefix : constant String := "command" & '.';

   function Allowed_With_Root_Selector (Id : Command_Id) return Boolean is (Traits (Id).With_Root_Selector);

   function Allowed_With_Settings_Pane (Id : Command_Id) return Boolean is (Traits (Id).With_Settings_Pane);

   function Allowed_With_Text_Focus (Id : Command_Id) return Boolean is (Traits (Id).With_Text_Focus);

   function Identifier
     (Id : Command_Id)
      return String is (To_String (Traits (Id).Identifier));

   function Name_Key
     (Id : Command_Id)
      return String is
     (if Id = No_Command then ""
      elsif Length (Traits (Id).Name_Key) > 0 then To_String (Traits (Id).Name_Key)
      else Name_Key_Prefix & Identifier (Id));

   function Description_Key
     (Id : Command_Id)
      return String is
     (if Name_Key (Id) = "" then "" else Name_Key (Id) & ".description");

   function Default_Shortcut_For (Id : Command_Id) return Shortcut is (Traits (Id).Primary);

   --  ----- shortcut overrides (user-editable keymap) ---------------------------

   Overrides    : array (Command_Id) of Shortcut := [others => (others => <>)];
   Override_Set : array (Command_Id) of Boolean := [others => False];

   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut) is
   begin
      Overrides (Id)    := Value;
      Override_Set (Id) := True;
   end Set_Shortcut_Override;

   procedure Clear_Shortcut_Override (Id : Command_Id) is
      Secondary : constant Shortcut := Traits (Id).Secondary;
   begin
      Override_Set (Id) := False;
      if Secondary.Present then
         for Other in Registered_Command_Id loop
            if Other /= Id
              and then (Shortcut_For (Other) = Secondary or else Secondary_Shortcut_For (Other) = Secondary)
            then
               Set_Shortcut_Override (Id, Traits (Id).Primary);
               return;
            end if;
         end loop;
      end if;
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

   --  The built-in secondary is part of the default binding: overriding the
   --  command (rebinding or unbinding it) replaces it along with the primary.
   function Secondary_Shortcut_For
     (Id : Command_Id)
      return Shortcut is (if Override_Set (Id) then (others => <>) else Traits (Id).Secondary);

   function Key_Text
     (Key : Guikit.Input.Key_Code)
      return String is separate;

   function Shortcut_Text
     (Value : Shortcut)
      return String
 is separate;

   function Shortcut_Display_Text
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
      return Command_Placement is (Traits (Id).Placement);

   function Command_Palette_Visible
     (Id : Command_Id)
      return Boolean is
   begin
      return Id /= No_Command;
   end Command_Palette_Visible;

   function Requires_Settings_Path (Id : Command_Id) return Boolean is (Id in Settings_Command_Id);

   function Persists_Global_Ui_State (Id : Command_Id) return Boolean is (Traits (Id).Persists_UI_State);

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
   begin
      return Files.Model.Current_Is_Trash (Model);
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

   Reason_Keys : constant array (Disabled_Reason) of Unbounded_String :=
     [No_Reason                  => +"",
      Selection_Empty_Reason     => +"error.selection.empty",
      Create_Pending_Reason      => +"error.create.pending",
      Trash_View_Reason          => +"error.command.trash_view",
      Recent_View_Reason         => +"error.command.recent_view",
      Not_Archive_Reason         => +"error.extract.not_archive",
      Clipboard_Empty_Reason     => +"error.clipboard.empty",
      Settings_Closed_Reason     => +"error.settings.closed",
      Back_Unavailable_Reason    => +"error.history.back_unavailable",
      Forward_Unavailable_Reason => +"error.history.forward_unavailable",
      Rename_Unavailable_Reason  => +"error.rename.disabled",
      Filter_Empty_Reason        => +"error.filter.empty",
      Root_Unselected_Reason     => +"error.root.selection.empty",
      Eject_Unavailable_Reason   => +"error.root.eject_unavailable",
      Trash_Unavailable_Reason   => +"error.trash.unavailable"];

   function Reason_Key
     (Reason : Disabled_Reason)
      return String is (To_String (Reason_Keys (Reason)));

   function Status_Of
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Command_Status is separate;

   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean is (Status_Of (Id, Model).Enabled);

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

   --  The one table from a sort field to its command; Sort_Field_For, the
   --  label key and every caller that maps a field to a command read it.
   Sort_Commands : constant array (Files.Types.Sort_Field) of Sort_Command_Id :=
     [Files.Types.Sort_Name    => Sort_By_Name_Command,
      Files.Types.Sort_Size    => Sort_By_Size_Command,
      Files.Types.Sort_Type    => Sort_By_Type_Command,
      Files.Types.Sort_Created => Sort_By_Created_Command,
      Files.Types.Sort_Changed => Sort_By_Changed_Command];

   function Sort_Command
     (Field : Files.Types.Sort_Field)
      return Sort_Command_Id is (Sort_Commands (Field));

   function Sort_Field_For
     (Id : Sort_Command_Id)
      return Files.Types.Sort_Field is
   begin
      for Field in Sort_Commands'Range loop
         if Sort_Commands (Field) = Id then
            return Field;
         end if;
      end loop;
      --  Unreachable: Sort_Commands names every Sort_Command_Id.
      raise Program_Error;
   end Sort_Field_For;

   function Sort_Label_Key
     (Field : Files.Types.Sort_Field)
      return String is (Name_Key (Sort_Commands (Field)));

   procedure Execute
     (Id    : Pure_Command_Id;
      Model : in out Files.Model.Window_Model)
 is separate;

   function Context_Menu_Rows_For
     (Target : Files.Model.Context_Menu_Target)
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
         when Files.Model.Context_Menu_Item =>
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
         when Files.Model.Context_Menu_Empty =>
            Add (Create_File_Command);
            Add (New_Folder_Command);
            Add (Paste_Items_Command);
            Separator;
            Add (Open_Terminal_Command);
            Add (Refresh_Directory_Command);
            Separator;
            Add (Empty_Trash_Command);
            Add (Clear_Recent_Command);
         when Files.Model.Context_Menu_Header =>
            Add (Toggle_Column_Modified_Command);
            Add (Toggle_Column_Size_Command);
            Add (Toggle_Column_Type_Command);
            Add (Toggle_Column_Created_Command);
            Add (Toggle_Column_Permissions_Command);
            Separator;
            Add (Cycle_Group_By_Command);
         when Files.Model.Context_Menu_None =>
            null;
      end case;

      return Result;
   end Context_Menu_Rows_For;

end Files.Commands;

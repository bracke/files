with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Files.Commands is
   use Ada.Strings.Unbounded;
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
        (Identifier => +"", others => <>),
      Select_Small_Icons_Command =>
        (Identifier => +"view.small", Primary => (True, GI.Key_1, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Select_Large_Icons_Command =>
        (Identifier => +"view.large", Primary => (True, GI.Key_2, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Select_Details_Command =>
        (Identifier => +"view.details", Primary => (True, GI.Key_3, Ctrl),
         With_Text_Focus | Persists_UI_State => True, others => <>),
      Toggle_Info_Pane_Command =>
        (Identifier => +"info.toggle", Primary => (True, GI.Key_4, Ctrl),
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
        (Identifier => +"sort.menu.toggle", Name_Key => +"command.sort.menu", others => <>),
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
        (Identifier => +"path.focus", Primary => (True, GI.Key_L, Ctrl),
         With_Text_Focus => True, others => <>),
      Navigate_Home_Command =>
        (Identifier => +"navigate.home", Primary => (True, GI.Key_Home, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Back_Command =>
        (Identifier => +"navigate.back", Primary => (True, GI.Key_Left, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Forward_Command =>
        (Identifier => +"navigate.forward", Primary => (True, GI.Key_Right, Alt),
         With_Text_Focus => True, others => <>),
      Navigate_Parent_Command =>
        (Identifier => +"navigate.parent", Primary => (True, GI.Key_Up, Alt),
         With_Text_Focus => True, others => <>),
      Create_File_Command =>
        (Identifier => +"file.create", Primary => (True, GI.Key_N, Ctrl), others => <>),
      New_Folder_Command =>
        (Identifier => +"file.new_folder", Primary => (True, GI.Key_N, Ctrl_Shift),
         others => <>),
      Delete_Selected_Items_Command =>
        (Identifier => +"file.delete_selected", Name_Key => +"command.file.delete",
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
        (Identifier => +"filter.focus", Primary => (True, GI.Key_F, Ctrl),
         With_Text_Focus => True, others => <>),
      Open_Command_Palette_Command =>
        (Identifier => +"palette.open", Primary => (True, GI.Key_P, Ctrl),
         With_Root_Selector | With_Settings_Pane | With_Text_Focus => True, others => <>),
      --  Escape: closes the top overlay or cancels an edit. The identifier
      --  keeps its first name, so shortcuts saved under it still load.
      Close_Overlay_Command =>
        (Identifier => +"palette.close", Primary => (True, GI.Key_Escape, None),
         With_Root_Selector | With_Settings_Pane | With_Text_Focus => True, others => <>),
      Select_Drive_Command =>
        (Identifier => +"drive.select", Primary => (True, GI.Key_D, Ctrl),
         With_Root_Selector => True, others => <>),
      Open_Selected_Root_Command =>
        (Identifier => +"drive.open_selected", With_Root_Selector => True, others => <>),
      Eject_Selected_Root_Command =>
        (Identifier => +"drive.eject_selected", With_Root_Selector => True, others => <>),
      Clear_Filter_Command =>
        (Identifier => +"filter.clear", Primary => (True, GI.Key_F, Ctrl_Shift),
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

   Live : Keymap := Default_Keymap;

   function Live_Keymap return Keymap is (Live);

   procedure Set_Live_Keymap (Map : Keymap) is
   begin
      Live := Map;
   end Set_Live_Keymap;

   procedure Set_Shortcut_Override (Map : in out Keymap; Id : Command_Id; Value : Shortcut) is
   begin
      Map.Overrides (Id)    := Value;
      Map.Override_Set (Id) := True;
   end Set_Shortcut_Override;

   procedure Clear_Shortcut_Override (Map : in out Keymap; Id : Command_Id) is
      Secondary : constant Shortcut := Traits (Id).Secondary;
   begin
      Map.Override_Set (Id) := False;
      if Secondary.Present then
         for Other in Registered_Command_Id loop
            if Other /= Id
              and then (Shortcut_For (Map, Other) = Secondary or else Secondary_Shortcut_For (Map, Other) = Secondary)
            then
               Set_Shortcut_Override (Map, Id, Traits (Id).Primary);
               return;
            end if;
         end loop;
      end if;
   end Clear_Shortcut_Override;

   function Rebind (Map : in out Keymap; Id : Command_Id; Chord : Shortcut) return Rebind_Outcome is
   begin
      if Chord.Present then
         for Other in Registered_Command_Id loop
            if Other /= Id and then Shortcut_For (Map, Other) = Chord then
               return Conflict;
            end if;
         end loop;
         declare
            Owner : constant Command_Id := Find_By_Shortcut (Map, Chord.Key, Chord.Modifiers);
         begin
            --  Only a built-in secondary can hold it now: the owner keeps
            --  its primary alone (an override drops the secondary).
            if Owner /= No_Command and then Owner /= Id then
               Set_Shortcut_Override (Map, Owner, Shortcut_For (Map, Owner));
            end if;
         end;
      end if;
      if Chord = Default_Shortcut_For (Id) then
         Clear_Shortcut_Override (Map, Id);
      else
         Set_Shortcut_Override (Map, Id, Chord);
      end if;
      return Rebound;
   end Rebind;

   function Shortcut_Override (Map : Keymap; Id : Command_Id; Is_Set : out Boolean) return Shortcut is
   begin
      Is_Set := Map.Override_Set (Id);
      return Map.Overrides (Id);
   end Shortcut_Override;

   --  The effective primary shortcut: the override when set, else the default.
   function Shortcut_For (Map : Keymap; Id : Command_Id) return Shortcut is
     (if Map.Override_Set (Id) then Map.Overrides (Id) else Default_Shortcut_For (Id));

   --  The built-in secondary is part of the default binding: overriding the
   --  command (rebinding or unbinding it) replaces it along with the primary.
   function Secondary_Shortcut_For (Map : Keymap; Id : Command_Id) return Shortcut is
     (if Map.Override_Set (Id) then (others => <>) else Traits (Id).Secondary);

   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut) is
   begin
      Set_Shortcut_Override (Live, Id, Value);
   end Set_Shortcut_Override;

   procedure Clear_Shortcut_Override (Id : Command_Id) is
   begin
      Clear_Shortcut_Override (Live, Id);
   end Clear_Shortcut_Override;

   procedure Reset_Shortcut_Overrides is
   begin
      Live := Default_Keymap;
   end Reset_Shortcut_Overrides;

   function Shortcut_Override (Id : Command_Id; Is_Set : out Boolean) return Shortcut is
     (Shortcut_Override (Live, Id, Is_Set));

   function Shortcut_For
     (Id : Command_Id)
      return Shortcut is (Shortcut_For (Live, Id));

   function Secondary_Shortcut_For
     (Id : Command_Id)
      return Shortcut is (Secondary_Shortcut_For (Live, Id));

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

   --  Read Text as Parse_Shortcut does, also saying whether every token was
   --  understood: an unknown or empty token, or more or fewer than one key,
   --  makes it invalid.
   procedure Read_Shortcut
     (Text   : String;
      Result : out Shortcut;
      Valid  : out Boolean)
   is separate;

   function Parse_Shortcut (Text : String) return Shortcut is
      Result : Shortcut;
      Valid  : Boolean;
   begin
      Read_Shortcut (Text, Result, Valid);
      return Result;
   end Parse_Shortcut;

   function Is_Valid_Shortcut_Text (Text : String) return Boolean is
      Result : Shortcut;
      Valid  : Boolean;
   begin
      Read_Shortcut (Text, Result, Valid);
      return Valid;
   end Is_Valid_Shortcut_Text;

   function Shortcut_Search_Text
     (Id : Command_Id)
      return String
 is separate;

   function Command_Palette_Visible
     (Id : Command_Id)
      return Boolean is
   begin
      return Id /= No_Command;
   end Command_Palette_Visible;

   function Requires_Settings_Path (Id : Command_Id) return Boolean is (Id in Settings_Command_Id);

   function Persists_Global_Ui_State (Id : Command_Id) return Boolean is (Traits (Id).Persists_UI_State);

   function Contains
     (Identifier_Text : String)
      return Boolean is
     (Id_For_Identifier (Identifier_Text) /= No_Command);

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

   function Find_By_Shortcut
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id is (Find_By_Shortcut (Live, Key, Modifiers));

   function Find_By_Shortcut
     (Map       : Keymap;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id is
   begin
      for Id in Registered_Command_Id loop
         declare
            Candidate : constant Shortcut := Shortcut_For (Map, Id);
            Secondary : constant Shortcut := Secondary_Shortcut_For (Map, Id);
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

end Files.Commands;

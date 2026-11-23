with Files.Command_Reasons;
with Guikit.Input;
with Files.Types;

--  Central command registry, shortcuts, enablement, and execution routing.
package Files.Commands is

   type Command_Id is
     (No_Command,
      Select_Small_Icons_Command,
      Select_Large_Icons_Command,
      Select_Details_Command,
      Toggle_Info_Pane_Command,
      Toggle_Hidden_Files_Command,
      Toggle_Show_Extensions_Command,
      Toggle_Free_Space_Display_Command,
      Toggle_Settings_Pane_Command,
      Toggle_Sort_Menu_Command,
      Sort_By_Name_Command,
      Sort_By_Size_Command,
      Sort_By_Type_Command,
      Sort_By_Created_Command,
      Sort_By_Changed_Command,
      Focus_Path_Input_Command,
      Navigate_Home_Command,
      Navigate_Back_Command,
      Navigate_Forward_Command,
      Navigate_Parent_Command,
      Create_File_Command,
      New_Folder_Command,
      Delete_Selected_Items_Command,
      Delete_Selected_Permanently_Command,
      Rename_Selected_Items_Command,
      Copy_Selected_Items_Command,
      Cut_Selected_Items_Command,
      Duplicate_Selected_Command,
      Paste_Items_Command,
      Open_Selected_Items_Command,
      Open_With_Command,
      Compress_Zip_Command,
      Compress_7z_Command,
      Extract_Archive_Command,
      Generate_Thumbnails_Command,
      Focus_Filter_Input_Command,
      Open_Command_Palette_Command,
      Close_Overlay_Command,
      Select_Drive_Command,
      Open_Selected_Root_Command,
      Eject_Selected_Root_Command,
      Clear_Filter_Command,
      Select_All_Command,
      Invert_Selection_Command,
      Deselect_All_Command,
      Search_Recursive_Command,
      Search_Contents_Command,
      Refresh_Directory_Command,
      Save_Settings_Command,
      Reset_Settings_Command,
      Toggle_Favorite_Command,
      Navigate_Trash_Command,
      Restore_From_Trash_Command,
      Empty_Trash_Command,
      Open_Terminal_Command,
      Create_Symlink_Command,
      Create_Hardlink_Command,
      Undo_Command,
      Redo_Command,
      Toggle_Column_Modified_Command,
      Toggle_Column_Size_Command,
      Toggle_Column_Type_Command,
      Toggle_Column_Created_Command,
      Toggle_Column_Permissions_Command,
      Cycle_Group_By_Command,
      Toggle_Folder_Tree_Command,
      Copy_To_Command,
      Move_To_Command,
      Copy_Path_Command,
      Open_Containing_Folder_Command,
      Toggle_Quick_Look_Command,
      Set_Color_Label_Command,
      Navigate_Recent_Command,
      Clear_Recent_Command);

   subtype Registered_Command_Id is Command_Id range
     Select_Small_Icons_Command .. Clear_Recent_Command;

   --  The commands that sort the listing by one field, one per Sort_Field.
   subtype Sort_Command_Id is Command_Id range
     Sort_By_Name_Command .. Sort_By_Changed_Command;

   --  How each command is executed. The controller's private Run_Command owns
   --  the dispatch and switches over these two subtypes and the remaining ids with
   --  no others choice, so the compiler checks that every id is handled once.
   --
   --  Commands whose whole effect is window-model state, run by
   --  the controller's Execute_Pure_Command.
   subtype Pure_Command_Id is Command_Id
     with Static_Predicate =>
       Pure_Command_Id in No_Command
         | Select_Small_Icons_Command
         | Select_Large_Icons_Command
         | Select_Details_Command
         | Toggle_Info_Pane_Command
         | Toggle_Sort_Menu_Command
         | Sort_Command_Id
         | Focus_Path_Input_Command
         | Rename_Selected_Items_Command
         | Focus_Filter_Input_Command
         | Open_Command_Palette_Command
         | Clear_Filter_Command
         | Select_All_Command
         | Invert_Selection_Command
         | Deselect_All_Command
         | Copy_Path_Command
         | Set_Color_Label_Command;

   --  Commands that change the settings file: the controller applies them
   --  only when it is given the settings path (Requires_Settings_Path).
   subtype Settings_Command_Id is Command_Id
     with Static_Predicate =>
       Settings_Command_Id in Save_Settings_Command
         | Reset_Settings_Command
         | Toggle_Hidden_Files_Command
         | Toggle_Show_Extensions_Command
         | Toggle_Free_Space_Display_Command
         | Toggle_Column_Modified_Command
         | Toggle_Column_Size_Command
         | Toggle_Column_Type_Command
         | Toggle_Column_Created_Command
         | Toggle_Column_Permissions_Command
         | Cycle_Group_By_Command
         | Toggle_Favorite_Command
         | Clear_Recent_Command;

   --  Every other command: what the controller runs without the settings path.
   subtype Non_Settings_Command_Id is Command_Id
     with Static_Predicate => Non_Settings_Command_Id not in Settings_Command_Id;

   type Shortcut is record
      Present   : Boolean := False;
      Key       : Guikit.Input.Key_Code := Guikit.Input.Key_Unknown;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   end record;

   --  Return the stable string identifier for a command.
   --
   --  @param Id Command identifier.
   --  @return Stable command identifier string.
   function Identifier
     (Id : Command_Id)
      return String;

   --  Return the localization key for the command display name.
   --
   --  @param Id Command identifier.
   --  @return Localization key.
   function Name_Key
     (Id : Command_Id)
      return String;

   --  Return the localization key for the command description.
   --
   --  @param Id Command identifier.
   --  @return Localization key, or an empty string when no description exists.
   function Description_Key
     (Id : Command_Id)
      return String;

   --  Return the command keyboard shortcut.
   --
   --  @param Id Command identifier.
   --  @return Shortcut metadata.
   function Shortcut_For
     (Id : Command_Id)
      return Shortcut;

   --  Return a command's live secondary keyboard shortcut, when one exists. The
   --  built-in secondary belongs to the default binding: once the command has
   --  an override (a rebind or an unbind) it has no secondary.
   --
   --  @param Id Command identifier.
   --  @return Secondary shortcut metadata (absent while Id is overridden).
   function Secondary_Shortcut_For
     (Id : Command_Id)
      return Shortcut;

   --  Return stable searchable text for a shortcut.
   --
   --  @param Value Shortcut metadata to format.
   --  @return Lowercase shortcut text, or an empty string when absent.
   function Shortcut_Text
     (Value : Shortcut)
      return String;

   --  Return a shortcut as a person reads it: modifier and key names in the
   --  current language, in the usual Ctrl, Shift, Alt, Super order ("Strg+1").
   --  Shortcut_Text stays the stored, parseable form; this one is display only.
   --
   --  @param Value Shortcut metadata to format.
   --  @return Localized shortcut text, or an empty string when absent.
   function Shortcut_Display_Text
     (Value : Shortcut)
      return String;

   --  Parse the text produced by Shortcut_Text (e.g. "control+shift+k") back into
   --  a shortcut. Accepts common modifier aliases (ctrl, cmd, option). Present is
   --  False when no key was recognised.
   --
   --  @param Text A shortcut string, modifiers then key, joined by '+'.
   --  @return The parsed shortcut.
   function Parse_Shortcut (Text : String) return Shortcut;

   --  A keymap: which commands are rebound or unbound, and to what; every
   --  other command keeps its built-in binding. The process's live keymap
   --  is one -- Shortcut_For, Secondary_Shortcut_For and Find_By_Shortcut
   --  without a Map read it, and only the settings put in force change it
   --  (Keymap_Settings.Apply_Shortcut_Overrides) -- and the settings pane
   --  edits its own, held in its draft, until a save is accepted.
   type Keymap is private;

   --  No command rebound or unbound.
   Default_Keymap : constant Keymap;

   --  Map's primary shortcut for a command: its override when set, else its
   --  built-in default.
   --
   --  @param Map The keymap.
   --  @param Id Command identifier.
   --  @return Shortcut metadata.
   function Shortcut_For (Map : Keymap; Id : Command_Id) return Shortcut;

   --  Map's secondary shortcut for a command: the built-in secondary, which
   --  belongs to the default binding, so absent once Map overrides Id.
   --
   --  @param Map The keymap.
   --  @param Id Command identifier.
   --  @return Secondary shortcut metadata.
   function Secondary_Shortcut_For (Map : Keymap; Id : Command_Id) return Shortcut;

   --  The command a chord runs under Map: the first whose primary or
   --  secondary binding matches.
   --
   --  @param Map The keymap.
   --  @param Key Key code.
   --  @param Modifiers Active modifiers.
   --  @return Matching command or No_Command.
   function Find_By_Shortcut
     (Map       : Keymap;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id;

   --  Override a command's shortcut in Map (Value.Present False unbinds it).
   --  The override replaces the whole default binding, built-in secondary
   --  included.
   --
   --  @param Map The keymap to change.
   --  @param Id Command identifier.
   --  @param Value Shortcut to bind (Present False records an explicit unbind).
   procedure Set_Shortcut_Override (Map : in out Keymap; Id : Command_Id; Value : Shortcut);

   --  Clear a command's override in Map so it reverts to its built-in
   --  default. Its built-in secondary comes back too -- unless another
   --  command now holds that chord, which then stays the other's: Id keeps
   --  its default primary alone (as an override equal to it).
   --
   --  @param Map The keymap to change.
   --  @param Id Command identifier.
   procedure Clear_Shortcut_Override (Map : in out Keymap; Id : Command_Id);

   --  The built-in default primary shortcut for a command, ignoring any override.
   --
   --  @param Id Command identifier.
   --  @return The default shortcut.
   function Default_Shortcut_For (Id : Command_Id) return Shortcut;

   --  Return stable searchable text for all command shortcuts.
   --
   --  @param Id Command identifier.
   --  @return Space-separated lowercase shortcut texts.
   function Shortcut_Search_Text
     (Id : Command_Id)
      return String;

   --  Return whether a command should appear in the command palette.
   --
   --  @param Id Command identifier.
   --  @return True when palette-visible.
   function Command_Palette_Visible
     (Id : Command_Id)
      return Boolean;

   --  Return whether a command requires the configured central settings path.
   --
   --  @param Id Command identifier.
   --  @return True when execution requires the application settings path.
   function Requires_Settings_Path
     (Id : Command_Id)
      return Boolean;

   --  Return whether a command changes global UI state (view mode, sort field or
   --  direction, or the info pane) that is mirrored into the settings and
   --  persisted. The interaction layer routes such commands so a runtime change --
   --  e.g. from the bottom bar -- is written back to the settings file, not lost
   --  until the next launch.
   --
   --  @param Id Command identifier.
   --  @return True when the command's effect is persisted as global UI state.
   function Persists_Global_Ui_State
     (Id : Command_Id)
      return Boolean;

   --  Return the command whose stable identifier is Identifier_Text.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return The matching command, or No_Command when none matches.
   function Id_For_Identifier
     (Identifier_Text : String)
      return Command_Id;

   --  Why a command cannot run now (Files.Command_Reasons, a leaf that
   --  Files.Operations reports the same keys from).
   subtype Disabled_Reason is Files.Command_Reasons.Disabled_Reason;

   --  Whether a command can run, and if not, why.
   type Command_Status is record
      Enabled : Boolean := True;
      --  Meaningful only when Enabled is False.
      Reason  : Disabled_Reason := Files.Command_Reasons.No_Reason;
   end record;

   --  Return whether a keyboard shortcut may run its command while a text
   --  field (path, filter, rename, palette, settings) owns the keyboard. Only
   --  commands that act on the window or move focus qualify; anything acting
   --  on the selection, the clipboard or the files themselves would otherwise
   --  fire behind the field (Shift+Delete while renaming deleted the selection).
   --
   --  @param Id Command identifier.
   --  @return True when the shortcut may run with a focused text field.
   function Allowed_With_Text_Focus
     (Id : Command_Id)
      return Boolean;

   --  Find the command a shortcut runs: the first whose live primary or
   --  secondary binding (see Shortcut_For / Secondary_Shortcut_For) matches.
   --
   --  @param Key Key code.
   --  @param Modifiers Active modifiers.
   --  @return Matching command or No_Command.
   function Find_By_Shortcut
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id;

   --  The command that sorts by a field. Its Name_Key is also the field's
   --  label (the sort button, the sort menu rows).
   --
   --  @param Field Sort field.
   --  @return The Sort_By_* command for Field.
   function Sort_Command
     (Field : Files.Types.Sort_Field)
      return Sort_Command_Id;

   --  The field a sort command sorts by: the inverse of Sort_Command.
   --
   --  @param Id Sort command.
   --  @return The field Id sorts by.
   function Sort_Field_For
     (Id : Sort_Command_Id)
      return Files.Types.Sort_Field;

   --  The localization key of a sort field's label.
   --
   --  @param Field Sort field.
   --  @return Name_Key of the field's sort command.
   function Sort_Label_Key
     (Field : Files.Types.Sort_Field)
      return String;

private

   type Override_Table is array (Command_Id) of Shortcut;
   type Override_Flags is array (Command_Id) of Boolean;

   type Keymap is record
      Overrides    : Override_Table := [others => (others => <>)];
      Override_Set : Override_Flags := [others => False];
   end record;

   Default_Keymap : constant Keymap := (others => <>);

   --  The live keymap, which Shortcut_For, Secondary_Shortcut_For and
   --  Find_By_Shortcut without a Map read.
   --
   --  @return The keymap in force.
   function Live_Keymap return Keymap;

   --  Make Map the live keymap (Keymap_Settings puts the settings' in force).
   --
   --  @param Map The keymap to put in force.
   procedure Set_Live_Keymap (Map : Keymap);

   --  The override Map holds for a command, if any.
   --
   --  @param Map The keymap.
   --  @param Id Command identifier.
   --  @param Is_Set Out: whether Map overrides Id at all.
   --  @return The override shortcut (meaningful only when Is_Set).
   function Shortcut_Override (Map : Keymap; Id : Command_Id; Is_Set : out Boolean) return Shortcut;

   --  Override a command's shortcut in the live keymap.
   --
   --  @param Id Command identifier.
   --  @param Value Shortcut to bind (Present False records an explicit unbind).
   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut);

   --  Clear a command's override in the live keymap (Clear_Shortcut_Override
   --  with a Map says what that brings back).
   --
   --  @param Id Command identifier.
   procedure Clear_Shortcut_Override (Id : Command_Id);

   --  Clear every override of the live keymap.
   procedure Reset_Shortcut_Overrides;

   --  Return whether Identifier names a registered command.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return True when a registered command exists.
   function Contains
     (Identifier_Text : String)
      return Boolean;

   --  Whether Parse_Shortcut reads Text in full: empty or blank (an explicit
   --  unbind), or modifiers and exactly one key, every token known. A
   --  misspelt token ("ctrl+bogus", "ctrl+shfit+1") makes it invalid, so a
   --  settings file's typo can be refused instead of unbinding the command
   --  or binding another key.
   --
   --  @param Text A shortcut string, modifiers then key, joined by '+'.
   --  @return True when every token is a modifier or the one known key.
   function Is_Valid_Shortcut_Text (Text : String) return Boolean;

   --  The override in effect for a command, if any.
   --
   --  @param Id Command identifier.
   --  @param Is_Set Out: whether Id has an override at all.
   --  @return The override shortcut (meaningful only when Is_Set).
   function Shortcut_Override (Id : Command_Id; Is_Set : out Boolean) return Shortcut;

   --  Parse the key name produced by Key_Text back into a key code, or
   --  Key_Unknown when the text names no key.
   --
   --  @param Text A lowercase key name (e.g. "a", "f5", "backspace").
   --  @return The matching key code, or Key_Unknown.
   function Text_To_Key (Text : String) return Guikit.Input.Key_Code;

   --  Return whether a command may execute while the root selector is open.
   --
   --  @param Id Command identifier.
   --  @return True when the root-selector modal state allows the command.
   function Allowed_With_Root_Selector
     (Id : Command_Id)
      return Boolean;

   --  Return whether a command may execute while the settings pane is open.
   --
   --  @param Id Command identifier.
   --  @return True when the settings-pane modal state allows the command.
   function Allowed_With_Settings_Pane
     (Id : Command_Id)
      return Boolean;

end Files.Commands;

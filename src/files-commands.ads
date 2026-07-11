with Files.File_System;
with Files.Model;
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
      Close_Command_Palette_Command,
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

   type Command_Placement is
     (No_Placement,
      Toolbar_Left,
      Toolbar_Middle,
      Toolbar_Right,
      Bottom_Bar,
      Command_Palette_Only);

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

   --  Return a secondary command keyboard shortcut, when one exists.
   --
   --  @param Id Command identifier.
   --  @return Secondary shortcut metadata.
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

   --  Parse the key name produced by Key_Text back into a key code, or
   --  Key_Unknown when the text names no key.
   --
   --  @param Text A lowercase key name (e.g. "a", "f5", "backspace").
   --  @return The matching key code, or Key_Unknown.
   function Text_To_Key (Text : String) return Guikit.Input.Key_Code;

   --  Parse the text produced by Shortcut_Text (e.g. "control+shift+k") back into
   --  a shortcut. Accepts common modifier aliases (ctrl, cmd, option). Present is
   --  False when no key was recognised.
   --
   --  @param Text A shortcut string, modifiers then key, joined by '+'.
   --  @return The parsed shortcut.
   function Parse_Shortcut (Text : String) return Shortcut;

   --  Override a command's primary shortcut (Value.Present False unbinds it).
   --  Shortcut_For / Find_By_Shortcut then resolve to the effective
   --  (override-or-default) shortcut. Overrides are process-global.
   --
   --  @param Id Command identifier.
   --  @param Value Shortcut to bind (Present False records an explicit unbind).
   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut);

   --  Clear a command's override so it reverts to its built-in default shortcut.
   --
   --  @param Id Command identifier.
   procedure Clear_Shortcut_Override (Id : Command_Id);

   --  Clear every shortcut override, reverting all commands to their defaults.
   procedure Reset_Shortcut_Overrides;

   --  The override in effect for a command, if any.
   --
   --  @param Id Command identifier.
   --  @param Is_Set Out: whether Id has an override at all.
   --  @return The override shortcut (meaningful only when Is_Set).
   function Shortcut_Override (Id : Command_Id; Is_Set : out Boolean) return Shortcut;

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

   --  Return placement metadata for toolbar or bottom-bar commands.
   --
   --  @param Id Command identifier.
   --  @return Placement metadata.
   function Placement_For
     (Id : Command_Id)
      return Command_Placement;

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

   --  Return number of registered commands.
   --
   --  @return Registered command count.
   function Command_Count return Natural;

   --  Join the full paths of the given items into a single newline-separated
   --  string, one path per line, in item order. Returns an empty string when no
   --  items are supplied. This is the pure, filesystem-free text seam the
   --  Copy_Path_Command uses before the platform layer writes the system
   --  clipboard.
   --
   --  @param Items Items whose full paths are joined.
   --  @return Newline-joined full paths, or an empty string when Items is empty.
   function Joined_Full_Paths
     (Items : Files.File_System.Item_Vectors.Vector)
      return String;

   --  Return whether Identifier names a registered command.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return True when a registered command exists.
   function Contains
     (Identifier_Text : String)
      return Boolean;

   --  Return the command whose stable identifier is Identifier_Text.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return The matching command, or No_Command when none matches.
   function Id_For_Identifier
     (Identifier_Text : String)
      return Command_Id;

   --  Return whether a command is executable in the current model state.
   --
   --  @param Id Command identifier.
   --  @param Model Current window model.
   --  @return True when command can execute.
   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean;

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

   --  Find a command registered for the given shortcut.
   --
   --  @param Key Key code.
   --  @param Modifiers Active modifiers.
   --  @return Matching command or No_Command.
   function Find_By_Shortcut
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Command_Id;

   --  Execute a pure model command without filesystem access.
   --
   --  Commands that require loading directories, opening files, discovering
   --  roots, or creating deterministic filesystem names are routed by
   --  Files.Controller.Execute_Command instead.
   --
   --  @param Id Command identifier.
   --  @param Model Window model to mutate.
   procedure Execute
     (Id    : Command_Id;
      Model : in out Files.Model.Window_Model);

end Files.Commands;

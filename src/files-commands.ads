with Files.Model;
with Files.Types;

--  Central command registry, shortcuts, enablement, and execution routing.
package Files.Commands is

   type Command_Id is
     (No_Command,
      Select_Small_Icons_Command,
      Select_Large_Icons_Command,
      Select_Details_Command,
      Toggle_Info_Pane_Command,
      Toggle_Settings_Pane_Command,
      Focus_Path_Input_Command,
      Navigate_Home_Command,
      Navigate_Back_Command,
      Navigate_Forward_Command,
      Create_File_Command,
      Delete_Selected_Items_Command,
      Rename_Selected_Items_Command,
      Open_Selected_Items_Command,
      Focus_Filter_Input_Command,
      Open_Command_Palette_Command,
      Close_Command_Palette_Command,
      Select_Drive_Command,
      Open_Selected_Root_Command,
      Eject_Selected_Root_Command,
      Clear_Filter_Command,
      Refresh_Directory_Command,
      Import_Settings_Command,
      Export_Settings_Command,
      Save_Settings_Command,
      Reset_Settings_Command);

   subtype Registered_Command_Id is Command_Id range
     Select_Small_Icons_Command .. Reset_Settings_Command;

   type Command_Placement is
     (No_Placement,
      Toolbar_Left,
      Toolbar_Middle,
      Toolbar_Right,
      Bottom_Bar,
      Command_Palette_Only);

   type Shortcut is record
      Present   : Boolean := False;
      Key       : Files.Types.Key_Code := Files.Types.Key_Unknown;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
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

   --  Return number of registered commands.
   --
   --  @return Registered command count.
   function Command_Count return Natural;

   --  Return whether Identifier names a registered command.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return True when a registered command exists.
   function Contains
     (Identifier_Text : String)
      return Boolean;

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
     (Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set)
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

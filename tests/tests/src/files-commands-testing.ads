--  What the suite reaches of Files.Commands that is not part of its interface.
package Files.Commands.Testing is

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

   --  Return whether Identifier names a registered command.
   --
   --  @param Identifier_Text Stable identifier string to find.
   --  @return True when a registered command exists.
   function Contains (Identifier_Text : String) return Boolean;

   --  The live keymap, which the window's keys resolve against.
   --
   --  @return The keymap in force.
   function Live_Keymap return Keymap;

   --  Override a command's shortcut in the live keymap, as settings put in
   --  force would.
   --
   --  @param Id Command identifier.
   --  @param Value Shortcut to bind (Present False records an explicit unbind).
   procedure Set_Shortcut_Override (Id : Command_Id; Value : Shortcut);

   --  Clear a command's override in the live keymap.
   --
   --  @param Id Command identifier.
   procedure Clear_Shortcut_Override (Id : Command_Id);

   --  Clear every override of the live keymap.
   procedure Reset_Shortcut_Overrides;

   --  Override a command's shortcut in Map (Value.Present False unbinds it).
   --
   --  @param Map The keymap to change.
   --  @param Id Command identifier.
   --  @param Value Shortcut to bind.
   procedure Set_Shortcut_Override (Map : in out Keymap; Id : Command_Id; Value : Shortcut);

   --  Clear a command's override in Map, its secondary back unless taken.
   --
   --  @param Map The keymap to change.
   --  @param Id Command identifier.
   procedure Clear_Shortcut_Override (Map : in out Keymap; Id : Command_Id);

end Files.Commands.Testing;

with Files.Settings;

--  The live keymap (Files.Commands) and the settings' [shortcuts] section
--  kept in step, and a keymap read from or written to those overrides: the
--  settings pane edits a draft's overrides through a Keymap of its own, and
--  only settings put in force change the live one.
package Files.Commands.Keymap_Settings is

   --  The keymap Overrides describe. An override for a command this build
   --  does not know, or with a combo it cannot read (a typo), is dropped:
   --  the command keeps its default binding rather than losing it or taking
   --  whatever the rest names. An empty combo is an explicit unbind.
   --
   --  @param Overrides A settings [shortcuts] section.
   --  @return The keymap they describe.
   function Keymap_Of (Overrides : Files.Settings.Shortcut_Override_Vectors.Vector) return Keymap;

   --  The [shortcuts] section that describes Map: one entry per command Map
   --  overrides, in command order; an explicit unbind is an empty combo.
   --
   --  @param Map The keymap.
   --  @return Its overrides as the settings hold them.
   function Overrides_Of (Map : Keymap) return Files.Settings.Shortcut_Override_Vectors.Vector;

   --  Put Settings' shortcut overrides in force as the live keymap, then
   --  hold them as the live keymap reads (Overrides_Of): an entry Keymap_Of
   --  drops is dropped from Settings too.
   --
   --  @param Settings Settings whose overrides take effect, updated in place.
   procedure Apply_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model);

end Files.Commands.Keymap_Settings;

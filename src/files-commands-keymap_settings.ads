with Files.Settings;

--  The live keymap (Files.Commands' shortcut overrides) and the settings'
--  [shortcuts] section kept in step: what a save writes, and what loading or
--  taking in settings makes the keymap. Neither the settings pane nor the
--  window owns this; both, and the settings store, call it.
package Files.Commands.Keymap_Settings is

   --  Settings with their shortcut overrides taken from the live keymap
   --  (Files.Commands), which the pane's shortcut rows change before any
   --  save: what a save writes. The [shortcuts] section is thus always a
   --  mirror of the effective overrides; an explicit unbind persists as an
   --  empty combo (Shortcut_Text of an absent shortcut is "").
   --
   --  @param Settings Settings to update in place.
   procedure Store_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model);

   --  Make Settings' shortcut overrides the live keymap's (Files.Commands),
   --  then hold them as a save writes them (Store_Shortcut_Overrides). An
   --  override for a command this build does not know, or with a combo it
   --  cannot read (a typo), is dropped: the command keeps its default
   --  binding rather than losing it or taking whatever the rest names. An
   --  empty combo is an explicit unbind.
   --
   --  @param Settings Settings whose overrides take effect, updated in place.
   procedure Apply_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model);

end Files.Commands.Keymap_Settings;

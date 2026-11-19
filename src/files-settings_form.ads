with Guikit.Settings_Panel;

with Files.Settings;

--  The bridge between the domain settings draft and the reusable
--  Guikit.Settings_Panel component: it builds the typed field descriptors from
--  a draft (labels, choice options, mapping-editor entries) and applies a
--  change the panel emits back onto a draft. The component owns the focus,
--  scroll, rendering and hit-testing; this package owns the draft <->
--  descriptor mapping only. It knows no model: Files.Model.Settings_Pane
--  hands it the pane's draft and keeps what it gives back.
package Files.Settings_Form is

   --  The field descriptors for the settings panel, built from a draft.
   --
   --  @param Draft The settings draft that supplies the values.
   --  @return The fields to hand to Guikit.Settings_Panel.
   function Fields
     (Draft : Files.Settings.Settings_Draft)
      return Guikit.Settings_Panel.Field_Vectors.Vector;

   --  The defaults, with every shortcut override dropped: what the pane's
   --  Reset button and the reset command both do before saving.
   --
   --  @return The draft of the default settings.
   function Reset_To_Defaults return Files.Settings.Settings_Draft;

   --  Apply a change emitted by the panel to a draft.
   --
   --  @param Draft The draft to update.
   --  @param Change The change the panel produced.
   --  @return True when a persisted setting changed and the caller should save.
   function Apply
     (Draft  : in out Files.Settings.Settings_Draft;
      Change : Guikit.Settings_Panel.Change)
      return Boolean;

end Files.Settings_Form;

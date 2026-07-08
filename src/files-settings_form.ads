with Guikit.Settings_Panel;

with Files.Model;

--  The bridge between the domain settings draft and the reusable
--  Guikit.Settings_Panel component: it builds the typed field descriptors from
--  the model's current draft (labels, choice options, mapping-editor entries)
--  and applies a change the panel emits back onto the draft. The component owns
--  the focus, scroll, rendering and hit-testing; this package owns the
--  draft <-> descriptor mapping only.
package Files.Settings_Form is

   --  The field descriptors for the settings panel, built from the model draft.
   --
   --  @param Model Current model (its settings draft supplies the values).
   --  @return The fields to hand to Guikit.Settings_Panel.
   function Fields
     (Model : Files.Model.Window_Model)
      return Guikit.Settings_Panel.Field_Vectors.Vector;

   --  Apply a change emitted by the panel to the model's draft.
   --
   --  @param Model Model whose draft is updated.
   --  @param Change The change the panel produced.
   --  @return True when a persisted setting changed and the caller should save.
   function Apply
     (Model  : in out Files.Model.Window_Model;
      Change : Guikit.Settings_Panel.Change)
      return Boolean;

end Files.Settings_Form;

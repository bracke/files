with Guikit.Settings_Panel;

with Files.Model;
with Files.Settings;

--  The bridge between the domain settings draft and the reusable
--  Guikit.Settings_Panel component: it builds the typed field descriptors from
--  a draft (labels, choice options, mapping-editor entries) and applies a
--  change the panel emits back onto a draft. The component owns the focus,
--  scroll, rendering and hit-testing; this package owns the draft <->
--  descriptor mapping only. Files.Model.Settings_Pane holds the draft and
--  the panel and never calls back here: Begin_Edit and Apply_Change, used by
--  the controller, build the (localized) fields and the mapped draft and hand
--  them to the model, as Files.Overlays.Command_Palette lists the palette's rows.
package Files.Overlays.Settings_Form is

   --  The field descriptors for the settings panel, built from a draft.
   --
   --  @param Draft The settings draft that supplies the values.
   --  @return The fields to hand to Guikit.Settings_Panel.
   function Fields
     (Draft : Files.Settings.Settings_Draft)
      return Guikit.Settings_Panel.Field_Vectors.Vector;

   --  Whether saving Draft would change the settings as saved (Saved):
   --  Draft applied over Saved, with the live shortcut overrides, says
   --  something else (Files.Settings.Same_Content). False for a draft that
   --  cannot be applied, which cannot be saved.
   --
   --  @param Saved The settings as saved.
   --  @param Draft The draft the pane would save.
   --  @return True when a save would write something new.
   function Needs_Save
     (Saved : Files.Settings.Settings_Model;
      Draft : Files.Settings.Settings_Draft)
      return Boolean;

   --  Needs_Save for a draft already applied over Saved
   --  (Files.Settings.Apply_Draft, which also checks it): for a caller that
   --  needs the check's verdict too, so the draft is parsed once.
   --
   --  @param Saved The settings as saved.
   --  @param Applied The draft applied over Saved.
   --  @return True when a save would write something new.
   function Needs_Save
     (Saved   : Files.Settings.Settings_Model;
      Applied : Files.Settings.Settings_Model)
      return Boolean;

   --  Apply a change emitted by the panel to a draft. Reset (to the
   --  defaults, dropping every shortcut override), add and remove re-check
   --  the draft (its Valid and Error_Key say what holds now) and ask for a
   --  save when it is valid and Needs_Save against Saved; Prev/Next only
   --  page. A toggle, choice, number or captured shortcut asks for a save,
   --  which re-checks the draft; a text edit does not (the controller saves
   --  it on commit). Only a re-check or a save changes the draft's error.
   --
   --  @param Draft The draft to update.
   --  @param Change The change the panel produced.
   --  @param Saved The settings as saved.
   --  @param Rechecked Set when the draft was re-checked (reset, add, remove).
   --  @return True when the caller should save.
   function Apply
     (Draft     : in out Files.Settings.Settings_Draft;
      Change    : Guikit.Settings_Panel.Change;
      Saved     : Files.Settings.Settings_Model;
      Rechecked : out Boolean)
      return Boolean;

   --  Open the settings pane on Settings: the draft of them to edit, and
   --  them as what is saved (Needs_Save weighs a change against them).
   --
   --  @param Model Model whose settings pane opens.
   --  @param Settings The settings to edit, as saved.
   procedure Begin_Edit
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Replace the open pane's draft: normalized here, the one place a draft
   --  is, and handed to the model with the panel's fields for it.
   --
   --  @param Model Model whose draft is replaced.
   --  @param Draft The new draft.
   procedure Set_Draft
     (Model : in out Files.Model.Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Apply a change the panel emitted to the pane's draft (Apply, against
   --  the saved settings). A No_Change leaves the model as it is. After a
   --  re-check that asks for no save, the error line follows the draft:
   --  cleared when it is valid, its error when not; a save reports itself.
   --
   --  @param Model Model whose draft is updated.
   --  @param Change The change the panel produced.
   --  @return True when a persisted setting changed and the caller should save.
   function Apply_Change
     (Model  : in out Files.Model.Window_Model;
      Change : Guikit.Settings_Panel.Change)
      return Boolean;

   --  Press the pane's Reset button (Apply_Change): the draft goes back to
   --  the defaults and every shortcut override is dropped. The reset
   --  command runs through here, so the two cannot differ.
   --
   --  @param Model Model whose draft is reset.
   --  @return Whether that needs a save (Needs_Save): False when everything
   --    already was the default.
   function Reset_Draft
     (Model : in out Files.Model.Window_Model)
      return Boolean;

   --  Record Settings as what is saved, for the pane's next Needs_Save:
   --  after the pane's save, and after a command or another window changed
   --  the settings while the pane is open -- applied, even when their write
   --  failed and was reported (Save, which always writes, tries again).
   --
   --  @param Model Model whose settings pane is updated.
   --  @param Settings The settings now in force.
   procedure Mark_Saved
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

end Files.Overlays.Settings_Form;

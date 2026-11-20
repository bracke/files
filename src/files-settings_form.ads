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
--  them to the model, as Files.Command_Palette lists the palette's rows.
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

   --  Whether saving Draft would change what the file holds (Saved, the
   --  draft of the saved settings), or the shortcut overrides are dropped
   --  (which the draft does not hold).
   --
   --  @param Saved The draft of the settings as saved.
   --  @param Draft The draft the pane would save.
   --  @param Overrides_Dropped Whether shortcut overrides were just dropped.
   --  @return True when a save would write something new.
   function Needs_Save
     (Saved, Draft      : Files.Settings.Settings_Draft;
      Overrides_Dropped : Boolean)
      return Boolean;

   --  Apply a change emitted by the panel to a draft. Reset, add and
   --  remove re-check the draft (its Valid and Error_Key say what holds
   --  now) and ask for a save when it is valid and saving it would change
   --  the file (Needs_Save against Saved); Prev/Next only page and keep the
   --  draft's error. A toggle, choice, number or captured shortcut asks for
   --  a save; a text edit does not (the controller saves it on commit).
   --
   --  @param Draft The draft to update.
   --  @param Change The change the panel produced.
   --  @param Saved The draft of the settings as saved.
   --  @return True when the caller should save.
   function Apply
     (Draft  : in out Files.Settings.Settings_Draft;
      Change : Guikit.Settings_Panel.Change;
      Saved  : Files.Settings.Settings_Draft)
      return Boolean;

   --  Open the settings pane on Draft, handing the model the panel's fields
   --  for the normalized draft.
   --
   --  @param Model Model whose settings pane opens.
   --  @param Draft The draft to edit.
   procedure Begin_Edit
     (Model : in out Files.Model.Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Replace the open pane's draft: normalized here, the one place a draft
   --  is, and handed to the model with the panel's fields for it.
   --
   --  @param Model Model whose draft is replaced.
   --  @param Draft The new draft.
   procedure Set_Draft
     (Model : in out Files.Model.Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Apply a change the panel emitted to the pane's draft (Apply). A
   --  No_Change leaves the model as it is.
   --
   --  @param Model Model whose draft is updated.
   --  @param Change The change the panel produced.
   --  @return True when a persisted setting changed and the caller should save.
   function Apply_Change
     (Model  : in out Files.Model.Window_Model;
      Change : Guikit.Settings_Panel.Change)
      return Boolean;

   --  Return the pane's draft to the defaults and drop every shortcut
   --  override (Reset_To_Defaults): the pane's Reset button and the reset
   --  command alike.
   --
   --  @param Model Model whose draft is reset.
   --  @return Whether that needs a save (Needs_Save against the saved
   --    settings): False when everything already was the default.
   function Reset_Draft
     (Model : in out Files.Model.Window_Model)
      return Boolean;

   --  Record Settings as what the file holds, after a save, for the pane's
   --  next Needs_Save.
   --
   --  @param Model Model whose settings pane is updated.
   --  @param Settings The settings now saved.
   procedure Mark_Saved
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

end Files.Settings_Form;

--  The settings pane's draft: a Settings_Model as editable text rows
--  (Make_Draft), checked (Validate_Draft) and applied (Apply_Draft) the way
--  Parse would read it, and kept in step with saves and outside changes
--  (Draft_After_Save, Refresh_Draft).
package Files.Settings.Drafts is

   --  Build an editable settings draft from a settings model.
   --
   --  @param Settings Settings model to edit.
   --  @return Text draft suitable for UI editing.
   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft;

   --  Bring a draft into a consistent state: pair up its parallel key/value
   --  mapping lists to equal length (dropping orphan rows) and clamp each
   --  mapping's selection index, refreshing the selected key and value.
   --
   --  @param Draft Settings draft to normalize in place.
   procedure Normalize_Draft
     (Draft : in out Settings_Draft);

   --  Bring the pane-edited scalars and the shortcuts of Draft up to date
   --  with a change made outside the pane (a command run while it is open,
   --  another process's rebind taken in), so the pane shows the change and
   --  its next save keeps it. A setting, or a command's shortcuts, that did
   --  not change between Before and After keeps what the pane holds, an
   --  edit included. Merged so, an edit may clash with the outside change's
   --  binding: Overlays.Settings_Form.Refresh_Draft, which the window calls,
   --  binds the edits again over what is in force.
   --
   --  @param Draft The pane's draft.
   --  @param Before Settings before the change.
   --  @param After Settings after it.
   --  @return Draft with each changed pane setting taken from After.
   function Refresh_Draft
     (Draft  : Settings_Draft;
      Before : Settings_Model;
      After  : Settings_Model)
      return Settings_Draft;

   --  The settings pane's draft after Saved was saved from Draft: the pane
   --  settings and every mapping row as Saved holds them (keys normalized,
   --  a row whose key another row took merged into it), listed in the order
   --  the pane showed them rather than Make_Draft's, a blank row the editor
   --  had just added at the end kept (the file does not hold it; a blank
   --  row elsewhere is dropped), and each mapping editor still on the row
   --  it was on -- or, its row dropped, the nearest one before it.
   --
   --  @param Draft The pane's draft that was saved.
   --  @param Saved The settings it saved.
   --  @return Draft rebuilt from Saved, keeping where each editor was.
   function Draft_After_Save
     (Draft : Settings_Draft;
      Saved : Settings_Model)
      return Settings_Draft;

   --  Apply a valid settings draft to an existing settings model.
   --
   --  @param Settings Settings model to update.
   --  @param Draft Valid draft values.
   --  @return Validation result containing updated settings or a diagnostic key.
   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result;

   --  Return a default settings draft, discarding any edited values.
   --
   --  @return Draft created from Default_Settings.
   function Reset_Draft_To_Defaults return Settings_Draft;

private

   --  Validate a settings draft without changing a settings model.
   --
   --  @param Draft Draft to validate.
   --  @return Validation result containing deterministic diagnostic key.
   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result;

end Files.Settings.Drafts;

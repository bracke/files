with Files.Model;
with Files.Settings;
with Files.Types;

--  Changing the selected item's permissions and owner from the info pane.
package Files.Operations.Metadata is

   --  Toggle one rwx bit of the single selected item's mode and apply it.
   --
   --  Bit is the info-pane grid cell index (0 .. 8, rows user/group/other,
   --  columns read/write/execute); the affected POSIX bit is 2 ** (8 - Bit).
   --
   --  @param Model Window model whose selected item's mode is changed.
   --  @param Bit Grid cell index in 0 .. 8.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Apply User_Id/Group_Id to the single selected item through chown,
   --  recording the previous owner/group for undo and reloading so the info
   --  pane reflects the change.
   --
   --  The operation is disabled unless exactly one non-trash item is selected,
   --  its ownership was read, and the platform supports ownership changes.
   --  Changing ownership usually requires root, so an unprivileged attempt to
   --  set a different owner fails with error.ownership.denied.
   --
   --  @param Model Window model whose selected item's ownership is changed.
   --  Hostkit.Metadata.Keep_Id for User_Id or Group_Id leaves that id as
   --  the file has it: an edit of one asks for that one only. The entry
   --  recorded for undo and redo holds the ids the file had and has.
   --
   --  @param User_Id New owning user id to apply, or Keep_Id.
   --  @param Group_Id New owning group id to apply, or Keep_Id.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Files.Types.Account_Id;
      Group_Id : Files.Types.Account_Id;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Open the info-pane ownership editor for the single selected item,
   --  prefilled with the owner's (or group's) resolved account name. Does
   --  nothing on a platform without chown support, or when the model refuses
   --  (see Files.Model.Ownership_Input.Focus_Ownership_Input).
   --
   --  @param Model Window model to update.
   --  @param Editing_Group True to edit the group, False to edit the owner.
   procedure Focus_Ownership_Input
     (Model         : in out Files.Model.Window_Model;
      Editing_Group : Boolean);

   --  Commit the info-pane ownership editor: the typed account (a name, or
   --  all digits for an id) becomes the selected item's owner or group, and
   --  the editor closes. A name that resolves to no account fails with
   --  "error.ownership.invalid_name"; the id the item already has changes
   --  nothing -- no chown, which even with the ids a file has clears its
   --  set-user-id and set-group-id bits on Linux and macOS, and no Undo.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by the change.
   --  @return The change's result.
   function Commit_Ownership_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

private

   --  Apply New_Mode to the single selected item through chmod, recording the
   --  previous mode for undo and reloading so the info pane reflects the change.
   --
   --  The operation is disabled unless exactly one non-trash item is selected,
   --  its mode was read, and the platform supports permission changes.
   --
   --  @param Model Window model whose selected item's mode is changed.
   --  @param New_Mode POSIX permission bits (low 12 bits) to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Metadata;

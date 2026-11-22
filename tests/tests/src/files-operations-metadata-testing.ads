with Files.Model;
with Files.Settings;

--  Test access to Files.Operations.Metadata's private part.
package Files.Operations.Metadata.Testing is

   --  Files.Operations.Metadata.Set_Permissions_For.
   --  @param Model Window model whose selected item's mode is changed.
   --  @param New_Mode POSIX permission bits (low 12 bits) to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
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

end Files.Operations.Metadata.Testing;

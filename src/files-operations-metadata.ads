with Files.Model;
with Files.Settings;

--  The permission/ownership metadata operations of Files.Operations, extracted
--  into a group child. A private child; the parent renames these.
private package Files.Operations.Metadata is

   --  Apply New_Mode to the single selected item, record the previous mode for
   --  undo, and reload so the info pane reflects the change. Disabled unless
   --  exactly one non-trash item is selected with a readable mode on a platform
   --  that supports permission changes.
   --
   --  @param Model Window model whose selected item's mode is changed.
   --  @param New_Mode POSIX permission bits (low 12 bits) to apply.
   --  @param Settings Settings model used for the reload.
   --  @return Structured operation result.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Toggle one rwx bit (grid cell index 0 .. 8) of the selected item's mode
   --  and apply it through Set_Permissions_For.
   --
   --  @param Model Window model whose selected item's mode is changed.
   --  @param Bit Grid cell index in 0 .. 8.
   --  @param Settings Settings model used for the reload.
   --  @return Structured operation result.
   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Apply User_Id/Group_Id to the single selected item through chown, record
   --  the previous owner/group for undo, and reload. Disabled unless exactly one
   --  non-trash item is selected with readable ownership on a supporting host.
   --
   --  @param Model Window model whose selected item's ownership is changed.
   --  @param User_Id New owning user id.
   --  @param Group_Id New owning group id.
   --  @param Settings Settings model used for the reload.
   --  @return Structured operation result.
   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Metadata;

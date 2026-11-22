with Files.Model;
with Files.Settings;

--  Moving the selection to the trash, deleting it, restoring it from the
--  trash, and emptying the trash.
package Files.Operations.Trash is

   --  Move selected items to the platform trash when available.
   --
   --  @param Model Window model to inspect and refresh after mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Permanently delete selected items through the explicit advanced command.
   --
   --  This is intentionally separate from Delete_Selected, which always uses
   --  platform trash/recycle-bin semantics.
   --
   --  @param Model Window model to inspect and refresh after mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Restore selected trashed items to their recorded original locations.
   --
   --  @param Model Window model to inspect and refresh after mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Permanently delete every entry currently in the trash view.
   --
   --  Enumerates the trashed payloads the trash view lists and purges each one
   --  (payload plus its .trashinfo metadata). The pass is best-effort: per-item
   --  failures are collected and the remaining entries are still removed. The
   --  trash view is reloaded afterwards. Emptying the trash is terminal and
   --  never records an undo entry. Returns success when at least one entry was
   --  removed (with an error.trash.empty_partial diagnostic set on partial
   --  failure), or Operation_Failed when every entry failed to delete.
   --
   --  @param Model Window model to inspect and refresh after mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Trash;

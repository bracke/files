with Files.Model;
with Files.Settings;

--  Making and changing items in place: new files and folders, duplicates,
--  links, renames, and thumbnails.
package Files.Operations.Editing is

   --  Duplicate each selected item into a uniquely named copy in the current
   --  directory, then reload so the first created copy appears and is selected.
   --  Files and directories are both copied recursively. The copy name keeps the
   --  original extension and inserts a " (copy)" marker before it (for example
   --  report.txt becomes report (copy).txt), made unique with an incrementing
   --  counter when a candidate name already exists.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-duplicate reload.
   --  @return Structured operation result.
   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Create a symbolic link to each selected item in the current directory,
   --  then reload so the first created link appears and is selected. Each link
   --  is named after its source with a " (link)" marker inserted before the
   --  extension (for example report.txt becomes report (link).txt), made unique
   --  with an incrementing counter when a candidate name already exists. The
   --  created links are recorded for undo (undo deletes them).
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-create reload.
   --  @return Structured operation result.
   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Create a hard link to each selected regular file in the current
   --  directory, then reload so the first created link appears and is selected.
   --  Naming, uniquification, and undo recording match Create_Symlink_Selected.
   --  Directories cannot be hard-linked and are reported as a failure.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-create reload.
   --  @return Structured operation result.
   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Commit the active create-file temporary item to the filesystem.
   --
   --  @param Model Window model to update after filesystem mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Begin creating a file (or, Folder, a folder) in the current directory,
   --  named with the next free untitled name.
   --
   --  @param Model Window model to update.
   --  @param Folder True for a folder, False for a file.
   procedure Begin_Create_Item
     (Model  : in out Files.Model.Window_Model;
      Folder : Boolean);

   --  Commit active single-item rename mode to the filesystem.
   --
   --  @param Model Window model to update after filesystem mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Generate cached thumbnails for selected regular files.
   --
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result with first generated thumbnail path.
   function Generate_Selected_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Editing;

with Files.File_System;
with Files.Model;
with Files.Settings;
with Files.Types;

--  The archive / link / delete / trash / paste transfer operations of
--  Files.Operations, extracted into a group child. A private child; the parent
--  renames these to keep the public API stable.
private package Files.Operations.Transfer is

   --  Compress the selected items into a single archive in the current
   --  directory, then reload so the new archive appears and is selected.
   --  Directories are recursed; files are stored with directory-relative entry
   --  names. The archive is named after the first selected item with the
   --  format's extension (.zip / .7z), made unique if it already exists.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-compress reload.
   --  @param Format Archive container format to produce.
   --  @return Structured operation result.
   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result;

   --  Extract each selected archive (.zip or .7z) into a new directory in the
   --  current directory named after the archive's base name, made unique if it
   --  already exists, then reload so the first created directory is selected.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-extract reload.
   --  @return Structured operation result.
   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

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

   --  Advance an armed paste execution by up to Max_Items resolved actions,
   --  copying or moving each written item through Execute_Drop_Import and
   --  updating the model's progress counters. When the cursor reaches the end of
   --  the action list (or a cancellation was requested) the execution finalizes:
   --  it records a single undo covering the items actually completed (move is
   --  reversed by moving back, copy by deleting the created copies), clears the
   --  move-mode clipboard, reloads the directory, and clears the execution state.
   --  A no-op Success is returned when no execution is active.
   --
   --  @param Model Window model holding the armed execution.
   --  @param Settings Settings model used for the finalizing directory reload.
   --  @param Max_Items Maximum resolved actions to process this call.
   --  @return Success while still in progress or after a clean finalize; a
   --    failure result with a localized error key when a write failed.
   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result;

   --  Request cancellation of the armed paste execution. Already-completed items
   --  are kept (like real file managers); the next Advance_Paste_Execution
   --  finalizes over the completed set. Does nothing when no execution is active.
   --
   --  @param Model Window model holding the armed execution.
   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model);

   --  Begin a clipboard paste (copy or move) into the current directory,
   --  resolving name collisions interactively.
   --
   --  Sources are validated as for a drag-and-drop import. When no destination
   --  name collides the paste executes immediately (identical to the old
   --  behaviour minus the silent auto-rename). When one or more names collide,
   --  the model enters the pending paste-conflict sub-mode so the shell can show
   --  the conflict dialog; nothing is written until the user resolves them.
   --
   --  Also the entry point for drag-and-drop imports into the current directory:
   --  callers pass From_Clipboard => False so that finalizing a move does not
   --  clear the (unrelated) clipboard.
   --
   --  @param Model Window model receiving the pasted paths.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Source_Paths Clipboard or dropped source paths.
   --  @param Mode Copy or move (cut) mode.
   --  @param From_Clipboard True for a clipboard paste (a completed move clears
   --    the clipboard), False for a drag-and-drop import.
   --  @return Success when executed or when the dialog was armed; a failure
   --    result with a localized error key on a validation failure.
   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result;

   --  Begin a copy or move of the given sources into an explicit destination
   --  directory, using the same collision handling and resumable progress
   --  execution as Begin_Paste (which is this with Destination = current path).
   --  Used by the Copy to.../Move to... destination picker and by drag-and-drop
   --  imports onto a specific target directory.
   --
   --  @param Model Window model receiving the operation.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Source_Paths Source paths to copy or move.
   --  @param Destination Directory that receives the entries.
   --  @param Mode Copy or move mode.
   --  @param From_Clipboard True for a clipboard paste (a completed move clears
   --    the clipboard), False for a drag-and-drop import.
   --  @return Success when executed or when the conflict dialog was armed; a
   --    failure result with a localized error key on a validation failure.
   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result;

   --  Apply one conflict decision to the pending paste. Records the choice
   --  (per-item, or batch-wide when Apply_All is set), then either advances to
   --  the next unresolved conflict or, once none remain, executes the resolved
   --  copies/moves, records undo, reloads, and clears the sub-mode. Choice_Cancel
   --  aborts the whole paste with no filesystem change.
   --
   --  @param Model Window model in the pending paste-conflict sub-mode.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Choice The user's decision for the current conflict.
   --  @param Apply_All True to apply the decision to every remaining conflict.
   --  @return Structured operation result; Disabled when no paste is pending.
   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
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

   --  Commit active single-item rename mode to the filesystem.
   --
   --  @param Model Window model to update after filesystem mutation.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Transfer;

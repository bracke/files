with Files.File_System;
with Files.Model;
with Files.Settings;
with Files.Types;

--  Filesystem-backed command operations and open-action preparation.
package Files.Operations is
   subtype UString is Files.Types.UString;

   type Operation_Status is
     (Operation_Success,
      Operation_Disabled,
      Operation_Invalid_Name,
      Operation_Failed,
      Operation_Action_Executed,
      Operation_Navigated,
      Operation_Missing_Open_Action);

   type Operation_Result is record
      Status    : Operation_Status := Operation_Disabled;
      Error_Key : UString;
      Path      : UString;
      Action    : Files.Settings.Open_Action;
      Action_Executable : UString;
      Action_Arguments  : Natural := 0;
      Action_Uses_Shell : Boolean := False;
      Execution_Attempted : Boolean := False;
      Executable_Found    : Boolean := False;
      Exit_Status_Known   : Boolean := False;
      Exit_Status         : Integer := 0;
   end record;

   type Open_Action_Execution_Policy is record
      Uses_Argument_Vector       : Boolean := True;
      Shell_Requires_Explicit_Opt_In : Boolean := True;
      Checks_Executable_Before_Spawn : Boolean := True;
      Tracks_Execution_Attempt  : Boolean := True;
      Tracks_Exit_Status        : Boolean := True;
      Runs_Asynchronously       : Boolean := False;
      Supports_Cancellation     : Boolean := False;
      Rejects_Unsafe_Placeholders : Boolean := True;
      Reports_Missing_Action    : Boolean := True;
      Reports_Missing_Executable : Boolean := True;
      Captures_Executable_Discovery : Boolean := True;
      Captures_Process_Result       : Boolean := True;
      Quotes_Shell_Arguments        : Boolean := True;
      Preserves_Vector_Boundaries   : Boolean := True;
      Multi_File_Deterministic      : Boolean := True;
   end record;

   type Open_Action_Lifecycle_State is
     (Open_Action_Not_Started,
      Open_Action_Preflight_Failed,
      Open_Action_Spawned,
      Open_Action_Completed,
      Open_Action_Failed);

   type Open_Action_Lifecycle is record
      State             : Open_Action_Lifecycle_State := Open_Action_Not_Started;
      Executable        : UString;
      Argument_Count    : Natural := 0;
      Uses_Shell        : Boolean := False;
      Exit_Status_Known : Boolean := False;
      Exit_Status       : Integer := 0;
      Cancellation_Available : Boolean := False;
   end record;

   --  Return open-action execution policy for the current implementation.
   --
   --  @return Process execution policy and known lifecycle limits.
   function Open_Action_Policy return Open_Action_Execution_Policy;

   --  Build lifecycle metadata for an operation result.
   --
   --  @param Result Operation result to summarize.
   --  @return Open-action lifecycle metadata.
   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle;

   --  Return the executable used for explicit shell open actions.
   --
   --  COMSPEC is preferred when present. Otherwise SHELL is used, falling back
   --  to /bin/sh.
   --
   --  @return Shell executable path or command name.
   function Shell_Executable return String;

   --  Return the first argument used to ask the selected shell to run a command.
   --
   --  @return /C for COMSPEC shells and -c otherwise.
   function Shell_Command_Option return String;

   --  Spawn an open action's executable, optionally fully detached.
   --
   --  When Detach is True the action is launched through the host shell with
   --  full stdin/stdout/stderr redirection and backgrounding so the spawned
   --  process does not inherit Files's file descriptors or signal mask. This is
   --  the launch path used by the "Open With" application picker.
   --
   --  @param Action Open action describing the executable and arguments.
   --  @param Exit_Status Spawn exit status, or -1 when no process was started.
   --  @param Detach Whether to launch the process fully detached.
   --  @return True when the spawn reported success.
   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean;

   --  Refresh the current directory and replace loaded items.
   --
   --  @param Model Window model to refresh.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Poll the current directory and refresh only when its signature changed.
   --
   --  @param Model Window model containing the last loaded directory signature.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Archive container format produced by Compress_Selected.
   type Archive_Format is (Zip_Archive, Seven_Zip_Archive);

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

   --  Return the terminal-emulator executable that Open_Terminal would launch.
   --
   --  The TERMINAL environment variable is preferred; otherwise the first of a
   --  fixed list of common Linux emulators found on PATH is returned. The result
   --  is empty when no terminal emulator is available.
   --
   --  @return Terminal executable name or path, or an empty string when none.
   function Detected_Terminal return String;

   --  Launch a terminal emulator with its working directory set to the model's
   --  current directory. The terminal is spawned fully detached, mirroring the
   --  "Open With" launch policy.
   --
   --  @param Model Window model providing the current directory.
   --  @param Settings Settings model (unused; kept for routing symmetry).
   --  @return Structured operation result; failed when no terminal was launched.
   function Open_Terminal
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Replace the current view with recursive search results for the filter text.
   --
   --  @param Model Window model containing the current path and filter query.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Commit the current path-input text by validating and loading the destination.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate home and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate backward and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate forward and load the destination directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Navigate to the current backend's trash payload directory.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Select a root location and load it in the current window.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory classification.
   --  @param Root_Path Root path selected by the user.
   --  @return Structured operation result.
   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result;

   --  Preflight eject/unmount for the selected root without forcing permanent state changes.
   --
   --  The first implementation exposes the command flow and reports a
   --  localized unavailable error until a native backend is available.
   --
   --  @param Model Window model containing the open root selector.
   --  @return Structured operation result.
   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result;

   --  Prepare the selected file's open action without executing it.
   --
   --  Directories are reported as navigable targets, and regular files use
   --  settings-driven action lookup plus placeholder expansion.
   --
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for open-action lookup.
   --  @param Modifiers Active modifier keys for file open-action lookup.
   --  @return Structured operation result with expanded action data.
   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Operation_Result;

   --  Open the selected item using directory navigation or configured file action execution.
   --
   --  @param Model Window model to inspect and possibly navigate.
   --  @param Settings Settings model used for directory loading and open-action lookup.
   --  @param Modifiers Active modifier keys for file open-action lookup.
   --  @return Structured operation result.
   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
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

   --  Generate cached thumbnails for selected regular files.
   --
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result with first generated thumbnail path.
   function Generate_Selected_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  A user's answer to a paste-conflict prompt (mirrors the dialog buttons).
   type Conflict_Choice is
     (Choice_Replace,
      Choice_Skip,
      Choice_Rename,
      Choice_Cancel);

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
   --  @param User_Id New owning user id to apply.
   --  @param Group_Id New owning group id to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Refresh the cached recursive folder size for the current selection.
   --
   --  When exactly one directory is selected and its size is not already cached
   --  the directory tree is walked (bounded) and the totals are stored on the
   --  model for the info pane; otherwise any stale cache is cleared. Cheap when
   --  the selection is unchanged. Never mutates the filesystem.
   --
   --  @param Model Window model whose folder-size cache is updated.
   --  @param Settings Settings model (reserved for future filtering).
   procedure Update_Folder_Size
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Undo the most recently recorded reversible action (rename, move, or
   --  move-to-trash), then clear the undo record and reload the directory.
   --
   --  @param Model Window model carrying the undo record to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result; failed when nothing is recorded or
   --          an inverse step could not be applied.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations;

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

   --  Import dropped paths into the current directory and refresh the model.
   --
   --  @param Model Window model receiving the dropped paths.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Source_Paths Dropped filesystem paths.
   --  @param Mode Copy or move mode.
   --  @return Structured operation result with first imported destination path.
   function Import_Dropped_Paths
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Operation_Result;

   --  Import dropped paths into a specific destination directory.
   --
   --  @param Model Window model to refresh after a successful import.
   --  @param Settings Settings model used for directory classification.
   --  @param Source_Paths Paths received from a drag-and-drop operation.
   --  @param Destination_Directory Directory receiving the dropped entries.
   --  @param Mode Copy or move mode for all valid plans.
   --  @return Structured operation result.
   function Import_Dropped_Paths_To
     (Model                 : in out Files.Model.Window_Model;
      Settings              : Files.Settings.Settings_Model;
      Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
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

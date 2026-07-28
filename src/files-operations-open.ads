with Guikit.Input;

with Files.Model;
with Files.Settings;

--  The open/launch/terminal operations of Files.Operations, extracted into a
--  group child. A private child; the parent renames these.
private package Files.Operations.Open is

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

   --  Spawn an open action's executable, optionally detached.
   --
   --  When Detach is True the process is started through Files.Launcher and we do
   --  not wait for it: the application a user opens a file in may run for hours.
   --  There is therefore no exit status -- Exit_Status stays -1 -- and the result
   --  says only whether the launch began. This is the path the "Open With" picker
   --  and the system-default opener use.
   --
   --  When Detach is False the process is run to completion and its exit status is
   --  reported, which is what a caller wants from a short-lived helper.
   --
   --  @param Action Open action describing the executable and arguments.
   --  @param Exit_Status Exit status, or -1 when none was awaited or none started.
   --  @param Detach Whether to launch the process without waiting for it.
   --  @return True when the process ran successfully, or (detached) was started.
   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean;

   --  Detect an available terminal emulator.
   --
   --  TERMINAL is honored when set and present on PATH. Otherwise a small
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
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
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
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result;

end Files.Operations.Open;

with Files.Desktop_Applications;
with Files.Items;
with Files.Model;
with Files.Quick_Look.Preparation;
with Files.Settings;
with Guikit.Input;
with Files.Types;

--  Opening items: the open actions settings choose, Open With, a terminal,
--  and Quick Look content.
package Files.Operations.Opening is

   --  Check an open action's effective executable using the same host-aware
   --  PATH and executable-file policy used immediately before spawning it.
   --
   --  @param Action Open action to preflight.
   --  @return True when its executable (or explicit shell) is available.
   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean;

   --  Spawn an open action's executable, optionally detached.
   --
   --  When Detach is True the process is started through Hostkit.Process.Launch and
   --  we do not wait for it: the application a user opens a file in may run for hours.
   --  There is therefore no exit status -- Exit_Status stays -1 -- and the result
   --  says only whether the launch began. This is the path the "Open With" picker
   --  and the system-default opener use.
   --
   --  When Detach is False the process is run to completion and its exit status is
   --  reported, which is what a caller wants from a short-lived helper.
   --
   --  On failure, Failure_Key says why a launch did not start when there is
   --  more to say than that it failed.
   --
   --  @param Action Open action describing the executable and arguments.
   --  @param Exit_Status Exit status, or -1 when none was awaited or none started.
   --  @param Failure_Key On failure, the error key to show: error.open.path_too_long
   --    when the system opener cannot take the path (Windows, past 259
   --    characters with no short name), else empty for the caller's own.
   --  @param Detach Whether to launch the process without waiting for it.
   --  @return True when the process ran successfully, or (detached) was started.
   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Failure_Key : out UString;
      Detach      : Boolean := False)
      return Boolean;

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

   --  Launch a terminal emulator with its working directory set to the model's
   --  current directory. The terminal is spawned fully detached, mirroring the
   --  "Open With" launch policy.
   --
   --  @param Model Window model providing the current directory.
   --  @return Structured operation result; failed when no terminal was launched.
   function Open_Terminal
     (Model : in out Files.Model.Window_Model)
      return Operation_Result;

   --  Prepare Quick Look preview content for a directory item, performing the
   --  bounded filesystem read the pure content-prep seam needs. Image items are
   --  classified with the shared image detector and previewed by path; other
   --  regular files get a capped leading-bytes read for text detection; the rest
   --  fall back to the metadata-only info card.
   --
   --  @param Item Directory item to preview.
   --  @return Prepared Quick Look content.
   function Prepare_Quick_Look
     (Item : Files.Items.Directory_Item)
      return Files.Quick_Look.Quick_Look_Content renames Files.Quick_Look.Preparation.Prepare;

   --  Open Targets with App (Open With), all its launches started or none; an App
   --  that runs in a terminal (Terminal=true) is started inside the one Open
   --  Terminal would open, and fails when there is none.
   --
   --  @param Model Window model whose error line and recent list follow.
   --  @param App The application chosen.
   --  @param Targets The paths to open.
   --  @return Action_Executed for the first launch, or Failed with the launch
   --    and path that failed and why; Failed with "error.terminal.unavailable"
   --    when App needs a terminal no host one can run.
   function Launch_Application
     (Model   : in out Files.Model.Window_Model;
      App     : Files.Desktop_Applications.Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Operation_Result;

   --  Open the command palette as the Open With picker for the selection,
   --  listing the applications installed now.
   --
   --  @param Model Window model to update.
   procedure Begin_Open_With (Model : in out Files.Model.Window_Model);

private

   --  Start every launch of one open, all or nothing: each action's
   --  executable is checked before any starts, then each is started
   --  detached (started and let go, so no exit status is known). Once all
   --  have started, every path of Paths joins the recent list -- the same
   --  rule whether the open came from Open or from Open With. The first
   --  failure is reported on the error line and stops the rest.
   --
   --  @param Model Window model whose error line and recent list follow.
   --  @param Actions The launches, in order; not empty.
   --  @param Paths The paths the open opens: Paths (I) is the one Actions (I)
   --    opens when there are as many, otherwise the first stands for all.
   --  @return Action_Executed for the first launch; Failed with the launch
   --    and path that failed and why.
   function Launch_Open_Actions
     (Model   : in out Files.Model.Window_Model;
      Actions : Files.Desktop_Applications.Open_Action_Vectors.Vector;
      Paths   : Files.Types.String_Vectors.Vector)
      return Operation_Result;

   --  Return the terminal-emulator executable that Open_Terminal would launch.
   --
   --  The TERMINAL environment variable is preferred on every host: it is the
   --  user naming the one they want. Otherwise the answer is the host's --
   --  the first of a list of common emulators found on PATH on Linux, of
   --  Windows Terminal, PowerShell and cmd on Windows, and `open` on macOS,
   --  where a terminal is an application bundle rather than a program on PATH.
   --  The result is empty when no terminal emulator is available.
   --
   --  @return Terminal executable name or path, or an empty string when none.
   function Detected_Terminal return String;

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

end Files.Operations.Opening;

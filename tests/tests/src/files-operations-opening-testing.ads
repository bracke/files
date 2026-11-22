with Files.Model;
with Files.Settings;
with Guikit.Input;

--  Test access to Files.Operations.Opening's private part.
package Files.Operations.Opening.Testing is

   --  @return Files.Operations.Opening.Detected_Terminal.
   function Detected_Terminal return String;

   --  Files.Operations.Opening.Prepare_Open_Selected_Action.
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for open-action lookup.
   --  @param Modifiers Active modifier keys for file open-action lookup.
   --  @return Structured operation result with expanded action data.
   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result;

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

   --  Check an open action's effective executable using the same host-aware
   --  PATH and executable-file policy used immediately before spawning it.
   --
   --  @param Action Open action to preflight.
   --  @return True when its executable (or explicit shell) is available.
   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean;

end Files.Operations.Opening.Testing;

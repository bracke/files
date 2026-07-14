with Files.Settings;

--  Asynchronous launching of external applications ("Open", "Open With").
--
--  A launch here is fire-and-forget: the process is started and files carries on
--  drawing. It reports whether the launch *began*, never what the application went
--  on to do -- an application a user opens a file in may run for hours, so there is
--  no exit status to wait for and none is offered. Callers that do want the exit
--  status of a short-lived helper want Files.Operations.Execute_Open_Action without
--  Detach, which runs it synchronously.
--
--  This replaced a shell: detaching used to be done by handing a command line to
--  sh -- "( ... </dev/null >/dev/null 2>&1 & )" -- or to cmd -- "start "" /b ..." --
--  purely so that the blocking spawn underneath would return promptly. That put a
--  cross-platform quoting and shell-selection problem in the path of every launch.
--  The process is now started directly, with its arguments passed as a vector, so
--  a filename containing shell metacharacters is just a filename.
package Files.Launcher is

   --  Start Action's executable and return immediately.
   --
   --  @param Action Open action describing the executable and its arguments.
   --  @return True when the process was started; False when it could not be.
   function Launch (Action : Files.Settings.Open_Action) return Boolean;

end Files.Launcher;

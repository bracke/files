with Files.Settings;
with Files.Types;

--  What an operation reports back: its status, a localized error key, the
--  path it ended on, and for an open action what ran. Its own unit so the
--  operations (Files.Operations) and the helper jobs that run them
--  (Files.Operation_Jobs) share it: the operations never start a job
--  (Files.Operation_Commands does), and only the helper side
--  (Files.Operation_Jobs.Helper) runs an operation.
package Files.Operation_Results is

   type Operation_Status is
     (Operation_Success,
      Operation_Disabled,
      Operation_Invalid_Name,
      Operation_Failed,
      Operation_Action_Executed,
      Operation_Navigated,
      Operation_Missing_Open_Action);

   --  What running an open action did: whether a process start was tried,
   --  whether its executable was found, and its exit status when one was
   --  awaited (a detached launch has none).
   type Execution_Outcome is record
      Attempted         : Boolean := False;
      Executable_Found  : Boolean := False;
      Exit_Status_Known : Boolean := False;
      Exit_Status       : Integer := 0;
   end record;

   type Operation_Result is record
      Status    : Operation_Status := Operation_Disabled;
      Error_Key : Files.Types.UString;
      Path      : Files.Types.UString;
      Action    : Files.Settings.Open_Action;
      Execution : Execution_Outcome;
   end record;

end Files.Operation_Results;

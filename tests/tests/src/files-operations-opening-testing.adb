with Ada.Strings.Unbounded;

package body Files.Operations.Opening.Testing is

   use Ada.Strings.Unbounded;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
   is
      State : Open_Action_Lifecycle_State := Open_Action_Not_Started;
   begin
      if Result.Status = Operation_Action_Executed then
         --  "Completed" means we saw it finish, which we only do when we waited for
         --  it. A detached launch is started and let go, so the honest state is
         --  Spawned: the process is running, and its outcome is not ours to know.
         State :=
           (if Result.Execution.Exit_Status_Known
            then Open_Action_Completed
            else Open_Action_Spawned);
      elsif Result.Status = Operation_Failed and then Result.Execution.Attempted then
         State := Open_Action_Failed;
      elsif Result.Status = Operation_Failed
        and then not Result.Execution.Executable_Found
        and then To_String (Result.Action.Executable) /= ""
      then
         State := Open_Action_Preflight_Failed;
      elsif Result.Execution.Attempted then
         State := Open_Action_Spawned;
      end if;

      return
        (State             => State,
         Executable        => Result.Action.Executable,
         Argument_Count    => Natural (Result.Action.Arguments.Length),
         Uses_Shell        => Result.Action.Use_Shell,
         Exit_Status_Known => Result.Execution.Exit_Status_Known,
         Exit_Status       => Result.Execution.Exit_Status,
         Cancellation_Available => False);
   end Open_Action_Lifecycle_Of;

   function Detected_Terminal return String
     renames Files.Operations.Opening.Detected_Terminal;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Opening.Prepare_Open_Selected_Action;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Failure_Key : out UString;
      Detach      : Boolean := False)
      return Boolean
     renames Files.Operations.Opening.Execute_Open_Action;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean
     renames Files.Operations.Opening.Open_Action_Executable_Is_Available;

end Files.Operations.Opening.Testing;

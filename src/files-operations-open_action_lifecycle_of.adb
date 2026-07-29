separate (Files.Operations)
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
           (if Result.Exit_Status_Known
            then Open_Action_Completed
            else Open_Action_Spawned);
      elsif Result.Status = Operation_Failed and then Result.Execution_Attempted then
         State := Open_Action_Failed;
      elsif Result.Status = Operation_Failed
        and then not Result.Executable_Found
        and then To_String (Result.Action_Executable) /= ""
      then
         State := Open_Action_Preflight_Failed;
      elsif Result.Execution_Attempted then
         State := Open_Action_Spawned;
      end if;

      return
        (State             => State,
         Executable        => Result.Action_Executable,
         Argument_Count    => Result.Action_Arguments,
         Uses_Shell        => Result.Action_Uses_Shell,
         Exit_Status_Known => Result.Exit_Status_Known,
         Exit_Status       => Result.Exit_Status,
         Cancellation_Available => False);
   end Open_Action_Lifecycle_Of;

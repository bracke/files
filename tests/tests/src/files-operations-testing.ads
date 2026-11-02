--  Test-only views of Files.Operations: how the suite classifies an open
--  action's result, which the program never asks.
package Files.Operations.Testing is

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

   --  Build lifecycle metadata for an operation result.
   --
   --  @param Result Operation result to summarize.
   --  @return Open-action lifecycle metadata.
   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle;

end Files.Operations.Testing;

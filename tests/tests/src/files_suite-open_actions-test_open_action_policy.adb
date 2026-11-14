separate (Files_Suite.Open_Actions)
   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Generic_Failure : constant Files.Operations.Operation_Result :=
           (Status              => Files.Operations.Operation_Failed,
            Error_Key           => To_Unbounded_String ("error.directory.load"),
            Path                => To_Unbounded_String (Root),
            Action              =>
              Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            Execution           =>
              (Attempted => False, Executable_Found => False, Exit_Status_Known => False, Exit_Status => 0));
      begin
         Assert
           (Files.Operations.Testing.Open_Action_Lifecycle_Of (Generic_Failure).State =
            Files.Operations.Testing.Open_Action_Not_Started,
            "generic failed operations are not classified as open-action preflight failures");
      end;
   end Test_Open_Action_Policy;

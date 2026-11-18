separate (Files_Suite.Recovery)
   procedure Test_A_Reasonless_Helper_Failure_Is_A_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  The default result: what a helper that died between its first and
      --  last result left for the window to read.
      Result : Files.Transfer_Jobs.Job_Result;
   begin
      Result.Mutation := (Success => False, Error_Key => Null_Unbounded_String);
      Files.Transfer_Jobs.Testing.Settle (Result, Cancelled => False);
      Assert (not Result.Mutation.Success and then To_String (Result.Mutation.Error_Key) = "error.drop.failed",
              "a failed helper result with no reason reads as a failed drop, not as success");

      Result := (others => <>);
      Result.Mutation := (Success => False, Error_Key => Null_Unbounded_String);
      Files.Transfer_Jobs.Testing.Settle (Result, Cancelled => True);
      Assert (Result.Cancelled, "a cancelled helper's reasonless failure is the cancellation");

      Result := (others => <>);
      Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.io.no_space"));
      Files.Transfer_Jobs.Testing.Settle (Result, Cancelled => False);
      Assert (To_String (Result.Mutation.Error_Key) = "error.io.no_space", "a reason the helper gave is kept");
   end Test_A_Reasonless_Helper_Failure_Is_A_Failure;

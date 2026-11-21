separate (Files_Suite.Recovery)
   procedure Test_A_Reasonless_Helper_Failure_Is_A_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  The default result: what a helper that died between its first and
      --  last result left for the window to read.
      Result : Files.Jobs.Transfer.Job_Result;
      type Key_Array is array (Positive range <>) of Unbounded_String;
   begin
      Result.Mutation := (Success => False, Error_Key => Null_Unbounded_String);
      Files.Jobs.Transfer.Testing.Settle (Result, Cancelled => False);
      Assert (not Result.Mutation.Success and then To_String (Result.Mutation.Error_Key) = "error.drop.failed",
              "a failed helper result with no reason reads as a failed drop, not as success");

      Result := (others => <>);
      Result.Mutation := (Success => False, Error_Key => Null_Unbounded_String);
      Files.Jobs.Transfer.Testing.Settle (Result, Cancelled => True);
      Assert (Result.Cancelled, "a cancelled helper's reasonless failure is the cancellation");

      Result := (others => <>);
      Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.io.no_space"));
      Files.Jobs.Transfer.Testing.Settle (Result, Cancelled => False);
      Assert (To_String (Result.Mutation.Error_Key) = "error.io.no_space", "a reason the helper gave is kept");

      --  A cancel and a real failure meeting: the failure keeps its reason.
      --  A destination that appeared says error.drop.failed; only the
      --  cancellation's own key, or the placeholder a killed helper left,
      --  reads as the cancellation.
      Result := (others => <>);
      Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
      Files.Jobs.Transfer.Testing.Settle (Result, Cancelled => True);
      Assert (not Result.Cancelled, "a collision during a cancel is still a collision");
      for Key of Key_Array'
        [To_Unbounded_String (Files.File_System.Cancelled_Error_Key),
         To_Unbounded_String (Files.File_System.Interrupted_Error_Key)]
      loop
         Result := (others => <>);
         Result.Mutation := (Success => False, Error_Key => Key);
         Files.Jobs.Transfer.Testing.Settle (Result, Cancelled => True);
         Assert (Result.Cancelled, To_String (Key) & " after a cancel is the cancellation");
      end loop;
   end Test_A_Reasonless_Helper_Failure_Is_A_Failure;

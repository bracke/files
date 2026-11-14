separate (Files_Suite.Recovery)
   procedure Test_Operation_Result_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "invalid-job-items");
      File     : Ada.Streams.Stream_IO.File_Type;
      Result   : Files.Operations.Operation_Result;
      Decoded  : Files.Operations.Operation_Result;
      Rejected : Boolean := False;
   begin
      Reset_Root;

      --  A result round-trips with its action and its execution outcome.
      Result.Status := Files.Operations.Operation_Action_Executed;
      Result.Path := To_Unbounded_String ("file.txt");
      Result.Action.Executable := To_Unbounded_String ("viewer");
      Result.Action.Arguments.Append (To_Unbounded_String ("file.txt"));
      Result.Action.Use_Shell := True;
      Result.Execution :=
        (Attempted => True, Executable_Found => True, Exit_Status_Known => True, Exit_Status => 3);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Job_Records.Write_Operation_Result (Ada.Streams.Stream_IO.Stream (File), Result);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Decoded := Files.Job_Records.Read_Operation_Result (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Files_Suite.Support.Assert_Equal (Decoded.Status, Result.Status, "a decoded result keeps its status");
      Files_Suite.Support.Assert_Equal (To_String (Decoded.Path), "file.txt", "a decoded result keeps its path");
      Files_Suite.Support.Assert_Equal
        (To_String (Decoded.Action.Executable), "viewer", "a decoded result keeps its action's executable");
      Files_Suite.Support.Assert_Equal
        (Natural (Decoded.Action.Arguments.Length), 1, "a decoded result keeps its action's arguments");
      Files_Suite.Support.Assert_Equal (Decoded.Action.Use_Shell, True, "a decoded result keeps its shell flag");
      Assert
        (Files.Operations."=" (Decoded.Execution, Result.Execution),
         "a decoded result keeps its execution outcome: attempted="
         & Boolean'Image (Decoded.Execution.Attempted)
         & " found=" & Boolean'Image (Decoded.Execution.Executable_Found)
         & " known=" & Boolean'Image (Decoded.Execution.Exit_Status_Known)
         & " exit=" & Integer'Image (Decoded.Execution.Exit_Status));

      --  An action with more arguments than the transport carries is refused
      --  on the way out ...
      for Index in 1 .. 257 loop
         Result.Action.Arguments.Append (To_Unbounded_String ("extra"));
      end loop;
      Rejected := False;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      begin
         Files.Job_Records.Write_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File), Result);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "an action with too many arguments is not serialized");

      --  ... and a record claiming that many is refused on the way in.
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Operations.Operation_Status'Output
        (Ada.Streams.Stream_IO.Stream (File), Files.Operations.Operation_Success);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Error_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Path_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "viewer", Files.Job_Records.Max_Path_Length);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 257);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Decoded := Files.Job_Records.Read_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "a decoded action with too many arguments is rejected");
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Operation_Result_Record_Validation;

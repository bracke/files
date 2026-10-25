separate (Files_Suite.Operations)
   procedure Test_Operation_Result_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "invalid-job-items");
      File     : Ada.Streams.Stream_IO.File_Type;
      Result   : Files.Operations.Operation_Result;
      Rejected : Boolean := False;
   begin
      Reset_Root;
      Result.Action.Executable := To_Unbounded_String ("viewer");
      Result.Action_Executable := To_Unbounded_String ("different-viewer");
      Rejected := False;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      begin
         Files.Job_Records.Write_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File), Result);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "inconsistent action metadata is not serialized");

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Operations.Operation_Status'Output
        (Ada.Streams.Stream_IO.Stream (File), Files.Operations.Operation_Success);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Error_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Path_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "viewer", Files.Job_Records.Max_Path_Length);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "file.txt");
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "viewer", Files.Job_Records.Max_Path_Length);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 0);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Integer'Output (Ada.Streams.Stream_IO.Stream (File), 0);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Result := Files.Job_Records.Read_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "inconsistent decoded action metadata is rejected");
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Operation_Result_Record_Validation;

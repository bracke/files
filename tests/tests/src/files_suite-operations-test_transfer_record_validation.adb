separate (Files_Suite.Operations)
   procedure Test_Transfer_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Transfer_Result : Files.Transfer_Jobs.Job_Result;
      Transfer_Path   : constant String := Join (Root, "invalid-transfer-result");
      Transfer_Target : constant String := Join (Root, "linked-transfer-result");
      Transfer_Request_Path : constant String := Join (Root, "invalid-transfer-request");
      Transfer_Request_Target : constant String := Join (Root, "linked-transfer-request");
      Transfer_Action : Files.Paste.Resolved_Action;
      Rejected : Boolean := False;
   begin
      Reset_Root;
      Transfer_Result.Mutation :=
        (Success => True, Error_Key => Null_Unbounded_String);
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a successful transfer result without a created identity is rejected");

      Transfer_Result.Created_Identity := To_Unbounded_String ("created-token");
      Transfer_Result.Cancelled := True;
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer result cannot report success and cancellation together");

      Transfer_Result.Cancelled := False;
      Transfer_Result.Trashed := To_Unbounded_String ("backup-path");
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer backup path without its identity is rejected");

      Transfer_Result.Trashed_Identity :=
        To_Unbounded_String ("backup-token");
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer result rejects a relative replacement path");

      Transfer_Result := (others => <>);
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Target, Transfer_Result);
      Ada.Directories.Delete_File (Transfer_Path);
      if Hostkit.Fs.Create_Hard_Link (Transfer_Target, Transfer_Path) then
         Rejected := False;
         begin
            Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
              (Transfer_Path);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected, "transfer result reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Transfer_Path);
      else
         Files_Suite.Support.Link_Not_Made ("Test_Transfer_Record_Validation", Files_Suite.Support.Hard_Link);
      end if;

      Transfer_Action :=
        (Source_Path => To_Unbounded_String ("relative-source"),
         Dest_Path   => To_Unbounded_String (Join (Root, "destination")),
         Skip        => False,
         Replaced    => False);
      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Path, Transfer_Action,
         Files.File_System.Drop_Copy);
      Rejected := False;
      begin
         Transfer_Action :=
           Files.Transfer_Jobs.Testing.Read_Request_Action
             (Transfer_Request_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer request rejects a relative source path");

      Transfer_Action.Source_Path := To_Unbounded_String (Join (Root, "source"));
      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Path, Transfer_Action,
         Files.File_System.Drop_Copy,
         Batch_Directory => "/tmp/batch" & Character'Val (0) & "suffix");
      Rejected := False;
      begin
         Transfer_Action :=
           Files.Transfer_Jobs.Testing.Read_Request_Action
             (Transfer_Request_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer request rejects a NUL-containing batch path");

      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Target, Transfer_Action,
         Files.File_System.Drop_Copy);
      Ada.Directories.Delete_File (Transfer_Request_Path);
      if Hostkit.Fs.Create_Hard_Link
        (Transfer_Request_Target, Transfer_Request_Path)
      then
         Rejected := False;
         begin
            Transfer_Action :=
              Files.Transfer_Jobs.Testing.Read_Request_Action
                (Transfer_Request_Path);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected, "transfer request reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Transfer_Request_Path);
      else
         Files_Suite.Support.Link_Not_Made ("Test_Transfer_Record_Validation", Files_Suite.Support.Hard_Link);
      end if;
   end Test_Transfer_Record_Validation;

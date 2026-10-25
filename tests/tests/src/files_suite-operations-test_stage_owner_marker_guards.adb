separate (Files_Suite.Operations)
   procedure Test_Stage_Owner_Marker_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Transport_Job : Files.Process_Jobs.Session;
      Transport_Path : Files.Types.UString;
      function Transport return String is (To_String (Transport_Path));
      Saved     : constant String := Join (Root, "saved-stage");
      Stage     : Files.Types.UString;
      Identity  : Files.Types.UString;
      File      : Ada.Streams.Stream_IO.File_Type;
   begin
      Reset_Root;
      Files.Process_Jobs.Reserve (Transport_Job);
      Transport_Path := To_Unbounded_String (Files.Process_Jobs.Path (Transport_Job, ""));
      Files.Job_Context.Initialize ("");
      declare
         Rejected : Boolean := False;
      begin
         begin
            Files.Job_Context.Initialize ("relative-job-context");
         exception
            when Ada.Directories.Use_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then Files.Job_Context.Directory = "",
            "job context rejects a relative helper directory without changing state");
         Rejected := False;
         begin
            declare
               Invalid : constant String :=
                 Files.Job_Context.Create_Stage ("relative-stage-parent");
               pragma Unreferenced (Invalid);
            begin
               null;
            end;
         exception
            when Ada.Directories.Use_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then not Ada.Directories.Exists ("relative-stage-parent"),
            "stage creation rejects a relative parent directory");
      end;
      Files.Job_Context.Initialize (Transport);
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Stage)));
      declare
         Owner : constant String := Join (To_String (Stage), ".files-owner");
         Owner_Alias : constant String := Join (Root, "stage-owner-hardlink");
         Owner_Linked : constant Boolean :=
           Hostkit.Fs.Create_Hard_Link (Owner, Owner_Alias);
      begin
         if Owner_Linked then
            Files.Process_Jobs.Clean_Stages (Transport_Job);
            Assert
              (Ada.Directories.Exists (To_String (Stage))
               and then Ada.Directories.Exists
                 (Join (Join (Transport, "stages"), "stage-1")),
               "stage cleanup rejects a multiply-linked owner marker");
            Ada.Directories.Delete_File (Owner_Alias);
         end if;
      end;
      declare
         Owner : constant String := Join (To_String (Stage), ".files-owner");
         Owner_Data : constant String := Project_Tools.Files.Read_Raw_File (Owner);
      begin
         Write_Binary_File (Owner, Owner_Data & "trailing");
         Files.Process_Jobs.Clean_Stages (Transport_Job);
         Assert
           (Ada.Directories.Exists (To_String (Stage)),
            "stage cleanup rejects an owner marker with trailing data");
         Write_Binary_File (Owner, Owner_Data);
      end;
      Ada.Directories.Rename (To_String (Stage), Saved);
      Ada.Directories.Create_Directory (To_String (Stage));
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Join (To_String (Stage), ".files-owner"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-owner-1");
      String'Output (Ada.Streams.Stream_IO.Stream (File), Transport);
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (Ada.Directories.Exists (To_String (Stage)) and then Ada.Directories.Exists (Saved)
              and then Ada.Directories.Exists (Join (Transport, "stages")),
              "cleanup preserves a replacement and retains its ownership record for retry");
      Ada.Directories.Delete_File (Join (To_String (Stage), ".files-owner"));
      Ada.Directories.Delete_Directory (To_String (Stage));
      Ada.Directories.Rename (Saved, To_String (Stage));
      declare
         Unheld : Files.Job_Transports.Lease;
      begin
         Files.Job_Context.Clean_Stages (Transport, Unheld);
         Assert (Ada.Directories.Exists (To_String (Stage)),
                 "an unclaimed stage cleanup cannot delete a live stage");
      end;
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (Join (Transport, "stages")),
              "cleanup retries and removes the restored owned stage");
      Files.Job_Context.Initialize ("");
   exception
      when others => Files.Job_Context.Initialize (""); raise;
   end Test_Stage_Owner_Marker_Guards;

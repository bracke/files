separate (Files_Suite.Operations)
   procedure Test_Stage_Record_Cleanup (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Transport_Job : Files.Process_Jobs.Session;
      Transport_Path : Files.Types.UString;
      function Transport return String is (To_String (Transport_Path));
      Unrelated : constant String := Join (Root, "unrelated");
      Unowned   : constant String := Join (Root, ".files-work-9001");
      Link      : constant String := Join (Root, ".files-work-9002");
      Saved     : constant String := Join (Root, "saved-stage");
      Stage     : Files.Types.UString;
      Identity  : Files.Types.UString;
      File      : Ada.Streams.Stream_IO.File_Type;
      Linked    : Boolean;
      Record_Linked : Boolean := False;
      Record_Alias : constant String := Join (Root, "stage-record-hardlink");
      Children_Before : Files.Types.UString;
      Transport_Identity : Files.Types.UString;
      Before    : Ada.Calendar.Time;

      procedure Add_Stage_Record
        (Record_Name, Path, Expected_Identity : String;
         Corrupt : Boolean := False;
         Oversized : Boolean := False)
      is
         Record_Directory : constant String :=
           Join (Join (Transport, "stages"), Record_Name);
         Record_File : Ada.Streams.Stream_IO.File_Type;
      begin
         if not Ada.Directories.Exists (Record_Directory) then
            Ada.Directories.Create_Path (Record_Directory);
         elsif Hostkit.Fs.Is_Link (Record_Directory)
           or else Ada.Directories.Kind (Record_Directory) /=
             Ada.Directories.Directory
         then
            raise Ada.Directories.Use_Error;
         end if;
         Ada.Streams.Stream_IO.Create
           (Record_File, Ada.Streams.Stream_IO.Out_File, Join (Record_Directory, "data"));
         String'Output
           (Ada.Streams.Stream_IO.Stream (Record_File),
            (if Corrupt then "damaged-stage-record" else "files-stage-3"));
         if Oversized then
            --  String'Output encodes these two bounds before the payload.
            --  A malformed record must be rejected before attempting the
            --  allocation described by its forged upper bound.
            Integer'Output (Ada.Streams.Stream_IO.Stream (Record_File), 1);
            Integer'Output
              (Ada.Streams.Stream_IO.Stream (Record_File), Integer'Last);
         elsif not Corrupt then
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Path);
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Expected_Identity);
         end if;
         Ada.Streams.Stream_IO.Close (Record_File);
      end Add_Stage_Record;
   begin
      Reset_Root;
      Files.Process_Jobs.Reserve (Transport_Job);
      Transport_Path := To_Unbounded_String (Files.Process_Jobs.Path (Transport_Job, ""));
      Transport_Identity := To_Unbounded_String (Files.File_Identities.Token (Transport));
      Ada.Directories.Create_Directory (Unrelated);
      Ada.Directories.Create_Directory (Unowned);
      Write_Binary_File (Join (Unrelated, "keep"), "unrelated");
      Files.Job_Context.Initialize (Transport);

      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "partial");
      --  Simulate termination after the owner marker was published but before
      --  the write-ahead record was finalized with its identity.
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File,
         Join (Join (Join (Transport, "stages"), "stage-1"), "data"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-3");
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Stage));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "");
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File,
         Join (Join (Join (Transport, "stages"), "stage-1"), "data"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "trailing");
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert
        (Ada.Directories.Exists (To_String (Stage))
         and then not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-1")),
         "stage cleanup discards a trailing-data record without deleting its named entry");
      Add_Stage_Record
        ("stage-trailing-retry", To_String (Stage), "");
      Linked := Hostkit.Fs.Create_Link (Unrelated, Link);
      Add_Stage_Record ("stage-unrelated", Unrelated, Files.File_Identities.Token (Unrelated));
      Record_Linked := Hostkit.Fs.Create_Hard_Link
        (Join (Join (Join (Transport, "stages"), "stage-unrelated"), "data"),
         Record_Alias);
      Add_Stage_Record ("stage-unowned", Unowned, Files.File_Identities.Token (Unowned));
      Add_Stage_Record ("stage-absent", Join (Root, ".files-work-8000"), "");
      Add_Stage_Record ("stage-relative", ".files-work-relative", "");
      if Linked then
         Add_Stage_Record ("stage-link", Link, Files.File_Identities.Token (Link));
      end if;
      Add_Stage_Record ("stage-corrupt", "", "", Corrupt => True);
      Add_Stage_Record ("stage-oversized", "", "", Oversized => True);
      Add_Stage_Record ("stage-truncated", "", "");
      Write_Binary_File
        (Join (Join (Join (Transport, "stages"), "stage-truncated"), "data"),
         "truncated");
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (not Ada.Directories.Exists (To_String (Stage)), "cleanup removes its own partial staging directory");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Unrelated, "keep")),
         "unrelated",
         "cleanup preserves unrelated data");
      Assert (Ada.Directories.Exists (Unowned), "cleanup refuses an unowned staging-shaped pathname");
      Assert (not Linked or else Hostkit.Fs.Is_Link (Link), "cleanup never follows or deletes a substituted symlink");
      Assert
        (not Record_Linked
         or else not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-unrelated")),
         "stage cleanup rejects and discards a multiply-linked record");
      if Record_Linked and then Ada.Directories.Exists (Record_Alias) then
         Ada.Directories.Delete_File (Record_Alias);
      end if;
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt"))
         and then not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-oversized"))
         and then not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-truncated"))
         and then not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-relative")),
         "malformed and allocation-sized stage records are discarded without trusting their contents");
      Assert (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-absent")),
              "a write-ahead reservation with no created pathname is discarded safely");
      Assert
        (not Files.Job_Helpers.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 1,
            Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
         and then Ada.Directories.Exists (Join (Transport, "stages")),
         "bounded cleanup cannot consume stage records while the creator is live");
      Files.Process_Jobs.Testing.Release_Owner (Transport_Job);
      if Hostkit.Host.Current = Hostkit.Host.Linux
        and then not Hostkit.Host.Is_Elevated
      then
         declare
            Data : constant String :=
              Join (Join (Join (Transport, "stages"), "stage-unreadable"), "data");
            Result : Files.File_System.Mutation_Result;
            Outcome : Files.Job_Cleanup.Cleanup_Outcome;
            use type Files.Job_Cleanup.Cleanup_Outcome;
         begin
            Add_Stage_Record
              ("stage-unreadable", Join (Root, ".files-work-missing"), "");
            Result := Files.File_System.Set_Permissions (Data, 0);
            Assert (Result.Success, "make a stage record temporarily unreadable");
            Outcome := Files.Job_Cleanup.Run
              (Transport, To_String (Transport_Identity),
               Attempt_Limit => 1, Discard_Unreadable_On_Last_Attempt => False);
            Assert
              (Outcome = Files.Job_Cleanup.Cleanup_Failed
               and then Ada.Directories.Exists
                 (Join (Join (Transport, "stages"), "stage-unreadable")),
               "one fallback pass keeps an unreadable stage record for later retry");
            Result := Files.File_System.Set_Permissions (Data, 8#600#);
            Assert (Result.Success, "restore stage record access for cleanup");
         end;
      end if;
      Before := Ada.Calendar.Clock;
      Assert
        (not Files.Job_Helpers.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 2,
            Initial_Retry_Delay => 0.001, Maximum_Retry_Delay => 0.001)
         and then Ada.Calendar.Clock - Before < Prompt_Limit
         and then not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt"))
         and then not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-truncated")),
         "bounded cleanup does not retry permanently malformed stage records");
      Files.Job_Context.Initialize ("");
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "foreground partial");
      Assert (Files.Job_Context.Discard_Stage (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Stage)),
              "foreground staging records its identity and cleans through the same guarded path");
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Stage)));
      if Ada.Directories.Exists ("/proc/thread-self/children") then
         Children_Before := To_Unbounded_String
           (Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children"));
      end if;
      declare
         Owner_Directory : Files.Types.UString;
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Join (To_String (Stage), ".files-owner"));
         Files_Suite.Support.Assert_Equal
           (String'Input (Ada.Streams.Stream_IO.Stream (File)),
            "files-stage-owner-1",
            "foreground stage publishes its owner marker atomically");
         Owner_Directory := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
         Ada.Streams.Stream_IO.Close (File);
         Ada.Directories.Rename (To_String (Stage), Saved);
         Ada.Directories.Create_Directory (To_String (Stage));
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Join (To_String (Stage), ".files-owner"));
         String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-owner-1");
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Owner_Directory));
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
         Ada.Streams.Stream_IO.Close (File);
         Assert (not Files.Job_Context.Discard_Stage (To_String (Stage))
                 and then Ada.Directories.Exists (To_String (Stage)),
                 "foreground cleanup refuses a replacement and schedules its owned stage for retry");
         Ada.Directories.Delete_File (Join (To_String (Stage), ".files-owner"));
         Ada.Directories.Delete_Directory (To_String (Stage));
         Ada.Directories.Rename (Saved, To_String (Stage));
         for Attempt in Files_Suite.Support.Polling loop
            exit when not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Owner_Directory));
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Stage))
                 and then not Ada.Directories.Exists (To_String (Owner_Directory)),
                 "idle foreground cleanup retries its durable record and removes its transport");
         if Ada.Directories.Exists ("/proc/thread-self/children") then
            for Attempt in Files_Suite.Support.Polling loop
               exit when Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 To_String (Children_Before);
            end loop;
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children"),
               To_String (Children_Before),
               "idle cleanup leaves no child process waiting for a later job API call");
         end if;
      end;
      --  Cleanup rightly refuses the unowned and linked records planted
      --  above, so it could never finish this transport. Remove them, then
      --  release the transport and wait for its cleanup child, so no
      --  cleanup outlives this test.
      declare
         Unowned_Record : constant Files.File_System.Mutation_Result :=
           Files.File_System.Delete_Permanently (Join (Join (Transport, "stages"), "stage-unowned"));
         Link_Record : constant Files.File_System.Mutation_Result :=
           Files.File_System.Delete_Permanently (Join (Join (Transport, "stages"), "stage-link"));
         pragma Unreferenced (Unowned_Record, Link_Record);
      begin
         null;
      end;
      Files.Process_Jobs.Reset (Transport_Job);
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (Transport);
      end loop;
   exception
      when others => Files.Job_Context.Initialize (""); raise;
   end Test_Stage_Record_Cleanup;

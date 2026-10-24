separate (Files_Suite.Operations)
   procedure Test_Stage_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is
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

      --  The cleanup entry point must fail closed even when an arbitrary
      --  directory's current identity is supplied by its caller.
      declare
         Victim : constant String := Join (Root, "cleanup-victim");
      begin
         Ada.Directories.Create_Directory (Victim);
         Write_Binary_File (Join (Victim, "keep"), "unrelated");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (Victim, Files.File_Identities.Token (Victim), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Ada.Directories.Exists (Victim)
            and then Project_Tools.Files.Read_Raw_File (Join (Victim, "keep")) = "unrelated",
            "cleanup refuses an arbitrary unmarked directory");
      end;

      declare
         Job        : Files.Process_Jobs.Session;
         Directory  : Files.Types.UString;
         Marker     : Files.Types.UString;
         Original   : Files.Types.UString;
         Recorded   : Files.Types.UString;
         Read_Error : Boolean;
         Rejected   : Boolean;
      begin
         Files.Process_Jobs.Reserve (Job);
         Directory := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Marker := To_Unbounded_String
           (Join (To_String (Directory), ".files-job-transport"));
         Original := To_Unbounded_String
           (Project_Tools.Files.Read_Raw_File (To_String (Marker)));
         Write_Binary_File (To_String (Marker), To_String (Original) & "trailing");
         Files.Job_Transports.Inspect_Marker
           (To_String (Directory), Recorded, Read_Error);
         Rejected := Length (Recorded) = 0 and then not Read_Error;
         Write_Binary_File (To_String (Marker), To_String (Original));
         Files.Process_Jobs.Reset (Job);
         Assert
           (Rejected,
            "transport ownership markers reject trailing data as invalid");
      end;

      declare
         Link_Path : constant String := Join (Root, "dangling-transport-link");
         Linked : constant Boolean := Hostkit.Fs.Create_Link
           (Join (Root, "missing-link-target"), Link_Path);
      begin
         if Linked then
            Assert
              (Hostkit.Fs.Is_Link (Link_Path)
               and then not Files.Job_Helpers.Run_Cleanup
                 (Link_Path, "untrusted", Attempt_Limit => 1,
                  Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
               and then Hostkit.Fs.Is_Link (Link_Path),
               "cleanup never reports a dangling symlink as a removed transport");
            Ada.Directories.Delete_File (Link_Path);
         end if;
      end;

      --  A marked transport is removed through the symlink-safe owned-tree
      --  path, so injected links cannot redirect recursive cleanup.
      declare
         Job       : Files.Process_Jobs.Session;
         Owned     : Files.Types.UString;
         Target    : constant String := Join (Root, "cleanup-link-target");
         Link_Path : Files.Types.UString;
         Linked    : Boolean;
      begin
         Ada.Directories.Create_Directory (Target);
         Write_Binary_File (Join (Target, "keep"), "target");
         Files.Process_Jobs.Reserve (Job);
         Owned := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Link_Path := To_Unbounded_String (Join (To_String (Owned), "injected-link"));
         Linked := Hostkit.Fs.Create_Link (Target, To_String (Link_Path));
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Ada.Directories.Exists (To_String (Owned)),
            "cleanup refuses a marked transport while its owner holds the lease");
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Assert
           (Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then not Ada.Directories.Exists (To_String (Owned)),
            "cleanup removes an abandoned marked transport under its own claim");
         Assert
           (not Linked or else Project_Tools.Files.Read_Raw_File (Join (Target, "keep")) = "target",
            "transport cleanup unlinks an injected symlink without following it");
      end;

      --  A marker copied from the genuine directory does not authorize a
      --  replacement subsequently installed at the same pathname.
      declare
         Job      : Files.Process_Jobs.Session;
         Original : Files.Types.UString;
         Saved    : Files.Types.UString;
         Expected : Files.Types.UString;
         Marker   : constant String := ".files-job-transport";

         procedure Restore is
         begin
            --  Windows refuses to remove the transport while its lease handle
            --  is open, so release the session before restoring the fixture.
            Files.Process_Jobs.Reset (Job);
            if Length (Original) > 0 and then Ada.Directories.Exists (To_String (Original)) then
               Project_Tools.Files.Delete_Tree (To_String (Original));
            end if;
            if Length (Saved) > 0 and then Ada.Directories.Exists (To_String (Saved)) then
               Ada.Directories.Rename (To_String (Saved), To_String (Original));
            end if;
         end Restore;
      begin
         Files.Process_Jobs.Reserve (Job);
         Original := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Saved := Original & "-saved";
         Expected := To_Unbounded_String (Files.File_Identities.Token (To_String (Original)));
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Ada.Directories.Rename (To_String (Original), To_String (Saved));
         Ada.Directories.Create_Directory (To_String (Original));
         Write_Binary_File
           (Join (To_String (Original), Marker),
            Project_Tools.Files.Read_Raw_File (Join (To_String (Saved), Marker)));
         Write_Binary_File (Join (To_String (Original), "keep"), "replacement");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Original), To_String (Expected), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Project_Tools.Files.Read_Raw_File
              (Join (To_String (Original), "keep")) = "replacement"
            and then Ada.Directories.Exists (To_String (Saved)),
            "cleanup refuses a replacement carrying the original transport marker");
         Restore;
      exception
         when others => Restore; raise;
      end;

      Files.Process_Jobs.Reserve (Transport_Job);
      Transport_Path := To_Unbounded_String (Files.Process_Jobs.Path (Transport_Job, ""));
      Transport_Identity := To_Unbounded_String (Files.File_Identities.Token (Transport));
      Ada.Directories.Create_Directory (Unrelated);
      Ada.Directories.Create_Directory (Unowned);
      Write_Binary_File (Join (Unrelated, "keep"), "unrelated");
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
      Assert (Project_Tools.Files.Read_Raw_File (Join (Unrelated, "keep")) = "unrelated",
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
         Assert (String'Input (Ada.Streams.Stream_IO.Stream (File)) = "files-stage-owner-1",
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
         for Attempt in 1 .. 5_000 loop
            exit when not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Owner_Directory));
            delay 0.001;
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Stage))
                 and then not Ada.Directories.Exists (To_String (Owner_Directory)),
                 "idle foreground cleanup retries its durable record and removes its transport");
         if Ada.Directories.Exists ("/proc/thread-self/children") then
            for Attempt in 1 .. 5_000 loop
               exit when Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 To_String (Children_Before);
               delay 0.001;
            end loop;
            Assert
              (Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 To_String (Children_Before),
               "idle cleanup leaves no child process waiting for a later job API call");
         end if;
      end;
   exception
      when others => Files.Job_Context.Initialize (""); raise;
   end Test_Stage_Ownership;

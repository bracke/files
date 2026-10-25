separate (Files_Suite.Operations)
   procedure Test_Crash_Transport_Scavenging (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Active_Path     : Files.Types.UString;
      Fallback_Path   : Files.Types.UString;
      Retry_Path      : Files.Types.UString;
      Delayed_Path    : Files.Types.UString;
      Missing_Lease_Path : Files.Types.UString;
      Abandoned_Path  : Files.Types.UString;
      Pre_Lease_Path  : Files.Types.UString;
      Before_Lease_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-11111111111111111111111111111111"));
      After_Lease_Path : Files.Types.UString;
      Young_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-22222222222222222222222222222222"));
      Payload_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-33333333333333333333333333333333"));
      Similar_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-not-a-current-transport"));
      Report_Path     : constant String := Join (Root, "abandoned-transport");
      Fallback_Report : constant String := Join (Root, "fallback-transport");
      Retry_Report    : constant String := Join (Root, "retry-transport");
      Retry_Control   : constant String := Join (Root, "failed-scavenge-coordinator");
      Delayed_Report  : constant String := Join (Root, "delayed-transport");
      Delayed_Control : constant String := Join (Root, "delayed-scavenge-coordinator");
      Missing_Lease_Report : constant String := Join (Root, "missing-lease-transport");
      Had_Scavenge_Failure : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_FAIL_SCAVENGER_ONCE");
      Old_Scavenge_Failure : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE", "");
      Had_Delayed_Failure : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
      Old_Delayed_Failure : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_UNTIL", "");
      Pre_Lease_Report : constant String := Join (Root, "pre-lease-transport");
      Scavenge_Control : constant String := Join (Root, "scavenge-coordinator");
      Shutdown_Control : constant String := Join (Root, "shutdown-coordinator");
      Had_Scavenge_Stall : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_SCAVENGER");
      Old_Scavenge_Stall : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER", "");

      procedure Create_Abandoned (Report : String; Path : out Files.Types.UString) is
         Arguments   : Hostkit.String_Vectors.Vector;
         Exit_Status : Integer;
         File        : Ada.Text_IO.File_Type;
      begin
         Arguments.Append (To_Unbounded_String ("--files-test-abandon-transport"));
         Arguments.Append (To_Unbounded_String (Report));
         Assert
           (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
            and then Exit_Status = 0,
            "the crash fixture creates a transport and exits without finalization");
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report);
         Path := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end Create_Abandoned;

      procedure Remove_Fixture (Path : Files.Types.UString) is
      begin
         if Length (Path) > 0 and then Ada.Directories.Exists (To_String (Path)) then
            Project_Tools.Files.Delete_Tree (To_String (Path));
         end if;
      end Remove_Fixture;

      procedure Restore is
      begin
         if Had_Scavenge_Stall then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Old_Scavenge_Stall);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_SCAVENGER");
         end if;
         if Had_Scavenge_Failure then
            Ada.Environment_Variables.Set
              ("FILES_TEST_FAIL_SCAVENGER_ONCE", Old_Scavenge_Failure);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_ONCE");
         end if;
         if Had_Delayed_Failure then
            Ada.Environment_Variables.Set
              ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Old_Delayed_Failure);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
         end if;
         if Ada.Directories.Exists (Scavenge_Control & ".started")
           and then not Ada.Directories.Exists (Scavenge_Control & ".release")
         then
            Write_Binary_File (Scavenge_Control & ".release", "release");
         end if;
         if Ada.Directories.Exists (Shutdown_Control & ".started")
           and then not Ada.Directories.Exists (Shutdown_Control & ".release")
         then
            Write_Binary_File (Shutdown_Control & ".release", "release");
         end if;
         Files.Process_Jobs.Reset (Active);
         Remove_Fixture (Fallback_Path);
         Remove_Fixture (Retry_Path);
         Remove_Fixture (Delayed_Path);
         Remove_Fixture (Missing_Lease_Path);
         Remove_Fixture (Abandoned_Path);
         Remove_Fixture (Pre_Lease_Path);
         Remove_Fixture (Before_Lease_Path);
         Remove_Fixture (After_Lease_Path);
         Remove_Fixture (Young_Path);
         Remove_Fixture (Payload_Path);
         Remove_Fixture (Similar_Path);
      end Restore;
   begin
      Reset_Root;
      declare
         Victim : constant String := Join (Root, "exclusive-stream-victim");
         Alias  : constant String := Join (Root, "exclusive-stream-alias");
         Output : Files.Exclusive_Streams.Output_Stream;
         Refused : Boolean := False;
         Linked  : Boolean := False;
      begin
         Write_Binary_File (Victim, "unchanged");
         Linked := Hostkit.Fs.Create_Hard_Link (Victim, Alias);
         if Linked then
            begin
               Files.Exclusive_Streams.Create (Output, Alias);
            exception
               when Ada.IO_Exceptions.Use_Error => Refused := True;
            end;
            Files.Exclusive_Streams.Close_Safely (Output);
            Assert
              (Refused
               and then Project_Tools.Files.Read_Raw_File (Victim) = "unchanged",
               "exclusive transport streams refuse hardlinks without truncating their target");
            Ada.Directories.Delete_File (Alias);
         end if;
         Ada.Directories.Delete_File (Victim);
      exception
         when others =>
            Files.Exclusive_Streams.Close_Safely (Output);
            if Linked and then Ada.Directories.Exists (Alias) then
               Ada.Directories.Delete_File (Alias);
            end if;
            if Ada.Directories.Exists (Victim) then
               Ada.Directories.Delete_File (Victim);
            end if;
            raise;
      end;
      Files.Process_Jobs.Reserve (Active);
      Active_Path := To_Unbounded_String (Files.Process_Jobs.Path (Active, ""));

      Create_Abandoned (Fallback_Report, Fallback_Path);
      declare
         Marker : constant String := Join (To_String (Fallback_Path), ".files-job-transport");
         Restricted : constant Boolean :=
           Hostkit.Host.Current = Hostkit.Host.Linux and then not Hostkit.Host.Is_Elevated;
         Result : Files.File_System.Mutation_Result;
         Before : Ada.Calendar.Time;
      begin
         if Restricted then
            Result := Files.File_System.Set_Permissions (Marker, 0);
            Assert (Result.Success, "make the fallback scan wait for marker access");
         end if;
         Before := Ada.Calendar.Clock;
         Files.Job_Scavenger.Scavenge (Join (Root, "missing-scavenge-coordinator"));
         Assert
           (Ada.Calendar.Clock - Before < Prompt_Limit,
            "startup returns promptly even when the coordinator cannot launch");
         if Restricted then
            Result := Files.File_System.Set_Permissions (Marker, 8#600#);
            Assert (Result.Success, "restore fallback marker access");
         end if;
         for Attempt in Files_Suite.Support.Polling loop
            exit when not Ada.Directories.Exists (To_String (Fallback_Path));
         end loop;
         Assert
           (not Ada.Directories.Exists (To_String (Fallback_Path))
            and then Ada.Directories.Exists (To_String (Active_Path)),
            "the monitor completes fallback recovery after startup continues");
      exception
         when others =>
            if Restricted then
               Result := Files.File_System.Set_Permissions (Marker, 8#600#);
            end if;
            raise;
      end;

      Create_Abandoned (Missing_Lease_Report, Missing_Lease_Path);
      declare
         Lease_Path : constant String := Join (To_String (Missing_Lease_Path), ".files-job-owner");
         Identity : constant String := Files.Job_Transports.Recorded_Identity
           (To_String (Missing_Lease_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Ada.Directories.Delete_File (Lease_Path);
         Assert
           (Files.Job_Transports.Claim_Abandoned
              (To_String (Missing_Lease_Path), Identity, Claim) =
                Files.Job_Transports.Claim_Unrecoverable
            and then Files.Job_Scavenger.Run (Wait_For_Grace => False)
            and then Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a missing lease is reported as terminal and its transport is preserved");
         Write_Binary_File (Lease_Path, "");
         Assert
           (Files.Job_Scavenger.Run (Wait_For_Grace => False)
            and then Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a replacement lease cannot make a missing original safe to reclaim");
      end;

      Create_Abandoned (Retry_Report, Retry_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_ONCE", Retry_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Retry_Control)
           and then not Ada.Directories.Exists (To_String (Retry_Path));
      end loop;
      Assert
        (Ada.Directories.Exists (Retry_Control)
         and then not Ada.Directories.Exists (To_String (Retry_Path)),
         "startup recovery observes a failed coordinator and relaunches one bounded retry");
      if Had_Scavenge_Failure then
         Ada.Environment_Variables.Set
           ("FILES_TEST_FAIL_SCAVENGER_ONCE", Old_Scavenge_Failure);
      else
         Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_ONCE");
      end if;

      Create_Abandoned (Delayed_Report, Delayed_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Delayed_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Delayed_Control & ".attempts")
           and then Ada.Strings.Fixed.Count
             (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
              "failed coordinator") >= 2;
      end loop;
      Assert
        (Ada.Directories.Exists (Delayed_Control & ".attempts")
         and then Ada.Strings.Fixed.Count
           (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
            "failed coordinator") >= 2
         and then Ada.Directories.Exists (To_String (Delayed_Path)),
         "temporary coordinator failure survives both immediate attempts");
      Write_Binary_File (Delayed_Control, "release");
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Delayed_Path));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Delayed_Path)),
         "the idle coordinator retries autonomously after access returns");
      if Had_Delayed_Failure then
         Ada.Environment_Variables.Set
           ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Old_Delayed_Failure);
      else
         Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
      end if;

      Create_Abandoned (Report_Path, Abandoned_Path);
      Create_Abandoned (Pre_Lease_Report, Pre_Lease_Path);
      Assert
        (Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "abnormal exits leave their transports for startup recovery");
      declare
         Marker_Header : constant String := "files-job-transport-4";
         Marker_Path   : constant String := Join (To_String (Pre_Lease_Path), ".files-job-transport");
         Marker_Data   : String := Project_Tools.Files.Read_Raw_File (Marker_Path);
         Header_At     : constant Natural := Ada.Strings.Fixed.Index (Marker_Data, Marker_Header);
         Marker_File   : Ada.Streams.Stream_IO.File_Type;
         Recorded_Header, Recorded_Directory, Recorded_Identity,
           Recorded_Owner : Files.Types.UString;
      begin
         Assert (Header_At > 0, "the fixture starts with the current transport marker");
         Ada.Streams.Stream_IO.Open
           (Marker_File, Ada.Streams.Stream_IO.In_File, Marker_Path);
         Recorded_Header := To_Unbounded_String
           (String'Input (Ada.Streams.Stream_IO.Stream (Marker_File)));
         Recorded_Directory := To_Unbounded_String
           (String'Input (Ada.Streams.Stream_IO.Stream (Marker_File)));
         Recorded_Identity := To_Unbounded_String
           (String'Input (Ada.Streams.Stream_IO.Stream (Marker_File)));
         Recorded_Owner := To_Unbounded_String
           (String'Input (Ada.Streams.Stream_IO.Stream (Marker_File)));
         Ada.Streams.Stream_IO.Close (Marker_File);
         Assert
           (To_String (Recorded_Header) = Marker_Header
            and then Length (Recorded_Owner) > 0,
            "the current fixture includes its lease identity");
         Marker_Data (Header_At + Marker_Header'Length - 1) := '3';
         Write_Binary_File (Marker_Path, Marker_Data);
         declare
            Identity : constant String := Files.Job_Transports.Recorded_Identity
              (To_String (Pre_Lease_Path));
            Claim : Files.Job_Transports.Lease;
         begin
            Assert
              (Identity /= ""
               and then Files.Job_Transports.Claim_Abandoned
                 (To_String (Pre_Lease_Path), Identity, Claim) =
                   Files.Job_Transports.Claim_Unrecoverable,
               "truncated-ID markers cannot claim a transport lease");
         end;
         Ada.Streams.Stream_IO.Create
           (Marker_File, Ada.Streams.Stream_IO.Out_File, Marker_Path);
         String'Output
           (Ada.Streams.Stream_IO.Stream (Marker_File),
            "files-job-transport-1");
         String'Output
           (Ada.Streams.Stream_IO.Stream (Marker_File),
            To_String (Recorded_Directory));
         String'Output
           (Ada.Streams.Stream_IO.Stream (Marker_File),
            To_String (Recorded_Identity));
         Ada.Streams.Stream_IO.Close (Marker_File);
      end;
      declare
         Identity : constant String := Files.Job_Transports.Recorded_Identity
           (To_String (Pre_Lease_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Assert
           (Identity /= ""
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Pre_Lease_Path), Identity, Claim) =
                Files.Job_Transports.Claim_Unrecoverable,
            "development-format markers never create an independent lease");
      end;
      declare
         Active_Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Active_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Assert
           (Active_Identity /= ""
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Active_Path), Active_Identity, Claim) =
                Files.Job_Transports.Claim_Busy
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Active_Path), "wrong identity", Claim) =
                Files.Job_Transports.Claim_Refused,
            "lease claims distinguish a live owner from invalid identity input");
      end;
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         declare
            Replacement_Job : Files.Process_Jobs.Session;
            Directory : Files.Types.UString;
            Identity : Files.Types.UString;
            Claim : Files.Job_Transports.Lease;
         begin
            Files.Process_Jobs.Reserve (Replacement_Job);
            Directory := To_Unbounded_String
              (Files.Process_Jobs.Path (Replacement_Job, ""));
            Identity := To_Unbounded_String
              (Files.Job_Transports.Recorded_Identity (To_String (Directory)));
            Ada.Directories.Delete_File
              (Join (To_String (Directory), ".files-job-owner"));
            Write_Binary_File
              (Join (To_String (Directory), ".files-job-owner"), "substitute lease");
            Assert
              (Files.Job_Transports.Claim_Abandoned
                 (To_String (Directory), To_String (Identity), Claim) =
                   Files.Job_Transports.Claim_Unrecoverable
               and then Ada.Directories.Exists (To_String (Directory)),
               "a new inode at the lease pathname cannot claim a live job");
            Files.Process_Jobs.Reset (Replacement_Job);
            Remove_Fixture (Directory);
         end;
         declare
            Directory : Files.Types.UString;
            Identity : Files.Types.UString;
            Owner : Files.Job_Transports.Lease;
         begin
            Files.Job_Transports.Create (Directory, Identity, Owner);
            Assert
              (Files.Job_Transports.Holds (Owner, To_String (Directory)),
               "a newly created transport holds its published lease");
            Ada.Directories.Delete_File
              (Join (To_String (Directory), ".files-job-owner"));
            Write_Binary_File
              (Join (To_String (Directory), ".files-job-owner"), "substitute lease");
            Assert
              (not Files.Job_Transports.Holds (Owner, To_String (Directory)),
               "a held lock does not authorize stage cleanup after lease replacement");
            Files.Job_Transports.Release (Owner);
            Remove_Fixture (Directory);
         end;
      end if;

      declare
         Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Abandoned_Path));
         First, Second : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Abandoned
               (To_String (Abandoned_Path), Identity, First) =
                 Files.Job_Transports.Claim_Acquired
             and then Files.Job_Transports.Holds
               (First, To_String (Abandoned_Path))
             and then Files.Job_Transports.Claim_Abandoned
               (To_String (Abandoned_Path), Identity, Second) =
                 Files.Job_Transports.Claim_Busy,
             "an abandoned transport has one acquired claim and reports later claims as busy");
      end;

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Scavenge_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Scavenge_Control & ".started");
      end loop;
      Assert
        (Ada.Directories.Exists (Scavenge_Control & ".started")
         and then Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup recovery uses one bounded coordinator before processing transports");
      declare
         First_Child : constant String :=
           Project_Tools.Files.Read_Raw_File (Scavenge_Control & ".started");
         Returned_Before_Release : Boolean := False;
         Same_Child : Boolean;

         task Second_Scan;
         task body Second_Scan is
         begin
            Files.Job_Scavenger.Scavenge;
            Write_Binary_File (Scavenge_Control & ".second-returned", "returned");
         end Second_Scan;
      begin
         for Attempt in Files_Suite.Support.Polling (Limit => 0.5) loop
            exit when Ada.Directories.Exists (Scavenge_Control & ".second-returned");
         end loop;
         Returned_Before_Release :=
           Ada.Directories.Exists (Scavenge_Control & ".second-returned");
         Same_Child := Project_Tools.Files.Read_Raw_File
           (Scavenge_Control & ".started") = First_Child;
         Write_Binary_File (Scavenge_Control & ".release", "release");
         Assert (Returned_Before_Release and then Same_Child,
                 "a repeated scan returns promptly without starting another coordinator");
      exception
         when others =>
            Write_Binary_File (Scavenge_Control & ".release", "release");
            raise;
      end;
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Abandoned_Path));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup scavenging removes abandoned jobs but preserves unprovable development transports");
      Assert
        (Ada.Directories.Exists (To_String (Active_Path)),
         "startup scavenging preserves a transport whose owner is still live");

      --  Exercise both sides of marker publication. A lease-free directory
      --  could belong to a paused creator, while a released lease with no
      --  marker proves its owner has stopped.
      Remove_Fixture (Before_Lease_Path);
      Remove_Fixture (Young_Path);
      Remove_Fixture (Payload_Path);
      Remove_Fixture (Similar_Path);
      Files.Private_Directories.Create (To_String (Before_Lease_Path));
      Write_Binary_File
        (Join (To_String (Before_Lease_Path), ".files-job-transport.tmp"), "partial marker");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Before_Lease_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
      declare
         Incomplete_Identity : Files.Types.UString;
         Incomplete_Owner    : Files.Job_Transports.Lease;
      begin
         Files.Job_Transports.Create
           (After_Lease_Path, Incomplete_Identity, Incomplete_Owner);
         Ada.Directories.Delete_File
           (Join (To_String (After_Lease_Path), ".files-job-transport"));
         Files.Job_Transports.Release (Incomplete_Owner);
      end;
      Files.Private_Directories.Create (To_String (Young_Path));
      Files.Private_Directories.Create (To_String (Payload_Path));
      Write_Binary_File (Join (To_String (Payload_Path), "keep"), "unrelated");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Payload_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
      Files.Private_Directories.Create (To_String (Similar_Path));
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Similar_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));

      declare
         Candidate_Identity : Files.Types.UString;
         Candidate_Owner    : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Young_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 60.0) = Files.Job_Transports.Claim_Unrecoverable,
            "a directory without this version's witness is not claimed by age alone");
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Before_Lease_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 0.0) = Files.Job_Transports.Claim_Unrecoverable,
            "age never authorizes a second lease for a potentially live creator");
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Payload_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 0.0) = Files.Job_Transports.Claim_Refused,
            "an unmarked directory with non-protocol payload is classified as refused");
      end;

      declare
         Complete : constant Boolean :=
           Files.Job_Scavenger.Run (Wait_For_Grace => False);
      begin
         Assert
           (Complete,
            "scavenging reports unproven exact-name transports without retrying forever");
      end;
      Assert
        (Ada.Directories.Exists (To_String (Before_Lease_Path)),
         "scavenging preserves a pre-lease creator even when its directory is old");
      Assert
        (Ada.Directories.Exists (To_String (After_Lease_Path)),
         "a markerless lease is preserved because its inode was not published");
      Assert
        (Ada.Directories.Exists (To_String (Young_Path)),
         "a missing witness preserves an unproven pre-lease directory");
      Assert
        (Ada.Directories.Exists (To_String (Payload_Path))
         and then Project_Tools.Files.Read_Raw_File
           (Join (To_String (Payload_Path), "keep")) = "unrelated",
         "unmarked recovery refuses directories containing non-protocol payloads");
      Assert
        (Ada.Directories.Exists (To_String (Similar_Path)),
         "unmarked recovery requires the complete generated transport name format");

      Write_Binary_File
        (Join (To_String (Young_Path), ".files-job-transport.tmp"), "partial marker");
      declare
         Complete : constant Boolean := Files.Job_Scavenger.Run;
      begin
         Assert
           (Complete,
            "scavenging does not retry permanently refused non-protocol transports");
      end;
      Assert
        (Ada.Directories.Exists (To_String (Young_Path)),
         "an expired grace period reports but never deletes a pre-lease directory");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Young_Path), GNAT.OS_Lib.GM_Time_Of (2099, 1, 2, 3, 4, 5));
      declare
         Candidate_Identity : Files.Types.UString;
         Candidate_Owner : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Young_Path), Candidate_Identity, Candidate_Owner) =
                Files.Job_Transports.Claim_Unrecoverable,
            "a future timestamp cannot keep a pre-lease directory retrying forever");
      end;

      Write_Binary_File
        (Join (To_String (Young_Path), ".files-job-transport"), "invalid marker");
      Assert
        (Files.Job_Scavenger.Run (Wait_For_Grace => False)
         and then Ada.Directories.Exists (To_String (Young_Path)),
         "an invalid published marker remains safely unclaimed without retry churn");
      declare
         Arguments : Hostkit.String_Vectors.Vector;
         Errors : constant String := Join (Root, "unsafe-transport-errors");
         Result : Hostkit.Process.Process_Outcome;
      begin
         Arguments.Append (To_Unbounded_String ("--files-scavenge"));
         Result := Hostkit.Process.Run_Captured
           (Hostkit.Fs.Own_Executable, Arguments,
            Stderr_Path => Errors, Timeout_Ms => 10_000);
         Assert
           (Result.Started and then not Result.Timed_Out
            and then Result.Exit_Status = 0
            and then Ada.Strings.Fixed.Index
              (Project_Tools.Files.Read_Raw_File (Errors), To_String (Young_Path)) > 0,
            "an invalid marker is preserved and reported with its pathname");
         Assert
           (Files.Job_Scavenger.Has_Unrecoverable,
            "the desktop can observe unsafe recovery reported by its child");

         declare
            Report_Directory : constant String :=
              Ada.Environment_Variables.Value ("FILES_RECOVERY_REPORT_DIR", "");
            Signal : constant String := Join (Report_Directory, "unsafe");
            Victim : constant String := Join (Root, "recovery-report-victim");
            Alias_Created : Boolean := False;
            Second_Errors : constant String :=
              Join (Root, "unsafe-transport-hardlink-errors");
         begin
            Ada.Directories.Delete_File (Signal);
            Write_Binary_File (Victim, "unchanged");
            Alias_Created := Hostkit.Fs.Create_Hard_Link (Victim, Signal);
            if Alias_Created then
               Result := Hostkit.Process.Run_Captured
                 (Hostkit.Fs.Own_Executable, Arguments,
                  Stderr_Path => Second_Errors, Timeout_Ms => 10_000);
               Assert
                 (Result.Started and then not Result.Timed_Out
                  and then Result.Exit_Status = 0,
                  "unsafe recovery still completes when its report marker is a hardlink");
               Files_Suite.Support.Assert_Equal
                 (Project_Tools.Files.Read_Raw_File (Victim),
                  "unchanged",
                  "unsafe recovery never appends through a planted report hardlink");
               Assert
                 (not Files.Job_Scavenger.Has_Unrecoverable,
                  "an untrusted hardlink is not accepted as a recovery report marker");
               Ada.Directories.Delete_File (Signal);
               Result := Hostkit.Process.Run_Captured
                 (Hostkit.Fs.Own_Executable, Arguments,
                  Stderr_Path => Second_Errors, Timeout_Ms => 10_000);
               Assert
                 (Result.Started and then not Result.Timed_Out
                  and then Result.Exit_Status = 0
                  and then Files.Job_Scavenger.Has_Unrecoverable,
                  "recovery creates a validated report marker after a refused hardlink");
            end if;
            Ada.Directories.Delete_File (Victim);
         exception
            when others =>
               if Alias_Created and then Ada.Directories.Exists (Signal) then
                  Ada.Directories.Delete_File (Signal);
               end if;
               if Ada.Directories.Exists (Victim) then
                  Ada.Directories.Delete_File (Victim);
               end if;
               raise;
         end;
      end;

      Assert
        (Files.Private_Directories.Try_Create (Root) =
           Files.Private_Directories.Collision,
         "private directory creation reports an existing pathname as a collision");
      declare
         Real_Directory : constant String := Join (Root, "private-real-directory");
         Linked_Path    : constant String := Join (Root, "private-linked-directory");
         Unexpected_Success : Boolean := False;
      begin
         Ada.Directories.Create_Directory (Real_Directory);
         if Files_Suite.Support.Create_Symlink (Real_Directory, Linked_Path) then
            begin
               Files.Private_Directories.Ensure (Linked_Path);
               Unexpected_Success := True;
            exception
               when Ada.Directories.Use_Error =>
                  null;
            end;
            Assert
              (not Unexpected_Success
               and then Hostkit.Fs.Is_Link (Linked_Path)
               and then Ada.Directories.Exists (Real_Directory),
               "private-directory hardening rejects a link without removing it or its target");
            declare
               Removed : constant Boolean := Hostkit.Fs.Delete_Link (Linked_Path);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         end if;
         Ada.Directories.Delete_Directory (Real_Directory);
      end;
      declare
         Unexpected_Success : Boolean := False;
      begin
         begin
            declare
               Result : constant Files.Private_Directories.Create_Result :=
                 Files.Private_Directories.Try_Create
                   (Join (Join (Root, "missing-parent"), "candidate"));
               pragma Unreferenced (Result);
            begin
               Unexpected_Success := True;
            end;
         exception
            when Ada.Directories.Use_Error => null;
         end;
         Assert
           (not Unexpected_Success,
            "private directory setup failures are not misreported as collisions");
      end;

      Remove_Fixture (Payload_Path);
      Remove_Fixture (Similar_Path);
      Assert
        (Files.Job_Scavenger.Run (Wait_For_Grace => False),
         "scavenging reports completion when only a live claimed transport remains");

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Shutdown_Control);
      for Attempt in Files_Suite.Support.Polling (Interval => 0.05) loop
         Files.Job_Scavenger.Scavenge;
         exit when Ada.Directories.Exists (Shutdown_Control & ".started");
      end loop;
      Assert (Ada.Directories.Exists (Shutdown_Control & ".started"),
              "shutdown fixture starts a coordinator that waits for release");
      declare
         File : Ada.Text_IO.File_Type;
         Child_Id : Integer;
         Reaped : Boolean;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Shutdown_Control & ".started");
         Child_Id := Integer'Value (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
         Files.Job_Scavenger.Shutdown (Reaped);
         Assert (Reaped, "shutdown reports a reaped coordinator");
         if Hostkit.Host.Current = Hostkit.Host.Linux
           and then Ada.Directories.Exists ("/proc/self")
         then
            Assert
              (not Ada.Directories.Exists
                 ("/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Child_Id), Ada.Strings.Both)),
               "shutdown reaps the coordinator before returning");
         end if;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end;
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Crash_Transport_Scavenging;

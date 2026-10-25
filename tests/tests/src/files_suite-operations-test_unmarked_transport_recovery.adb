separate (Files_Suite.Operations)
   procedure Test_Unmarked_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Before_Lease_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-11111111111111111111111111111111"));
      After_Lease_Path : Files.Types.UString;
      Young_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-22222222222222222222222222222222"));
      Payload_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-33333333333333333333333333333333"));
      Similar_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-not-a-current-transport"));

      procedure Restore is
      begin
         Files.Process_Jobs.Reset (Active);
         Remove_Transport_Fixture (Before_Lease_Path);
         Remove_Transport_Fixture (After_Lease_Path);
         Remove_Transport_Fixture (Young_Path);
         Remove_Transport_Fixture (Payload_Path);
         Remove_Transport_Fixture (Similar_Path);
      end Restore;
   begin
      Reset_Root;
      --  A live job keeps its transport present, as it is during startup recovery.
      Files.Process_Jobs.Reserve (Active);

      --  Exercise both sides of marker publication. A lease-free directory
      --  could belong to a paused creator, while a released lease with no
      --  marker proves its owner has stopped.
      Remove_Transport_Fixture (Before_Lease_Path);
      Remove_Transport_Fixture (Young_Path);
      Remove_Transport_Fixture (Payload_Path);
      Remove_Transport_Fixture (Similar_Path);
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
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Unmarked_Transport_Recovery;

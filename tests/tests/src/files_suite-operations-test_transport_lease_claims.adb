separate (Files_Suite.Operations)
   procedure Test_Transport_Lease_Claims (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Active_Path     : Files.Types.UString;
      Missing_Lease_Path : Files.Types.UString;
      Missing_Lease_Report : constant String := Join (Root, "missing-lease-transport");

      procedure Restore is
      begin
         Files.Process_Jobs.Reset (Active);
         Remove_Transport_Fixture (Missing_Lease_Path);
      end Restore;
   begin
      Reset_Root;
      Files.Process_Jobs.Reserve (Active);
      Active_Path := To_Unbounded_String (Files.Process_Jobs.Path (Active, ""));

      Create_Abandoned_Transport (Missing_Lease_Report, Missing_Lease_Path);
      declare
         Lease_Path : constant String := Join (To_String (Missing_Lease_Path), ".files-job-owner");
         Identity : constant String := Files.Job_Transports.Recorded_Identity
           (To_String (Missing_Lease_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Ada.Directories.Delete_File (Lease_Path);
         Assert
           (Files.Job_Transports.Claim_Abandoned (To_String (Missing_Lease_Path), Identity, Claim) =
              Files.Job_Transports.Claim_Unrecoverable,
            "a missing lease is reported as terminal and its transport is preserved: reported unrecoverable");
         Assert
           (Files.Job_Scavenger.Run (Wait_For_Grace => False),
            "a missing lease is reported as terminal and its transport is preserved: scavenger completes");
         Assert
           (Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a missing lease is reported as terminal and its transport is preserved: transport kept");
         Write_Binary_File (Lease_Path, "");
         Assert
           (Files.Job_Scavenger.Run (Wait_For_Grace => False)
            and then Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a replacement lease cannot make a missing original safe to reclaim");
      end;
      declare
         Active_Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Active_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Assert
           (Active_Identity /= "",
            "lease claims distinguish a live owner from invalid identity input: identity recorded");
         Assert
           (Files.Job_Transports.Claim_Abandoned (To_String (Active_Path), Active_Identity, Claim) =
              Files.Job_Transports.Claim_Busy,
            "lease claims distinguish a live owner from invalid identity input: live owner busy");
         Assert
           (Files.Job_Transports.Claim_Abandoned (To_String (Active_Path), "wrong identity", Claim) =
              Files.Job_Transports.Claim_Refused,
            "lease claims distinguish a live owner from invalid identity input: wrong identity refused");
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
            Remove_Transport_Fixture (Directory);
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
            Remove_Transport_Fixture (Directory);
         end;
      end if;
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Transport_Lease_Claims;

separate (Files_Suite.Operations)
   procedure Test_Startup_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Active_Path     : Files.Types.UString;
      Abandoned_Path  : Files.Types.UString;
      Pre_Lease_Path  : Files.Types.UString;
      Report_Path     : constant String := Join (Root, "abandoned-transport");
      Pre_Lease_Report : constant String := Join (Root, "pre-lease-transport");
      Scavenge_Control : constant String := Join (Root, "scavenge-coordinator");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      procedure Restore is
      begin
         if Ada.Directories.Exists (Scavenge_Control & ".started")
           and then not Ada.Directories.Exists (Scavenge_Control & ".release")
         then
            Write_Binary_File (Scavenge_Control & ".release", "release");
         end if;
         Files.Process_Jobs.Reset (Active);
         Remove_Transport_Fixture (Abandoned_Path);
         Remove_Transport_Fixture (Pre_Lease_Path);
      end Restore;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TEST_STALL_SCAVENGER");
      Reset_Root;
      Files.Process_Jobs.Reserve (Active);
      Active_Path := To_Unbounded_String (Files.Process_Jobs.Path (Active, ""));

      Create_Abandoned_Transport (Report_Path, Abandoned_Path);
      Create_Abandoned_Transport (Pre_Lease_Report, Pre_Lease_Path);
      Assert
        (Ada.Directories.Exists (To_String (Abandoned_Path)),
         "abnormal exits leave their transports for startup recovery: the abandoned transport");
      Assert
        (Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "abnormal exits leave their transports for startup recovery: the pre-lease transport");
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
         Files_Suite.Support.Assert_Equal
           (To_String (Recorded_Header), Marker_Header, "the current fixture includes its lease identity: header");
         Assert (Length (Recorded_Owner) > 0, "the current fixture includes its lease identity: owner recorded");
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
         Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Abandoned_Path));
         First, Second : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Abandoned (To_String (Abandoned_Path), Identity, First) =
              Files.Job_Transports.Claim_Acquired,
            "an abandoned transport has one acquired claim and reports later claims as busy: first claim acquired");
         Assert
           (Files.Job_Transports.Holds (First, To_String (Abandoned_Path)),
            "an abandoned transport has one acquired claim and reports later claims as busy: first claim holds");
         Assert
           (Files.Job_Transports.Claim_Abandoned (To_String (Abandoned_Path), Identity, Second) =
              Files.Job_Transports.Claim_Busy,
            "an abandoned transport has one acquired claim and reports later claims as busy: second claim busy");
      end;

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Scavenge_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Scavenge_Control & ".started");
      end loop;
      Assert
        (Ada.Directories.Exists (Scavenge_Control & ".started"),
         "startup recovery uses one bounded coordinator before processing transports: the coordinator started");
      Assert
        (Ada.Directories.Exists (To_String (Abandoned_Path)),
         "startup recovery uses one bounded coordinator before processing transports: "
         & "the abandoned transport is still there");
      Assert
        (Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup recovery uses one bounded coordinator before processing transports: "
         & "the pre-lease transport is still there");
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
         Assert (Returned_Before_Release,
                 "a repeated scan returns promptly without starting another coordinator: returned before release");
         Assert (Same_Child,
                 "a repeated scan returns promptly without starting another coordinator: same coordinator");
      exception
         when others =>
            Write_Binary_File (Scavenge_Control & ".release", "release");
            raise;
      end;
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Abandoned_Path));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Abandoned_Path)),
         "startup scavenging removes abandoned jobs but preserves unprovable development transports: "
         & "abandoned removed");
      Assert
        (Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup scavenging removes abandoned jobs but preserves unprovable development transports: "
         & "development transport kept");
      Assert
        (Ada.Directories.Exists (To_String (Active_Path)),
         "startup scavenging preserves a transport whose owner is still live");
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Startup_Transport_Recovery;

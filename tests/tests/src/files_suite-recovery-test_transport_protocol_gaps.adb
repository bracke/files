with Files.Jobs.Process.Testing;
with Files_Suite.Support.Timing;
with Files_Suite.Support.Disk;
separate (Files_Suite.Recovery)
   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Spawn.Spawn_Outcome;
      use type Hostkit.Spawn.Wait_State;
      Prefix : String renames Files.Protocol_Names.Transport_Prefix;
      Before : constant String := Join
        (Hostkit.Fs.Temp_Directory, Prefix & "77777777777777777777777777777777");
      After : constant String := Join
        (Hostkit.Fs.Temp_Directory, Prefix & "88888888888888888888888888888888");
      Held : constant String := Join
        (Hostkit.Fs.Temp_Directory, Prefix & "99999999999999999999999999999999");
      Control : constant String := Join (Root, "held-transport-creator");
      Job : Files.Jobs.Process.Session;
      Child : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Arguments : Hostkit.String_Vectors.Vector;
      Exit_Status : Integer;
      Status : Hostkit.Spawn.Status;
      Found : Boolean := False;
      Finished, Cancelled : Boolean;
      Rejected : Boolean := False;
      File : Ada.Text_IO.File_Type;

      procedure Remove (Path : String) is
         Simple : constant String := Ada.Directories.Simple_Name (Path);
         Witness : constant String := Join
           (Hostkit.Fs.Temp_Directory,
            ".files-job-creation-" & Simple (Simple'First + Prefix'Length .. Simple'Last));
      begin
         if Ada.Directories.Exists (Path) then
            Project_Tools.Files.Delete_Tree (Path);
         end if;
         if Ada.Directories.Exists (Witness) then
            Ada.Directories.Delete_File (Witness);
         end if;
      end Remove;

      procedure Signal_Release is
      begin
         if not Ada.Directories.Exists (Control & ".release") then
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Control & ".release");
            Ada.Text_IO.Close (File);
         end if;
      end Signal_Release;
   begin
      Reset_Root;
      Remove (Before);
      Remove (After);
      Remove (Held);
      Files.Jobs.Process.Reserve (Job);
      begin
         Files.Jobs.Process.Testing.Launch (Job, "--files-test-blocked");
         Files.Jobs.Process.Testing.Launch (Job, "--files-test-blocked");
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "a second launch cannot replace the tracked helper handle");
      Ada.Directories.Create_Directory (Files.Jobs.Process.Path (Job, "cancel"));
      Rejected := False;
      begin
         Files.Jobs.Process.Cancel (Job);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Files.Jobs.Process.Poll (Job, Finished, Cancelled);
      Assert (Rejected and then not Cancelled,
              "a failed cancellation file creation leaves the request retryable");
      Ada.Directories.Delete_Directory (Files.Jobs.Process.Path (Job, "cancel"));
      declare
         Victim : constant String := Join (Root, "cancel-marker-victim");
         Marker : constant String := Files.Jobs.Process.Path (Job, "cancel");
         Linked : Boolean := False;
      begin
         Write_Binary_File (Victim, "unchanged");
         Linked := Hostkit.Fs.Create_Hard_Link (Victim, Marker);
         if Linked then
            Rejected := False;
            begin
               Files.Jobs.Process.Cancel (Job);
            exception
               when Ada.Directories.Use_Error => Rejected := True;
            end;
            Files.Jobs.Process.Poll (Job, Finished, Cancelled);
            Assert (Rejected, "a planted hardlink is not accepted as a cancellation marker: rejected");
            Assert (not Cancelled, "a planted hardlink is not accepted as a cancellation marker: not cancelled");
            Assert
              (not Files.Jobs.Process.Cancellation_Requested (Files.Jobs.Process.Path (Job, "")),
               "a planted hardlink is not accepted as a cancellation marker: no cancellation requested");
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File (Victim),
               "unchanged",
               "cancellation never truncates through a planted marker hardlink");
            Ada.Directories.Delete_File (Marker);
         else
            Files_Suite.Support.Disk.Link_Not_Made ("Test_Transport_Protocol_Gaps", Files_Suite.Support.Disk.Hard_Link);
         end if;
         Ada.Directories.Delete_File (Victim);
      exception
         when others =>
            if Linked and then Ada.Directories.Exists (Marker) then
               Ada.Directories.Delete_File (Marker);
            end if;
            if Ada.Directories.Exists (Victim) then
               Ada.Directories.Delete_File (Victim);
            end if;
            raise;
      end;
      Files.Jobs.Process.Cancel (Job);
      Files.Jobs.Process.Poll (Job, Finished, Cancelled);
      Assert
        (Cancelled
         and then Files.Jobs.Process.Cancellation_Requested
           (Files.Jobs.Process.Path (Job, "")),
              "retry publishes the cancellation file before marking the session cancelled");
      Files.Jobs.Process.Reset (Job);

      Arguments.Append (To_Unbounded_String ("--files-test-crash-before-marker"));
      Arguments.Append (To_Unbounded_String (Before));
      Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
              and then Exit_Status = 0, "the pre-lease crash fixture exits cleanly");
      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-crash-after-lease"));
      Arguments.Append (To_Unbounded_String (After));
      Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
              and then Exit_Status = 0, "the pre-marker lease crash fixture exits cleanly");
      Assert (Ada.Directories.Exists (Before) and then Ada.Directories.Exists (After),
              "both interrupted creation phases leave recoverable directories");
      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         declare
            Unavailable_Identity : Files.Types.UString;
            Unavailable_Claim    : Files.Jobs.Transports.Lease;
         begin
            Assert
              (Files.Jobs.Transports.Claim_Incomplete
                 (Before, Unavailable_Identity, Unavailable_Claim,
                  Minimum_Age => 0.0) = Files.Jobs.Transports.Claim_Unrecoverable
               and then Ada.Directories.Exists (Before),
               "incomplete transport cleanup refuses an identity-free deletion");
         end;
         Files.File_Identities.Testing.Set_Unavailable (False);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Found := Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
      Assert (not Ada.Directories.Exists (Before) and then not Ada.Directories.Exists (After),
              "recovery removes both witnessed markerless crash states");

      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-hold-before-marker"));
      Arguments.Append (To_Unbounded_String (Held));
      Arguments.Append (To_Unbounded_String (Control));
      Assert (Hostkit.Spawn.Start
        (Hostkit.Fs.Own_Executable, Arguments, (others => <>), Child) = Hostkit.Spawn.Spawn_Ok,
        "start a creator paused before marker publication");
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (Control & ".started");
      end loop;
      Assert (Ada.Directories.Exists (Control & ".started"), "the creator holds its witness");
      declare
         Identity : Files.Types.UString;
         Claim : Files.Jobs.Transports.Lease;
      begin
         Assert (Files.Jobs.Transports.Claim_Incomplete
           (Held, Identity, Claim, Minimum_Age => 0.0) = Files.Jobs.Transports.Claim_Deferred,
           "recovery cannot claim a creator still between directory and marker publication");
      end;
      Signal_Release;
      for Attempt in Files_Suite.Support.Timing.Polling loop
         Found := Hostkit.Spawn.Wait (Child, Hostkit.Spawn.Wait_Poll, Status);
         exit when Found and then Status.State in Hostkit.Spawn.Wait_Exited
           | Hostkit.Spawn.Wait_Signalled | Hostkit.Spawn.Wait_Lost;
      end loop;
      Assert (Found, "the paused creator exits after release: found");
      Assert (Status.State = Hostkit.Spawn.Wait_Exited, "the paused creator exits after release: exited");
      Files_Suite.Support.Assert_Equal (Status.Exit_Code, 0, "the paused creator exits after release: exit code");
      Hostkit.Spawn.Release (Child);
      Files_Suite.Support.Discard (Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False));
      Assert (not Ada.Directories.Exists (Held), "recovery reclaims the creator after its lock closes");

      --  Simulate a failed witness unlink after a successful publication,
      --  followed by loss of the marker while the transport owner is live.
      --  A published witness must never be mistaken for pre-marker proof.
      declare
         Owner : Files.Jobs.Transports.Lease;
         Directory, Identity : Files.Types.UString;
         Claim : Files.Jobs.Transports.Lease;
         Incomplete_Identity : Files.Types.UString;
      begin
         Files.Jobs.Transports.Create (Directory, Identity, Owner);
         declare
            Path : constant String := To_String (Directory);
            Simple : constant String := Ada.Directories.Simple_Name (Path);
            Witness : constant String := Join
              (Hostkit.Fs.Temp_Directory,
               ".files-job-creation-" & Simple (Simple'First + Prefix'Length .. Simple'Last));
            Handle : Hostkit.Lease_Files.Lease;
            Published : constant Ada.Streams.Stream_Element_Array :=
              [Character'Pos ('p'), Character'Pos ('u'), Character'Pos ('b'),
               Character'Pos ('l'), Character'Pos ('i'), Character'Pos ('s'),
               Character'Pos ('h'), Character'Pos ('4')];
         begin
            Assert
              (Hostkit.Lease_Files.Create (Witness, Handle) =
                 Hostkit.Lease_Files.Opened,
               "a leftover published witness can be constructed");
            if Hostkit.Lease_Files.Is_Held (Handle) then
               declare
                  Recorded : constant Boolean :=
                    Hostkit.Lease_Files.Write_At (Handle, Published);
               begin
                  Hostkit.Lease_Files.Release (Handle);
                  Assert (Recorded, "the leftover witness records publication");
               end;
            end if;
            Ada.Directories.Delete_File (Join (Path, ".files-job-transport"));
            Assert
              (Files.Jobs.Transports.Claim_Incomplete
                 (Path, Incomplete_Identity, Claim, Minimum_Age => 0.0) =
                   Files.Jobs.Transports.Claim_Unrecoverable,
               "a published witness cannot authorize markerless cleanup");
            Found := Files.Jobs.Scavenger.Run
              (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
            Assert (Ada.Directories.Exists (Path),
                    "scavenging preserves a live transport with a published witness");
            Files.Jobs.Transports.Release (Owner);
            Remove (Path);
         exception
            when others =>
               Files.Jobs.Transports.Release (Owner);
               Remove (Path);
               raise;
         end;
      end;

      --  A creator inside Transports.Create has made its folder and is making
      --  its lease there: Hostkit makes a lease under a temporary name and
      --  renames it into place. That temporary is the creator's, not a
      --  payload: a scan meanwhile defers to the live creator rather than
      --  call the transport unsafe, and once the creator is gone (it died
      --  before the rename) the folder is cleaned up, temporary and all.
      declare
         Hex     : constant String := "44444444444444444444444444444444";
         Path    : constant String := Join (Hostkit.Fs.Temp_Directory, Prefix & Hex);
         Witness : constant String := Join (Hostkit.Fs.Temp_Directory, ".files-job-creation-" & Hex);
         Handle  : Hostkit.Lease_Files.Lease;
         Preparing : constant Ada.Streams.Stream_Element_Array :=
           [Character'Pos ('p'), Character'Pos ('r'), Character'Pos ('e'),
            Character'Pos ('p'), Character'Pos ('a'), Character'Pos ('r'),
            Character'Pos ('e'), Character'Pos ('4')];
         Identity : Files.Types.UString;
         Claim    : Files.Jobs.Transports.Lease;
      begin
         Remove (Path);
         Assert (Hostkit.Lease_Files.Create (Witness, Handle) = Hostkit.Lease_Files.Opened,
                 "a creator's witness is made");
         Assert (Hostkit.Lease_Files.Write_At (Handle, Preparing), "and records preparation");
         Files.IO.Private_Directories.Create (Path);
         Write_Binary_File (Join (Path, ".hostkit-lease-999999-1"), "");
         Assert
           (Files.Jobs.Transports.Claim_Incomplete (Path, Identity, Claim, Minimum_Age => 0.0)
              = Files.Jobs.Transports.Claim_Deferred,
            "a creator making its lease is deferred to, not refused");
         Found := Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
         Assert (Ada.Directories.Exists (Path) and then not Files.Jobs.Scavenger.Testing.Was_Reported (Path),
                 "a scan leaves the live creator's transport alone and unreported");
         Hostkit.Lease_Files.Release (Handle);
         Found := Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
         Assert (not Ada.Directories.Exists (Path),
                 "a creator that died making its lease leaves a folder recovery removes");
         Assert (not Files.Jobs.Scavenger.Testing.Was_Reported (Path), "never reported as unsafe");
         Remove (Path);
      exception
         when others =>
            Hostkit.Lease_Files.Release (Handle);
            Remove (Path);
            raise;
      end;

      --  Another user's job folder in a shared temporary folder (here: one
      --  not private to this user) is not this process's to judge: a scan
      --  leaves it alone and never reports it.
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Path : constant String :=
              Join (Hostkit.Fs.Temp_Directory, Prefix & "55555555555555555555555555555555");
         begin
            Remove (Path);
            Ada.Directories.Create_Directory (Path);
            Assert (Hostkit.Metadata.Set_Permissions (Path, 8#755#), "the fixture folder is opened to others");
            Write_Binary_File (Join (Path, "payload"), "theirs");
            Assert (not Hostkit.Metadata.Private_To_Current_User (Path), "the fixture folder is not private");
            Found := Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
            Assert (Ada.Directories.Exists (Join (Path, "payload"))
                    and then not Files.Jobs.Scavenger.Testing.Was_Reported (Path),
                    "a job folder not private to this user is left alone and unreported");
            Remove (Path);
         exception
            when others =>
               Remove (Path);
               raise;
         end;

         --  A link named like a job folder (planted, or another user's) is
         --  not followed: the folder it points at, private to this user and
         --  holding a payload, is left alone, and the link is not reported.
         declare
            Link   : constant String :=
              Join (Hostkit.Fs.Temp_Directory, Prefix & "66666666666666666666666666666666");
            Target : constant String := Join (Root, "linked-job-folder");
         begin
            if GNAT.OS_Lib.Is_Symbolic_Link (Link) then
               GNAT.OS_Lib.Delete_File (Link, Found);
            end if;
            Files.IO.Private_Directories.Create (Target);
            Write_Binary_File (Join (Target, "payload"), "kept");
            if Hostkit.Fs.Create_Link (Target, Link) then
               Found := Files.Jobs.Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
               Assert (Ada.Directories.Exists (Join (Target, "payload"))
                       and then GNAT.OS_Lib.Is_Symbolic_Link (Link)
                       and then not Files.Jobs.Scavenger.Testing.Was_Reported (Link),
                       "a link named like a job folder is neither followed, removed nor reported");
               GNAT.OS_Lib.Delete_File (Link, Found);
            else
               Files_Suite.Support.Disk.Link_Not_Made ("Test_Transport_Protocol_Gaps");
            end if;
            Project_Tools.Files.Delete_Tree (Target);
         exception
            when others =>
               if GNAT.OS_Lib.Is_Symbolic_Link (Link) then
                  GNAT.OS_Lib.Delete_File (Link, Found);
               end if;
               raise;
         end;
      end if;

      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Arguments.Clear;
         Arguments.Append (To_Unbounded_String ("--files-test-no-btime-transport"));
         Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
                 and then Exit_Status = 0,
                 "transport creation and staged copies fail closed without Linux birth time");
      end if;
      Remove (Before);
      Remove (After);
      Remove (Held);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Files.Jobs.Process.Reset (Job);
         Signal_Release;
         raise;
   end Test_Transport_Protocol_Gaps;

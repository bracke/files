with Files_Suite.Support.Processes;
with Files.Jobs.Scavenger.Testing;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   procedure Test_Scavenger_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Jobs.Process.Session;
      Shutdown_Control : constant String := Join (Root, "shutdown-coordinator");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;

      procedure Restore is
      begin
         if Ada.Directories.Exists (Shutdown_Control & ".started")
           and then not Ada.Directories.Exists (Shutdown_Control & ".release")
         then
            Write_Binary_File (Shutdown_Control & ".release", "release");
         end if;
         Files.Jobs.Process.Reset (Active);
      end Restore;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TEST_STALL_SCAVENGER");
      --  A scan or retry left by an earlier test would reclaim this test's
      --  fixtures before its own coordinator could.
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Files.Jobs.Scavenger.Testing.Idle;
      end loop;
      Assert
        (Files.Jobs.Scavenger.Testing.Idle,
         "no earlier recovery scan is still running: " & Files.Jobs.Scavenger.Testing.Busy_Reason);
      Reset_Root;
      --  A live job keeps its transport present, as it is during startup recovery.
      Files.Jobs.Process.Reserve (Active);

      Assert
        (Files.Jobs.Scavenger.Run (Wait_For_Grace => False),
         "scavenging reports completion when only a live claimed transport remains");

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Shutdown_Control);
      for Attempt in Files_Suite.Support.Timing.Polling (Interval => 0.05) loop
         Files.Jobs.Scavenger.Scavenge;
         exit when Ada.Directories.Exists (Shutdown_Control & ".started");
      end loop;
      Assert (Ada.Directories.Exists (Shutdown_Control & ".started"),
              "shutdown fixture starts a coordinator that waits for release");
      declare
         File : Ada.Text_IO.File_Type;
         Child_Id : Integer;
         Child_Started : Unbounded_String;
         Reaped : Boolean;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Shutdown_Control & ".started");
         Child_Id := Integer'Value (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
         --  The coordinator waits for release, so it is there to be told
         --  from a later process its id may be given to once reaped.
         Child_Started := To_Unbounded_String (Files_Suite.Support.Processes.Start_Time (Child_Id));
         Files.Jobs.Scavenger.Shutdown (Reaped);
         Assert (Reaped, "shutdown reports a reaped coordinator");
         if Hostkit.Host.Current = Hostkit.Host.Linux
           and then Ada.Directories.Exists ("/proc/self")
         then
            Assert (Length (Child_Started) > 0, "the coordinator's start time was read from /proc");
            Assert
              (Files_Suite.Support.Processes.Start_Time (Child_Id) /= To_String (Child_Started),
               "shutdown reaps the coordinator before returning");
         else
            Files_Suite.Support.Skip
              ("Test_Scavenger_Shutdown", "the reaped-coordinator half needs Linux and its /proc");
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
   end Test_Scavenger_Shutdown;

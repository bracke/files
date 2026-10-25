separate (Files_Suite.Operations)
   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_FAIL_CLEANUP_WORKER";
      Marker    : constant String := Join (Root, "cleanup-worker-failures");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;
      --  Longer than the parent's 2 s delay before a cleanup relaunch, with
      --  room for the spawn.
      Quiet_Seconds : constant Duration := 3.0;

      function Failure_Count return Natural is
         Count : Natural := 0;
      begin
         if not Ada.Directories.Exists (Marker) then
            return 0;
         end if;
         declare
            Content : constant String := Project_Tools.Files.Read_Raw_File (Marker);
         begin
            for Character of Content loop
               if Character = Ada.Characters.Latin_1.LF then
                  Count := Count + 1;
               end if;
            end loop;
         end;
         return Count;
      end Failure_Count;

      procedure Clean_Up is
      begin
         if Length (Transport) > 0 then
            if Hostkit.Fs.Is_Link (To_String (Transport)) then
               Ada.Directories.Delete_File (To_String (Transport));
            elsif Ada.Directories.Exists (To_String (Transport)) then
               Project_Tools.Files.Delete_Tree (To_String (Transport));
            end if;
         end if;
         if Ada.Directories.Exists (Marker) then
            Ada.Directories.Delete_File (Marker);
         end if;
      end Clean_Up;
   begin
      Reset_Root;
      declare
         --  Restores the variable before the cleanup, on failure too.
         Failing : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Failing, Variable);
         Ada.Environment_Variables.Set (Variable, Marker);
         Files.Process_Jobs.Reserve (Job);
         Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Ada.Directories.Create_Directory (Join (To_String (Transport), "stages"));
         Files.Process_Jobs.Reset (Job);

         for Attempt in Files_Suite.Support.Polling loop
            exit when Failure_Count >= 1;
         end loop;
         Assert (Failure_Count >= 1, "the parent launches a cleanup worker");
         declare
            First_Failure : constant Instant := Now;
            Relaunch      : Duration;
         begin
            for Attempt in Files_Suite.Support.Polling loop
               exit when Failure_Count >= 2;
            end loop;
            Files_Suite.Support.Assert_Equal (Failure_Count, 2, "the parent makes its one bounded cleanup relaunch");
            Relaunch := Seconds (Elapsed (First_Failure));

            --  Nothing in the parent reports that it gave up (Process_Jobs keeps
            --  its failure count and orphan queue in its body), so the proof is
            --  that no third worker appears within a window a relaunch would have
            --  used. A relaunch waits out the parent's 2 s retry delay, then a
            --  spawn: wait the larger of the fixed floor and half again the
            --  relaunch this runner just took (so a slow runner waits longer by
            --  itself), and stop early if a third worker does report.
            for Attempt in Files_Suite.Support.Polling
              (Limit    => Duration'Max (Quiet_Seconds, Relaunch * 3 / 2),
               Interval => 0.01)
            loop
               exit when Failure_Count > 2;
            end loop;
         end;
         Files_Suite.Support.Assert_Equal
           (Failure_Count,
            2,
            "persistent cleanup refusal stops worker churn and leaves durable recovery state: no third worker");
         Assert
           (Ada.Directories.Exists (To_String (Transport)),
            "persistent cleanup refusal stops worker churn and leaves durable recovery state: transport kept");
      end;
      Clean_Up;

      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Reset_Root;
         declare
            --  Restores the variable before the cleanup, on failure too.
            Failing : Files_Suite.Support.Environment_Guard;
         begin
            Files_Suite.Support.Save (Failing, Variable);
            Ada.Environment_Variables.Set (Variable, Marker);
            Files.Process_Jobs.Reserve (Job);
            Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
            Files.Process_Jobs.Testing.Release_Owner (Job);
            Project_Tools.Files.Delete_Tree (To_String (Transport));
            Assert
              (Hostkit.Fs.Create_Link (Join (Root, "missing-transport-target"),
                                      To_String (Transport)),
               "replace a released transport with a dangling link");
            Files.Process_Jobs.Reset (Job);
            for Attempt in Files_Suite.Support.Polling loop
               exit when Failure_Count >= 1;
            end loop;
            Assert
              (Failure_Count >= 1,
               "idle cleanup retains a dangling transport link for guarded retry: a cleanup worker ran");
            Assert
              (Hostkit.Fs.Is_Link (To_String (Transport)),
               "idle cleanup retains a dangling transport link for guarded retry: the link is kept");
         end;
         Clean_Up;
      end if;
   exception
      when others =>
         Clean_Up;
         raise;
   end Test_Cleanup_Retry_Bound;

with Files.Jobs.Scavenger.Testing;
with Files.File_System.Permissions.Testing;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   procedure Test_Scavenger_Coordinator_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : aliased Files.Jobs.Process.Session;
      Active_Path     : Files.Types.UString;
      Fallback_Path   : Files.Types.UString;
      Retry_Path      : Files.Types.UString;
      Delayed_Path    : Files.Types.UString;
      Fallback_Report : constant String := Join (Root, "fallback-transport");
      Retry_Report    : constant String := Join (Root, "retry-transport");
      Retry_Control   : constant String := Join (Root, "failed-scavenge-coordinator");
      Delayed_Report  : constant String := Join (Root, "delayed-transport");
      Delayed_Control : constant String := Join (Root, "delayed-scavenge-coordinator");
      --  Each restores its variable, on failure too; Finalize puts it back early once its phase is done.
      Once_Environment  : Files_Suite.Support.Guards.Environment_Guard;
      Until_Environment : Files_Suite.Support.Guards.Environment_Guard;
      --  Resets Active and removes the fixtures, on failure too, before the variables come back.
      Jobs : Files_Suite.Support.Guards.Process_Jobs_Guard (Active'Access);
   begin
      Files_Suite.Support.Guards.Save (Once_Environment, "FILES_TEST_FAIL_SCAVENGER_ONCE");
      Files_Suite.Support.Guards.Save (Until_Environment, "FILES_TEST_FAIL_SCAVENGER_UNTIL");
      Reset_Root;
      Files.Jobs.Process.Reserve (Active);
      Active_Path := To_Unbounded_String (Files.Jobs.Process.Path (Active, ""));

      Create_Abandoned_Transport (Fallback_Report, Fallback_Path);
      Files_Suite.Support.Guards.Track (Jobs, Fallback_Path);
      declare
         Marker : constant String := Join (To_String (Fallback_Path), ".files-job-transport");
         Restricted : constant Boolean :=
           Hostkit.Host.Current = Hostkit.Host.Linux and then not Hostkit.Host.Is_Elevated;
         Result : Files.File_System.Mutation_Result;
         Before : Instant;
      begin
         if Restricted then
            Result := Files.File_System.Permissions.Testing.Set_Permissions (Marker, 0);
            Assert (Result.Success, "make the fallback scan wait for marker access");
         end if;
         Before := Now;
         Files.Jobs.Scavenger.Scavenge (Join (Root, "missing-scavenge-coordinator"));
         Assert_Within (Before, Prompt_Limit, "startup returns promptly even when the coordinator cannot launch");
         if Restricted then
            Result := Files.File_System.Permissions.Testing.Set_Permissions (Marker, 8#600#);
            Assert (Result.Success, "restore fallback marker access");
         end if;
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when not Ada.Directories.Exists (To_String (Fallback_Path));
         end loop;
         Assert
           (not Ada.Directories.Exists (To_String (Fallback_Path)),
            "the monitor completes fallback recovery after startup continues: fallback transport removed");
         Assert
           (Ada.Directories.Exists (To_String (Active_Path)),
            "the monitor completes fallback recovery after startup continues: live transport kept");
      exception
         when others =>
            if Restricted then
               Result := Files.File_System.Permissions.Testing.Set_Permissions (Marker, 8#600#);
            end if;
            raise;
      end;

      Create_Abandoned_Transport (Retry_Report, Retry_Path);
      Files_Suite.Support.Guards.Track (Jobs, Retry_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_ONCE", Retry_Control);
      Files.Jobs.Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (Retry_Control)
           and then not Ada.Directories.Exists (To_String (Retry_Path));
      end loop;
      Assert
        (Ada.Directories.Exists (Retry_Control),
         "startup recovery observes a failed coordinator and relaunches one bounded retry: the failure was observed");
      Assert
        (not Ada.Directories.Exists (To_String (Retry_Path)),
         "startup recovery observes a failed coordinator and relaunches one bounded retry: the retry recovered");
      Files_Suite.Support.Guards.Finalize (Once_Environment);

      Create_Abandoned_Transport (Delayed_Report, Delayed_Path);
      Files_Suite.Support.Guards.Track (Jobs, Delayed_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Delayed_Control);
      Files.Jobs.Scavenger.Scavenge;
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (Delayed_Control & ".attempts")
           and then Ada.Strings.Fixed.Count
             (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
              "failed coordinator") >= 2;
      end loop;
      Assert
        (Ada.Directories.Exists (Delayed_Control & ".attempts"),
         "temporary coordinator failure survives both immediate attempts: attempts recorded");
      Assert
        (Ada.Strings.Fixed.Count
           (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
            "failed coordinator") >= 2,
         "temporary coordinator failure survives both immediate attempts: both attempts failed");
      Assert
        (Ada.Directories.Exists (To_String (Delayed_Path)),
         "temporary coordinator failure survives both immediate attempts: transport kept");
      Write_Binary_File (Delayed_Control, "release");
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when not Ada.Directories.Exists (To_String (Delayed_Path));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Delayed_Path)),
         "the idle coordinator retries autonomously after access returns");
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Files.Jobs.Scavenger.Testing.Idle;
      end loop;
      Assert
        (Files.Jobs.Scavenger.Testing.Idle,
         "recovery is quiet again once its retries succeed: " & Files.Jobs.Scavenger.Testing.Busy_Reason);
      Files_Suite.Support.Guards.Finalize (Until_Environment);
      Files_Suite.Support.Guards.Release (Jobs);
   end Test_Scavenger_Coordinator_Failures;

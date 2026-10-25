separate (Files_Suite.Operations)
   procedure Test_Unsafe_Recovery_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Young_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-22222222222222222222222222222222"));

      procedure Restore is
      begin
         Files.Process_Jobs.Reset (Active);
         Remove_Transport_Fixture (Young_Path);
      end Restore;
   begin
      --  A scan or retry left by an earlier test would reclaim this test's
      --  fixtures before its own coordinator could.
      for Attempt in Files_Suite.Support.Polling loop
         exit when Files.Job_Scavenger.Idle;
      end loop;
      Assert (Files.Job_Scavenger.Idle, "no earlier recovery scan is still running");
      Reset_Root;
      --  A live job keeps its transport present, as it is during startup recovery.
      Files.Process_Jobs.Reserve (Active);
      --  Startup recovery has run by now in a session, and its first run
      --  creates the report directory a child reports unsafe recovery into.
      --  Run it once on an abandoned transport and wait for the reclaim.
      declare
         Abandoned : Files.Types.UString;
      begin
         Create_Abandoned_Transport (Join (Root, "report-setup-transport"), Abandoned);
         Files.Job_Scavenger.Scavenge;
         for Attempt in Files_Suite.Support.Polling loop
            exit when not Ada.Directories.Exists (To_String (Abandoned));
         end loop;
      end;
      --  Rebuild the pre-lease directory Test_Unmarked_Transport_Recovery
      --  leaves this far: a partial marker and a future timestamp.
      Remove_Transport_Fixture (Young_Path);
      Files.Private_Directories.Create (To_String (Young_Path));
      Write_Binary_File
        (Join (To_String (Young_Path), ".files-job-transport.tmp"), "partial marker");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Young_Path), GNAT.OS_Lib.GM_Time_Of (2099, 1, 2, 3, 4, 5));

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
         Assert (Result.Started, "an invalid marker is preserved and reported with its pathname: started");
         Assert (not Result.Timed_Out, "an invalid marker is preserved and reported with its pathname: not timed out");
         Files_Suite.Support.Assert_Equal
           (Result.Exit_Status,
            0,
            "an invalid marker is preserved and reported with its pathname: exit status");
         Assert
           (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Errors), To_String (Young_Path)) > 0,
            "an invalid marker is preserved and reported with its pathname: pathname reported");
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
               Assert (Result.Started, "unsafe recovery still completes when its report marker is a hardlink: started");
               Assert
                 (not Result.Timed_Out,
                  "unsafe recovery still completes when its report marker is a hardlink: not timed out");
               Files_Suite.Support.Assert_Equal
                 (Result.Exit_Status,
                  0,
                  "unsafe recovery still completes when its report marker is a hardlink: exit status");
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
               Assert (Result.Started, "recovery creates a validated report marker after a refused hardlink: started");
               Assert
                 (not Result.Timed_Out,
                  "recovery creates a validated report marker after a refused hardlink: not timed out");
               Files_Suite.Support.Assert_Equal
                 (Result.Exit_Status,
                  0,
                  "recovery creates a validated report marker after a refused hardlink: exit status");
               Assert
                 (Files.Job_Scavenger.Has_Unrecoverable,
                  "recovery creates a validated report marker after a refused hardlink: report marker created");
            else
               Files_Suite.Support.Link_Not_Made ("Test_Unsafe_Recovery_Report", Files_Suite.Support.Hard_Link);
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
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Unsafe_Recovery_Report;

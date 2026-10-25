separate (Files_Suite.Operations)
   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;
      Before    : Instant;

      function Item (Name : String) return String is
        (Join (To_String (Transport), Name));

      procedure Touch (Path : String) is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
      end Touch;

      procedure Release_Transport is
      begin
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Touch (Item ("release-cleanup-worker"));
            for Attempt in Files_Suite.Support.Polling loop
               exit when not Ada.Directories.Exists (To_String (Transport));
            end loop;
         end if;
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
      end Release_Transport;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TEST_STALL_CLEANUP_WORKER");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_CLEANUP_WORKER", "1");
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Item ("stages"));

      Before := Now;
      Files.Process_Jobs.Reset (Job);
      Assert_Within (Before, Prompt_Limit, "session disposal returns without waiting for the cleanup worker");
      --  The worker is held until the release file appears, so a disposal that
      --  had waited for it -- or cleaned up in its place -- would find the
      --  transport gone.
      Assert (Ada.Directories.Exists (To_String (Transport)),
              "disposal hands the transport to the cleanup worker instead of removing it itself");
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Item ("cleanup-worker-started"));
      end loop;
      Assert
        (Ada.Directories.Exists (Item ("cleanup-worker-started"))
         and then Ada.Directories.Exists (To_String (Transport)),
         "the stalled worker remains owned after disposal returns");

      Touch (Item ("release-cleanup-worker"));
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Transport));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Transport)),
         "cleanup completes without a later process-jobs API call");

      --  The second half stops the worker with SIGSTOP and watches its state
      --  through /proc, which only Linux has.
      if Hostkit.Host.Current = Hostkit.Host.Linux and then Ada.Directories.Exists ("/proc/self/stat") then
         declare
            Launcher_Id : Integer;
            Resumed : Boolean;
            Id_File : Ada.Text_IO.File_Type;
         begin
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_CLEANUP_WORKER", "stop");
            Files.Process_Jobs.Reserve (Job);
            Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
            Ada.Directories.Create_Directory (Item ("stages"));
            Files.Process_Jobs.Reset (Job);
            for Attempt in Files_Suite.Support.Polling loop
               exit when Ada.Directories.Exists (Item ("cleanup-worker-started"));
            end loop;
            Assert
              (Ada.Directories.Exists (Item ("cleanup-worker-started")),
               "the stopped cleanup worker publishes its process id");
            Ada.Text_IO.Open
              (Id_File, Ada.Text_IO.In_File, Item ("cleanup-worker-started"));
            Launcher_Id := Integer'Value (Ada.Text_IO.Get_Line (Id_File));
            Ada.Text_IO.Close (Id_File);
            --  The worker stops itself straight after publishing; wait until
            --  the kernel reports it stopped, so the reaper is seen to handle a
            --  stopped worker rather than racing one that is still running.
            for Attempt in Files_Suite.Support.Polling loop
               exit when Files_Suite.Support.Process_State (Launcher_Id) = 'T';
            end loop;
            Assert_Equal
              (Files_Suite.Support.Process_State (Launcher_Id) & "", "T",
               "the cleanup worker is stopped before it is continued (state in /proc/<pid>/stat)");
            Resumed := Hostkit.Signals.Send_To_Process
              (Launcher_Id, Hostkit.Signals.Signal_Continue);
            Assert (Resumed, "the stopped cleanup worker remains resumable");
            --  Reaped, not merely finished: an exited child nobody waited for
            --  stays in /proc as a zombie until it is collected.
            for Attempt in Files_Suite.Support.Polling loop
               exit when not Ada.Directories.Exists (To_String (Transport))
                 and then Files_Suite.Support.Process_State (Launcher_Id) = ' ';
            end loop;
            Assert
              (not Ada.Directories.Exists (To_String (Transport)),
               "stopped and continued cleanup workers finish the cleanup");
            Assert_Equal
              (Files_Suite.Support.Process_State (Launcher_Id) & "", " ",
               "stopped and continued cleanup workers stay owned until reaped (no process left in /proc)");
         end;
      else
         Files_Suite.Support.Skip
           ("Test_Autonomous_Cleanup_Worker", "the stopped-worker half needs Linux and its /proc");
      end if;
      Release_Transport;
   exception
      when others =>
         Release_Transport;
         raise;
   end Test_Autonomous_Cleanup_Worker;

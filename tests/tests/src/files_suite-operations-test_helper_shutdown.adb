separate (Files_Suite.Operations)
   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job       : Files.Process_Jobs.Session;
      Started   : Files.Types.UString;
      Before    : Instant;
      Finished  : Boolean;
      Cancelled : Boolean;
   begin
      --  The late-owner helper writes its report into Root.
      Reset_Root;
      declare
         Arguments : Hostkit.String_Vectors.Vector;
         Exit_Status : Integer;
      begin
         Arguments.Append (To_Unbounded_String ("--files-test-drain-reaper"));
         Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status),
                 "the drain-reaper helper runs");
         Files_Suite.Support.Assert_Equal
           (Exit_Status,
            0,
            "shutdown drains queued orphan work before reporting completion");
      end;
      declare
         Arguments : Hostkit.String_Vectors.Vector;
         Exit_Status : Integer;
         Report : constant String := Join (Root, "late-shutdown-owner");
         File : Ada.Text_IO.File_Type;
         Directory : Files.Types.UString;
      begin
         Arguments.Append (To_Unbounded_String ("--files-test-late-shutdown-owner"));
         Arguments.Append (To_Unbounded_String (Report));
         Assert
           (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
            and then Exit_Status = 0,
            "shutdown waits for live session owners before sealing the queue");
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report);
         Directory := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
         Assert
           (not Ada.Directories.Exists (To_String (Directory)),
            "the reaper drains a session released after shutdown was requested");
      end;
      Files.Process_Jobs.Reserve (Job);
      Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
      Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)), "the shutdown fixture enters blocked helper work");
      declare
         Keeper : Files.Process_Jobs.Session := Job;
      begin
         Files.Process_Jobs.Reset (Job);
         Files.Process_Jobs.Poll (Keeper, Finished, Cancelled);
         Assert (not Finished, "a copied session keeps its helper alive");
         Before := Now;
         Files.Process_Jobs.Reset (Keeper);
         Assert_Within (Before, Prompt_Limit, "closing the last session never waits for blocked helper work");
      end;
      for Attempt in Files_Suite.Support.Polling loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when not Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Started)),
              "terminated helpers are reaped and their transport is cleaned");
      Files.Process_Jobs.Reserve (Job);
      Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
      Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)), "the cancellation fixture enters blocked helper work");
      Before := Now;
      Files.Process_Jobs.Cancel (Job);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when Finished;
      end loop;
      Assert (Finished and then Cancelled, "cancellation detaches a stalled helper");
      Assert_Within (Before, Detach_Limit, "cancellation detaches stalled helpers after its bounded grace period");
      Files.Process_Jobs.Reset (Job);

      Files.Process_Jobs.Reserve (Job);
      Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
      Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)),
              "the failed-stop fixture enters blocked helper work");
      Files.Process_Jobs.Testing.Simulate_Failed_Stop (Job);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when Finished;
      end loop;
      Assert
        (Finished and then not Cancelled,
         "polling retries a failed initial stop request and reaps the helper");
      Files.Process_Jobs.Reset (Job);
   end Test_Helper_Shutdown;

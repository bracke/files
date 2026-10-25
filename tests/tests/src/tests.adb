with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;

with AUnit;
with AUnit.Reporter.Text;
with AUnit.Options;
with AUnit.Run;
with Files_Suite.Support;
with All_Suites;
with Files.Job_Helpers;
with Files.Job_Context;
with Files.Job_Scavenger;
with Files.Job_Transports;
with Files.Job_Cleanup;
with Files.File_Identities;
with Files.File_Identities.Testing;
with Files.Private_Directories;
with Files.File_System;
with Files.Process_Jobs;
with Files.Operation_Jobs;
with Files.Operation_Jobs.Testing;
with Files.Refresh_Jobs.Testing;
with Files.Transfer_Jobs;
with Files.Transfer_Jobs.Testing;
with Files.Paste;
with Ada.Strings.Unbounded;
with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;
with Test_Progress;

procedure Tests is
   use type AUnit.Status;
   use type Hostkit.Lease_Files.Open_Outcome;

   function Run is new AUnit.Run.Test_Runner_With_Status (All_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status   : AUnit.Status;
begin
   if not Ada.Environment_Variables.Exists ("FILES_TEST_ROOT") then
      declare
         Created_Temp : constant String :=
           Hostkit.Fs.Create_Temporary_Directory ("files-suite-");
         Suite_Temp : constant String :=
           GNAT.OS_Lib.Normalize_Pathname
             (Created_Temp, Resolve_Links => True);
         Job_Temp   : constant String := Hostkit.Fs.Join (Suite_Temp, "jobs");
      begin
         if Suite_Temp = "" then
            raise Program_Error;
         end if;
         Ada.Directories.Create_Directory (Job_Temp);
         Ada.Environment_Variables.Set
           ("FILES_TEST_ROOT", Hostkit.Fs.Join (Suite_Temp, "fixtures"));
         Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Suite_Temp);
         Ada.Environment_Variables.Set ("TMPDIR", Job_Temp);
      end;
   end if;

   if Ada.Command_Line.Argument_Count in 2 .. 3
     and then Ada.Command_Line.Argument (1) in
       "--files-test-crash-before-marker" | "--files-test-crash-after-lease"
         | "--files-test-hold-before-marker"
   then
      declare
         Directory : constant String := Ada.Command_Line.Argument (2);
         Simple : constant String := Ada.Directories.Simple_Name (Directory);
         Witness_Path : constant String := Hostkit.Fs.Join
           (Hostkit.Fs.Temp_Directory,
            ".files-job-creation-" & Simple (Simple'First + 10 .. Simple'Last));
         Witness : Hostkit.Lease_Files.Lease;
         Owner : Hostkit.Lease_Files.Lease;
         Preparing : constant Ada.Streams.Stream_Element_Array :=
           [Character'Pos ('p'), Character'Pos ('r'), Character'Pos ('e'),
            Character'Pos ('p'), Character'Pos ('a'), Character'Pos ('r'),
            Character'Pos ('e'), Character'Pos ('4')];
         File : Ada.Text_IO.File_Type;
      begin
         if Hostkit.Lease_Files.Create (Witness_Path, Witness) /=
           Hostkit.Lease_Files.Opened
           or else not Hostkit.Lease_Files.Write_At (Witness, Preparing)
         then
            Hostkit.Process.End_Now (1);
         end if;
         Files.Private_Directories.Create (Directory);
         if Ada.Command_Line.Argument (1) = "--files-test-crash-after-lease" then
            if Hostkit.Lease_Files.Create
              (Hostkit.Fs.Join (Directory, ".files-job-owner"), Owner) /=
                Hostkit.Lease_Files.Opened
            then
               Hostkit.Process.End_Now (1);
            end if;
         elsif Ada.Command_Line.Argument (1) = "--files-test-hold-before-marker" then
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (3) & ".started");
            Ada.Text_IO.Close (File);
            for Attempt in Files_Suite.Support.Polling loop
               exit when Ada.Directories.Exists (Ada.Command_Line.Argument (3) & ".release");
            end loop;
         end if;
         Hostkit.Process.End_Now (0);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--files-test-no-btime-transport"
   then
      declare
         procedure Seed_Nonce (Directory, Marker : String) is
            Name : constant String := Hostkit.Fs.Join (Directory, Marker);
            Text : constant String := "abcdefghijklmnop";
            Nonce : Ada.Streams.Stream_Element_Array (1 .. 16);
            Handle : Hostkit.Lease_Files.Lease;
         begin
            for Index in Nonce'Range loop
               Nonce (Index) := Ada.Streams.Stream_Element
                 (Character'Pos (Text (Natural (Index))));
            end loop;
            if Hostkit.Lease_Files.Create (Name, Handle) /=
              Hostkit.Lease_Files.Opened
            then
               Hostkit.Process.End_Now (1);
            end if;
            declare
               Seeded : constant Boolean :=
                 Hostkit.Lease_Files.Write_At (Handle, Nonce);
            begin
               Hostkit.Lease_Files.Release (Handle);
               if not Seeded then
                  Hostkit.Process.End_Now (1);
               end if;
            end;
         end Seed_Nonce;
         Owner : Files.Job_Transports.Lease;
         Directory, Identity : Ada.Strings.Unbounded.Unbounded_String;
         Parent : constant String :=
           Hostkit.Fs.Create_Temporary_Directory ("files-no-btime-stage-");
         Fake_Stage : constant String := Hostkit.Fs.Join (Parent, ".files-work-777");
         Fake_Transport : constant String := Hostkit.Fs.Join
           (Parent, "files-job-0123456789abcdef0123456789abcdef");
         Fake_Recovery : constant String := Hostkit.Fs.Join (Parent, ".files-recovery-1");
         Fake_Payload : constant String := Hostkit.Fs.Join (Fake_Recovery, "payload");
         Ordinary_Parent : constant String := Hostkit.Fs.Join (Parent, "ordinary-private");
         Ordinary_Payload : constant String := Hostkit.Fs.Join (Ordinary_Parent, "payload");
         Recovery_Alias : constant String := Hostkit.Fs.Join (Parent, ".files-recovery-2");
         Source : constant String := Hostkit.Fs.Join (Parent, "source.txt");
         Destination : constant String := Hostkit.Fs.Join (Parent, "copy.txt");
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Environment_Variables.Set ("FILES_TEST_NO_BTIME", "1");
         if Files.File_Identities.Token (Parent) = "" then
            Hostkit.Process.End_Now (1);
         end if;
         Ada.Environment_Variables.Clear ("FILES_TEST_NO_BTIME");
         Files.File_Identities.Testing.Set_Unavailable (True);
         Ada.Environment_Variables.Set ("TMPDIR", Parent);
         Files.Private_Directories.Create (Fake_Stage);
         Seed_Nonce (Fake_Stage, ".files-stage-id");
         Files.Private_Directories.Create (Fake_Transport);
         Seed_Nonce (Fake_Transport, ".files-job-owner");
         Files.Private_Directories.Create (Fake_Recovery);
         Files.Private_Directories.Create (Fake_Payload);
         Seed_Nonce (Fake_Payload, ".files-job-owner");
         Files.Private_Directories.Create (Ordinary_Parent);
         Files.Private_Directories.Create (Ordinary_Payload);
         Seed_Nonce (Ordinary_Payload, ".files-job-owner");
         if not Hostkit.Fs.Create_Link (Ordinary_Parent, Recovery_Alias) then
            Hostkit.Process.End_Now (1);
         end if;
         if Files.File_Identities.Token (Fake_Stage) /= ""
           or else Files.File_Identities.Token (Fake_Transport) /= ""
           or else Files.File_Identities.Token (Fake_Payload) /= ""
           or else Files.File_Identities.Token
             (Hostkit.Fs.Join (Recovery_Alias, "payload")) /= ""
         then
            Hostkit.Process.End_Now (1);
         end if;
         --  Recreate a transport with the same name and copied nonce. Inode
         --  reuse must not make it match any old identity.
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Fake_Transport, ".files-job-owner"));
         Ada.Directories.Delete_Directory (Fake_Transport);
         Files.Private_Directories.Create (Fake_Transport);
         Seed_Nonce (Fake_Transport, ".files-job-owner");
         if Files.File_Identities.Token (Fake_Transport) /= "" then
            Hostkit.Process.End_Now (1);
         end if;
         declare
            Rejected : Boolean := False;
         begin
            begin
               Files.Job_Transports.Create (Directory, Identity, Owner);
            exception
               when Ada.Directories.Use_Error => Rejected := True;
            end;
            if not Rejected or else Ada.Strings.Unbounded.Length (Directory) /= 0
              or else Ada.Strings.Unbounded.Length (Identity) /= 0
            then
               Hostkit.Process.End_Now (1);
            end if;
         end;
         Files.Job_Context.Initialize ("");
         declare
            Rejected : Boolean := False;
         begin
            begin
               declare
                  Stage : constant String := Files.Job_Context.Create_Stage (Parent);
                  pragma Unreferenced (Stage);
               begin
                  null;
               end;
            exception
               when Ada.Directories.Use_Error => Rejected := True;
            end;
            if not Rejected
              or else Ada.Directories.Exists (Hostkit.Fs.Join (Parent, ".files-work-1"))
            then
               Hostkit.Process.End_Now (1);
            end if;
         end;
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Source);
         Ada.Text_IO.Put (File, "source remains");
         Ada.Text_IO.Close (File);
         declare
            Copy_Identity, Copy_Revision : Ada.Strings.Unbounded.Unbounded_String;
            Copied : constant Files.File_System.Mutation_Result :=
              Files.File_System.Copy_Tree (Source, Destination, Copy_Identity, Copy_Revision);
         begin
            if Copied.Success or else Ada.Directories.Exists (Destination)
              or else not Ada.Directories.Exists (Source)
              or else Ada.Directories.Exists (Hostkit.Fs.Join (Parent, ".files-work-1"))
            then
               Hostkit.Process.End_Now (1);
            end if;
         end;
         Files.Job_Context.Initialize ("");
         Files.Job_Transports.Release (Owner);
         Ada.Directories.Delete_File (Source);
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Fake_Stage, ".files-stage-id"));
         Ada.Directories.Delete_Directory (Fake_Stage);
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Fake_Transport, ".files-job-owner"));
         Ada.Directories.Delete_Directory (Fake_Transport);
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Fake_Payload, ".files-job-owner"));
         Ada.Directories.Delete_Directory (Fake_Payload);
         Ada.Directories.Delete_Directory (Fake_Recovery);
         Ada.Directories.Delete_File (Recovery_Alias);
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Ordinary_Payload, ".files-job-owner"));
         Ada.Directories.Delete_Directory (Ordinary_Payload);
         Ada.Directories.Delete_Directory (Ordinary_Parent);
         Ada.Directories.Delete_Directory (Parent);
         Hostkit.Process.End_Now (0);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 4
     and then Ada.Command_Line.Argument (1) = "--files-test-crash-with-helper"
   then
      declare
         use type Hostkit.Spawn.Spawn_Outcome;
         Owner : Files.Job_Transports.Lease;
         Directory : Ada.Strings.Unbounded.Unbounded_String;
         Identity : Ada.Strings.Unbounded.Unbounded_String;
         Child : Hostkit.Spawn.Process_Handle;
         Arguments : Hostkit.String_Vectors.Vector;
         File : Ada.Text_IO.File_Type;
      begin
         Files.Job_Transports.Create (Directory, Identity, Owner);
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2));
         Ada.Text_IO.Put_Line (File, Ada.Strings.Unbounded.To_String (Directory));
         Ada.Text_IO.Close (File);
         Arguments.Append
           (Ada.Strings.Unbounded.To_Unbounded_String ("--files-test-lease-holder"));
         Arguments.Append (Directory);
         Arguments.Append
           (Ada.Strings.Unbounded.To_Unbounded_String (Ada.Command_Line.Argument (3)));
         Arguments.Append
           (Ada.Strings.Unbounded.To_Unbounded_String (Ada.Command_Line.Argument (4)));
         if Hostkit.Spawn.Start
           (Hostkit.Fs.Own_Executable, Arguments, (others => <>), Child) /=
             Hostkit.Spawn.Spawn_Ok
         then
            Hostkit.Process.End_Now (1);
         end if;
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Ada.Command_Line.Argument (3));
         end loop;
         Hostkit.Process.End_Now
           (if Ada.Directories.Exists (Ada.Command_Line.Argument (3)) then 0 else 1);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 4
     and then Ada.Command_Line.Argument (1) = "--files-test-lease-holder"
   then
      declare
         Owner : Files.Job_Transports.Lease;
         File : Ada.Text_IO.File_Type;
      begin
         if not Files.Job_Transports.Join_Helper
           (Ada.Command_Line.Argument (2), Owner)
         then
            Hostkit.Process.End_Now (2);
         end if;
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (3));
         Ada.Text_IO.Close (File);
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Ada.Command_Line.Argument (4));
         end loop;
         Hostkit.Process.End_Now
           (if Ada.Directories.Exists (Ada.Command_Line.Argument (4)) then 0 else 3);
      end;
   end if;

   --  Create one transport and terminate without Ada finalization. The parent
   --  regression test uses this to exercise real crash recovery rather than a
   --  test-only hook that manually releases the ownership lease.
   if Ada.Command_Line.Argument_Count = 2
     and then Ada.Command_Line.Argument (1) = "--files-test-abandon-transport"
   then
      declare
         Job  : Files.Process_Jobs.Session;
         File : Ada.Text_IO.File_Type;
      begin
         Files.Process_Jobs.Reserve (Job);
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2));
         Ada.Text_IO.Put_Line (File, Files.Process_Jobs.Path (Job, ""));
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (0);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--files-test-drain-reaper"
   then
      declare
         Job : Files.Process_Jobs.Session;
         Directory : Ada.Strings.Unbounded.Unbounded_String;
         Stopped : Boolean;
      begin
         Files.Process_Jobs.Reserve (Job);
         Directory := Ada.Strings.Unbounded.To_Unbounded_String
           (Files.Process_Jobs.Path (Job, ""));
         Files.Process_Jobs.Launch (Job, "--files-test-blocked");
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists
              (Ada.Strings.Unbounded.To_String (Directory) & "/started");
         end loop;
         if not Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (Directory) & "/started")
         then
            Hostkit.Process.End_Now (1);
         end if;
         Files.Process_Jobs.Reset (Job);
         Files.Process_Jobs.Shutdown (Stopped);
         Hostkit.Process.End_Now
           (if Stopped and then not Ada.Directories.Exists
             (Ada.Strings.Unbounded.To_String (Directory)) then 0 else 1);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 2
     and then Ada.Command_Line.Argument (1) = "--files-test-late-shutdown-owner"
   then
      declare
         Job : Files.Process_Jobs.Session;
         File : Ada.Text_IO.File_Type;
         Directory : Ada.Strings.Unbounded.Unbounded_String;
         Stopped : Boolean;
      begin
         Files.Process_Jobs.Reserve (Job);
         Directory := Ada.Strings.Unbounded.To_Unbounded_String
           (Files.Process_Jobs.Path (Job, ""));
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2));
         Ada.Text_IO.Put_Line (File, Ada.Strings.Unbounded.To_String (Directory));
         Ada.Text_IO.Close (File);
         Files.Process_Jobs.Shutdown (Stopped);
         if Stopped then
            Hostkit.Process.End_Now (1);
         end if;
         Files.Process_Jobs.Release_For_Shutdown (Job);
         Files.Process_Jobs.Shutdown (Stopped);
         Hostkit.Process.End_Now
           (if Stopped and then not Ada.Directories.Exists
             (Ada.Strings.Unbounded.To_String (Directory)) then 0 else 1);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--files-scavenge"
     and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER", "") /= ""
   then
      declare
         Control : constant String :=
           Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER");
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Control & ".started");
         Ada.Text_IO.Put (File, Integer'Image (Hostkit.Host.Own_Process_Id));
         Ada.Text_IO.Close (File);
         while not Ada.Directories.Exists (Control & ".release") loop
            delay 0.01;
         end loop;
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--files-scavenge"
     and then Ada.Environment_Variables.Value
       ("FILES_TEST_FAIL_SCAVENGER_ONCE", "") /= ""
     and then not Ada.Directories.Exists
       (Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE"))
   then
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File,
            Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE"));
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (1);
      end;
   end if;

   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--files-scavenge"
     and then Ada.Environment_Variables.Value
       ("FILES_TEST_FAIL_SCAVENGER_UNTIL", "") /= ""
     and then not Ada.Directories.Exists
       (Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_UNTIL"))
   then
      declare
         Attempts : constant String := Ada.Environment_Variables.Value
           ("FILES_TEST_FAIL_SCAVENGER_UNTIL") & ".attempts";
         File : Ada.Text_IO.File_Type;
      begin
         if Ada.Directories.Exists (Attempts) then
            Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Attempts);
         else
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Attempts);
         end if;
         Ada.Text_IO.Put_Line (File, "failed coordinator");
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (1);
      end;
   end if;

   --  Refuse final result publication. Tests also remove the completed history
   --  before collection, leaving only the publication journal for recovery.
   if Ada.Command_Line.Argument_Count = 2
     and then Ada.Command_Line.Argument (1) = "--files-operation"
     and then Ada.Environment_Variables.Value ("FILES_TEST_LOST_CREATION_METADATA", "") = "1"
   then
      Ada.Directories.Create_Directory (Ada.Command_Line.Argument (2) & "/result");
   end if;
   if Ada.Command_Line.Argument_Count = 2
     and then (Ada.Command_Line.Argument (1) = "--files-test-blocked"
       or else (Ada.Command_Line.Argument (1) in "--files-refresh" | "--files-watch"
         and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_READS", "") = "1")
       or else (Ada.Command_Line.Argument (1) = "--files-operation"
         and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "") = "1")
       or else (Ada.Command_Line.Argument (1) = "--files-transfer"
         and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_TRANSFERS", "") /= "")
       or else (Ada.Command_Line.Argument (1) = "--files-folder-size"
         and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "") /= ""))
   then
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2) & "/started");
         Ada.Text_IO.Close (File);
         if Ada.Command_Line.Argument (1) in "--files-transfer" | "--files-folder-size" then
            declare
               Marker : constant String := Ada.Environment_Variables.Value
                 (if Ada.Command_Line.Argument (1) = "--files-transfer" then "FILES_TEST_STALL_TRANSFERS"
                  else "FILES_TEST_STALL_FOLDER_SIZES");
            begin
               Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Marker & ".tmp");
               Ada.Text_IO.Put (File, Ada.Command_Line.Argument (2));
               Ada.Text_IO.Close (File);
               Ada.Directories.Rename (Marker & ".tmp", Marker);
            end;
         end if;
         loop
            if Ada.Command_Line.Argument (1) = "--files-operation"
              and then Files.Process_Jobs.Cancellation_Requested
                (Ada.Command_Line.Argument (2))
            then
               Hostkit.Process.End_Now (0);
            end if;
            delay 0.1;
         end loop;
      end;
   end if;
   if Ada.Command_Line.Argument_Count = 3
     and then Ada.Command_Line.Argument (1) = "--files-cleanup"
     and then Ada.Environment_Variables.Value
       ("FILES_TEST_FAIL_CLEANUP_WORKER", "") /= ""
   then
      declare
         Marker : constant String := Ada.Environment_Variables.Value
           ("FILES_TEST_FAIL_CLEANUP_WORKER");
         File : Ada.Text_IO.File_Type;
      begin
         if Ada.Directories.Exists (Marker) then
            Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Marker);
         else
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Marker);
         end if;
         Ada.Text_IO.Put_Line (File, "failed cleanup worker");
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (1);
      end;
   end if;
   if Ada.Command_Line.Argument_Count = 3
     and then Ada.Command_Line.Argument (1) = "--files-cleanup"
     and then Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE", "") /= ""
     and then not Ada.Directories.Exists
       (Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE"))
   then
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File,
            Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE"));
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (0);
      end;
   end if;
   if Ada.Command_Line.Argument_Count = 3
     and then Ada.Command_Line.Argument (1) = "--files-cleanup"
     and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_CLEANUP_WORKER", "") = "stop"
   then
      declare
         Directory : constant String := Ada.Command_Line.Argument (2);
         Started   : constant String := Directory & "/cleanup-worker-started";
         File      : Ada.Text_IO.File_Type;
         Sent      : Boolean;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Started);
         Ada.Text_IO.Put (File, Integer'Image (Hostkit.Host.Own_Process_Id));
         Ada.Text_IO.Close (File);
         Sent := Hostkit.Signals.Send_To_Process
           (Hostkit.Host.Own_Process_Id, Hostkit.Signals.Signal_Stop);
         if not Sent then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            return;
         end if;
      end;
   end if;
   if Ada.Command_Line.Argument_Count = 3
     and then Ada.Command_Line.Argument (1) = "--files-cleanup"
     and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_CLEANUP_WORKER", "") = "1"
   then
      declare
         Directory : constant String := Ada.Command_Line.Argument (2);
         Started   : constant String := Directory & "/cleanup-worker-started";
         Release   : constant String := Directory & "/release-cleanup-worker";
         File      : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Started);
         Ada.Text_IO.Close (File);
         while not Ada.Directories.Exists (Release) loop
            delay 0.01;
         end loop;
      end;
   end if;
   if Files.Job_Helpers.Run_If_Requested then
      if Ada.Command_Line.Argument (1) = "--files-refresh"
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_REFRESH_RESULT_INCONSISTENT", "") = "1"
      then
         Files.Refresh_Jobs.Testing.Replace_Result_Flags
           (Ada.Command_Line.Argument (2) & "/result",
            Success => False,
            Reloaded => True);
      end if;
      if Ada.Command_Line.Argument (1) = "--files-operation"
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH", "") = "1"
      then
         Files.Operation_Jobs.Testing.Replace_Result_Kind
           (Ada.Command_Line.Argument (2) & "/result",
            Files.Operation_Jobs.Search_Names);
      end if;
      if Ada.Command_Line.Argument (1) = "--files-operation"
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH", "") = "1"
      then
         Files.Operation_Jobs.Testing.Replace_Result_Recent
           (Ada.Command_Line.Argument (2) & "/result", True);
      end if;
      if Ada.Command_Line.Argument (1) = "--files-transfer"
        and then Ada.Environment_Variables.Value ("FILES_TEST_TRANSFER_RESULT_LOSS", "") /= ""
      then
         declare
            Directory : constant String := Ada.Command_Line.Argument (2);
            Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRANSFER_RESULT_LOSS");
            File : Ada.Streams.Stream_IO.File_Type;
            Checkpoint : constant Files.Transfer_Jobs.Job_Result := (others => <>);
            Action : Files.Paste.Resolved_Action;
         begin
            Ada.Directories.Delete_File (Directory & "/result");
            if Fault = "checkpoint" then
               Files.Transfer_Jobs.Testing.Write_Result
                 (Directory & "/result", Checkpoint);
            elsif Fault in "journal" | "replacement" | "source-replacement" then
               Ada.Directories.Delete_File (Directory & "/completed");
            end if;
            if Fault in "replacement" | "source-replacement" then
               Action := Files.Transfer_Jobs.Testing.Read_Request_Action
                 (Directory & "/request");
               declare
                  Dest : constant String := Ada.Strings.Unbounded.To_String
                    (if Fault = "replacement" then Action.Dest_Path else Action.Source_Path);
               begin
                  if Fault = "replacement" then
                     Ada.Directories.Rename (Dest, Dest & "-saved");
                  end if;
                  Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Dest);
                  String'Write (Ada.Streams.Stream_IO.Stream (File), "unrelated replacement");
                  Ada.Streams.Stream_IO.Close (File);
               end;
            end if;
         end;
      end if;
      Files.Job_Scavenger.Shutdown;
      Files.Job_Context.Shutdown;
      declare
         Stopped : Boolean;
      begin
         Files.Process_Jobs.Shutdown (Stopped);
         if not Stopped then
            Hostkit.Process.End_Now (1);
         end if;
      end;
      return;
   end if;
   --  Pin the locale so localization-dependent assertions are deterministic
   --  regardless of the developer machine's locale (C normalizes to "en").
   Ada.Environment_Variables.Set ("LC_ALL", "C");
   --  Keep every test's trash payload separate from the user's desktop trash.
   declare
      Trash_Root : constant String := Hostkit.Fs.Create_Temporary_Directory ("files-test-trash-");
   begin
      if Trash_Root = "" then
         raise Program_Error;
      end if;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Root);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Status :=
        Run (Reporter, (AUnit.Options.Default_Options with delta Filter => Test_Progress.Filter'Access));
      --  Tests that cannot run on this host count as passed with AUnit; say how many.
      Ada.Text_IO.Put_Line ("Skipped Tests:" & Natural'Image (Files_Suite.Support.Skip_Count));
      if Status = AUnit.Failure then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      --  A skip passes, so a test that quietly stops running here would go
      --  unnoticed: CI names how many may skip on each host, and more fails.
      declare
         Ceiling : constant String := Ada.Environment_Variables.Value ("FILES_TEST_MAX_SKIPS", "");
         Skipped : constant Natural := Files_Suite.Support.Skip_Count;
      begin
         if Ceiling /= "" then
            if (for some C of Ceiling => C not in '0' .. '9') or else Ceiling'Length > 9 then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, "FILES_TEST_MAX_SKIPS=" & Ceiling & " is not a decimal count");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            elsif Skipped > Natural'Value (Ceiling) then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "FAILED:" & Skipped'Image & " tests skipped, more than FILES_TEST_MAX_SKIPS=" & Ceiling
                  & "; the SKIP lines above name them");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;
         end if;
      end;
      declare
         Removed : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Permanently (Trash_Root);
         pragma Unreferenced (Removed);
      begin
         null;
      end;
      Files.Job_Scavenger.Shutdown;
      Files.Job_Context.Shutdown;
      declare
         Stopped : Boolean;
      begin
         Files.Process_Jobs.Shutdown (Stopped);
         if not Stopped then
            Hostkit.Process.End_Now (1);
         end if;
      end;
      declare
         Suite_Temp : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TEMP", "");
         Removed : constant Files.File_System.Mutation_Result :=
           (if Suite_Temp = "" then (Success => True, Error_Key => Ada.Strings.Unbounded.Null_Unbounded_String)
            else Files.File_System.Delete_Permanently (Suite_Temp));
         pragma Unreferenced (Removed);
      begin
         null;
      end;
   end;
exception
   when others =>
      Files.Job_Scavenger.Shutdown;
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown;
      raise;
end Tests;

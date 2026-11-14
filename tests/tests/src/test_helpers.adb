with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Files.File_Identities;
with Files.File_Identities.Testing;
with Files.File_System;
with Files.Helper_Modes;
with Files.Job_Context;
with Files.Job_Transports;
with Files.Operation_Jobs;
with Files.Operation_Jobs.Testing;
with Files.Paste;
with Files.Private_Directories;
with Files.Process_Jobs;
with Files.Refresh_Jobs.Testing;
with Files.Transfer_Jobs;
with Files.Transfer_Jobs.Testing;
with Files_Suite.Support;
with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

package body Test_Helpers is

   package HM renames Files.Helper_Modes;
   use type Hostkit.Lease_Files.Open_Outcome;

   --  How long a helper held by a test waits for the test to let it go, or to
   --  kill it, before it gives up: far beyond any test's own bounded waits, so
   --  it only ends a helper whose test has already died and left it behind.
   --  Scaled by FILES_TEST_TIME_SCALE like the tests' waits, so it stays
   --  beyond them on a slow runner too.
   function Helper_Hold_Limit return Duration is
     (Files_Suite.Support.Seconds (Files_Suite.Support.Scaled (4 * Files_Suite.Support.Poll_Limit)));

   --  Publish a file another process waits for in one step: write Content
   --  beside Path, then rename it into place, so a reader that sees Path
   --  exist never reads it half-written (empty, or without its process id).
   --
   --  @param Path File the waiting process looks for.
   --  @param Content What it holds.
   procedure Publish (Path : String; Content : String := "") is
      Partial : constant String := Path & ".partial";
      File    : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Partial);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
      Ada.Directories.Rename (Partial, Path);
   end Publish;

   function Requested_Mode return Helper_Mode is
      First : constant String :=
        (if Ada.Command_Line.Argument_Count = 0 then "" else Ada.Command_Line.Argument (1));
   begin
      if First = "--files-test-crash-before-marker" then
         return Crash_Before_Marker;
      elsif First = "--files-test-crash-after-lease" then
         return Crash_After_Lease;
      elsif First = "--files-test-hold-before-marker" then
         return Hold_Before_Marker;
      elsif First = "--files-test-no-btime-transport" then
         return No_Btime_Transport;
      elsif First = "--files-test-crash-with-helper" then
         return Crash_With_Helper;
      elsif First = "--files-test-lease-holder" then
         return Lease_Holder;
      elsif First = "--files-test-abandon-transport" then
         return Abandon_Transport;
      elsif First = "--files-test-drain-reaper" then
         return Drain_Reaper;
      elsif First = "--files-test-late-shutdown-owner" then
         return Late_Shutdown_Owner;
      elsif First = "--files-test-blocked" then
         return Blocked_Helper;
      elsif First = HM.Flag (HM.Scavenge) then
         return Scavenge_Helper;
      elsif First = HM.Flag (HM.Operation) then
         return Operation_Helper;
      elsif First = HM.Flag (HM.Refresh) then
         return Refresh_Helper;
      elsif First = HM.Flag (HM.Watch) then
         return Watch_Helper;
      elsif First = HM.Flag (HM.Transfer) then
         return Transfer_Helper;
      elsif First = HM.Flag (HM.Folder_Size) then
         return Folder_Size_Helper;
      elsif First = HM.Flag (HM.Cleanup) then
         return Cleanup_Helper;
      end if;
      return No_Test_Helper;
   end Requested_Mode;

   --  Create a transport directory the way a job does and end without Ada
   --  finalization: before its marker (crash or hold) or after its lease.
   --
   --  @param Mode Crash_Before_Marker, Crash_After_Lease or Hold_Before_Marker.
   procedure Transport_Creator (Mode : Helper_Mode) is
   begin
      if Ada.Command_Line.Argument_Count not in 2 .. 3 then
         return;
      end if;
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
      begin
         if Hostkit.Lease_Files.Create (Witness_Path, Witness) /=
           Hostkit.Lease_Files.Opened
           or else not Hostkit.Lease_Files.Write_At (Witness, Preparing)
         then
            Hostkit.Process.End_Now (1);
         end if;
         Files.Private_Directories.Create (Directory);
         if Mode = Crash_After_Lease then
            if Hostkit.Lease_Files.Create
              (Hostkit.Fs.Join (Directory, ".files-job-owner"), Owner) /=
                Hostkit.Lease_Files.Opened
            then
               Hostkit.Process.End_Now (1);
            end if;
         elsif Mode = Hold_Before_Marker then
            Publish (Ada.Command_Line.Argument (3) & ".started");
            for Attempt in Files_Suite.Support.Polling (Limit => Helper_Hold_Limit, Interval => 0.01) loop
               exit when Ada.Directories.Exists (Ada.Command_Line.Argument (3) & ".release");
            end loop;
            --  Never released: the test that held it is gone.
            if not Ada.Directories.Exists (Ada.Command_Line.Argument (3) & ".release") then
               Hostkit.Process.End_Now (1);
            end if;
         end if;
         Hostkit.Process.End_Now (0);
      end;
   end Transport_Creator;

   --  Check that, with file identities unavailable, nothing private is
   --  recognized or created on trust.
   procedure No_Btime_Transport_Check is
   begin
      if Ada.Command_Line.Argument_Count /= 1 then
         return;
      end if;
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
   end No_Btime_Transport_Check;

   --  Create a transport, start a lease-holder helper on it, and end.
   procedure Crash_With_Lease_Holder is
   begin
      if Ada.Command_Line.Argument_Count /= 4 then
         return;
      end if;
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
   end Crash_With_Lease_Holder;

   --  Join a transport's lease as its helper and hold it until released.
   procedure Hold_Transport_Lease is
   begin
      if Ada.Command_Line.Argument_Count /= 4 then
         return;
      end if;
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
   end Hold_Transport_Lease;

   --  Create one transport and terminate without Ada finalization. The parent
   --  regression test uses this to exercise real crash recovery rather than a
   --  test-only hook that manually releases the ownership lease.
   procedure Abandon_Transport_Fixture is
   begin
      if Ada.Command_Line.Argument_Count /= 2 then
         return;
      end if;
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
   end Abandon_Transport_Fixture;

   --  Leave a blocked helper behind and check that shutdown reaps it.
   procedure Drain_Reaper_Check is
   begin
      if Ada.Command_Line.Argument_Count /= 1 then
         return;
      end if;
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
   end Drain_Reaper_Check;

   --  Check that shutdown waits for a session released late.
   procedure Late_Shutdown_Owner_Check is
   begin
      if Ada.Command_Line.Argument_Count /= 2 then
         return;
      end if;
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
   end Late_Shutdown_Owner_Check;

   --  Hold a recovery coordinator until its test releases it.
   procedure Stall_Scavenger is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER", "") = "" then
         return;
      end if;
      declare
         Control : constant String :=
           Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER");
      begin
         Publish (Control & ".started", Integer'Image (Hostkit.Host.Own_Process_Id));
         for Attempt in Files_Suite.Support.Polling (Limit => Helper_Hold_Limit, Interval => 0.01) loop
            exit when Ada.Directories.Exists (Control & ".release");
         end loop;
         if not Ada.Directories.Exists (Control & ".release") then
            Hostkit.Process.End_Now (1);
         end if;
      end;
   end Stall_Scavenger;

   --  Fail one recovery coordinator, the first.
   procedure Fail_Scavenger_Once is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE", "") = ""
        or else Ada.Directories.Exists (Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE"))
      then
         return;
      end if;
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File,
            Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE"));
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (1);
      end;
   end Fail_Scavenger_Once;

   --  Fail recovery coordinators until their test lets them run.
   procedure Fail_Scavenger_Until is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_UNTIL", "") = ""
        or else Ada.Directories.Exists (Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_UNTIL"))
      then
         return;
      end if;
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
   end Fail_Scavenger_Until;

   --  A recovery coordinator: stalled or failed as its test armed it.
   procedure Scavenge_Helper_Faults is
   begin
      if Ada.Command_Line.Argument_Count /= 1 then
         return;
      end if;
      Stall_Scavenger;
      Fail_Scavenger_Once;
      Fail_Scavenger_Until;
   end Scavenge_Helper_Faults;

   --  Hold a helper in its work until its test cancels or kills it.
   --
   --  @param Mode The helper's mode.
   procedure Hold_Stalled_Helper (Mode : Helper_Mode) is
   begin
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2) & "/started");
         Ada.Text_IO.Close (File);
         if Mode in Transfer_Helper | Folder_Size_Helper then
            declare
               Marker : constant String := Ada.Environment_Variables.Value
                 (if Mode = Transfer_Helper then "FILES_TEST_STALL_TRANSFERS"
                  else "FILES_TEST_STALL_FOLDER_SIZES");
            begin
               Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Marker & ".tmp");
               Ada.Text_IO.Put (File, Ada.Command_Line.Argument (2));
               Ada.Text_IO.Close (File);
               Ada.Directories.Rename (Marker & ".tmp", Marker);
            end;
         end if;
         --  Held until the test cancels or kills it; the bound only ends a
         --  helper whose test has died without doing either.
         for Attempt in Files_Suite.Support.Polling (Limit => Helper_Hold_Limit, Interval => 0.1) loop
            if Mode = Operation_Helper
              and then Files.Process_Jobs.Cancellation_Requested
                (Ada.Command_Line.Argument (2))
            then
               Hostkit.Process.End_Now (0);
            end if;
         end loop;
         Hostkit.Process.End_Now (1);
      end;
   end Hold_Stalled_Helper;

   --  An operation helper: its result publication refused, and stalled, as
   --  its test armed it.
   procedure Operation_Helper_Faults is
   begin
      if Ada.Command_Line.Argument_Count /= 2 then
         return;
      end if;
      --  Refuse final result publication. Tests also remove the completed history
      --  before collection, leaving only the publication journal for recovery.
      if Ada.Environment_Variables.Value ("FILES_TEST_LOST_CREATION_METADATA", "") = "1" then
         Ada.Directories.Create_Directory (Ada.Command_Line.Argument (2) & "/result");
      end if;
      if Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "") = "1" then
         Hold_Stalled_Helper (Operation_Helper);
      end if;
   end Operation_Helper_Faults;

   --  Fail a cleanup worker.
   procedure Fail_Cleanup_Worker is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_FAIL_CLEANUP_WORKER", "") = "" then
         return;
      end if;
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
   end Fail_Cleanup_Worker;

   --  Skip one cleanup worker's work, the first, and report success.
   procedure Skip_Cleanup_Once is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE", "") = ""
        or else Ada.Directories.Exists (Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE"))
      then
         return;
      end if;
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File,
            Ada.Environment_Variables.Value ("FILES_TEST_SKIP_CLEANUP_ONCE"));
         Ada.Text_IO.Close (File);
         Hostkit.Process.End_Now (0);
      end;
   end Skip_Cleanup_Once;

   --  Stop the cleanup worker by signal, to be resumed or reaped by its test.
   --
   --  @param Stop True when the signal could not be sent.
   procedure Stop_Cleanup_Worker (Stop : out Boolean) is
   begin
      Stop := False;
      if Ada.Environment_Variables.Value ("FILES_TEST_STALL_CLEANUP_WORKER", "") /= "stop" then
         return;
      end if;
      declare
         Directory : constant String := Ada.Command_Line.Argument (2);
         Started   : constant String := Directory & "/cleanup-worker-started";
         Sent      : Boolean;
      begin
         Publish (Started, Integer'Image (Hostkit.Host.Own_Process_Id));
         Sent := Hostkit.Signals.Send_To_Process
           (Hostkit.Host.Own_Process_Id, Hostkit.Signals.Signal_Stop);
         if not Sent then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            Stop := True;
            return;
         end if;
      end;
   end Stop_Cleanup_Worker;

   --  Hold the cleanup worker until its test releases it.
   procedure Hold_Cleanup_Worker is
   begin
      if Ada.Environment_Variables.Value ("FILES_TEST_STALL_CLEANUP_WORKER", "") /= "1" then
         return;
      end if;
      declare
         Directory : constant String := Ada.Command_Line.Argument (2);
         Started   : constant String := Directory & "/cleanup-worker-started";
         Release   : constant String := Directory & "/release-cleanup-worker";
      begin
         Publish (Started);
         for Attempt in Files_Suite.Support.Polling (Limit => Helper_Hold_Limit, Interval => 0.01) loop
            exit when Ada.Directories.Exists (Release);
         end loop;
         if not Ada.Directories.Exists (Release) then
            Hostkit.Process.End_Now (1);
         end if;
      end;
   end Hold_Cleanup_Worker;

   --  A cleanup worker: failed, skipped, stopped or held as its test armed it.
   --
   --  @param Stop True when the executable must return at once.
   procedure Cleanup_Helper_Faults (Stop : out Boolean) is
   begin
      Stop := False;
      if Ada.Command_Line.Argument_Count /= 3 then
         return;
      end if;
      Fail_Cleanup_Worker;
      Skip_Cleanup_Once;
      Stop_Cleanup_Worker (Stop);
      if Stop then
         return;
      end if;
      Hold_Cleanup_Worker;
   end Cleanup_Helper_Faults;

   procedure Run_Before_Dispatch (Mode : Helper_Mode; Stop : out Boolean) is
   begin
      Stop := False;
      case Mode is
         when No_Test_Helper =>
            null;
         when Crash_Before_Marker | Crash_After_Lease | Hold_Before_Marker =>
            Transport_Creator (Mode);
         when No_Btime_Transport =>
            No_Btime_Transport_Check;
         when Crash_With_Helper =>
            Crash_With_Lease_Holder;
         when Lease_Holder =>
            Hold_Transport_Lease;
         when Abandon_Transport =>
            Abandon_Transport_Fixture;
         when Drain_Reaper =>
            Drain_Reaper_Check;
         when Late_Shutdown_Owner =>
            Late_Shutdown_Owner_Check;
         when Scavenge_Helper =>
            Scavenge_Helper_Faults;
         when Operation_Helper =>
            Operation_Helper_Faults;
         when Blocked_Helper =>
            if Ada.Command_Line.Argument_Count = 2 then
               Hold_Stalled_Helper (Mode);
            end if;
         when Refresh_Helper | Watch_Helper =>
            if Ada.Command_Line.Argument_Count = 2
              and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_READS", "") = "1"
            then
               Hold_Stalled_Helper (Mode);
            end if;
         when Transfer_Helper =>
            if Ada.Command_Line.Argument_Count = 2
              and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_TRANSFERS", "") /= ""
            then
               Hold_Stalled_Helper (Mode);
            end if;
         when Folder_Size_Helper =>
            if Ada.Command_Line.Argument_Count = 2
              and then Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "") /= ""
            then
               Hold_Stalled_Helper (Mode);
            end if;
         when Cleanup_Helper =>
            Cleanup_Helper_Faults (Stop);
      end case;
   end Run_Before_Dispatch;

   procedure Damage_Result (Mode : Helper_Mode) is
   begin
      if Mode = Refresh_Helper
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_REFRESH_RESULT_INCONSISTENT", "") = "1"
      then
         Files.Refresh_Jobs.Testing.Replace_Result_Flags
           (Ada.Command_Line.Argument (2) & "/result",
            Success => False,
            Reloaded => True);
      end if;
      if Mode = Operation_Helper
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_KIND_MISMATCH", "") = "1"
      then
         Files.Operation_Jobs.Testing.Replace_Result_Kind
           (Ada.Command_Line.Argument (2) & "/result",
            Files.Operation_Jobs.Search_Names);
      end if;
      if Mode = Operation_Helper
        and then Ada.Environment_Variables.Value
          ("FILES_TEST_OPERATION_RESULT_RECENT_MISMATCH", "") = "1"
      then
         Files.Operation_Jobs.Testing.Replace_Result_Recent
           (Ada.Command_Line.Argument (2) & "/result", True);
      end if;
      if Mode = Transfer_Helper
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
   end Damage_Result;

end Test_Helpers;

with Interfaces.C;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.OS_Lib;

with AUnit;
with AUnit.Reporter.Text;
with AUnit.Options;
with AUnit.Run;
with Files_Suite.Support;
with All_Suites;
with Files.Diagnostics;
with Files.Job_Helpers;
with Files.Job_Context;
with Files.Job_Scavenger;
with Files.Durability.Testing;
with Files.File_System;
with Files.File_System.Testing;
with Files.Process_Jobs;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files.Types;
with Hostkit.Fs;
with Hostkit.Process;
with Test_Helpers;
with Test_Progress;

procedure Tests is
   use type AUnit.Status;

   function Run is new AUnit.Run.Test_Runner_With_Status (All_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status   : AUnit.Status;

   --  The scratch directory this process made for the run, which it alone
   --  removes at the end; empty when the caller supplied FILES_TEST_TEMP, and
   --  in every helper process, which inherits it.
   Owned_Temp : Ada.Strings.Unbounded.Unbounded_String;

   procedure Drop_Backup_Privileges is
      function Drop return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_drop_backup_privileges";
      Dropped : constant Interfaces.C.int := Drop;
      pragma Unreferenced (Dropped);
   begin
      null;
   end Drop_Backup_Privileges;
begin
   --  Before any test or helper runs: a Windows shell may have switched on
   --  the backup and restore privileges, which pass over every DACL the
   --  permission tests set (see files_test_metadata.c).
   Drop_Backup_Privileges;

   --  Volume trashes are off (cross-device tests keep exercising the home
   --  trash), and even where a test turns them on the trash view never scans
   --  the mounts, so Empty Trash in a test never meets a real drive's trash.
   --  A helper process inherits the test's setting (a test that turned them
   --  on runs its helpers with them on), so only the suite itself sets it.
   if not Ada.Environment_Variables.Exists ("FILES_TEST_VOLUME_TRASH") then
      Ada.Environment_Variables.Set ("FILES_TEST_VOLUME_TRASH", "off");
   end if;

   --  The scratch area for application state (the recovery index, the
   --  volume-trash list) and helper jobs, made here unless the caller named
   --  one -- also when the caller names only FILES_TEST_ROOT, so that state
   --  never lands in the user's own data directory.
   if not Ada.Environment_Variables.Exists ("FILES_TEST_TEMP") then
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
         Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Suite_Temp);
         Ada.Environment_Variables.Set ("TMPDIR", Job_Temp);
         Owned_Temp := Ada.Strings.Unbounded.To_Unbounded_String (Suite_Temp);
      end;
   end if;
   if not Ada.Environment_Variables.Exists ("FILES_TEST_ROOT") then
      Ada.Environment_Variables.Set
        ("FILES_TEST_ROOT",
         Hostkit.Fs.Join (Ada.Environment_Variables.Value ("FILES_TEST_TEMP"), "fixtures"));
   end if;
   --  Nor the user's caches and configuration: every listing reads the
   --  thumbnail cache, and background refreshes write to it (it follows
   --  XDG_CACHE_HOME on every host). Helper processes inherit the same.
   declare
      procedure Private_Folder (Variable, Name : String) is
         Folder : constant String :=
           Hostkit.Fs.Join (Ada.Environment_Variables.Value ("FILES_TEST_TEMP"), Name);
      begin
         Ada.Directories.Create_Path (Folder);
         Ada.Environment_Variables.Set (Variable, Folder);
      end Private_Folder;
   begin
      Private_Folder ("XDG_CACHE_HOME", "cache");
      Private_Folder ("XDG_CONFIG_HOME", "config");
   end;

   declare
      Mode : constant Test_Helpers.Helper_Mode := Test_Helpers.Requested_Mode;
      Stop : Boolean;
   begin
      Test_Helpers.Run_Before_Dispatch (Mode, Stop);
      if Stop then
         return;
      end if;
      --  A helper runs a transfer in this executable: the flush, copy and
      --  restore faults the test that started it armed reach it through the
      --  environment, on every host.
      Files.Durability.Testing.Install_From_Environment;
      Files.File_System.Testing.Install_From_Environment;
      if Files.Job_Helpers.Run_If_Requested then
         Test_Helpers.Damage_Result (Mode);
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
   end;
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
      --  An exception the event loop carried on past is a bug even when every
      --  assertion held: the loop skips the pass, and windows stop drawing.
      if Files.Diagnostics.Event_Loop_Failures > 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "FAILED: event loop failures:" & Natural'Image (Files.Diagnostics.Event_Loop_Failures)
            & " (FILES_DIAGNOSTICS=1 names them)");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      --  A filter that matches nothing runs nothing, and nothing fails: say
      --  so, or a mistyped FILES_TEST_ONLY reads as a green repeat.
      if Test_Progress.Only /= "" and then Test_Progress.Matched = 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "FAILED: FILES_TEST_ONLY=" & Test_Progress.Only & " matches no registered test routine");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      --  A skip passes, so a test that quietly stops running here would go
      --  unnoticed: CI names, per host, the tests that skip there and why
      --  ("Test: reason", one per line in FILES_TEST_EXPECTED_SKIPS; "--"
      --  starts a comment). Another skip fails the run -- a listed test
      --  skipping for another reason too -- and so does a listed one that
      --  ran: a count alone let one take the other's place. A run of selected
      --  tests (FILES_TEST_ONLY) checks only the first.
      declare
         List_Path : constant String := Ada.Environment_Variables.Value ("FILES_TEST_EXPECTED_SKIPS", "");
         Expected  : Files.Types.String_Vectors.Vector;
         File      : Ada.Text_IO.File_Type;
      begin
         if List_Path /= "" then
            Ada.Text_IO.Open (File, Ada.Text_IO.In_File, List_Path);
            while not Ada.Text_IO.End_Of_File (File) loop
               declare
                  Line    : constant String := Ada.Text_IO.Get_Line (File);
                  Comment : constant Natural := Ada.Strings.Fixed.Index (Line, "--");
                  Name    : constant String :=
                    Ada.Strings.Fixed.Trim
                      ((if Comment = 0 then Line else Line (Line'First .. Comment - 1)), Ada.Strings.Both);
               begin
                  if Name /= "" then
                     Expected.Append (Ada.Strings.Unbounded.To_Unbounded_String (Name));
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (File);
            for Name of Files_Suite.Support.Skips loop
               if not Expected.Contains (Name) then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "FAILED: skipped (" & Ada.Strings.Unbounded.To_String (Name) & "), and " & List_Path
                     & " does not list that skip");
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               end if;
            end loop;
            if Test_Progress.Only = "" then
               for Name of Expected loop
                  if not Files_Suite.Support.Has_Skipped (Ada.Strings.Unbounded.To_String (Name)) then
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "FAILED: " & List_Path & " lists (" & Ada.Strings.Unbounded.To_String (Name)
                        & "), but no test skipped so: take it off the list, or give its reason now");
                     Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                  end if;
               end loop;
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
      --  Only the directory this run made: one the caller supplied through
      --  FILES_TEST_ROOT / FILES_TEST_TEMP is the caller's to keep or remove.
      if Ada.Strings.Unbounded.Length (Owned_Temp) > 0 then
         declare
            Removed : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Permanently (Ada.Strings.Unbounded.To_String (Owned_Temp));
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      end if;
   exception
      when others =>
         --  The test trash goes on a crash too; the outer handler removes the rest.
         declare
            Removed : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Permanently (Trash_Root);
            pragma Unreferenced (Removed);
         begin
            null;
         end;
         raise;
   end;
exception
   when others =>
      Files.Job_Scavenger.Shutdown;
      Files.Job_Context.Shutdown;
      Files.Process_Jobs.Shutdown;
      --  The scratch area this run made is not left behind by a crash.
      if Ada.Strings.Unbounded.Length (Owned_Temp) > 0 then
         declare
            Removed : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Permanently (Ada.Strings.Unbounded.To_String (Owned_Temp));
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      end if;
      raise;
end Tests;

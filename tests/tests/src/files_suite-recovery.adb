with Files.Items;
with Files.Model.Testing;
with Files.File_Identities;
with Files.File_Identities.Testing;
with Files.Job_Cleanup;
with Files.Job_Scavenger;
with Files.Job_Transports;
with Files.Private_Directories;
with Files.Process_Jobs;
with Files.Process_Jobs.Testing;
with Files.Job_Context;
with Files.Job_Records;
with Files.Refresh_Jobs;
with Files.Refresh_Jobs.Testing;
with Ada.Calendar;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Interfaces;
with Files.Recovery_CLI;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;
with Files.Application.Windows;
with Files.Copy_Context;
with Files.Exclusive_Streams;
with Files.Lease_Streams;
with Files.File_System;
with Files.History_Journal;
with Files.Model;
with Files.Model.History;
with Files.Operation_Jobs.Testing;
with Files.Operations;
with Files.Operations.Testing;
with Files.Paste;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.Settings;
with Guikit.Shared_Bytes;
with Files.Types;
with Files.Transfer_Jobs;
with Files.Transfer_Jobs.Testing;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files.Model.Pasting;
with Files.Job_Scavenger.Testing;

package body Files_Suite.Recovery is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;
   use type Hostkit.Host.Kind;
   use type Files.Private_Directories.Create_Result;
   use type Files.Job_Transports.Claim_Outcome;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Interfaces.Unsigned_8;
   use type Hostkit.Lease_Files.Open_Outcome;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Types.Item_Kind;
   use type Files.Types.String_Vectors.Vector;
   use type Files.Types.Search_Scope;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Recovery_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Recovery_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Recovery_Test_Case);

   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stage_Markers_Outlast_Failed_Delete (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Interrupted_Release_Resumes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Emptied_Stage_Swept (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unmarked_Stage_Survives_Sweep (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Held_Release_Marker_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stale_Background_Results (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Result_Mismatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sweep_Leaves_Registry_Open (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Journal_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Request_Path_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Item_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Item_Large_Account_Ids (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Operation_Result_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Move_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replacement_Checkpoint_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovered_Checkpoint_Keeps_Result (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Truncated_Persisted_Records (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Lease_Survives_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Exclusive_Stream_Hardlink (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Stream_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scavenger_Coordinator_Failures (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Lease_Claims (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unmarked_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unsafe_Recovery_Report (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Private_Directory_Hardening (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scavenger_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Cleanup_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stage_Owner_Marker_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stage_Record_Cleanup (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Private_Record_Writes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Mode_Flags (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Recovery_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files jobs and recovery");
   end Name;

   overriding procedure Register_Tests (T : in out Recovery_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Registry_Bounded'Access,
         "verified deletes leave no recovery-registry record and stale records are reclaimed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sweep_Leaves_Registry_Open'Access,
         "a registry sweep lets the lock go for its slow work, so a Register meanwhile does not wait");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Released_Recovery_Goes_To_Trash'Access,
         "a replaced original kept for Undo goes to the trash under its own name when history ends");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Interrupted_Release_Resumes'Access,
         "an interrupted release is put back or finished, on every host");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Emptied_Stage_Swept'Access,
         "the registry sweep removes a recovery stage whose payload is already gone");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Unmarked_Stage_Survives_Sweep'Access,
         "the registry sweep leaves a stage with no payload and no restore or release marker");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Held_Release_Marker_Skipped'Access,
         "the registry sweep leaves a release whose marker lease is held, and resumes it once released");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Command_Line'Access,
         "--recover restores a payload, and --discard-recovery deletes only a recovery payload");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Operations'Access,
         "duplicate, archive, extract and recursive searches use cancellable helpers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stale_Background_Results'Access,
         "a background result never overwrites a newer view, and stays undoable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Result_Mismatch'Access,
         "a helper result that disagrees with its request is rejected but keeps its Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Helper_Shutdown'Access, "closing a session never waits for blocked helper work");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Protocol_Gaps'Access,
         "transport creation crashes and cancellation failures retain safe recovery");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Journal_Validation'Access,
         "copy journals reject trailing transport data");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Job_Request_Path_Validation'Access,
         "refresh, operation and watch requests reject relative or NUL-containing paths");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Job_Item_Record_Validation'Access,
         "directory signatures and job items reject invalid paths and thumbnails");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Job_Item_Large_Account_Ids'Access,
         "job items carry user and group ids from 2**31 up, in the format Natural ids had");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Operation_Result_Record_Validation'Access,
         "operation results round-trip and reject oversized actions");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Move_Record_Validation'Access,
         "path moves round-trip with their kind and reject a kind that does not match the new path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Record_Validation'Access,
         "transfer results and requests reject inconsistent or multiply-linked records");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replacement_Checkpoint_Validation'Access,
         "replacement checkpoints reject trailing fields and linked files");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovered_Checkpoint_Keeps_Result'Access,
         "an unreadable replacement checkpoint keeps the backup the result reported");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Truncated_Persisted_Records'Access,
         "every strict prefix of persisted job and history records is rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Autonomous_Cleanup_Worker'Access,
         "session disposal autonomously reaps a stalled cleanup worker");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cleanup_Exit_Verification'Access,
         "cleanup helper success is verified before retry state is discarded");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cleanup_Retry_Bound'Access,
         "permanent cleanup worker failures have a bounded parent retry count");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Reserve_Exception_Safety'Access,
         "failed job reservation leaves no active state and a later reservation succeeds");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Cleanup_Retry'Access, "failed ordinary transport cleanup retries while idle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Helper_Lease_Survives_Parent'Access,
         "a helper keeps recovery out after parent exit and fails closed if recovery wins");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Exclusive_Stream_Hardlink'Access,
         "exclusive transport streams refuse hardlinks without truncating their target");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Stream_Blocks'Access,
         "transport streams buffer in blocks and read back exactly what was written");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scavenger_Coordinator_Failures'Access,
         "startup recovery completes when its coordinator cannot launch or fails");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Lease_Claims'Access,
         "transport lease claims distinguish live, missing and replaced leases");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Transport_Recovery'Access,
         "startup scavenging removes crashed transports while preserving live and development ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Unmarked_Transport_Recovery'Access,
         "unmarked pre-lease transports are preserved and never claimed by age alone");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Unsafe_Recovery_Report'Access,
         "unsafe recovery is reported through a validated marker, never a planted hardlink");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Private_Directory_Hardening'Access,
         "private directory creation reports collisions and rejects links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scavenger_Shutdown'Access, "scavenger shutdown reaps a stalled coordinator before returning");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Window_Job_Shutdown'Access, "closing one window stops its stalled jobs while another remains active");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Cleanup_Guards'Access,
         "transport cleanup refuses unmarked, leased, linked and replaced directories");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stage_Owner_Marker_Guards'Access,
         "stage cleanup rejects forged owner markers and retries the restored stage");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stage_Record_Cleanup'Access, "cleanup deletes only staging directories owned by its job");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Private_Record_Writes'Access, "private records are owner-only, never over an entry, never left half");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Helper_Mode_Flags'Access, "every helper flag reads back as its mode, and only those do");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stage_Markers_Outlast_Failed_Delete'Access,
         "a stage whose delete fails partway keeps its owner file and markers for the sweep");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Destructive_Helper_Lifecycle'Access,
         "destructive helpers preserve history and remain cancellable while stalled");
   end Register_Tests;

   procedure Test_Stage_Markers_Outlast_Failed_Delete (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Private_Record_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Mode_Flags (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Interrupted_Release_Resumes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Emptied_Stage_Swept (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unmarked_Stage_Survives_Sweep (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Held_Release_Marker_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sweep_Leaves_Registry_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stale_Background_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Result_Mismatch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Journal_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Job_Request_Path_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Job_Item_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Job_Item_Large_Account_Ids (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Operation_Result_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Move_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transfer_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replacement_Checkpoint_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovered_Checkpoint_Keeps_Result (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Truncated_Persisted_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Lease_Survives_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Exclusive_Stream_Hardlink (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Stream_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scavenger_Coordinator_Failures (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Lease_Claims (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unmarked_Transport_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unsafe_Recovery_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Private_Directory_Hardening (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scavenger_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Cleanup_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stage_Owner_Marker_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stage_Record_Cleanup (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Recovery_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Recovery;

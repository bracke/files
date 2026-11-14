with Files.Items;
with Files.Model.Testing;
with Files.File_Identities;
with Files.Process_Jobs;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Zlib;
with Hostkit.Host;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.History_Journal;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Model.History;
with Files.Operations;
with Files.Operations.Testing;
with Files.Paste;
with Hostkit.Fs;
with Files.Settings;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files.Model.Pasting;

package body Files_Suite.History is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Operations.Operation_Status;
   use type Files.Model.Undo_Action_Kind;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type History_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : History_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out History_Test_Case);

   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Undo_Covers_Every_Item (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Duplicate_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Same_Size_Edits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Move_Kept_Copy_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Kept_Copy_Undo_Notice (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Save_Replaces_Leftover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Journal_Fits_Large_Actions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unjournaled_List_Pruned (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_Undo_Restores_Access (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Release_History_Trashes_Originals (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : History_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files history");
   end Name;

   overriding procedure Register_Tests (T : in out History_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Refresh'Access,
         "Undo and Redo refresh normal and Recent views without invalidating themselves");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Chained_Rename_Undo'Access, "one Undo reverses a batch whose renames chain (b to c, then a to b)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Operations'Access, "undo restores the most recent rename");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Redo_History'Access,
         "multi-level undo unwinds LIFO, redo re-applies, and a new op clears redo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Save_Replaces_Leftover'Access,
         "A leftover history.tmp does not block saves");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Journal_Fits_Large_Actions'Access,
         "The history journal leaves out the oldest entries to fit");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Unjournaled_List_Pruned'Access,
         "a history's left-out list is pruned when restored and truncated, not refused, past its cap");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Symlink_Creation'Access, "a created symlink undoes and redoes symmetrically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Set_Permissions'Access, "chmod undoes to the old mode and redoes to the new mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permission_Undo_Restores_Access'Access,
         "a permission edit keeps inherited access and its undo restores the access it replaced");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Set_Ownership_Identity'Access, "identity chown undoes and redoes symmetrically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Paste_Move'Access, "a move paste undoes back and redoes forward");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Partial_Redo_Creation'Access, "partial copy and link Redo retries finish and restore Undo history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Partial_Redo_Move'Access, "partial move and rename Redo retries preserve completed steps");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Paste_Replace'Access,
         "undo of a replace paste restores the overwritten original and is not redoable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Release_History_Trashes_Originals'Access,
         "A closing window sends originals kept for Undo to the trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Set_Permissions_And_Undo'Access, "chmod changes selected item mode and undo restores it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Failed_Undo_Keeps_Entry'Access, "a partially failed undo keeps its entry instead of dropping it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_Item_Undo_Recompletes'Access,
         "a partially-applied multi-item undo re-completes on retry instead of failing forever");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replace_Undo_Retry'Access, "replacement Undo retries preserve originals already restored");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Creation_History'Access, "batch creation has one Undo entry and preserves replacement files");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Undo_Covers_Every_Item'Access,
         "a batch's throttled Undo records still end in one entry covering every item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Duplicate_Undo_Identity'Access, "Undo protects replaced files, folders and links across Redo cycles");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Same_Size_Edits'Access, "Undo refuses copies changed by a same-size edit with restored mtime");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Admits_Verified_Identities'Access,
         "history admits only entries with verifiable publication identities");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Undo_Identity'Access, "partial paste Undo never removes replacements of its entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Entry_Identity'Access, "rename and move Undo and Redo refuse unrelated replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Failed_Move_Kept_Copy_Undo'Access,
         "undo of a failed move's kept copy deletes the copy and leaves the source that stayed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Kept_Copy_Undo_Notice'Access,
         "a failed move whose kept copy cannot be undone reports its own failure, the lost Undo beside it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Metadata_History_Identity'Access, "metadata Undo and Redo refuse unrelated replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Metadata_History'Access, "metadata history records live modes and ownership");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_History_Identity'Access,
         "trash and paste-replace Undo refuse unrelated trash replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recorded_Restore_Targets'Access,
         "trash and replacement Undo retain original destinations after sidecar changes");
   end Register_Tests;

   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Duplicate_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Same_Size_Edits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Move_Kept_Copy_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Kept_Copy_Undo_Notice (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Undo_Covers_Every_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Save_Replaces_Leftover (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Journal_Fits_Large_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unjournaled_List_Pruned (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permission_Undo_Restores_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Release_History_Trashes_Originals (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new History_Test_Case));
      return Result;
   end Suite;

end Files_Suite.History;

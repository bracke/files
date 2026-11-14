with Files.Items;
with Files.Model.Testing;
with Files.File_Identities;
with Files.File_Identities.Testing;
with Files.Process_Jobs;
with Files.Job_Context;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with System;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Hostkit.Host;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Folder_Tree;
with Files.Model;
with Files.Model.Selection;
with Files.Model.History;
with Files.Operations;
with Files.Paste;
with Hostkit.Fs;
with Hostkit.Metadata;
with Hostkit.Metadata_Copy;
with Files.Settings;
with Files.Types;
with Files.Transfer_Jobs;
with Files.Transfer_Jobs.Testing;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files.Model.Pasting;
with Interfaces.C;

package body Files_Suite.Transfer is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Operations.Operation_Status;
   use type Interfaces.C.int;
   use type Interfaces.C.long_long;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type System.Address;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Transfer_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Transfer_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Transfer_Test_Case);

   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cross_Device_Move_Keeps_Setgid (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Source_Changes_Off_Volume (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Keeps_Source_Until_Copy_Synced (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Read_Only_Survives_Copy_And_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Without_Xattr_Support (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Encrypted_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Execution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Helper_Refused (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Replace_Paths_Agree (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Transfer_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files transfers");
   end Name;

   overriding procedure Register_Tests (T : in out Transfer_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Failed_Replace_Rollback'Access,
                "failed cross-device replacement restores its original without unusable history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Destination_Races'Access,
                "concurrent destination creation preserves unrelated files, directories and links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Publication_Journal_Failure'Access,
         "publication journal failure preserves completed copy/move results and Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_Replace_Recovery'Access, "native-backend replacement supports rollback recovery and Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Preserve_Puts_Original_Back'Access,
         "a preserve that fails after moving the original puts it back where it was");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Cancellation'Access, "a transfer cancels between chunks without losing its source");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Transfers'Access, "background transfers preserve content, ownership, and cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Helper_Refused'Access, "a background paste whose helper cannot start ends with an error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replace_Trash_Failure'Access, "a failed trash operation during Replace preserves the original");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Replace_Paths_Agree'Access,
         "foreground and helper pastes agree on a vanished replace target and a same-path move");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cross_Device_Recovery'Access,
         "cross-device move, trash, and restore failures preserve recoverable data");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Execution'Access, "drop import copies, moves and arms the conflict dialog");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Guards'Access, "drop import handles same-directory, into-self and same-name sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Tree_Preserves_Symlinks'Access,
         "Copy_Tree reproduces symlinks as links and does not explode on a cycle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Conflict_Resolution_Core'Access,
         "pure paste-conflict resolver honors replace/skip/rename/no-conflict policies");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Conflict_Flow'Access,
         "paste into a colliding directory prompts and resolves replace/skip/rename/apply-all/cancel/undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Case_Only_Paste_Conflicts'Access,
         "on a case-insensitive destination a name differing only by case conflicts, in any script");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Execution_Batches'Access,
         "the resumable paste executor advances in batches and records one undo over the whole set");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Execution_Cancel'Access,
         "cancelling a paste keeps completed files, skips the rest, and records undo only for completed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Execution_Small_Op'Access,
         "a one-item paste finishes in the first advance and leaves no execution state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Conflict_Flow'Access,
         "a colliding drag-and-drop import arms the conflict dialog, resolves replace/skip/rename, and undoes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Progress'Access,
         "a collision-free drag-and-drop import imports every source through the resumable executor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_To_Picker_Flow'Access,
         "copy-to opens the picker, copies to the chosen dir, keeps originals, and undo removes copies");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_To_Picker_Flow'Access,
         "move-to moves to the chosen dir, removes originals, and undo moves them back");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_To_Into_Self_Guard'Access,
         "copy-to into the selection reports the into-self error and changes nothing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_To_Cancel'Access,
         "cancelling the copy-to picker clears it and changes nothing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_To_Tree_Label_Sets_Target'Access,
         "a tree label click while picking sets the target without navigating the main view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drops_While_Busy'Access, "drops cannot replace active jobs or conflict dialogs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Failed_Move_Rollback'Access, "failed moves restore destinations without unusable history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Access_Bits'Access, "copies retain executable and ordinary access bits");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cross_Device_Move_Keeps_Setgid'Access,
         "a cross-device move keeps setgid with the owner");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Entry_Identity'Access, "lost helper metadata retains original creation identities");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Without_Read_Access'Access, "same-device moves do not read file contents");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Timestamps'Access, "copies and cross-device history moves preserve modification times");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Source_Changes'Access, "cross-device moves retain edited and replaced sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Source_Changes_Off_Volume'Access,
         "a folder moved off another volume keeps its source when a child changes during the copy, on FAT too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Keeps_Source_Until_Copy_Synced'Access,
         "cross-device moves remove the source only after the copy is synced");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Read_Only_Survives_Copy_And_Move'Access,
         "read-only files stay read-only when copied and moved across devices");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Without_Xattr_Support'Access,
         "a copy onto a volume without extended attributes succeeds without them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Result_Recovery'Access, "paste recovery retains original identities and replacement backups");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Private_Copy_Stages'Access,
         "copy staging and replacement recovery protect private payloads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Extended_Metadata'Access,
         "copies and cross-device moves retain access times, extended attributes and ACLs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Encrypted_File'Access,
         "copies and cross-device moves of encrypted files are encrypted from creation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Commit_Recovery'Access,
         "lost move results retain Undo when the source pathname is recreated");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Ownership'Access,
         "cross-device moves and history retain directory, file and symbolic link ownership");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Hard_Link_Trees'Access,
         "copies and cross-device moves preserve nested hard-link topology");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Staging_Default_ACL'Access,
         "private copy staging works with restrictive inherited default ACLs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Destination_Revalidation'Access,
         "copies and Redo refuse destinations redirected into their source trees");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Read_Only_Directory_Transfers'Access,
         "read-only directories retain their modes across copies, moves and history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sparse_Transfers'Access,
         "sparse copies and cross-device history retain holes, length and all bytes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Hard_Linked_Symbolic_Links'Access,
         "copies and cross-device moves preserve hard links to symbolic links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Mode_Failure'Access,
         "failed directory mode restoration retains recoverable originals");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Exclusive_New_Files'Access,
         "exclusive file creation refuses existing entries and symbolic links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Deep_Tree_Copy'Access,
         "deep copies complete safely and depth refusals clean staging");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Hard_Link_Copy'Access,
         "batch copies and retryable Redo retain hard links across selected roots");
   end Register_Tests;

   procedure Test_Drop_Import_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cross_Device_Move_Keeps_Setgid (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Source_Changes_Off_Volume (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Keeps_Source_Until_Copy_Synced (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Read_Only_Survives_Copy_And_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Without_Xattr_Support (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Encrypted_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Copy_Tree must reproduce symlinks as links, never dereference them: a link
   --  to an ancestor would otherwise recurse until PATH_MAX (a copy explosion),
   --  and any link would be replaced by a full copy of its target. Regression
   --  guard for the src/ symlink-preservation fix.
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Helper_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Replace_Paths_Agree (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The stage sync after the move fails (Files.Durability.Testing): the
   --  original must be at its own path again, not left hidden in the stage.
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Transfer_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Transfer;

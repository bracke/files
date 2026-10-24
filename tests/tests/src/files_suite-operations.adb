with Files.File_Identities;
with Files.File_Identities.Testing;
with Files.Job_Helpers;
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
with Files.Resources;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Interfaces;
with Interfaces.C.Strings;
with Files.Quick_Look;
with Files.Recovery_CLI;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Zlib;

with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Applications;
with Files.Archive_Writing;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Copy_Context;
with Files.Exclusive_Streams;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Features;
with Files.Folder_Size;
with Files.Folder_Tree;
with Files.Fonts;
with Files.History_Journal;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Operation_Jobs.Testing;
with Files.Icon_Assets;
with Files.Operations;
with Files.Paste;
with Files.Platform;
with Hostkit.Fs;
with Hostkit.Metadata;
with Hostkit.Metadata_Copy;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Files.Shared_Bytes;
with Guikit.Input;
with Files.Types;
with Files.Transfer_Jobs;
with Files.Transfer_Jobs.Testing;
with Files.UTF8;
with Files.UI;
with Files_Suite.Support;

package body Files_Suite.Operations is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;
   use type Hostkit.Host.Kind;
   use type Interfaces.Unsigned_32;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Command_Placement;
   use type Files.Private_Directories.Create_Result;
   use type Files.Job_Transports.Claim_Outcome;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Application.Run_Mode;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Guikit.Draw.Accessibility_Role;
   use type Guikit.Draw.Icon_Asset_Color_Role;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Atlas_Texture_Format;
   use type Guikit.Vulkan.Texture_Source;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Interfaces.C.long_long;
   use type Hostkit.Lease_Files.Open_Outcome;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.String_Vectors.Vector;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Search_Scope;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;
   use Files_Suite.Support;

   type Operation_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Operation_Test_Case);

   --  How long a call may take and still not have waited for a stalled helper.
   Prompt_Limit : constant Duration := Files_Suite.Support.Prompt_Limit;

   function Complete_Operation
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Started : Files.Operations.Operation_Result) return Files.Operations.Operation_Result
   is
      Result : Files.Operations.Operation_Result := Started;
   begin
      for Attempt in 1 .. 5_000 loop
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
         Result := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         if Files.Model.Paste_Execution_Is_Active (Model) then
            delay 0.001;
         end if;
      end loop;
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the background filesystem operation completes");
      return Result;
   end Complete_Operation;

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Pending_Create_Mutation_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Environment_Guard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Folder_Size_Matches_Reference
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Multi_Selection
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Selection_Total_Counts_Folders
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hardlink_Dangling_Symlink (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unreadable_Hardlink_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Rename_Flips_Case (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Size_Over_Links (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Fifo_Never_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Host_Hidden_Flag_Hides (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Journal_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Truncated_Persisted_Records (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Lease_Survives_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Crash_Transport_Scavenging (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stage_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files operations");
   end Name;

   overriding procedure Register_Tests (T : in out Operation_Test_Case) is
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
        (T, Test_Refresh_Error_Recovery'Access,
         "refresh recovery clears load errors and preserves operation errors and newer state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Refresh'Access, "background refresh applies matching snapshots and rejects stale reads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Registry_Bounded'Access,
         "verified deletes leave no recovery-registry record and stale records are reclaimed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Owed_Reloads'Access,
         "edits within a view discard stale background results but never the reload they owe");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Refresh'Access,
         "Undo and Redo refresh normal and Recent views without invalidating themselves");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Trash_Undo_Refresh'Access, "Undo immediately relists a Recent item restored from trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stalled_Refresh'Access, "stalled refresh and native watches never hold polling or paste cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Symlink_Recovery'Access, "trash, permanent delete and Undo operate on valid and dangling links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_Replace_Recovery'Access, "native-backend replacement supports rollback recovery and Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Released_Recovery_Goes_To_Trash'Access,
         "a replaced original kept for Undo goes to the trash under its own name when history ends");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Command_Line'Access,
         "--recover restores a payload, and --discard-recovery deletes only a recovery payload");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Preserve_Puts_Original_Back'Access,
         "a preserve that fails after moving the original puts it back where it was");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Operations'Access,
                "duplicate, archive, extract and recursive searches use cancellable helpers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Helper_Shutdown'Access, "closing a session never waits for blocked helper work");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Protocol_Gaps'Access,
         "transport creation crashes and cancellation failures retain safe recovery");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Journal_Validation'Access,
         "copy journals reject trailing transport data");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Job_Record_Validation'Access,
         "background records reject inconsistent redundant metadata");
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
        (T, Test_Crash_Transport_Scavenging'Access,
         "startup scavenging removes crashed and pre-release transports while preserving live jobs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Window_Job_Shutdown'Access, "closing one window stops its stalled jobs while another remains active");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stage_Ownership'Access, "cleanup deletes only staging directories owned by its job");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Cancellation'Access, "a transfer cancels between chunks without losing its source");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Transfers'Access, "background transfers preserve content, ownership, and cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replace_Trash_Failure'Access, "a failed trash operation during Replace preserves the original");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cross_Device_Recovery'Access,
         "cross-device move, trash, and restore failures preserve recoverable data");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Delete_Selected_Operation'Access, "delete operation moves selected item to trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash'Access, "restore operation returns trashed item to original path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash_Guards'Access,
         "restore refuses (keeping the payload) when the destination or its parent is unavailable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_Url_Round_Trip'Access,
         "restore decodes a percent/space name back to its exact original path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Operation'Access, "empty trash purges every trashed payload and sidecar");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Partial_Failure'Access, "empty trash removes what it can and reports partial failures");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Undo_Safe'Access, "undoing a restore whose emptied source is gone fails safely");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_Directory_Loads_Items'Access, "open directory loads and navigates");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_File_Prepares_Action'Access, "open file executes configured action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Missing_Open_Action_Reports_Error'Access, "missing open action reports localized error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_File'Access, "commit create-file temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_Folder'Access, "commit create-folder temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Does_Not_Overwrite'Access, "create-file refuses existing destination");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Advanced_Filesystem_Operations'Access, "advanced filesystem operations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Is_Per_User'Access,
         "the thumbnail cache lands in this host's user cache, not the browsed folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Is_Bounded'Access,
         "the thumbnail cache is pruned to its budget, oldest first");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Decode_Emoji_Png_From_Font'Access,
         "a real colour emoji picture decodes out of a real font");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permission_String_Agrees_With_The_Host'Access,
         "the permission column's execute bit matches what the host says");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Explicit_Thumbnail_Survives_The_Listing'Access,
         "a thumbnail generated for a non-image item is still shown when the directory is listed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_File_Operation_Names'Access, "file operation invalid names");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Leaf_Name_Rules'Access, "leaf-name rules are host-gated");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Expand_User_Path'Access, "a leading tilde in the path field expands to home");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Rename'Access, "commit rename mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Chained_Rename_Undo'Access, "one Undo reverses a batch whose renames chain (b to c, then a to b)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Labels_Forget_Deleted_And_Follow_Background'Access,
         "a permanent delete forgets labels and favorites, and a background Undo carries labels back");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Labels_Travel_Through_Trash'Access,
         "a trashed file's label goes into the trash with it, comes back on restore, and goes with Empty Trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Result_Actions_Stay_Beside_Source'Access,
         "renaming, duplicating or linking a search result keeps it in its own folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Multi_Rename'Access, "commit synchronized multi-rename best-effort");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Free_Space_Display_Cycle'Access,
         "the free-space field toggle cycles free -> used -> bar -> free");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Apply_Ui_State_Round_Trip'Access,
         "applying persisted UI state sets view and sort absolutely, even for the default field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Icon_Assets_Load_From_Disk'Access,
         "filetype icon definitions load from the bundled .icon files at runtime");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Metadata_Snapshot'Access, "info pane snapshot includes metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Section_Tooltips'Access, "info pane sections carry descriptive tooltips");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Coalesced_Multi'Access,
         "multi-selection info pane coalesces sections with one value row per item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Filesize_Files_Only'Access,
         "info pane Filesize section is shown only for files, dropped when all folders");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Total_In_Contents'Access,
         "combined selection total is the last line of the Contents section");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Extra_Is_Lazy'Access,
         "filetype extra (folder counts, document scans) is computed lazily, not on load");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Helper_Cancellation'Access,
         "stalled folder-size helpers allow prompt polling, retargeting and cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Is_Lazy'Access,
         "recursive folder size is requested for a selected folder and computed off the UI path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Folder_Size_Matches_Reference'Access,
         "background folder-size scan matches the synchronous Directory_Size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Multi_Selection'Access,
         "a multi-item selection caches each selected folder's recursive size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Selection_Total_Counts_Folders'Access,
         "the selection total counts selected folders' recursive size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Refresh_And_History_Loading'Access, "controller refresh and history load items");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Navigate_Parent_Operation'Access, "navigate parent moves up and records history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compress_Selected_Operation'Access, "compress selected items into zip and 7z archives");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Duplicate_Selected_Operation'Access, "duplicate selected item into a uniquely named copy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extract_Selected_Operation'Access, "extract selected archive into a new folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Operations'Access, "undo restores the most recent rename");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Redo_History'Access,
         "multi-level undo unwinds LIFO, redo re-applies, and a new op clears redo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Symlink_Creation'Access, "a created symlink undoes and redoes symmetrically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Set_Permissions'Access, "chmod undoes to the old mode and redoes to the new mode");
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
        (T, Test_Create_Symlink_Operation'Access, "create-symlink links the selected item and undo removes it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_Hardlink_Operation'Access, "create-hard-link links the selected file and undo removes it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Special_Entry_Metadata'Access,
         "links to folders and dangling links list without a metadata error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Hardlink_Dangling_Symlink'Access,
         "hard-link creation and Redo preserve dangling symbolic link entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Unreadable_Hardlink_History'Access,
         "unreadable hard links publish successfully and Redo waits for a safe snapshot");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detected_Terminal_Helper'Access, "detected terminal helper honors the TERMINAL override");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Available_Applications'Access, "open-with discovers and parses desktop applications");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Toggle_Hidden_Files'Access, "toggle hidden files persists and reloads with new visibility");
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
        (T, Test_Case_Only_Rename_Is_Safe'Access,
         "a case-only rename never loses data and distinct collisions stay refused");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Case_Only_Rename_Flips_Case'Access,
         "renaming report.txt to Report.txt changes the case, on a case-insensitive volume too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permission_Grid_Click'Access, "info-pane permission cell click toggles the mode bit");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Set_Ownership_Identity_And_Undo'Access,
         "chown to the file's own uid/gid succeeds, records undo, and undo restores");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Set_Ownership_Denied'Access,
         "chown to a different owner is denied for a non-root process without changing the file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ownership_Name_Resolution'Access,
         "user/group name resolution finds known names and rejects bogus ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ownership_Edit_Through_Reducer'Access,
         "info-pane ownership click focuses the editor and Enter commits the identity change");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recursive_Folder_Size'Access, "recursive folder size sums descendant files and surfaces the row");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Tree_Preserves_Symlinks'Access,
         "Copy_Tree reproduces symlinks as links and does not explode on a cycle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Size_Over_Links'Access,
         "folder size counts a link once and never follows a cycle, a dangling link or a link out of the tree");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Fifo_Never_Blocks'Access,
         "a FIFO lists, searches, previews, thumbnails and copies without blocking anything");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Host_Hidden_Flag_Hides'Access,
         "a file the host marks hidden (or a dot file) is hidden in the listing and counted as hidden");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Conflict_Resolution_Core'Access,
         "pure paste-conflict resolver honors replace/skip/rename/no-conflict policies");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Conflict_Flow'Access,
         "paste into a colliding directory prompts and resolves replace/skip/rename/apply-all/cancel/undo");
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
        (T, Test_Recent_View_Operation'Access,
         "recent view lists stored paths (missing skipped), records opens, and clears");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Duplicate'Access, "Recent duplicates stay beside each source and retain the view and Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Content_Search_Operation'Access,
         "content search matches file contents case-insensitively, skips binary and capped files, "
         & "and drives the scope model");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Archive_Completeness'Access,
         "archives fail instead of silently omitting selected sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Archive_Destinations'Access,
         "Recent archives publish beside their sources and preserve the working directory");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Window_Folder_Measurements'Access,
         "window size helpers are independent and refresh invalidates cached measurements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Destructive_Helper_Lifecycle'Access,
         "destructive helpers preserve history and remain cancellable while stalled");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Creation_History'Access, "batch creation has one Undo entry and preserves replacement files");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Pending_Create_Mutation_Guards'Access,
         "pending inline creation blocks direct selection mutations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drops_While_Busy'Access, "drops cannot replace active jobs or conflict dialogs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Refresh'Access, "empty metadata is cached and info panes preserve manual refreshes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Archive_Directories'Access, "ZIP and 7z preserve nested empty and directory-only selections");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Failed_Move_Rollback'Access, "failed moves restore destinations without unusable history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Input_Snapshot'Access, "search input is modal and stale outcomes are discarded");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Read_Errors'Access, "unreadable searches fail without replacing the listing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Selection_Completion'Access, "keyboard selection and completed refresh populate info metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Entry_Identity'Access, "Undo protects replaced files, folders and links across Redo cycles");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Keeps_Place'Access,
         "a refresh keeps the scroll and Quick Look, and waits while the palette is open");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Navigation_Defers_Thumbnails'Access,
         "opening a folder never waits on new thumbnails: a background listing makes them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Access_Bits'Access, "copies retain executable and ordinary access bits");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recovery_Entry_Identity'Access, "lost helper metadata retains original creation identities");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Entry_Identity'Access, "rename and move Undo and Redo refuse unrelated replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Without_Read_Access'Access, "same-device moves do not read file contents");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Timestamps'Access, "copies and cross-device history moves preserve modification times");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Source_Changes'Access, "cross-device moves retain edited and replaced sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Metadata_History_Identity'Access, "metadata Undo and Redo refuse unrelated replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Metadata_History'Access, "metadata history records live modes and ownership");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Result_Recovery'Access, "paste recovery retains original identities and replacement backups");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Private_Copy_Stages'Access,
         "copy staging and replacement recovery protect private payloads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_History_Identity'Access,
         "trash and paste-replace Undo refuse unrelated trash replacements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Extended_Metadata'Access,
         "copies and cross-device moves retain access times, extended attributes and ACLs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Move_Commit_Recovery'Access,
         "lost move results retain Undo when the source pathname is recreated");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recorded_Restore_Targets'Access,
         "trash and replacement Undo retain original destinations after sidecar changes");
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
        (T, Test_Trash_Source_Verification'Access,
         "cross-device trash retains edited and replaced sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Exclusive_New_Files'Access,
         "exclusive file creation refuses existing entries and symbolic links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Deep_Tree_Copy'Access,
         "deep copies complete safely and depth refusals clean staging");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Environment_Guard'Access, "the test environment guard restores variables, on an exception too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Hard_Link_Copy'Access,
         "batch copies and retryable Redo retain hard links across selected roots");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Hidden'Access, "Empty Trash purges hidden payloads regardless of display preferences");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Limit_Errors'Access, "search limits fail without presenting incomplete or empty results");
   end Register_Tests;

   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Thumbnails are a regenerable per-user cache and belong in the user's cache
   --  area. The resolver consulted only XDG_CACHE_HOME and HOME, and on Windows
   --  neither is normally set, so it fell through to its last resort: a hidden
   --  .files-thumbnails directory written into whichever folder was being
   --  browsed -- in the user's own data, and listed back to them. The guard that
   --  matters on every host is the last assertion: given somewhere to put a
   --  cache, it never picks the browsed folder.
   --  The cache used to grow without limit: nothing ever deleted a thumbnail,
   --  so it kept one file per image ever browsed, plus every orphan whose source
   --  had since been renamed or deleted.
   --  The permission column takes the execute bit from the item's Kind instead
   --  of asking the host a second time, which is only sound while the
   --  classifiers keep implying it. This is what notices if that stops being
   --  true: without it the column would quietly disagree with the filesystem.
   --  The listing reads the thumbnail cache's own directory once instead of
   --  stat-ing a cache path per entry. The tempting cheaper version -- ask "is
   --  this an image?" first and skip the lookup when it is not -- is wrong, and
   --  this is the case that makes it wrong: Generate_Selected_Thumbnails has no
   --  image gate, so the thumbnail command will happily produce one for a text
   --  file, and the listing has to keep showing it. Reading what is actually in
   --  the cache keeps that true; guessing from the filetype would not.
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Decode a real colour emoji picture out of a real font.
   --
   --  Textrender reads where the picture is and hands out the bytes; this is the
   --  other side of that seam, and until it worked the colour glyph path had only
   --  ever been driven by a stub returning a known pattern. The bytes here are
   --  whatever Noto Color Emoji actually contains.
   --
   --  Skipped when the font is not installed, so a missing font is not a failure.
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Each info-pane section label carries a descriptive hover tooltip drawn from
   --  its "<key>.tooltip" catalog entry.
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Clicking the free-space field cycles its display: free -> used -> bar ->
   --  free, tracked by the Show_Used_Space / Show_Space_Bar settings.
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  With several items selected the info pane is coalesced field-major: each
   --  section label is drawn once (not repeated per item) and each selected
   --  item's value follows as its own row.
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Filesize is a file-only field: folders show nothing for it, and when every
   --  selected item is a folder the section is dropped entirely. The label is
   --  "Filesize" in the default catalog.
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The combined selection total is the last line of the Contents section
   --  (below the Contents label and the per-folder rows), not a header above the
   --  sections.
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The expensive "extra info" (folder child counts, document scans) must not
   --  be computed on load -- that made navigation slow. It is computed lazily
   --  only for the selected item when the info pane is open.
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Await_View (Model : in out Files.Model.Window_Model; Settings : Files.Settings.Settings_Model) is
      Applied : Boolean;
      pragma Unreferenced (Applied);
   begin
      for Attempt in 1 .. 5_000 loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings);
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         delay 0.001;
      end loop;
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "the operation's reload completes");
   end Await_View;

   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Metadata_Mode_Of (Path : String) return Natural is
      Available : Boolean;
      Mode : constant Natural := Files.File_System.Permission_Bits_Of (Path, Available);
   begin
      Assert (Available, "metadata mode is available");
      return Mode;
   end Metadata_Mode_Of;

   function Is_Owner_Only (Path : String) return Boolean is
      Mode  : constant Natural := Metadata_Mode_Of (Path);
      Owner : constant Natural := (Mode / 8#100#) mod 8;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         return not Hostkit.Fs.Directory_Accessible_By_Others (Path);
      end if;
      return Owner in 6 | 7 and then Mode mod 8#100# = 0;
   end Is_Owner_Only;

   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Environment_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Pending_Create_Mutation_Guards
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      type Mutation_Kind is
        (Duplicate_Item, Compress_Item, Extract_Item,
         Create_Symbolic_Link, Create_Hard_Link);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Routed : Files.Controller.Controller_Result;
   begin
      for Background in Boolean loop
         for Kind in Mutation_Kind loop
            Reset_Root;
            Write_Binary_File (Join (Root, "source.zip"), "not an archive");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Begin_Create_File (Model, "pending.txt");
            Files.Model.Toggle_Visible_Selection (Model, 1);
            Assert
              (Files.Model.Selection_Includes_Temporary (Model)
               and then Files.Model.Selected_Count (Model) = 2,
               "prepare a real-plus-temporary mixed selection");

            Step :=
              (case Kind is
                  when Duplicate_Item =>
                    Files.Operations.Duplicate_Selected (Model, Settings),
                  when Compress_Item =>
                    Files.Operations.Compress_Selected
                      (Model, Settings, Files.Operations.Zip_Archive),
                  when Extract_Item =>
                    Files.Operations.Extract_Selected (Model, Settings),
                  when Create_Symbolic_Link =>
                    Files.Operations.Create_Symlink_Selected (Model, Settings),
                  when Create_Hard_Link =>
                    Files.Operations.Create_Hardlink_Selected (Model, Settings));
            Assert
              (Step.Status = Files.Operations.Operation_Disabled
               and then Files.Model.Last_Error_Key (Model) = "error.create.pending"
               and then Files.Model.Temporary_Item_Is_Active (Model)
               and then not Files.Model.Undo_Available (Model)
               and then not Files.Process_Jobs.Active
                 (Files.Model.Background_Operation (Model))
               and then not Ada.Directories.Exists (Join (Root, "source (copy).zip"))
               and then not Ada.Directories.Exists (Join (Root, "source (1).zip"))
               and then not Ada.Directories.Exists (Join (Root, "source"))
               and then not Ada.Directories.Exists (Join (Root, "source (link).zip"))
               and then not Hostkit.Fs.Is_Link (Join (Root, "source (link).zip")),
               "direct selection mutations preserve a pending inline creation");

            if Kind = Duplicate_Item then
               Routed := Files.Controller.Execute_Command
                 (Files.Commands.Duplicate_Selected_Command, Model, Settings);
               Assert
                 (Routed.Status = Files.Controller.Controller_Ignored
                  and then Routed.Operation.Status = Files.Operations.Operation_Disabled
                  and then To_String (Routed.Operation.Error_Key) = "error.create.pending",
                  "the disabled command reports the pending edit instead of failing silently");
            end if;
         end loop;
      end loop;

      --  Clipboard paste, native file drops, and item-targeted drops all share
      --  Begin_Paste_To. None may write underneath the active inline editor.
      Reset_Root;
      Ada.Directories.Create_Directory (Join (Root, "inbox"));
      Ada.Directories.Create_Directory (Join (Root, "view"));
      Write_Binary_File (Join (Join (Root, "inbox"), "incoming.txt"), "incoming");
      Load := Files.File_System.Load_Directory (Join (Root, "view"), Settings);
      Files.Model.Initialize (Model, Join (Root, "view"), Load.Items, Root);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      declare
         Sources : Files.Types.String_Vectors.Vector;
         Outcome : Files.Controller.Controller_Result;
      begin
         Sources.Append
           (To_Unbounded_String (Join (Join (Root, "inbox"), "incoming.txt")));
         Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
         Assert
           (Step.Status = Files.Operations.Operation_Disabled
            and then To_String (Step.Error_Key) = "error.create.pending"
            and then Files.Model.Temporary_Item_Is_Active (Model)
            and then not Files.Model.Paste_Execution_Is_Active (Model)
            and then not Files.Model.Paste_Conflict_Is_Active (Model)
            and then not Ada.Directories.Exists
              (Join (Join (Root, "view"), "incoming.txt")),
            "clipboard paste cannot write beneath a pending inline creation");
         Outcome := Files.Controller.Handle_Drop_Import
           (Model, Settings, Sources);
         Assert
           (Outcome.Operation.Status = Files.Operations.Operation_Disabled
            and then To_String (Outcome.Operation.Error_Key) = "error.create.pending"
            and then Files.Model.Temporary_Item_Is_Active (Model)
            and then not Ada.Directories.Exists
              (Join (Join (Root, "view"), "incoming.txt")),
            "external drops share the pending-create paste guard");
         Step := Files.Operations.Begin_Paste_To
           (Model, Settings, Sources, Join (Root, "view"),
            Files.File_System.Drop_Move, From_Clipboard => False);
         Assert
           (Step.Status = Files.Operations.Operation_Disabled
            and then Ada.Directories.Exists
              (Join (Join (Root, "inbox"), "incoming.txt"))
            and then not Ada.Directories.Exists
              (Join (Join (Root, "view"), "incoming.txt")),
            "targeted moves preserve both the pending editor and their source");
      end;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Pending_Create_Mutation_Guards;

   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Folder sizes used by the info pane and selection total are requested from
   --  Files.Folder_Size. Selecting a folder must leave the recursive walk to the
   --  helper and publish the completed result on a later frame.
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The background scan must produce exactly the same totals as the
   --  synchronous Directory_Size for a subtree within the entry/depth guards.
   procedure Test_Background_Folder_Size_Matches_Reference
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tree      : constant String := Join (Root, "tree");
      Deep      : constant String := Join (Join (Tree, "a"), "b");
      Reference : Files.File_System.Directory_Size_Result;
      Path      : Ada.Strings.Unbounded.Unbounded_String;
      Result    : Files.File_System.Directory_Size_Result;
      Available : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Deep);
      Ada.Directories.Create_Path (Join (Tree, "c"));
      --  4 files totalling 21 bytes across 3 nested directories (a, a/b, c).
      Write_Binary_File (Join (Tree, "root.txt"), "12345");            --  5 bytes
      Write_Binary_File (Join (Join (Tree, "a"), "mid.bin"), "0123456789");  --  10 bytes
      Write_Binary_File (Join (Deep, "leaf.dat"), "z");               --  1 byte
      Write_Binary_File (Join (Join (Tree, "c"), "note.md"), "hello"); --  5 bytes

      Reference := Files.File_System.Directory_Size (Tree);

      Files.Folder_Size.Cancel;
      Files.Folder_Size.Request (Tree);
      loop
         Files.Folder_Size.Step (Budget => 100_000);
         Files.Folder_Size.Take (Path, Result, Available);
         exit when Available or else not Files.Folder_Size.Is_Active;
         delay 0.001;
      end loop;

      Assert (Available, "background scan produced a finished result");
      Assert (Ada.Strings.Unbounded.To_String (Path) = Tree,
              "result path matches the requested root");
      Assert (Result.Available = Reference.Available
                and then Result.Total_Bytes = Reference.Total_Bytes
                and then Result.File_Count = Reference.File_Count
                and then Result.Item_Count = Reference.Item_Count
                and then Result.Capped = Reference.Capped,
              "background totals equal Directory_Size for the same tree");
      --  Independent check of the constructed tree: 4 files, 21 bytes,
      --  4 files + 3 directories = 7 visited items, within the guards.
      Assert (Reference.Available
                and then Reference.File_Count = 4
                and then Reference.Total_Bytes = 21
                and then Reference.Item_Count = 7
                and then not Reference.Capped,
              "reference totals match the constructed tree; got files="
                & Natural'Image (Reference.File_Count)
                & " bytes=" & Long_Long_Integer'Image (Reference.Total_Bytes)
                & " items=" & Natural'Image (Reference.Item_Count));
   end Test_Background_Folder_Size_Matches_Reference;

   --  A multi-item selection measures every selected directory: each folder's
   --  recursive size is cached under its own path so the info pane can show a
   --  per-folder size and a combined selection total.
   procedure Test_Folder_Size_Multi_Selection
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Dir_A    : constant String := Join (Root, "a");
      Dir_B    : constant String := Join (Root, "b");
      Path      : Ada.Strings.Unbounded.Unbounded_String;
      Result    : Files.File_System.Directory_Size_Result;
      Available : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir_A);
      Ada.Directories.Create_Path (Dir_B);
      Write_Binary_File (Join (Dir_A, "one.bin"), "12345");         --  5 bytes
      Write_Binary_File (Join (Dir_B, "two.bin"), "0123456789");    --  10 bytes
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Cancel_Folder_Scan (Model);

      --  Select both folders with the info pane open, then request their sizes.
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "both folders are selected");
      Files.Operations.Update_Folder_Size (Model, Settings);

      --  Drive both queued walks to completion, publishing each result as the
      --  frame loop's Poll_All_Folder_Sizes would.
      loop
         Files.Model.Poll_Folder_Sizes (Model);
         exit when not Files.Model.Folder_Scan_Is_Active (Model);
         delay 0.001;
      end loop;

      Assert (Files.Model.Folder_Size_Cached_For (Model, Dir_A)
                and then Files.Model.Folder_Size_Cached_For (Model, Dir_B),
              "each selected folder has its own cached size");
      Assert (Files.Model.Folder_Size_Value (Model, Dir_A).Total_Bytes = 5
                and then Files.Model.Folder_Size_Value (Model, Dir_B).Total_Bytes = 10,
              "per-folder sizes are the recursive totals of each folder");
   end Test_Folder_Size_Multi_Selection;

   --  The combined selection total (shown in the bottom bar) counts the recursive
   --  size of selected folders, not just selected files -- and it is computed for
   --  any selection, independent of the info pane.
   procedure Test_Selection_Total_Counts_Folders (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Mode_Of (Path : String) return Natural is
      Available : Boolean := False;
      Bits      : constant Natural := Files.File_System.Permission_Bits_Of (Path, Available);
   begin
      Assert (Available, "permission bits are readable for " & Path);
      return Bits mod 8#1000#;
   end Mode_Of;

   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  On a case-insensitive volume report.txt and Report.txt are one file, so
   --  the rename must go through a scratch name. The macOS and Windows
   --  runners' own disks are case-insensitive; where a macOS one is not, a
   --  small case-insensitive disk image stands in. Linux checks the plain case.
   procedure Test_Case_Only_Rename_Flips_Case (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Copy_Tree must reproduce symlinks as links, never dereference them: a link
   --  to an ancestor would otherwise recurse until PATH_MAX (a copy explosion),
   --  and any link would be replaced by a full copy of its target. Regression
   --  guard for the src/ symlink-preservation fix.
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  A FIFO opened for reading blocks until a writer arrives, so every path
   --  that reads a listed entry must refuse it or open it without waiting.
   procedure Test_Host_Hidden_Flag_Hides (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Fifo_Never_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Directory_Size_Over_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Hardlink_Dangling_Symlink
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir : constant String := Join (Root, "symlink-hardlink");
      Source : constant String := Join (Dir, "dangling");
      Direct_Link : constant String := Join (Dir, "direct");
      Link_Path : constant String := Join (Dir, "dangling (link)");
      Occupied : constant String := Join (Dir, "occupied");
      Mutation : Files.File_System.Mutation_Result;
      Load : Files.File_System.Directory_Load_Result;
      Model : Files.Model.Window_Model;
      Routed : Files.Controller.Controller_Result;
      Step : Files.Operations.Operation_Result;
      Target : Unbounded_String;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Special_Entry_Metadata", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Assert (Hostkit.Fs.Create_Link ("missing-target", Source),
              "prepare a dangling symbolic link source");
      Mutation := Files.File_System.Create_Hard_Link (Source, Direct_Link);
      Assert (Mutation.Success and then Hostkit.Fs.Is_Link (Direct_Link)
                and then Files.File_Identities.Token (Direct_Link) = Files.File_Identities.Token (Source),
              "direct creation hard-links the symbolic link entry itself");
      Assert (Hostkit.Fs.Read_Link_Target (Direct_Link, Target)
                and then To_String (Target) = "missing-target",
              "the direct hard link retains the unresolved target text");

      Assert (Hostkit.Fs.Create_Link ("missing-target", Occupied),
              "prepare a dangling destination collision");
      Mutation := Files.File_System.Create_Directory (Occupied);
      Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.exists"
                and then Hostkit.Fs.Is_Link (Occupied),
              "folder creation identifies and preserves a dangling link collision");
      Mutation := Files.File_System.Create_Symbolic_Link (Source, Occupied);
      Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.exists",
              "symbolic-link creation identifies a dangling link collision");
      Mutation := Files.File_System.Create_Hard_Link (Source, Occupied);
      Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.exists",
              "hard-link creation identifies a dangling link collision");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "dangling");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success
                and then Hostkit.Fs.Is_Link (Link_Path),
              "the selected dangling link can be hard-linked");
      Assert (Files.Model.Undo_Available (Model), "the created link has Undo history");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success
                and then not Hostkit.Fs.Is_Link (Link_Path)
                and then Hostkit.Fs.Is_Link (Source),
              "Undo removes only the new symbolic link entry");
      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success
                and then Hostkit.Fs.Is_Link (Link_Path)
                and then Files.File_Identities.Token (Link_Path) = Files.File_Identities.Token (Source),
              "Redo recreates a hard link to the same symbolic link inode");
   end Test_Hardlink_Dangling_Symlink;

   procedure Test_Unreadable_Hardlink_History
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir : constant String := Join (Root, "unreadable-hardlink");
      Source : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Load : Files.File_System.Directory_Load_Result;
      Model : Files.Model.Window_Model;
      Routed : Files.Controller.Controller_Result;
      Step : Files.Operations.Operation_Result;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip ("Test_Special_Entry_Metadata", "not Hostkit.Metadata.Mode_Bits_Are_Native");
         return;
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "hard link contents");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success,
              "readable hard link is created");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success,
              "hard link is removed before Redo");
      Assert (Files.File_System.Set_Permissions (Source, 0).Success,
              "source permissions can be removed");

      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Failed,
              "Redo refuses an unreadable hard link before publication");
      Assert (not Ada.Directories.Exists (Link_Path),
              "failed Redo leaves no hard link behind");
      Assert (Files.File_System.Set_Permissions (Source, 8#644#).Success,
              "source permissions can be restored");
      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success,
              "Redo can retry after the source becomes readable");
      Assert (Ada.Directories.Exists (Link_Path), "retry publishes the hard link");

      Files.Model.Clear_Undo (Model);
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "hard link contents");
      Assert (Files.File_System.Set_Permissions (Source, 0).Success,
              "new source permissions can be removed");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success,
              "creating an unreadable hard link reports success");
      Assert (Ada.Directories.Exists (Link_Path),
              "unreadable hard link is actually published");
      Assert (not Files.Model.Undo_Available (Model),
              "unsafe deletion is not recorded as Undo");
      Assert (Files.File_System.Set_Permissions (Source, 8#644#).Success,
              "new source permissions can be restored");
   end Test_Unreadable_Hardlink_History;

   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Operation_Test_Case));
      return Result;
   end Suite;

   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Confirm the destination picker through the real interaction reducer.
   procedure Confirm_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      IR : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => (Kind => Files.Events.Tree_Pick_Confirm_Input_Action, others => <>),
         Current_Font_Size => 16,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => IR);
   end Confirm_Pick;

   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The stage sync after the move fails (files_test_metadata.c): the
   --  original must be at its own path again, not left hidden in the stage.
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Journal_Validation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Batch    : constant Files.Copy_Context.Session :=
        Files.Copy_Context.Borrow (Root);
      Expected : Files.Types.String_Vectors.Vector;
      Actual   : Files.Types.String_Vectors.Vector;
      File     : Ada.Streams.Stream_IO.File_Type;
      Rejected : Boolean := False;
      Victim   : constant String := Join (Root, "copy-journal-victim");
      Source   : constant String := Join (Root, "copy-journal-source");
      Target   : constant String := Join (Root, "copy-journal-target");
      Result   : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      begin
         declare
            Invalid : constant Files.Copy_Context.Session :=
              Files.Copy_Context.Borrow ("relative-copy-batch");
            pragma Unreferenced (Invalid);
         begin
            null;
         end;
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject a relative borrowed directory");
      Rejected := False;
      begin
         declare
            Invalid : constant Files.Copy_Context.Session :=
              Files.Copy_Context.Borrow
                (Root & Character'Val (0) & "copy-batch");
            pragma Unreferenced (Invalid);
         begin
            null;
         end;
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject a NUL-containing borrowed directory");
      Rejected := False;

      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Files.Copy_Context.Save (Batch, Expected);
      Actual := Files.Copy_Context.Records (Batch);
      Assert (Actual = Expected, "a complete copy journal round-trips");

      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Join (Root, "links"));
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), True);
      Ada.Streams.Stream_IO.Close (File);
      begin
         Actual := Files.Copy_Context.Records (Batch);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject trailing bytes");

      Ada.Directories.Delete_File (Join (Root, "links"));
      Write_Binary_File (Victim, "protected copy journal");
      if Hostkit.Fs.Create_Hard_Link (Victim, Join (Root, "links")) then
         Rejected := False;
         begin
            Actual := Files.Copy_Context.Records (Batch);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected
            and then File_Has_Bytes (Victim, "protected copy journal"),
            "copy journal reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Join (Root, "links"));
      end if;

      Expected.Clear;
      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("source-revision"));
      Expected.Append (To_Unbounded_String ("source-digest"));
      Expected.Append (To_Unbounded_String ("relative-destination"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Expected.Append (To_Unbounded_String ("destination-revision"));
      Files.Copy_Context.Save (Batch, Expected);
      Write_Binary_File (Source, "copy me");
      Result := Files.File_System.Copy_Tree (Source, Target, Batch);
      Assert
        (not Result.Success and then not Ada.Directories.Exists (Target),
         "copy journals reject relative persisted hard-link paths before copying");

      if Hostkit.Fs.Create_Link (Victim, Join (Root, "links.tmp")) then
         Write_Binary_File (Victim, "preserve me");
         Rejected := False;
         begin
            Files.Copy_Context.Save (Batch, Expected);
         exception
            when Ada.Directories.Use_Error => Rejected := True;
         end;
         Assert
           (Rejected and then File_Has_Bytes (Victim, "preserve me"),
            "copy journals refuse a temporary symlink without truncating its target");
         declare
            Removed : constant Boolean :=
              Hostkit.Fs.Delete_Link (Join (Root, "links.tmp"));
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Copy_Journal_Validation;

   procedure Test_Job_Record_Validation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "invalid-job-items");
      File     : Ada.Streams.Stream_IO.File_Type;
      Items    : Files.File_System.Item_Vectors.Vector;
      Item     : Files.File_System.Directory_Item;
      Signature : Files.File_System.Directory_Signature;
      Result   : Files.Operations.Operation_Result;
      Transfer_Result : Files.Transfer_Jobs.Job_Result;
      Transfer_Path   : constant String := Join (Root, "invalid-transfer-result");
      Transfer_Target : constant String := Join (Root, "linked-transfer-result");
      Transfer_Request_Path : constant String := Join (Root, "invalid-transfer-request");
      Transfer_Request_Target : constant String := Join (Root, "linked-transfer-request");
      Transfer_Action : Files.Paste.Resolved_Action;
      Replacement_Backup : constant String := Join (Root, "replacement-backup");
      Replacement_Record : constant String := Join (Root, "replacement-record");
      Replacement_Target : constant String := Join (Root, "replacement-target");
      Rejected : Boolean := False;

      procedure Write_Replacement_Record (Record_Path : String) is
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         String'Output
           (Ada.Streams.Stream_IO.Stream (File), Replacement_Backup);
         String'Output
           (Ada.Streams.Stream_IO.Stream (File),
            Files.File_Identities.Token (Replacement_Backup));
         Ada.Streams.Stream_IO.Close (File);
      end Write_Replacement_Record;

      procedure Write_Raw_Items
        (Record_Path : String;
         Value       : Files.File_System.Directory_Item)
      is
         Stream : Ada.Streams.Stream_IO.Stream_Access;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         Stream := Ada.Streams.Stream_IO.Stream (File);
         Natural'Output (Stream, 1);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Name), Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Full_Path), Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Parent_Path), Files.Job_Records.Max_Path_Length);
         Files.Types.Item_Kind'Output (Stream, Value.Kind);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Filetype), Files.Job_Records.Max_Text_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Icon_Id), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Size_Available);
         Long_Long_Integer'Output (Stream, Value.Size);
         Boolean'Output (Stream, Value.Creation_Available);
         Ada.Calendar.Time'Output (Stream, Value.Creation_Time);
         Boolean'Output (Stream, Value.Modified_Available);
         Ada.Calendar.Time'Output (Stream, Value.Modified_Time);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Permissions), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Mode_Available);
         Natural'Output (Stream, Value.Mode_Bits);
         Boolean'Output (Stream, Value.Ownership_Available);
         Natural'Output (Stream, Value.Owner_Id);
         Natural'Output (Stream, Value.Group_Id);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Filetype_Extra), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Filetype_Extra_Loaded);
         Boolean'Output (Stream, Value.Thumbnail_Available);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Thumbnail_Path), Files.Job_Records.Max_Path_Length);
         Natural'Output (Stream, Value.Thumbnail_Width);
         Natural'Output (Stream, Value.Thumbnail_Height);
         Natural'Output (Stream, Files.Shared_Bytes.Length (Value.Thumbnail_Pixels));
         for Byte of Files.Shared_Bytes.To_Vector (Value.Thumbnail_Pixels) loop
            Interfaces.Unsigned_8'Output (Stream, Byte);
         end loop;
         Boolean'Output (Stream, Value.Metadata_Error);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Error_Key), Files.Job_Records.Max_Error_Length);
         Ada.Streams.Stream_IO.Close (File);
      end Write_Raw_Items;

      procedure Write_Raw_Signature
        (Record_Path : String;
         Value       : Files.File_System.Directory_Signature)
      is
         Stream : Ada.Streams.Stream_IO.Stream_Access;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         Stream := Ada.Streams.Stream_IO.Stream (File);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Path), Files.Job_Records.Max_Path_Length);
         Boolean'Output (Stream, Value.Exists);
         Natural'Output (Stream, Value.Entry_Count);
         Natural'Output (Stream, Value.Entry_State_Checksum);
         Ada.Calendar.Time'Output (Stream, Value.Latest_Modified);
         Boolean'Output (Stream, Value.Latest_Modified_Known);
         Ada.Streams.Stream_IO.Close (File);
      end Write_Raw_Signature;
   begin
      Reset_Root;

      Assert
        (Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => False)
         and then Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           ("", "", Recent => True),
         "refresh requests accept real absolute roots and the synthetic Recent view");
      Assert
        (not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           ("relative-root", Root, Recent => False)
         and then not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, "relative-signature", Recent => False)
         and then not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => True),
         "refresh requests reject relative or contradictory path state");
      Assert
        (Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           (Root, Recent => False)
         and then Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           ("", Recent => True)
         and then not Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           ("relative-root", Recent => False)
         and then not Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           (Root, Recent => True),
         "operation requests distinguish real roots from the synthetic Recent view");
      Assert
        (Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid (Root)
         and then not Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid
           ("relative-watch")
         and then not Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid
           (Root & Character'Val (0) & "ignored"),
         "watch requests require absolute NUL-free paths");

      Signature.Path := To_Unbounded_String ("relative-signature");
      Write_Raw_Signature (Path, Signature);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Signature := Files.Job_Records.Read_Signature
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "decoded directory signatures reject relative operational paths");

      Signature.Path := To_Unbounded_String
        (Root & Character'Val (0) & "ignored");
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Path);
      Rejected := False;
      begin
         Files.Job_Records.Write_Signature
           (Ada.Streams.Stream_IO.Stream (File), Signature);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "directory signatures with NUL-containing paths are not serialized");

      Item.Thumbnail_Available := True;
      Item.Thumbnail_Width := Natural'Last;
      Item.Thumbnail_Height := 1;
      Item.Thumbnail_Pixels := Files.Shared_Bytes.To_Shared ([1 => 0]);
      Items.Append (Item);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      begin
         Files.Job_Records.Write_Items
           (Ada.Streams.Stream_IO.Stream (File), Items);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "invalid thumbnail dimensions are not serialized");

      Item := Files.File_System.Make_Item
        (Root, "transport-item", Files.Types.Regular_File_Item);
      Item.Full_Path := To_Unbounded_String ("relative-transport-item");
      Write_Raw_Items (Path, Item);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Items := Files.Job_Records.Read_Items
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "decoded job items reject relative operational paths");

      Item.Full_Path := To_Unbounded_String (Join (Root, "transport-item"));
      Item.Parent_Path := To_Unbounded_String
        (Root & Character'Val (0) & "ignored");
      Items.Clear;
      Items.Append (Item);
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Path);
      Rejected := False;
      begin
         Files.Job_Records.Write_Items
           (Ada.Streams.Stream_IO.Stream (File), Items);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "job items with NUL-containing parent paths are not serialized");

      Result.Action.Executable := To_Unbounded_String ("viewer");
      Result.Action_Executable := To_Unbounded_String ("different-viewer");
      Rejected := False;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      begin
         Files.Job_Records.Write_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File), Result);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "inconsistent action metadata is not serialized");

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Operations.Operation_Status'Output
        (Ada.Streams.Stream_IO.Stream (File), Files.Operations.Operation_Success);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Error_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "", Files.Job_Records.Max_Path_Length);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "viewer", Files.Job_Records.Max_Path_Length);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "file.txt");
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Files.Job_Records.Write_String
        (Ada.Streams.Stream_IO.Stream (File), "viewer", Files.Job_Records.Max_Path_Length);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 0);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
      Integer'Output (Ada.Streams.Stream_IO.Stream (File), 0);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Result := Files.Job_Records.Read_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "inconsistent decoded action metadata is rejected");

      Transfer_Result.Mutation :=
        (Success => True, Error_Key => Null_Unbounded_String);
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a successful transfer result without a created identity is rejected");

      Transfer_Result.Created_Identity := To_Unbounded_String ("created-token");
      Transfer_Result.Cancelled := True;
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer result cannot report success and cancellation together");

      Transfer_Result.Cancelled := False;
      Transfer_Result.Trashed := To_Unbounded_String ("backup-path");
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer backup path without its identity is rejected");

      Transfer_Result.Trashed_Identity :=
        To_Unbounded_String ("backup-token");
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Path, Transfer_Result);
      Rejected := False;
      begin
         Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
           (Transfer_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer result rejects a relative replacement path");

      Transfer_Result := (others => <>);
      Files.Transfer_Jobs.Testing.Write_Result
        (Transfer_Target, Transfer_Result);
      Ada.Directories.Delete_File (Transfer_Path);
      if Hostkit.Fs.Create_Hard_Link (Transfer_Target, Transfer_Path) then
         Rejected := False;
         begin
            Transfer_Result := Files.Transfer_Jobs.Testing.Read_Result
              (Transfer_Path);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected, "transfer result reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Transfer_Path);
      end if;

      Transfer_Action :=
        (Source_Path => To_Unbounded_String ("relative-source"),
         Dest_Path   => To_Unbounded_String (Join (Root, "destination")),
         Skip        => False,
         Replaced    => False);
      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Path, Transfer_Action,
         Files.File_System.Drop_Copy);
      Rejected := False;
      begin
         Transfer_Action :=
           Files.Transfer_Jobs.Testing.Read_Request_Action
             (Transfer_Request_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer request rejects a relative source path");

      Transfer_Action.Source_Path := To_Unbounded_String (Join (Root, "source"));
      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Path, Transfer_Action,
         Files.File_System.Drop_Copy,
         Batch_Directory => "/tmp/batch" & Character'Val (0) & "suffix");
      Rejected := False;
      begin
         Transfer_Action :=
           Files.Transfer_Jobs.Testing.Read_Request_Action
             (Transfer_Request_Path);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert
        (Rejected,
         "a transfer request rejects a NUL-containing batch path");

      Files.Transfer_Jobs.Testing.Write_Request
        (Transfer_Request_Target, Transfer_Action,
         Files.File_System.Drop_Copy);
      Ada.Directories.Delete_File (Transfer_Request_Path);
      if Hostkit.Fs.Create_Hard_Link
        (Transfer_Request_Target, Transfer_Request_Path)
      then
         Rejected := False;
         begin
            Transfer_Action :=
              Files.Transfer_Jobs.Testing.Read_Request_Action
                (Transfer_Request_Path);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected, "transfer request reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Transfer_Request_Path);
      end if;

      Write_Binary_File (Replacement_Backup, "preserved destination");
      Write_Replacement_Record (Replacement_Record);
      Assert
        (Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
           (Replacement_Record),
         "a complete replacement checkpoint with a live identity is accepted");
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Replacement_Record);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), True);
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
           (Replacement_Record),
         "a replacement checkpoint rejects trailing fields");

      Write_Replacement_Record (Replacement_Target);
      Ada.Directories.Delete_File (Replacement_Record);
      if Hostkit.Fs.Create_Link (Replacement_Target, Replacement_Record) then
         Assert
           (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
              (Replacement_Record),
            "replacement recovery refuses a symlink checkpoint");
         declare
            Removed : constant Boolean :=
              Hostkit.Fs.Delete_Link (Replacement_Record);
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      end if;
      if Hostkit.Fs.Create_Hard_Link
        (Replacement_Target, Replacement_Record)
      then
         Assert
           (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
              (Replacement_Record),
            "replacement recovery refuses a multiply-linked checkpoint");
         Ada.Directories.Delete_File (Replacement_Record);
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Job_Record_Validation;

   procedure Test_Truncated_Persisted_Records
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element_Offset;

      Job_Path         : constant String := Join (Root, "complete-job-record");
      History_Directory : constant String := Join (Root, "prefix-history");
      History_Path     : constant String := Join (History_Directory, "history");
      File             : Ada.Streams.Stream_IO.File_Type;
      Written_Result   : Files.Operations.Operation_Result;
      Read_Result      : Files.Operations.Operation_Result;
      Model            : Files.Model.Window_Model;

      function Read_All
        (Path : String) return Ada.Streams.Stream_Element_Array
      is
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Path);
         declare
            Length : constant Ada.Streams.Stream_Element_Offset :=
              Ada.Streams.Stream_Element_Offset
                (Ada.Streams.Stream_IO.Size (File));
            Data : Ada.Streams.Stream_Element_Array (1 .. Length);
            Last : Ada.Streams.Stream_Element_Offset;
         begin
            Ada.Streams.Stream_IO.Read (File, Data, Last);
            Ada.Streams.Stream_IO.Close (File);
            Assert (Last = Data'Last, "persisted-record fixture reads every byte");
            return Data;
         end;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Read_All;

      procedure Write_Prefix
        (Path  : String;
         Data  : Ada.Streams.Stream_Element_Array;
         Count : Natural)
      is
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         if Count > 0 then
            Ada.Streams.Stream_IO.Write
              (File,
               Data
                 (Data'First ..
                    Data'First
                      + Ada.Streams.Stream_Element_Offset (Count) - 1));
         end if;
         Ada.Streams.Stream_IO.Close (File);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Write_Prefix;
   begin
      Reset_Root;
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Job_Path);
      Files.Job_Records.Write_Operation_Result
        (Ada.Streams.Stream_IO.Stream (File), Written_Result);
      Ada.Streams.Stream_IO.Close (File);

      declare
         Data : constant Ada.Streams.Stream_Element_Array :=
           Read_All (Job_Path);
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Job_Path);
         Read_Result := Files.Job_Records.Read_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         Assert
           (Read_Result.Status = Written_Result.Status,
            "the complete job record decodes before prefix mutation");

         for Prefix_Length in 0 .. Natural (Data'Length) - 1 loop
            Write_Prefix (Job_Path, Data, Prefix_Length);
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Job_Path);
            declare
               Rejected : Boolean := False;
            begin
               begin
                  Read_Result := Files.Job_Records.Read_Operation_Result
                    (Ada.Streams.Stream_IO.Stream (File));
               exception
                  when others =>
                     Rejected := True;
               end;
               Ada.Streams.Stream_IO.Close (File);
               Assert
                 (Rejected,
                  "strict job-record prefix is rejected at byte"
                  & Natural'Image (Prefix_Length));
            end;
         end loop;
      end;

      Ada.Directories.Create_Directory (History_Directory);
      Files.History_Journal.Save_Stacks
        (History_Directory,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Required => True);
      Files.Model.Initialize
        (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Assert
        (Files.History_Journal.Restore (History_Directory, Model),
         "the complete history record decodes before prefix mutation");

      declare
         Data : constant Ada.Streams.Stream_Element_Array :=
           Read_All (History_Path);
      begin
         for Prefix_Length in 0 .. Natural (Data'Length) - 1 loop
            Write_Prefix (History_Path, Data, Prefix_Length);
            Assert
              (not Files.History_Journal.Restore
                 (History_Directory, Model),
               "strict history-record prefix is rejected at byte"
               & Natural'Image (Prefix_Length));
         end loop;
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Truncated_Persisted_Records;

   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Lease_Survives_Parent
     (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Job_Cleanup.Cleanup_Outcome;
      Directory : Files.Types.UString;
      Identity : Files.Types.UString;
      Recovery_Owner : Files.Job_Transports.Lease;
      Arguments : Hostkit.String_Vectors.Vector;
      Exit_Status : Integer;
      Outcome : Files.Job_Transports.Claim_Outcome := Files.Job_Transports.Claim_Refused;
      Report_Path : constant String := Join (Root, "helper-lease-transport");
      Ready_Path : constant String := Join (Root, "helper-lease-ready");
      Release_Path : constant String := Join (Root, "helper-lease-release");
      Refused_Path : constant String := Join (Root, "helper-lease-refused");
      File : Ada.Text_IO.File_Type;
   begin
      Reset_Root;
      Arguments.Append (To_Unbounded_String ("--files-test-crash-with-helper"));
      Arguments.Append (To_Unbounded_String (Report_Path));
      Arguments.Append (To_Unbounded_String (Ready_Path));
      Arguments.Append (To_Unbounded_String (Release_Path));
      Assert
        (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
         and then Exit_Status = 0
         and then Ada.Directories.Exists (Ready_Path),
         "the parent exits abruptly after its helper joins the lease");
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report_Path);
      Directory := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      Ada.Text_IO.Close (File);
      Identity := To_Unbounded_String
        (Files.Job_Transports.Recorded_Identity (To_String (Directory)));
      Assert
        (Files.Job_Transports.Claim_Abandoned
           (To_String (Directory), To_String (Identity), Recovery_Owner) =
             Files.Job_Transports.Claim_Busy,
         "recovery cannot claim the transport after the parent crashes while its helper lives");
      Write_Binary_File (Release_Path, "release");
      for Attempt in 1 .. 10_000 loop
         Outcome := Files.Job_Transports.Claim_Abandoned
           (To_String (Directory), To_String (Identity), Recovery_Owner);
         exit when Outcome = Files.Job_Transports.Claim_Acquired;
         delay 0.001;
      end loop;
      Assert
        (Outcome = Files.Job_Transports.Claim_Acquired,
         "recovery acquires the transport after the helper exits");
      Assert
        (Files.Job_Transports.Retire (Recovery_Owner, To_String (Directory)),
         "recovery durably closes helper admission before releasing its lease");
      Files.Job_Transports.Release (Recovery_Owner);
      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-lease-holder"));
      Arguments.Append (Directory);
      Arguments.Append (To_Unbounded_String (Refused_Path));
      Arguments.Append (To_Unbounded_String (Release_Path));
      Assert
        (not Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
         and then Exit_Status = 2
         and then not Ada.Directories.Exists (Refused_Path),
         "a helper cannot join a retiring transport after recovery releases its lease");
      Assert
        (Files.Job_Cleanup.Run (To_String (Directory), To_String (Identity)) =
           Files.Job_Cleanup.Cleanup_Removed,
         "recovery removes the transport after both owners have exited");
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if not Ada.Directories.Exists (Release_Path) then
            Write_Binary_File (Release_Path, "release");
         end if;
         Files.Job_Transports.Release (Recovery_Owner);
         raise;
   end Test_Helper_Lease_Survives_Parent;

   procedure Test_Crash_Transport_Scavenging (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stage_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

end Files_Suite.Operations;

with Files.File_Identities;
with Files.Job_Helpers;
with Files.Job_Cleanup;
with Files.Job_Scavenger;
with Files.Job_Transports;
with Files.Private_Directories;
with Files.Process_Jobs;
with Files.Process_Jobs.Testing;
with Files.Job_Context;
with Files.Refresh_Jobs;
with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Interfaces.C.Strings;
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
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Applications;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Features;
with Files.Folder_Size;
with Files.Folder_Tree;
with Files.Fonts;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Icon_Assets;
with Files.Operations;
with Files.Paste;
with Files.Platform;
with Hostkit.Fs;
with Hostkit.Metadata;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files.Transfer_Jobs;
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
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
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
   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Unreadable_Hardlink_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_Background_Operations'Access,
                "duplicate, archive, extract and recursive searches use cancellable helpers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Helper_Shutdown'Access, "closing a session never waits for blocked helper work");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transport_Protocol_Gaps'Access,
         "transport creation crashes and cancellation failures retain safe recovery");
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
        (T, Test_Batch_Hard_Link_Copy'Access,
         "batch copies and retryable Redo retain hard links across selected roots");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Hidden'Access, "Empty Trash purges hidden payloads regardless of display preferences");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Limit_Errors'Access, "search limits fail without presenting incomplete or empty results");
   end Register_Tests;

   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_xdg_data";
      Mac_Home     : constant String := Root & "_mac_home";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Special_Path  : constant String := Join (Root, "space % file.txt");
      Nested_Trash_Source : constant String := Join (Root, "nested-trash-source");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation      : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 0.0)) =
         "2024-02-03T00:00:00",
         "trash deletion date formats midnight");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 60.9)) =
         "2024-02-03T00:01:00",
         "trash deletion date floors fractional seconds");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 86_399.9)) =
         "2024-02-03T23:59:59",
         "trash deletion date does not round up near midnight");
      --  On Windows the desktop trash is the Recycle Bin, which is always there:
      --  "no trash base exists" is not a state that platform can be in. Select
      --  the freedesktop backend explicitly, and the absence of a base is then
      --  meaningful on every host.
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Clear ("HOME");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert (not Files.File_System.Trash_Is_Available, "trash availability detects missing trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
         "trash backend reports unavailable when no trash base exists");

      --  And with nothing selected, each platform falls back to its own desktop
      --  trash: the Recycle Bin on Windows, the freedesktop layout elsewhere.
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      if Files.Platform.Current_API_Profile.Adapter = Files.File_System.Native_Adapter_Windows then
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment
              = Files.File_System.Trash_Windows_Recycle_Bin,
            "Windows falls back to the Recycle Bin, which needs no trash base");
         Assert (Files.File_System.Trash_Is_Available,
                 "the Recycle Bin is always available");
      else
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
            "elsewhere, no trash base means no trash");
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "unavailable trash backend reports no metadata sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Diagnostics,
         "trash capabilities expose native diagnostic policy");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "trash capabilities expose multi-item preflight policy");
      Write_File (Join (Root, "blocked-trash-parent"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Join (Root, "blocked-trash-parent"), "xdg"));
      Assert
        (not Files.File_System.Trash_Is_Available,
         "trash availability rejects a regular file in the trash parent chain");
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "missing-for-blocked-trash.txt"));
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "missing trash target still reports failed trash mutation");
      Mutation :=
        Files.File_System.Move_To_Trash_Preflight
          (Root & "/bad" & Character'Val (0) & "trash-target.txt");
      Assert (not Mutation.Success, "malformed trash target reports failed trash mutation");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "malformed trash target reports failed trash diagnostic");
      Write_File (Join (Root, "blocked-trash-target.txt"));
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "blocked-trash-target.txt"));
      Assert (not Mutation.Success, "trash preflight rejects blocked trash parent chain");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.unavailable",
         "blocked trash parent chain reports unavailable trash");
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-parent"));
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-target.txt"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert (Files.File_System.Trash_Is_Available, "trash availability detects XDG trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Xdg_Data_Home,
         "trash backend reports XDG data home when configured");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "XDG trash backend reports trashinfo sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Collision_Safe_Name,
         "XDG trash backend reports collision-safe naming");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "XDG trash backend reports multi-item preflight support");
      --  "/" is not a root on Windows; the drive is.
      Mutation := Files.File_System.Move_To_Trash_Preflight (Filesystem_Root);
      Assert (not Mutation.Success, "trash preflight rejects filesystem root");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "filesystem root trash preflight reports failed trash mutation");
      declare
         Prefix_Source : constant String := Join (Root, "trash-prefix-source");
         Prefix_Base   : constant String := Prefix_Source & "-xdg";
      begin
         Write_File (Prefix_Source);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Prefix_Base);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Mutation := Files.File_System.Move_To_Trash_Preflight (Prefix_Source);
         Assert (Mutation.Success, "trash preflight accepts sibling paths sharing a prefix");
         Assert
           (To_String (Mutation.Error_Key) = "",
            "trash prefix-sibling preflight has no diagnostic");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Ada.Directories.Delete_File (Prefix_Source);
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Windows_Recycle_Bin,
         "trash backend can represent native Windows recycle-bin intent");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Platform,
         "native Windows trash backend reports native-platform intent");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Permanent_Delete,
         "native trash capability does not opt into permanent deletion");
      declare
         Request : constant Files.File_System.Native_Trash_Request :=
           Files.File_System.Native_Trash_Request_For (Join (Root, "missing-for-native-trash.txt"));
         Native_Result : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Evaluate_Native_Trash (Request);
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
      begin
         Assert (Request.Requires_Native_Api, "native trash request records native API requirement");
         Assert (not Request.Can_Use_Current_Process, "native trash request does not claim local fallback");
         --  "here" was always Linux, where the Windows adapter is of course not
         --  the target. On Windows it IS, and the binding is genuinely available.
         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert (Native_Result.Supported,
                    "on Windows the native recycle-bin adapter is supported");
            Assert (Native_Result.Native_Binding_Available,
                    "on Windows the native trash binding is available");
            Assert
              (Native_Result.Native_Binding_Status
                 = Files.File_System.Native_API_Binding_Available,
               "on Windows the native trash binding reports available");
         else
            Assert (not Native_Result.Supported,
                    "off Windows the recycle-bin adapter is unsupported");
            Assert (not Native_Result.Native_Binding_Available,
                    "off Windows the Windows trash binding is unavailable");
            Assert
              (Native_Result.Native_Binding_Status
                 = Files.File_System.Native_API_Not_Target,
               "off Windows the Windows trash binding is not the target");
         end if;

         --  Evaluation never mutates, on any host.
         Assert (not Native_Result.Attempted, "native trash evaluation does not attempt mutation");
         Assert (not Native_Result.Completed, "native trash evaluation does not complete mutation");
         Assert
           (To_String (Native_Result.Binding_Unit) = "Hostkit.Trash",
            "Windows native trash result records the unit that owns the binding");
         Assert (not Native_Result.Desktop_Standard, "Windows native trash is not a desktop-standard fallback");
         Assert (Native_Result.Uses_Recycle_Bin, "Windows native trash result records recycle-bin target");
         Assert
           (To_String (Native_Result.Adapter_Name) = "windows.recycle_bin",
            "Windows native trash result records adapter name");
         Assert
           (To_String (Native_Result.Native_Api_Name) = "SHFileOperationW",
            "Windows native trash result records the API it actually calls");
         Assert
           (To_String (Native_Result.Operation_Name) = "move_to_trash",
            "native trash result records operation name");
         Assert (Native_Result.Preserves_Metadata, "native trash result records metadata-preservation intent");
         Assert
           (not Native_Result.Requires_User_Consent,
            "native trash result records no in-app consent requirement");
         --  An evaluation carries a diagnostic only when it has something to
         --  report. On Windows the adapter is right here and working, so there is
         --  nothing to say; everywhere else the "unavailable" key IS the finding.
         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert
              (To_String (Native_Result.Error_Key) = "",
               "on Windows a supported adapter evaluates without a diagnostic; key was "
               & To_String (Native_Result.Error_Key));

            --  Executing against a path that does not exist: the adapter is real,
            --  so it genuinely calls the shell and the shell genuinely refuses.
            --  That is a failed attempt, not an unsupported one -- and the two
            --  must not be reported the same way, or a broken Recycle Bin would
            --  look exactly like a missing one.
            Assert (Native_Execution.Supported, "on Windows the adapter is supported");
            Assert (Native_Execution.Attempted, "on Windows the shell is actually called");
            Assert
              (not Native_Execution.Completed,
               "and it refuses a path that does not exist");
            Assert
              (Native_Execution.Native_Binding_Available,
               "on Windows the binding stays available across execution");
            Assert
              (Native_Execution.Native_Binding_Status
                 = Files.File_System.Native_API_Binding_Available,
               "on Windows execution preserves binding status");
            Assert
              (To_String (Native_Execution.Error_Key) = "error.trash.failed",
               "a refused move is reported as a failure, not as an absent adapter; key was "
               & To_String (Native_Execution.Error_Key));
         else
            Assert
              (To_String (Native_Result.Error_Key) = "error.trash.native_unavailable",
               "off Windows the evaluation reports native-unavailable");
            Assert (not Native_Execution.Supported, "native trash execution reports unsupported adapter");
            Assert (not Native_Execution.Attempted, "native trash execution does not attempt unsupported adapter");
            Assert
              (not Native_Execution.Native_Binding_Available,
               "native trash execution reports unavailable binding");
            Assert
              (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Not_Target,
               "native trash execution preserves binding status");
            Assert
              (To_String (Native_Execution.Error_Key) = "error.trash.native_unavailable",
               "off Windows, native trash execution reports native-unavailable");
         end if;
      end;
      --  This used a path that did not exist, because the preflight refused a
      --  native backend outright and never got as far as looking. It does look
      --  now, so give it something real -- and then the answer depends on where we
      --  are: on Windows the Recycle Bin takes it, and everywhere else the Windows
      --  adapter is a stub that says so.
      declare
         Victim : constant String := Join (Root, "for-native-trash.txt");
      begin
         Write_File (Victim, "bin me");
         Mutation := Files.File_System.Move_To_Trash (Victim);

         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert (Mutation.Success,
                    "on Windows the Recycle Bin takes the item; error was "
                    & To_String (Mutation.Error_Key));
            Assert (not Path_Exists (Victim),
                    "the item is gone from its directory once the shell has it");
         else
            Assert (not Mutation.Success,
                    "off Windows the recycle-bin adapter cannot do it");
            Assert
              (To_String (Mutation.Error_Key) = "error.trash.native_unavailable",
               "and it fails as recoverable data, not an exception; key was "
               & To_String (Mutation.Error_Key));
         end if;

         --  Off Windows the move fails and the file stays, which would leave the
         --  scratch root holding one item more than the tests after this expect.
         if Path_Exists (Victim) then
            Ada.Directories.Delete_File (Victim);
         end if;
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Native,
         "trash backend can represent native macOS trash intent");
      --  Everything from here on is about the freedesktop implementation -- the
      --  trash directory, the .trashinfo metadata, the collision naming. Clearing
      --  the variable used to select it, back when XDG was the default everywhere.
      --  Windows now defaults to the Recycle Bin, which has none of those things,
      --  so ask for XDG by name and it stays exercised on every host instead of
      --  only where it happens to be the default.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Write_File (Join (Root, "native-execute.txt"));
      declare
         Request : constant Files.File_System.Native_Trash_Request :=
           Files.File_System.Native_Trash_Request_For (Join (Root, "native-execute.txt"));
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
      begin
         Assert (Request.Can_Use_Current_Process, "XDG trash request can execute in current process");
         Assert (Native_Execution.Supported, "XDG trash execution reports supported adapter");
         Assert (Native_Execution.Attempted, "XDG trash execution attempts mutation");
         Assert (Native_Execution.Completed, "XDG trash execution completes mutation");
         Assert (Native_Execution.Desktop_Standard, "XDG trash execution reports desktop-standard backend");
         Assert
           (not Native_Execution.Native_Binding_Available,
            "XDG trash execution does not claim OS-specific native binding");
         Assert
           (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Binding_Missing,
            "XDG trash execution reports no OS-specific native binding");
         Assert
           (To_String (Native_Execution.Binding_Unit) = "Files.File_System.Move_To_Trash",
            "XDG trash execution records binding unit");
         Assert
           (not Ada.Directories.Exists (Join (Root, "native-execute.txt")),
            "XDG trash execution moves source entry");
         Assert
           (To_String (Native_Execution.Adapter_Name) = "xdg.trash",
            "XDG trash execution records adapter name");
         Assert
           (To_String (Native_Execution.Error_Key) = "",
            "XDG trash execution has no error key");
      end;
      Write_File (Join (Root, "doomed.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Command = Files.Commands.Delete_Selected_Items_Command, "Delete routes through command registry");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "available trash moves selected item");
      Assert (To_String (Result.Operation.Path) = Join (Root, "doomed.txt"), "delete operation reports target path");
      Assert (To_String (Result.Operation.Error_Key) = "", "successful trash move has no error key");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful trash move clears model error");
      Assert (not Ada.Directories.Exists (Join (Root, "doomed.txt")), "trash move removes file from source");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")), "trash move stores file under XDG trash");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.trashinfo")),
         "trash move writes trashinfo metadata");
      Assert (Files.Model.Selected_Count (Model) = 0, "successful delete reconciles selection");
      Mutation := Files.File_System.Move_To_Trash (Join (Trash_File, "doomed.txt"));
      Assert (not Mutation.Success, "trash preflight rejects items already inside trash");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "already-trashed item reports trash failure");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")),
         "already-trashed item remains in place after rejected trash move");

      Write_File (Join (Root, "doomed.txt"), "again");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads collision target");
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second same-name delete succeeds");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt.2")), "trash collision chooses suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.2.trashinfo")),
         "trash collision writes suffixed metadata");

      Write_File (Join (Trash_Info, "sidecar-only.txt.trashinfo"));
      Write_File (Join (Root, "sidecar-only.txt"));
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "sidecar-only.txt"));
      Assert (Mutation.Success, "trash sidecar-only collision succeeds with suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "sidecar-only.txt.2")),
         "trash sidecar-only collision chooses suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.2.trashinfo")),
         "trash sidecar-only collision writes suffixed metadata");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.trashinfo")),
         "trash sidecar-only collision preserves existing metadata sidecar");

      Write_File (Join (Root, "doomed2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads second delete target");
      Select_Name (Model, "doomed2.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Assert
        (Result.Command = Files.Commands.Delete_Selected_Items_Command,
         "Backspace routes through same delete command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "Backspace delete uses trash operation");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed2.txt")), "Backspace moves file to trash");

      Write_File (Special_Path);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads encoded trash target");
      Select_Name (Model, "space % file.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "encoded trash target moves to trash");
      --  What this is about is the encoding of the awkward characters, and that is
      --  host-independent. The absolute path in front of them is not: it was spelled
      --  out here as Full_Name (Root) & "/...", which is only ever true on POSIX. A
      --  Windows path is "C:\..." and the encoder escapes its ':' and '\' too, so the
      --  literal never matched. Assert the part this test is named for, and leave the
      --  round-trip -- that the recorded path decodes back to the original location --
      --  to Test_Restore_From_Trash, which is what that test exists to prove.
      Assert
        (Project_Tools.Files.File_Contains
           (Join (Trash_Info, "space % file.txt.trashinfo"), "Path="),
         "trashinfo records the original path");
      Assert
        (Project_Tools.Files.File_Contains
           (Join (Trash_Info, "space % file.txt.trashinfo"), "space%20%25%20file.txt"),
         "trashinfo path percent-encodes spaces and percent signs");

      Write_File (Join (Root, "multi-a.txt"));
      Write_File (Join (Root, "multi-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads multi-delete targets");
      Files.Model.Set_Filter (Model, "multi-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "multi-selection delete succeeds");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-a.txt")), "multi-delete moves first file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-b.txt")), "multi-delete moves second file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-a.txt")), "multi-delete removes first source file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-b.txt")), "multi-delete removes second source file");

      Write_File (Join (Root, "partial-a.txt"));
      Write_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads partial-delete targets");
      Files.Model.Set_Filter (Model, "partial-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Ada.Directories.Delete_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "partial multi-delete reports failure");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.trash.failed",
         "partial multi-delete reports trash failure");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "partial-a.txt")),
         "partial multi-delete does not move earlier files before preflight failure");
      Assert
        (Ada.Directories.Exists (Join (Root, "partial-a.txt")),
         "partial multi-delete leaves earlier source files in place");
      Assert (Files.Model.Item_Count (Model) = 1, "partial multi-delete reloads stale directory model");
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.failed", "partial multi-delete keeps error state");

      Ada.Directories.Create_Path (Nested_Trash_Source);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Nested_Trash_Source, "xdg-data"));
      Mutation := Files.File_System.Move_To_Trash (Nested_Trash_Source);
      Assert (not Mutation.Success, "trash move into a source subdirectory fails");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "nested trash move reports trash failure");
      Assert (Ada.Directories.Exists (Nested_Trash_Source), "failed nested trash keeps source directory");
      Assert
        (not Ada.Directories.Exists
           (Join (Join (Join (Nested_Trash_Source, "xdg-data"), "Trash"), "info")
            & "/nested-trash-source.trashinfo"),
         "failed nested trash removes stale trashinfo metadata");

      declare
         Guard_Directory : constant String := Join (Root, "guard-preflight-z-dir");
         First_File      : constant String := Join (Root, "guard-preflight-a.txt");
         Guard_Trash     : constant String := Join (Join (Guard_Directory, "xdg-data"), "Trash");
         Guard_Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Guard_Load      : Files.File_System.Directory_Load_Result;
         Guard_Model     : Files.Model.Window_Model;
         Guard_Result    : Files.Controller.Controller_Result;
      begin
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Guard_Directory, "xdg-data"));
         Write_File (First_File);
         Ada.Directories.Create_Path (Guard_Directory);
         Guard_Load := Files.File_System.Load_Directory (Root, Guard_Settings);
         Assert (Guard_Load.Success, "guarded multi-delete setup loads");
         Files.Model.Initialize (Guard_Model, Root, Guard_Load.Items, Root);
         Files.Model.Set_Filter (Guard_Model, "guard-preflight-");
         Files.Model.Select_Visible (Guard_Model, 1);
         Files.Model.Toggle_Visible_Selection (Guard_Model, 2);

         Guard_Result := Files.Controller.Handle_Key (Guard_Model, Guard_Settings, Guikit.Input.Key_Delete);
         Assert
           (Guard_Result.Operation.Status = Files.Operations.Operation_Failed,
            "multi-delete preflights nested trash targets");
         Assert
           (To_String (Guard_Result.Operation.Error_Key) = "error.trash.failed",
            "multi-delete nested trash preflight reports trash failure");
         Assert
           (Ada.Directories.Exists (First_File),
            "multi-delete nested trash preflight does not move earlier selected files");
         Assert (Ada.Directories.Exists (Guard_Directory), "nested trash preflight keeps guarded directory");
         Assert
           (not Ada.Directories.Exists (Join (Join (Guard_Trash, "files"), "guard-preflight-a.txt")),
            "multi-delete nested trash preflight does not create a trash target for earlier files");
         Assert
           (Files.Model.Last_Error_Key (Guard_Model) = "error.trash.failed",
            "multi-delete nested trash preflight preserves model error");
      end;

      Project_Tools.Files.Delete_Tree (Mac_Home);
      Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Set ("HOME", Mac_Home);
      Write_File (Join (Root, "mac-trash.txt"));
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "mac-trash.txt"));
      Assert (Mutation.Success, "macOS-style home trash fallback moves files");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Home,
         "trash backend reports macOS-style home trash when present");
      Assert
        (Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "mac-trash.txt")),
         "macOS-style home trash stores the file directly under ~/.Trash");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "files")),
         "macOS-style home trash does not create a freedesktop files/ subdirectory");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "info")),
         "macOS-style home trash does not create a freedesktop info/ subdirectory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Project_Tools.Files.Delete_Tree (Mac_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Delete_Selected_Operation;

   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_restore_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Source_Path  : constant String := Join (Root, "restore-me.txt");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      Write_File (Source_Path, "payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "restore setup moves source file to trash");
      Assert (not Ada.Directories.Exists (Source_Path), "restore setup removes source file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")), "restore setup stores trashed payload");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore setup writes trashinfo sidecar");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "restore navigates into trash files directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "restore-me.txt");
      Assert (Files.Model.Selected_Count (Model) = 1, "restore selects the trashed item");

      Result :=
        Files.Controller.Execute_Command (Files.Commands.Restore_From_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "restore command returns success");
      Assert (Ada.Directories.Exists (Source_Path), "restore returns the file to its original path");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")),
         "restore removes the trashed payload");
      Assert
        (not Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore removes the trashinfo sidecar");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash;

   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_restore_guard_xdg";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Guard 1: the original path has been re-created since trashing. Restore
      --  must refuse rather than clobber it, and keep the trashed payload. This
      --  behaviour was previously only checked by its catalog string.
      declare
         Source_Path  : constant String := Join (Root, "guard-exists.txt");
         Trashed_Path : constant String := Join (Trash_File, "guard-exists.txt");
      begin
         Write_File (Source_Path, "trashed payload");
         Mutation := Files.File_System.Move_To_Trash (Source_Path);
         Assert (Mutation.Success, "guard setup trashes the file");
         Write_File (Source_Path, "a different file now lives here");
         Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
         Assert (not Mutation.Success, "restore refuses when the original path is occupied");
         Assert
           (To_String (Mutation.Error_Key) = "error.trash.restore_exists",
            "restore-exists refusal reports the localized diagnostic");
         Assert
           (Project_Tools.Files.File_Contains (Source_Path, "a different file now lives here"),
            "restore-exists refusal leaves the occupying file untouched");
         Assert
           (Ada.Directories.Exists (Trashed_Path),
            "restore-exists refusal keeps the trashed payload recoverable");
      end;

      --  Guard 2: the original's parent directory is gone. Restore must refuse
      --  and keep the payload rather than fail obscurely or lose it.
      declare
         Sub_Dir      : constant String := Join (Root, "gone");
         Source_Path  : constant String := Join (Sub_Dir, "guard-parent.txt");
         Trashed_Path : constant String := Join (Trash_File, "guard-parent.txt");
      begin
         Ada.Directories.Create_Path (Sub_Dir);
         Write_File (Source_Path, "payload");
         Mutation := Files.File_System.Move_To_Trash (Source_Path);
         Assert (Mutation.Success, "parent-guard setup trashes the file");
         Project_Tools.Files.Delete_Tree (Sub_Dir);
         Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
         Assert (not Mutation.Success, "restore refuses when the original parent is gone");
         Assert
           (To_String (Mutation.Error_Key) = "error.trash.restore_parent_missing",
            "restore-parent-missing refusal reports the localized diagnostic");
         Assert
           (Ada.Directories.Exists (Trashed_Path),
            "restore-parent-missing refusal keeps the trashed payload recoverable");
      end;

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash_Guards;

   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_restore_url_xdg";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      --  A name with a space and a literal percent: the .trashinfo Path is
      --  percent-encoded on the way in, so restoring it back to this exact path
      --  exercises the Url_Decode round-trip (%20 -> space, %25 -> %), which
      --  only the encoder side was previously covered for.
      Special_Name : constant String := "a b%c.txt";
      Source_Path  : constant String := Join (Root, Special_Name);
      Trashed_Path : constant String := Join (Trash_File, Special_Name);
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      Write_File (Source_Path, "round trip payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "a name with a space and percent trashes");
      Assert (not Ada.Directories.Exists (Source_Path), "trashing removes the source");
      Assert (Ada.Directories.Exists (Trashed_Path), "the trashed payload keeps its literal name");

      Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
      Assert (Mutation.Success, "restoring the percent/space name succeeds");
      Assert
        (Ada.Directories.Exists (Source_Path)
         and then Project_Tools.Files.File_Contains (Source_Path, "round trip payload"),
         "the decoded original path round-trips exactly through Url_Decode");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_Url_Round_Trip;

   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Source_A     : constant String := Join (Root, "empty-a.txt");
      Source_B     : constant String := Join (Root, "empty-b.txt");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Enablement: an ordinary directory never offers Empty Trash.
      Write_File (Source_A, "aaa");
      Write_File (Source_B, "bbb");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "empty-trash setup loads the ordinary directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is disabled in an ordinary directory");

      --  Trash two files so both a payload and its .trashinfo sidecar exist.
      declare
         Trash_A : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Source_A);
         Trash_B : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Source_B);
      begin
         Assert (Trash_A.Success and then Trash_B.Success, "empty-trash setup trashes both files");
      end;
      Assert (Ada.Directories.Exists (Join (Trash_File, "empty-a.txt")), "payload a is trashed");
      Assert (Ada.Directories.Exists (Join (Trash_Info, "empty-a.txt.trashinfo")), "sidecar a is written");
      Assert (Ada.Directories.Exists (Join (Trash_File, "empty-b.txt")), "payload b is trashed");
      Assert (Ada.Directories.Exists (Join (Trash_Info, "empty-b.txt.trashinfo")), "sidecar b is written");

      --  Enablement: the non-empty trash view offers Empty Trash.
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "empty-trash setup loads the trash view");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert (Files.Model.Item_Count (Model) = 2, "the trash view lists both trashed items");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is enabled in the non-empty trash view");

      --  Emptying purges every payload and sidecar and reloads an empty view.
      Result := Files.Controller.Execute_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "empty trash reports success");
      Assert (Files.Model.Item_Count (Model) = 0, "the trash view reloads empty after empty trash");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "empty-a.txt")), "payload a is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_Info, "empty-a.txt.trashinfo")), "sidecar a is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "empty-b.txt")), "payload b is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_Info, "empty-b.txt.trashinfo")), "sidecar b is purged");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is disabled once the trash view is empty");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Empty_Trash_Operation;

   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_partial_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Keep_File    : constant String := Join (Root, "purge-me.txt");
      Locked_Dir   : constant String := Join (Root, "locked-dir");
      Locked_Child : constant String := Join (Locked_Dir, "inside.txt");
      Trashed_Lock : constant String := Join (Trash_File, "locked-dir");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;

      procedure Restore_Environment is
      begin
         --  Re-open the locked payload so the fixture tree can be removed.
         declare
            Unlocked : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Trashed_Lock, 8#755#);
            pragma Unreferenced (Unlocked);
         begin
            null;
         end;

         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  One ordinary file plus one non-empty directory, both trashed.
      Write_File (Keep_File, "purge");
      Ada.Directories.Create_Path (Locked_Dir);
      Write_File (Locked_Child, "child");
      declare
         Trash_Keep : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Keep_File);
         Trash_Lock : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Locked_Dir);
      begin
         Assert (Trash_Keep.Success and then Trash_Lock.Success, "partial-empty setup trashes both entries");
      end;

      --  Strip all permissions from the trashed directory so its child cannot be
      --  removed, forcing that one entry's purge to fail while the file succeeds.
      Assert
        (Files.File_System.Set_Permissions (Trashed_Lock, 8#000#).Success,
         "partial-empty setup locks the trashed directory");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "partial-empty setup loads the trash view");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert (Files.Model.Item_Count (Model) = 2, "the trash view lists both trashed entries");

      --  Emptying must never crash; the ordinary file is always removed.
      Result := Files.Controller.Execute_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status in Files.Operations.Operation_Success | Files.Operations.Operation_Failed,
         "empty trash returns a defined status without crashing");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "purge-me.txt")), "the removable payload is purged");
      Assert
        (not Ada.Directories.Exists (Join (Trash_Info, "purge-me.txt.trashinfo")),
         "the removable payload's sidecar is purged");

      --  When the lock actually held (non-root), the survivor is reported through
      --  the non-fatal partial diagnostic while the overall result stays success.
      if Ada.Directories.Exists (Trashed_Lock) then
         Assert (Result.Operation.Status = Files.Operations.Operation_Success, "a partial empty still reports success");
         Assert
           (Files.Model.Last_Error_Key (Model) = "error.trash.empty_partial",
            "a partial empty records the partial diagnostic");
         Assert (Files.Model.Item_Count (Model) = 1, "the un-removable entry remains in the reloaded trash view");
      end if;

      --  Unlock and remove the fixture tree.
      declare
         Unlocked : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Permissions (Trashed_Lock, 8#755#);
         pragma Unreferenced (Unlocked);
      begin
         null;
      end;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Empty_Trash_Partial_Failure;

   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_undo_xdg_data";
      Source_Path  : constant String := Join (Root, "empty-undo.txt");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Trashing a selected item records an undo-only Undo_Restore_Trash entry
      --  whose source is the payload's new location inside the trash.
      Write_File (Source_Path, "payload");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "undo-safe setup loads the ordinary directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "empty-undo.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "undo-safe setup trashes the item");
      Assert (Files.Model.Undo_Available (Model), "trashing records an undo entry");

      --  Navigate into the trash and empty it: the pending restore's source path
      --  is now permanently gone.
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Navigated,
         "undo-safe setup opens the trash view");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "the trashed item is visible in the trash view");
      Result := Files.Controller.Execute_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "empty trash succeeds");
      Assert (Files.Model.Undo_Available (Model), "the dangling restore undo entry is still present");

      --  Undoing the restore whose source was emptied must fail safely, not crash.
      Result := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Result.Operation.Status /= Files.Operations.Operation_Success,
         "undoing a restore whose trashed source was emptied fails safely");
      Assert (not Ada.Directories.Exists (Source_Path), "the failed undo does not resurrect the emptied item");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Empty_Trash_Undo_Safe;

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "open-dir");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Join (Root, "other-dir"));
      Write_File (Join (Dir, "child.txt"));
      Items.Append (Files.File_System.Make_Item (Root, "open-dir", Files.Types.Directory_Item, "inode/directory"));
      Items.Append (Files.File_System.Make_Item (Root, "other-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled,
         "pending create selection blocks direct open preparation");
      Assert
        (To_String (Result.Error_Key) = "error.selection.empty",
         "pending create open preparation reports disabled selection");
      Assert (Files.Model.Current_Path (Model) = Root, "preparing directory open does not navigate");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.selection.empty",
         "preparing pending create open records disabled state");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "pending create item cannot be opened directly");
      Assert (Files.Model.Current_Path (Model) = Root, "disabled pending create open keeps path");

      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert
        (To_String (Routed.Operation.Path) = Ada.Directories.Full_Name (Dir),
         "directory open returns loaded path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "directory open changes path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "directory open clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "directory open clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "directory open clears rename state");
      Assert (Files.Model.Rename_Text (Model) = "", "directory open clears stale rename text");
      Assert (Files.Model.Temporary_Item_Name (Model) = "", "directory open clears stale temporary name");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "directory open clears rename focus");
      Assert (Files.Model.Item_Count (Model) = 1, "directory open loads destination items");
      Assert (Files.Model.Visible_Item (Model, 1).Name = To_Unbounded_String ("child.txt"), "child item is loaded");

      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "multi-directory open is rejected");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.multi_directory",
         "multi-directory open reports localized diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.multi_directory",
         "multi-directory open records localized diagnostic key");
      Assert (Files.Model.Current_Path (Model) = Root, "multi-directory open does not navigate");

      Files.Model.Initialize (Model, Root, Items, Root);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "double-click changes path");
   end Test_Open_Selected_Directory_Loads_Items;

   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Shell_Arguments : Files.Settings.String_Vectors.Vector;
      Injected_Argument : Unbounded_String;

      --  How this host's shell separates two commands: cmd uses "&", sh uses ";".
      Shell_Command_Separator : constant String :=
        (if Files.Platform.Current_API_Profile.Adapter = Files.File_System.Native_Adapter_Windows
         then "&"
         else ";");
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
      Routed    : Files.Controller.Controller_Result;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Policy    : constant Files.Operations.Open_Action_Execution_Policy :=
        Files.Operations.Open_Action_Policy;
   begin
      --  Exercise the configured-action and missing-action contracts
      --  deterministically; the host opener fallback would otherwise resolve
      --  unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Assert (Policy.Uses_Argument_Vector, "open-action policy requires argument vectors");
      Assert (Policy.Shell_Requires_Explicit_Opt_In, "open-action policy requires explicit shell opt-in");
      Assert (Policy.Checks_Executable_Before_Spawn, "open-action policy checks executables before spawn");
      Assert (Policy.Tracks_Execution_Attempt, "open-action policy tracks execution attempts");
      Assert (Policy.Tracks_Exit_Status, "open-action policy tracks exit status");
      Assert (Policy.Runs_Asynchronously, "open-action policy records asynchronous detached launches");
      Assert (not Policy.Supports_Cancellation, "open-action policy records cancellation limit");
      Assert
        (Policy.Rejects_Unsafe_Placeholders,
         "open-action policy records unsafe placeholder rejection");
      Assert (Policy.Reports_Missing_Action, "open-action policy records missing-action diagnostics");
      Assert
        (Policy.Reports_Missing_Executable,
         "open-action policy records missing-executable diagnostics");
      Assert
        (Policy.Captures_Executable_Discovery,
         "open-action policy records executable discovery capture");
      Assert (Policy.Captures_Process_Result, "open-action policy records process result capture");
      Assert (Policy.Quotes_Shell_Arguments, "open-action policy records shell argument quoting");
      Assert
        (Policy.Preserves_Vector_Boundaries,
         "open-action policy records argument vector boundary preservation");
      Assert (Policy.Multi_File_Deterministic, "open-action policy records deterministic multi-file execution");
      declare
         Generic_Failure : constant Files.Operations.Operation_Result :=
           (Status              => Files.Operations.Operation_Failed,
            Error_Key           => To_Unbounded_String ("error.directory.load"),
            Path                => To_Unbounded_String (Root),
            Action              =>
              Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            Action_Executable   => Null_Unbounded_String,
            Action_Arguments    => 0,
            Action_Uses_Shell   => False,
            Execution_Attempted => False,
            Executable_Found    => False,
            Exit_Status_Known   => False,
            Exit_Status         => 0);
      begin
         Assert
           (Files.Operations.Open_Action_Lifecycle_Of (Generic_Failure).State =
            Files.Operations.Open_Action_Not_Started,
            "generic failed operations are not classified as open-action preflight failures");
      end;
      Arguments.Append (To_Unbounded_String ("--readonly"));
      Arguments.Append (To_Unbounded_String ("{path}"));
      Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action (No_Op_Executable, Arguments));
      Modifiers (Guikit.Input.Control_Key) := True;
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Set_Error (Model, "error.open_action.missing");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "file open action can be prepared without spawn");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "prepared action reports selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "prepared action clears stale error state");
      Assert (To_String (Result.Action.Executable) = No_Op_Executable, "prepared action uses configured executable");
      Assert (To_String (Result.Action_Executable) = No_Op_Executable, "prepared result exposes executable text");
      Assert (Result.Action_Arguments = 3, "prepared result exposes argument count");
      Assert (not Result.Execution_Attempted, "prepared action does not execute");
      Assert (not Result.Action.Use_Shell, "prepared action preserves non-shell execution");
      Assert (Natural (Result.Action.Arguments.Length) = 3, "prepared action preserves argument vector");
      Assert (To_String (Result.Action.Arguments.Element (1)) = "--readonly", "literal argument is preserved");
      Assert (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"), "path placeholder expands");
      Assert (To_String (Result.Action.Arguments.Element (3)) = "Alpha.txt", "name placeholder expands");

      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed,
              "file open executes an action; got "
              & Files.Operations.Operation_Status'Image (Result.Status)
              & " with executable " & To_String (Result.Action_Executable));
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "file open returns selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "executed open action clears stale error state");
      Assert (To_String (Result.Action.Executable) = No_Op_Executable, "executed action uses configured executable");
      Assert (To_String (Result.Action_Executable) = No_Op_Executable, "executed result exposes executable text");
      Assert (Result.Action_Arguments = 3, "executed result exposes argument count");
      Assert (Result.Execution_Attempted, "executed result records process attempt");
      Assert (Result.Executable_Found, "executed result records executable discovery");
      Assert (not Result.Action.Use_Shell, "executed non-shell action does not request shell execution");
      Assert (Natural (Result.Action.Arguments.Length) = 3, "executed action preserves argument vector");
      Assert (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"), "path placeholder expands");
      Assert (To_String (Result.Action.Arguments.Element (3)) = "Alpha.txt", "name placeholder expands");
      Assert (Files.Model.Current_Path (Model) = Root, "opening a non-directory does not navigate");
      declare
         Lifecycle : constant Files.Operations.Open_Action_Lifecycle :=
           Files.Operations.Open_Action_Lifecycle_Of (Result);
      begin
         --  Open_Selected launches detached, so the action is spawned and let go.
         --  "Completed" would claim we watched it finish, and we did not.
         Assert
           (Lifecycle.State = Files.Operations.Open_Action_Spawned,
            "open-action lifecycle records a spawned action");
         Assert (To_String (Lifecycle.Executable) = No_Op_Executable, "lifecycle records executable");
         Assert (Lifecycle.Argument_Count = 3, "lifecycle records argument count");
         Assert (not Lifecycle.Exit_Status_Known, "lifecycle records no exit status for a detached launch");
      end;

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (No_Op_Executable, Files.Settings.String_Vectors.Empty_Vector));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed, "zero-argument open action executes");
      Assert (To_String (Result.Action_Executable) = No_Op_Executable, "zero-argument action exposes executable");
      Assert (Result.Action_Arguments = 0, "zero-argument action exposes empty argument vector");
      Assert (Result.Execution_Attempted, "zero-argument action records process attempt");
      Assert (Result.Executable_Found, "zero-argument action records executable discovery");
      Assert (not Result.Exit_Status_Known, "zero-argument detached action records no exit status");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Set_Error (Model, "error.open_action.execution");
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "multi-file open action can be prepared");
      Assert (not Result.Execution_Attempted, "multi-file open preparation does not execute actions");
      Assert
        (To_String (Result.Path) = Join (Root, "Alpha.txt"),
         "multi-file open preparation reports first selected path");
      Assert
        (To_String (Result.Action_Executable) = No_Op_Executable,
         "multi-file open preparation exposes first executable");
      Assert (Files.Model.Last_Error_Key (Model) = "", "multi-file open preparation clears stale error state");
      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed, "multi-file open executes actions");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "multi-file open reports first selected path");
      Assert (Result.Execution_Attempted, "multi-file open records process attempts");
      Assert (Result.Executable_Found, "multi-file open records executable discovery");
      Assert
           (To_String (Result.Action_Executable) = No_Op_Executable,
            "multi-file open exposes first action executable");
      Assert (Result.Action_Arguments = 3, "multi-file open exposes first action argument count");
      Assert
        (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "multi-file open exposes first expanded action path");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Spawned,
         "multi-file open lifecycle records a spawned action");
      Assert (Files.Model.Last_Error_Key (Model) = "", "multi-file open clears stale error state");
      Files.Model.Select_Visible (Model, 1);

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-preflight-marker");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         --  An action that leaves a trace if it runs, so the assertions below can
         --  prove nothing ran rather than take the result's word for it.
         --
         --  This was "/bin/sh -c touch <path>" -- two POSIX assumptions in one line.
         --  Windows has no /bin/sh, so this action failed on its own missing
         --  executable before the preflight reached the item the test is about.
         Preflight_Args.Append (To_Unbounded_String (Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action (Marker_Executable, Preflight_Args));
         --  Keep the missing-action preflight deterministic by opting out of
         --  the host opener fallback for the unmapped second selection.
         Preflight_Settings.Use_System_Default_Opener := False;
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result :=
           Files.Operations.Prepare_Open_Selected_Action (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preparation preflights all actions");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file open preparation failure records no process attempt");
         Assert
           (To_String (Preflight_Result.Path) = Join (Root, "Gamma.md"),
            "multi-file open preparation failure reports missing-action path");
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preflights all actions before spawning");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
           "multi-file preflight failure does not execute earlier selected action");
      end;

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-executable-marker");
         Missing_Executable : constant String := Join (Root, "missing-open-executable");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         --  An action that leaves a trace if it runs, so the assertions below can
         --  prove nothing ran rather than take the result's word for it.
         --
         --  This was "/bin/sh -c touch <path>" -- two POSIX assumptions in one line.
         --  Windows has no /bin/sh, so this action failed on its own missing
         --  executable before the preflight reached the item the test is about.
         Preflight_Args.Append (To_Unbounded_String (Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action (Marker_Executable, Preflight_Args));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/markdown",
            Files.Settings.Make_Action (Missing_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Failed,
            "multi-file open preflights missing executables before spawning");
         Assert
           (To_String (Preflight_Result.Error_Key) = "error.open_action.executable_missing",
            "multi-file executable preflight reports executable diagnostic");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file executable preflight failure records no process attempt");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
            "multi-file executable preflight failure does not execute earlier selected action");
      end;

      declare
         Detached_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Detached_Model    : Files.Model.Window_Model := Sample_Model;
         Detached_Result   : Files.Operations.Operation_Result;
      begin
         --  Open actions are now launched detached (fire-and-forget) through a
         --  backgrounding shell wrapper, so a launched application's own exit
         --  code is no longer observable: even /bin/false reports success
         --  because the wrapper shell itself exits zero after backgrounding.
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/plain",
            Files.Settings.Make_Action (No_Op_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/markdown",
            Files.Settings.Make_Action (Failing_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Detached_Model, 1);
         Files.Model.Toggle_Visible_Selection (Detached_Model, 3);
         Detached_Result := Files.Operations.Open_Selected (Detached_Model, Detached_Settings);
         Assert
           (Detached_Result.Status = Files.Operations.Operation_Action_Executed,
            "multi-file detached open succeeds without surfacing app exit codes");
         Assert
           (To_String (Detached_Result.Path) = Join (Root, "Alpha.txt"),
            "multi-file detached open reports first selected path");
         Assert
           (To_String (Detached_Result.Action_Executable) = No_Op_Executable,
            "multi-file detached open exposes first action executable");
         Assert
           (Detached_Result.Execution_Attempted,
            "multi-file detached open records process attempt");
         Assert
           (Detached_Result.Executable_Found,
            "multi-file detached open records executable discovery");
         --  There is no exit status to record. The launch does not wait, so what
         --  used to be asserted here was the wrapper shell's zero -- a number that
         --  said nothing whatever about the application.
         Assert
           (not Detached_Result.Exit_Status_Known,
            "a detached open has no exit status to report");
         Assert
           (Files.Model.Last_Error_Key (Detached_Model) = "",
            "multi-file detached open clears stale error state");
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then
              Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then
              Ada.Environment_Variables.Value ("SHELL") else ""));

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", "/bin/custom-sh");
         Assert (Files.Operations.Shell_Executable = "/bin/custom-sh", "explicit shell uses SHELL fallback");
         Assert (Files.Operations.Shell_Command_Option = "-c", "SHELL fallback uses POSIX command option");
         Ada.Environment_Variables.Set ("COMSPEC", "C:\Windows\System32\cmd.exe");
         Assert
           (Files.Operations.Shell_Executable = "C:\Windows\System32\cmd.exe",
            "explicit shell prefers COMSPEC when present");
         Assert (Files.Operations.Shell_Command_Option = "/C", "COMSPEC shell uses Windows command option");
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then
              Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then
              Ada.Environment_Variables.Value ("SHELL") else ""));
         Missing_Shell_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Missing_Shell_Model    : Files.Model.Window_Model := Sample_Model;
         Missing_Shell_Action   : Files.Operations.Operation_Result;

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", Join (Root, "missing-shell"));
         Files.Settings.Add_Open_Action
           (Missing_Shell_Settings,
            "text/plain",
            Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, Use_Shell => True));
         Files.Model.Select_Visible (Missing_Shell_Model, 1);
         Missing_Shell_Action := Files.Operations.Open_Selected (Missing_Shell_Model, Missing_Shell_Settings);
         Assert
           (Missing_Shell_Action.Status = Files.Operations.Operation_Failed,
            "explicit shell action fails preflight when shell executable is missing");
         Assert
           (not Missing_Shell_Action.Execution_Attempted,
            "missing shell executable is rejected before spawn");
         Assert
           (not Missing_Shell_Action.Executable_Found,
            "missing shell executable records failed executable lookup");
         Assert
           (To_String (Missing_Shell_Action.Error_Key) = "error.open_action.executable_missing",
            "missing shell executable reports executable diagnostic");
         Assert
           (Files.Model.Last_Error_Key (Missing_Shell_Model) = "error.open_action.executable_missing",
            "missing shell executable records model diagnostic");
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      Files.Model.Select_Visible (Model, 2);
      Files.Model.Focus_Filter_Input (Model);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Assert (Routed.Status = Files.Controller.Controller_Selection_Moved, "click selects item without opening");
      Assert (Routed.Command = Files.Commands.No_Command, "selection click does not execute a command");
      Assert (Files.Model.Selected_Index (Model) = 1, "click selection updates selected visible index");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "item click clears text input focus");
      Routed := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Routed.Status = Files.Controller.Controller_Selection_Moved, "arrow key moves after item click");
      Assert (Files.Model.Selected_Index (Model) = 2, "arrow key uses main view after item click");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/typed-path");
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 0);
      Assert (Routed.Status = Files.Controller.Controller_Ignored, "outside item click is ignored");
      Assert (Files.Model.Selected_Index (Model) = 2, "outside item click preserves selection");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "outside item click preserves focus");
      Assert (Files.Model.Path_Input_Text (Model) = "/tmp/typed-path", "outside item click preserves edited text");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Select_Visible (Model, 1);

      --  An argument that tries to be a second command. Each shell has its own way
      --  of spelling that -- ";" for sh, "&" for cmd -- and the executable has to be
      --  one that exists on the host, which "true" is not on Windows. If the quoting
      --  holds, the whole thing stays one argument to Noop, which ignores it and
      --  exits zero; if it leaks, the shell runs "exit 9" and we see a 9.
      Injected_Argument :=
        To_Unbounded_String
          ("literal" & Shell_Command_Separator & " exit 9");
      Shell_Arguments.Append (Injected_Argument);
      Shell_Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (No_Op_Executable, Shell_Arguments, True));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "unmodified action fallback can be prepared");
      Assert (Result.Action.Use_Shell, "prepared fallback action preserves explicit shell execution");
      Assert (Result.Action_Uses_Shell, "prepared result exposes explicit shell flag");
      Assert
        (To_String (Result.Action.Arguments.Element (1)) = To_String (Injected_Argument),
         "explicit shell action keeps the separator argument as one vector value");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "file open quotes explicit shell arguments before execution");
      Assert (Result.Action.Use_Shell, "explicit shell action remains explicit after execution");
      Assert (Result.Action_Uses_Shell, "executed shell result exposes explicit shell flag");
      Assert (Result.Execution_Attempted, "executed shell action records process attempt");
      Assert (not Result.Exit_Status_Known, "a detached shell action reports no exit status");

      --  The quoting is the point of this action. An exit code is the only way to
      --  see it hold, and a detached launch has none, so ask for the same action
      --  synchronously: it goes through the same quoting on the way in.
      declare
         Exit_Status : Integer := -1;
         Ran         : constant Boolean :=
           Files.Operations.Execute_Open_Action (Result.Action, Exit_Status);
      begin
         Assert (Ran, "the quoted shell action runs to completion when awaited");
         Assert
           (Exit_Status = 0,
            "the separator stays inside one argument rather than running as a command; exit was "
            & Exit_Status'Image);
      end;

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, True));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "explicit shell action can execute shell builtins");
      Assert (Result.Action.Use_Shell, "shell builtin action preserves explicit shell execution");
      Assert (Result.Execution_Attempted, "shell builtin action records shell execution attempt");
      Assert (Result.Executable_Found, "shell builtin action records shell discovery");
      Assert (not Result.Exit_Status_Known, "a detached shell builtin reports no exit status");

      declare
         Exit_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Exit_Arguments.Append (To_Unbounded_String ("7"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/plain",
            Files.Settings.Make_Action ("exit", Exit_Arguments, True));
      end;
      --  "exit 7" is launched and let go, so its non-zero exit code is not surfaced.
      --  That was true before as well, but for a worse reason: the backgrounding
      --  wrapper shell exited zero and we reported *that*. Now nothing is reported.
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "detached explicit shell builtin launches fire-and-forget");
      Assert
        (Result.Execution_Attempted,
         "detached explicit shell builtin records a launch");
      Assert
        (Result.Executable_Found,
         "detached explicit shell builtin records successful shell lookup");
      Assert
        (not Result.Exit_Status_Known,
         "a detached launch does not surface the command's own exit code");
      Assert
        (Files.Model.Last_Error_Key (Model) = "",
         "detached explicit shell builtin clears stale error state");

      Files.Settings.Add_Open_Action
           (Settings,
            "text/plain",
            Files.Settings.Make_Action (Failing_Executable, Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "detached open action launches without surfacing app exit codes");
      Assert (Result.Execution_Attempted, "detached process result records execution attempt");
      Assert (Result.Executable_Found, "detached process result records executable discovery");
      --  This action's executable fails, and that is the point: a detached launch is
      --  reported as launched, and the application's own exit code is never seen.
      --  What used to be asserted here -- a known, zero exit status -- was the
      --  wrapper shell's, which succeeded in backgrounding a program that then went
      --  on to fail. Nothing waits for it now, so there is no status at all.
      Assert (not Result.Exit_Status_Known, "a detached process reports no exit status");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State = Files.Operations.Open_Action_Spawned,
         "detached process lifecycle records it as spawned, not completed");
      Assert
        (not Files.Operations.Open_Action_Lifecycle_Of (Result).Exit_Status_Known,
         "detached process lifecycle exposes no exit status");
      Assert
        (Files.Model.Last_Error_Key (Model) = "",
         "detached open action clears localized error key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("/tmp/files_missing_open_action_executable", Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "missing open executable is represented");
      Assert (not Result.Execution_Attempted, "missing executable result does not attempt execution");
      Assert (not Result.Executable_Found, "missing executable result records failed lookup");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Preflight_Failed,
         "missing executable lifecycle records preflight failure");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.executable_missing",
         "missing open executable returns a specific diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.executable_missing",
         "missing open executable stores specific diagnostic key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (Root, Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "directory open executable is represented");
      Assert (not Result.Execution_Attempted, "directory executable result does not attempt execution");
      Assert (not Result.Executable_Found, "directory executable result records failed lookup");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.executable_missing",
         "directory executable returns the missing executable diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.executable_missing",
         "directory executable stores the missing executable diagnostic key");

      declare
         Unsafe_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Unsafe_Arguments.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-argument",
            Files.Settings.Make_Action (No_Op_Executable, Unsafe_Arguments));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-argument", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects embedded placeholders before operation preparation");
         Assert
           (To_String (Lookup.Error_Key) = "error.open_action.missing",
            "rejected embedded-placeholder action is absent from lookup");
         Assert (Files.Model.Current_Path (Model) = Root, "unsafe open action does not navigate");

         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-executable",
            Files.Settings.Make_Action ("{path}", Files.Types.String_Vectors.Empty_Vector));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-executable", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects executable placeholders before operation preparation");
         Assert
           (To_String (Lookup.Error_Key) = "error.open_action.missing",
            "rejected executable-placeholder action is absent from lookup");
      end;

      Files.Model.Set_Error (Model, "error.open_action.missing");
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action (No_Op_Executable, Arguments));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "modifier-specific action can be prepared");
      Assert
        (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "prepared modifier-specific action expands path");
      Routed := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return, Modifiers);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "Return routes file open command");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Action_Executed,
         "Return executes configured open action");
      Assert
        (To_String (Routed.Operation.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "Return open preserves modifier-specific action lookup");
      Assert (Files.Model.Last_Error_Key (Model) = "", "Return open clears stale error state");

      Files.Model.Select_Visible (Model, 2);
      Routed :=
        Files.Controller.Handle_Item_Click
          (Model, Settings, Visible_Index => 1, Activate => True, Modifiers => Modifiers);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click file routes open command");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Action_Executed,
         "double-click file executes configured action");
      Assert (Files.Model.Selected_Index (Model) = 1, "double-click selects activated file");
   end Test_Open_Selected_File_Prepares_Action;

   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      --  Exercise the genuine missing-action contract deterministically by
      --  opting out of the host opener fallback that would otherwise resolve.
      Settings.Use_System_Default_Opener := False;
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Missing_Open_Action, "prepare reports missing action");
      Assert (To_String (Result.Path) = Join (Root, "Gamma.md"), "prepare missing action reports file path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.open_action.missing", "prepare missing action records error");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Missing_Open_Action, "missing action is reported");
      Assert (To_String (Result.Path) = Join (Root, "Gamma.md"), "missing action reports selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.open_action.missing", "missing action sets error state");
      Assert (Files.Model.Current_Path (Model) = Root, "missing file action does not navigate");
   end Test_Missing_Open_Action_Reports_Error;

   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_File (Model, "created.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create commit succeeds");
      Assert (To_String (Result.Path) = Join (Root, "created.txt"), "create commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created.txt")), "create commit creates the file");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful create clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create commit clears temporary state");
      Assert (not Files.Model.Rename_Is_Active (Model), "create commit clears rename state");
      Assert (Files.Model.Item_Count (Model) = 1, "create commit reloads the directory model");
      Assert (Files.Model.Selected_Name (Model) = "created.txt", "created item is selected after reload");
   end Test_Commit_Create_File;

   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_Folder (Model, "created-folder");
      Assert (Files.Model.Temporary_Item_Is_Directory (Model), "create-folder marks temporary item as directory");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create-folder commit succeeds");
      Assert (To_String (Result.Path) = Join (Root, "created-folder"), "create-folder commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created-folder")), "create-folder commit creates the entry");
      Assert
        (Ada.Directories.Kind (Join (Root, "created-folder")) = Ada.Directories.Directory,
         "create-folder commit creates a directory");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful create-folder clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create-folder commit clears temporary state");
      Assert (not Files.Model.Temporary_Item_Is_Directory (Model), "create-folder commit clears directory flag");
      Assert (not Files.Model.Rename_Is_Active (Model), "create-folder commit clears rename state");
      Assert (Files.Model.Item_Count (Model) = 1, "create-folder commit reloads the directory model");
      Assert (Files.Model.Selected_Name (Model) = "created-folder", "created folder is selected after reload");
   end Test_Commit_Create_Folder;

   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result        : Files.Operations.Operation_Result;
      Existing_Path : constant String := Join (Root, "existing.txt");
      Direct_Path   : constant String := Join (Root, "direct-created.txt");
      Utf8_Two_Name   : constant String := "caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt";
      Utf8_Three_Name : constant String := Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & "uro.txt";
      Utf8_Four_Name  : constant String :=
        "folder-" & Byte (16#F0#) & Byte (16#9F#) & Byte (16#93#) & Byte (16#81#) & ".txt";
      Mutation      : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Existing_Path, "original");
      Ada.Directories.Create_Path (Join (Root, "existing-dir"));
      Mutation := Files.File_System.Create_Empty_File ("");
      Assert (not Mutation.Success, "create reports empty destination failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "empty destination create reports parent diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "existing-dir"));
      Assert (not Mutation.Success, "create refuses an existing directory destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.exists",
         "existing directory create reports exists diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Existing_Path);
      Assert (not Mutation.Success, "create refuses an existing file destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.exists",
         "existing file create reports exists diagnostic");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Existing_Path), "original") > 0,
         "direct existing-file create preserves file content");
      Mutation := Files.File_System.Create_Empty_File (Join (Join (Root, "missing-parent"), "child.txt"));
      Assert (not Mutation.Success, "create reports missing parent failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "missing parent create reports parent diagnostic");
      Assert
        (not Ada.Directories.Exists (Join (Join (Root, "missing-parent"), "child.txt")),
         "missing parent create writes no child file");
      Mutation := Files.File_System.Create_Empty_File (Join (Existing_Path, "child.txt"));
      Assert (not Mutation.Success, "create reports non-directory parent failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "non-directory parent create reports parent diagnostic");
      Mutation :=
        Files.File_System.Create_Empty_File (Join (Root, "bad" & Character'Val (9) & "name.txt"));
      Assert (not Mutation.Success, "direct create rejects invalid leaf names");
      Assert
        (To_String (Mutation.Error_Key) = "error.name.invalid",
         "direct invalid-name create reports invalid-name diagnostic");
      Assert
        (not Path_Exists (Join (Root, "bad" & Character'Val (9) & "name.txt")),
         "direct invalid-name create writes no file");
      Mutation := Files.File_System.Create_Empty_File (Direct_Path);
      Assert (Mutation.Success, "direct create mutation succeeds");
      Assert (To_String (Mutation.Error_Key) = "", "successful direct create has no error key");
      Assert (Ada.Directories.Exists (Direct_Path), "direct create writes the requested file");
      declare
         Original_Content : constant String := Project_Tools.Files.Read_Raw_File (Existing_Path);
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Begin_Create_File (Model, "existing.txt");

         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Assert (Result.Status = Files.Operations.Operation_Failed, "create refuses an existing destination");
         Assert (To_String (Result.Error_Key) = "error.file.exists", "create reports existing file error");
         Assert (To_String (Result.Path) = Existing_Path, "failed create reports attempted destination path");
         Assert (Files.Model.Last_Error_Key (Model) = "error.file.exists", "model records existing file error");
         Assert
           (Project_Tools.Files.Read_Raw_File (Existing_Path) = Original_Content,
            "failed create leaves existing file content unchanged");
         Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed create keeps temporary item active");
         Assert (Files.Model.Rename_Is_Active (Model), "failed create keeps rename mode active");
         Assert (Files.Model.Temporary_Item_Name (Model) = "existing.txt", "failed create keeps attempted name");

         Files.Model.Set_Rename_Text (Model, "retry.txt");
         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Assert (Result.Status = Files.Operations.Operation_Success, "create retry after collision succeeds");
         Assert (Ada.Directories.Exists (Join (Root, "retry.txt")), "create retry writes renamed file");
         Assert
           (Project_Tools.Files.Read_Raw_File (Existing_Path) = Original_Content,
            "create retry preserves original existing file");
         Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create retry clears temporary state");
         Assert (Files.Model.Selected_Name (Model) = "retry.txt", "create retry selects created file");
      end;

      Files.Model.Begin_Create_File (Model, Utf8_Two_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts two-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Two_Name)), "two-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Two_Name, "two-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Three_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts three-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Three_Name)), "three-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Three_Name, "three-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Four_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts four-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Four_Name)), "four-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Four_Name, "four-byte UTF-8 create selects file");
   end Test_Create_File_Does_Not_Overwrite;

   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sources  : Files.Types.String_Vectors.Vector;
      Search   : Files.File_System.Recursive_Search_Result;
      Before   : Files.File_System.Directory_Signature;
      Change   : Files.File_System.Directory_Change_Result;
      Plans    : Files.File_System.Drop_Import_Result;
      Mutation : Files.File_System.Mutation_Result;
      Thumbnail : Files.File_System.Thumbnail_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Source_File : constant String := Join (Root, "drop-source.txt");
      Source_Dir  : constant String := Join (Root, "drop-dir");
      Drop_Target : constant String := Join (Root, "drop-target");
      Delete_Dir  : constant String := Join (Root, "delete-tree");
      Thumbnail_Source : constant String := Join (Root, "picture.png");
      Decoded_Png_Source : constant String := Join (Root, "decoded-picture.png");
      Ppm_Thumbnail_Source : constant String := Join (Root, "picture.ppm");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
      Cache_Home : constant String := Join (Root, "cache-home");
      Had_Cache  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache  : Unbounded_String;

      procedure Restore_Cache is
      begin
         if Had_Cache then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Cache));
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;
      end Restore_Cache;
   begin
      if Had_Cache then
         Old_Cache := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "search"));
      Ada.Directories.Create_Path (Join (Join (Root, "search"), "nested"));
      Write_File (Join (Join (Root, "search"), "alpha-match.txt"), "alpha");
      Write_File (Join (Join (Join (Root, "search"), "nested"), "beta-match.txt"), "beta");
      Write_File (Join (Join (Root, "search"), "skip.txt"), "skip");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "MATCH", Settings);
      Assert (Search.Success, "recursive search succeeds");
      Assert (Natural (Search.Items.Length) = 2, "recursive search finds nested matches");
      Assert
        (To_String (Search.Items.Element (1).Name) = "alpha-match.txt",
         "recursive search preserves deterministic parent order");
      Assert
        (To_String (Search.Items.Element (2).Name) = "beta-match.txt",
         "recursive search descends into child directories");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "match", Settings, Max_Items => 1);
      Assert (Natural (Search.Items.Length) = 1, "recursive search respects result limits");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is disabled without filter text");
      Files.Model.Set_Filter (Model, "match");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is enabled with filter text");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Search_Recursive_Command,
         "recursive search routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "recursive search command succeeds");
      Assert (Files.Model.Item_Count (Model) = 2, "recursive search command loads nested result items");
      Assert
        (To_String (Files.Model.Visible_Item (Model, 2).Name) = "beta-match.txt",
         "recursive search command exposes nested matches in the model");
      Routed := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "refresh restores direct listing");
      Assert (Files.Model.Item_Count (Model) = 3, "refresh after recursive search reloads direct children");

      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Write_File (Join (Join (Root, "search"), "new-file.txt"), "new");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "polling directory watcher detects added entries");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count + 1,
         "directory watcher reports updated entry count");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Join (Root, "search")));
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "unchanged directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 4, "unchanged watcher refresh keeps loaded item count");
      Write_File (Join (Join (Root, "search"), "watched-add.txt"), "watch");
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "changed directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 5, "changed watcher refresh reloads new directory items");
      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Ada.Directories.Delete_File (Join (Join (Root, "search"), "skip.txt"));
      Write_File (Join (Join (Root, "search"), "same-count-replacement.txt"), "replacement");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "directory watcher detects same-count replacement");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count,
         "same-count replacement keeps directory entry count stable");
      Assert
        (Change.After_State.Entry_State_Checksum /= Before.Entry_State_Checksum,
         "same-count replacement changes directory entry checksum");
      Files.Model.Set_Directory_Signature (Model, Before);
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "same-count watcher refresh succeeds");
      Assert
        (Files.Model.Item_Count (Model) = 5,
         "same-count watcher refresh keeps replacement entry count");

      Ada.Directories.Create_Path (Drop_Target);
      Write_File (Source_File, "drop");
      Ada.Directories.Create_Path (Source_Dir);
      Write_File (Join (Source_Dir, "inside.txt"), "inside");
      Sources.Append (To_Unbounded_String (Source_File));
      Sources.Append (To_Unbounded_String (Source_Dir));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target);
      Assert (Plans.Success, "drop import planning accepts valid dropped paths");
      Assert (Natural (Plans.Plans.Length) = 2, "drop import plans every source path");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import copy executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "drop-source.txt")), "drop import copies files");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "drop-dir"), "inside.txt")),
         "drop import copies directories");
      Assert (Ada.Directories.Exists (Source_File), "drop copy preserves source file");

      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Source_File));
      --  Dropping onto a name that already exists now arms the paste conflict
      --  dialog (routed through the engine) instead of silently auto-renaming.
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "controller drop import succeeds");
      Assert
        (Files.Model.Paste_Conflict_Is_Active (Model),
         "a colliding drop arms the conflict dialog instead of auto-renaming");
      Assert
        (Files.Model.Paste_Conflict_Name (Model) = "drop-source.txt",
         "the drop conflict dialog names the colliding item");
      Routed.Operation :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving the drop conflict clears the dialog");
      Assert
        (Ada.Directories.Exists (Join (Drop_Target, "drop-source 2.txt")),
         "renaming the drop conflict writes a collision-safe destination");
      Assert (Files.Model.Item_Count (Model) = 3, "resolved drop import refreshes destination model");

      Ada.Directories.Create_Path (Join (Drop_Target, "nested-target"));
      Write_File (Join (Drop_Target, "drag-source.txt"), "drag");
      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Drop_Target, "drag-source.txt")));
      --  A drop onto a specific folder row routes through Begin_Paste_To; with
      --  no name collision it executes the move immediately.
      Routed.Operation :=
        Files.Operations.Begin_Paste_To
          (Model          => Model,
           Settings       => Settings,
           Source_Paths   => Sources,
           Destination    => Join (Drop_Target, "nested-target"),
           Mode           => Files.File_System.Drop_Move,
           From_Clipboard => False);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "item drag import can target a specific directory");
      Assert
        (not Files.Model.Paste_Conflict_Is_Active (Model),
         "a collision-free targeted drop executes without arming the dialog");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "nested-target"), "drag-source.txt")),
         "item drag import moves the source into the target directory");
      Assert
        (not Ada.Directories.Exists (Join (Drop_Target, "drag-source.txt")),
         "item drag move removes the source from the current directory");
      Assert (Files.Model.Item_Count (Model) = 4, "item drag import refreshes the source window model");

      Sources.Clear;
      Write_File (Join (Root, "move-source.txt"), "move");
      Sources.Append (To_Unbounded_String (Join (Root, "move-source.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import move executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "move-source.txt")), "drop move creates destination");
      Assert (not Ada.Directories.Exists (Join (Root, "move-source.txt")), "drop move removes source");

      --  Moving an item into the directory it already lives in is a no-op, but
      --  copying into the same directory still makes a numbered duplicate.
      Sources.Clear;
      Write_File (Join (Root, "stay.txt"), "stay");
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory move succeeds");
      Assert (Ada.Directories.Exists (Join (Root, "stay.txt")), "same-directory move keeps the file in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory move does not create a numbered duplicate");

      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Copy);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory copy succeeds");
      Assert
        (Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory copy still creates a numbered duplicate");

      --  A directory cannot be moved or copied into itself or a descendant;
      --  the recursive copy would otherwise recurse without bound.
      Ada.Directories.Create_Path (Join (Join (Root, "tree"), "sub"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "tree")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Move);
      Assert (not Plans.Success,
              "moving a directory into its own subtree is rejected; error was "
              & To_String (Plans.Error_Key));
      Assert
        (To_String (Plans.Error_Key) = "error.drop.into_self",
         "into-self drop reports a deterministic diagnostic");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into its own subtree is rejected");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "tree"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into itself is rejected");

      --  Two sources sharing a simple name from different directories must get
      --  distinct destinations within one batch (no silent overwrite).
      Ada.Directories.Create_Path (Join (Root, "src-a"));
      Ada.Directories.Create_Path (Join (Root, "src-b"));
      Write_File (Join (Join (Root, "src-a"), "dup.txt"), "a");
      Write_File (Join (Join (Root, "src-b"), "dup.txt"), "b");
      Ada.Directories.Create_Path (Join (Root, "dup-dest"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-a"), "dup.txt")));
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-b"), "dup.txt")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "dup-dest"), Files.File_System.Drop_Copy);
      Assert (Plans.Success, "same-name batch drop plans successfully");
      Assert (Natural (Plans.Plans.Length) = 2, "batch drop plans both sources");
      Assert
        (To_String (Plans.Plans.Element (1).Destination_Path)
           /= To_String (Plans.Plans.Element (2).Destination_Path),
         "same-name sources get distinct destinations within a batch");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-name batch copy executes");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup.txt")),
         "first same-name file is copied");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup 2.txt")),
         "second same-name file gets a distinct name instead of overwriting");

      Ada.Directories.Create_Path (Delete_Dir);
      Write_File (Join (Delete_Dir, "doomed.txt"), "doomed");
      Ada.Directories.Create_Path (Join (Delete_Dir, "nested"));
      Write_File (Join (Join (Delete_Dir, "nested"), "child.txt"), "child");
      Mutation := Files.File_System.Delete_Permanently (Delete_Dir);
      Assert (Mutation.Success, "explicit permanent delete removes a tree");
      Assert (not Ada.Directories.Exists (Delete_Dir), "permanent delete removes the target directory");
      Mutation := Files.File_System.Delete_Permanently ("/");
      Assert (not Mutation.Success, "permanent delete refuses root paths");
      Assert
        (To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
         "permanent delete reports unsafe target diagnostic");

      --  A child/.. spelling names the parent directory. Recursive deletion
      --  through that spelling could erase its contents before rmdir fails.
      declare
         Guard : constant String := Join (Root, "dot-delete-guard");
         Child : constant String := Join (Guard, "child");
         Kept : constant String := Join (Guard, "keep.txt");
         procedure Check_Refusal (Attempt : String) is
         begin
            Mutation := Files.File_System.Delete_Permanently (Attempt);
            Assert (not Mutation.Success
                      and then To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
                    "permanent delete refuses dot and parent path components");
            Assert (Ada.Directories.Exists (Child) and then Ada.Directories.Exists (Kept),
                    "a refused navigation path leaves the parent tree intact");
         end Check_Refusal;
      begin
         Ada.Directories.Create_Path (Child);
         Write_File (Kept, "keep this file");
         Check_Refusal (Child & "/..");
         Check_Refusal (Guard & "/.");
         Check_Refusal (Guard & "/./keep.txt");
         Check_Refusal (Child & "/../keep.txt");
      end;

      --  Regression: permanent-delete of a symlink to a directory must unlink
      --  the LINK, never follow it and recursively wipe the target's real
      --  contents (the previous Directory_Exists + Delete_Tree path did).
      declare
         Link_Target   : constant String := Join (Root, "sym-del-target");
         Kept_File     : constant String := Join (Link_Target, "precious.txt");
         Dir_Link      : constant String := Join (Root, "sym-del-link");
         Link_Result   : Files.File_System.Mutation_Result;
         Target_Kept   : Boolean := False;
         Content_Kept  : Boolean := False;
         Link_Gone     : Boolean := False;
      begin
         Ada.Directories.Create_Path (Link_Target);
         Write_File (Kept_File, "precious");
         if Files_Suite.Support.Create_Symlink (Link_Target, Dir_Link) then
            Link_Result := Files.File_System.Delete_Permanently (Dir_Link);
            --  Capture before cleanup so a failure cannot leave fixtures behind.
            Target_Kept  := Ada.Directories.Exists (Link_Target);
            Content_Kept := Ada.Directories.Exists (Kept_File);
            Link_Gone    := not Hostkit.Fs.Is_Link (Dir_Link);
            if Hostkit.Fs.Is_Link (Dir_Link) then
               declare
                  Removed : constant Boolean := Hostkit.Fs.Delete_Link (Dir_Link);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            end if;
            if Ada.Directories.Exists (Link_Target) then
               Project_Tools.Files.Delete_Tree (Link_Target);
            end if;
            Assert (Link_Result.Success, "permanent delete of a directory symlink succeeds");
            Assert (Link_Gone, "permanent delete removes the symlink itself");
            Assert (Target_Kept, "permanent delete of a symlink does not delete the link target directory");
            Assert (Content_Kept, "permanent delete of a symlink preserves the target's real contents");
         end if;
      end;

      Write_Binary_File (Thumbnail_Source, Minimal_Png_Header (48, 32));
      Thumbnail := Files.File_System.Generate_Thumbnail (Thumbnail_Source, Thumbnail_Cache, Size => 8);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "thumbnail generation succeeds");
      Assert (Thumbnail.Width = 8 and then Thumbnail.Height = 8, "thumbnail reports requested dimensions");
      Assert
        (Ada.Directories.Exists (To_String (Thumbnail.Thumbnail_Path)),
         "thumbnail generation writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "P6"),
         "thumbnail artifact is a binary PPM image");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "8 8"),
         "thumbnail artifact records requested image dimensions");
      declare
         Cache_Path : constant String := To_String (Thumbnail.Thumbnail_Path);
         Victim : constant String := Join (Root, "thumbnail-cache-victim");
      begin
         Ada.Directories.Delete_File (Cache_Path);
         Write_File (Victim, "must stay intact");
         if Files_Suite.Support.Create_Symlink (Victim, Cache_Path) then
            Thumbnail := Files.File_System.Generate_Thumbnail
              (Thumbnail_Source, Thumbnail_Cache, Size => 8);
            Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated,
                    "thumbnail generation replaces a cache symlink safely");
            Assert (not Hostkit.Fs.Is_Link (Cache_Path),
                    "thumbnail publication replaces the cache entry, not its target");
            Assert (File_Has_Bytes (Victim, "must stay intact"),
                    "thumbnail generation never truncates a cache symlink target");
            Assert (not Ada.Directories.Exists (Cache_Path & ".tmp")
                      and then not Hostkit.Fs.Is_Link (Cache_Path & ".tmp"),
                    "thumbnail publication leaves no temporary cache file");
         end if;
      end;

      --  Decode a COMPLETE PNG (IHDR + a real IDAT + IEND) through the pure-Ada
      --  fast path. The other cases use an IDAT-less header, so this is the only
      --  test that actually drives inflate + unfilter + pixel decode -- and thus
      --  the heap-backed raster buffer. A solid colour must survive the decode
      --  and downscale, so its distinctive red value appears in the written pixels.
      declare
         Png_W   : constant := 60;
         Png_H   : constant := 60;
         --  A well-formed PNG: signature, then an IHDR chunk (with a CRC slot,
         --  unlike Minimal_Png_Header) declaring 8-bit truecolour, non-interlaced.
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#);
         Ihdr    : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (Png_W)
           & Byte (0) & Byte (0) & Byte (0) & Byte (Png_H)
           & Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
         Raster  : Unbounded_String;
         Png_Src : constant String := Join (Root, "decodable-rgb.png");
         Decoded : Files.File_System.Thumbnail_Result;
      begin
         for Row in 1 .. Png_H loop
            Append (Raster, Byte (0));  -- PNG row filter type 0 (None)
            for Col in 1 .. Png_W loop
               Append (Raster, Byte (173) & Byte (89) & Byte (211));
            end loop;
         end loop;
         Write_Binary_File
           (Png_Src,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("IDAT", Stored_Zlib_Stream (To_String (Raster)))
            & Chunk ("IEND", ""));
         Decoded := Files.File_System.Generate_Thumbnail (Png_Src, Thumbnail_Cache, Size => 8);
         Assert
           (Decoded.Status = Files.File_System.Thumbnail_Generated,
            "a complete PNG decodes through the pure-Ada fast path");
         Assert
           (File_Has_Bytes (To_String (Decoded.Thumbnail_Path), Byte (173) & Byte (89) & Byte (211)),
            "the decoded solid colour survives inflate/unfilter/downscale");
      end;

      Write_Binary_File
        (Decoded_Png_Source,
         Minimal_Png_RGB
           (2,
            2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));
      Thumbnail := Files.File_System.Generate_Thumbnail (Decoded_Png_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PNG thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PNG thumbnail preserves source pixel colors");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Load := Files.File_System.Load_Directory (Root, Settings);
      declare
         Found_Auto_Thumbnail : Boolean := False;
         Extension_Settings    : Files.Settings.Settings_Model := Settings;
         Extension_Load        : Files.File_System.Directory_Load_Result;
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = "decoded-picture.png" then
               Found_Auto_Thumbnail := True;
               Assert (Item.Thumbnail_Available, "directory loading auto-generates image thumbnails");
               Assert (Item.Thumbnail_Width = 64, "auto-generated thumbnail records default width");
               Assert (Item.Thumbnail_Height = 64, "auto-generated thumbnail records default height");
               Assert
                 (Natural (Item.Thumbnail_Pixels.Length) = 64 * 64 * 4,
                  "auto-generated thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "auto-thumbnail image item is loaded");

         Files.Settings.Add_Extension_Mapping (Extension_Settings, "webp", "application/octet-stream");
         Write_File (Join (Root, "extension-only.webp"), "not a decoded image");
         Extension_Load := Files.File_System.Load_Directory (Root, Extension_Settings);
         Found_Auto_Thumbnail := False;
         for Item of Extension_Load.Items loop
            if To_String (Item.Name) = "extension-only.webp" then
               Found_Auto_Thumbnail := True;
               Assert
                 (Item.Thumbnail_Available,
                  "directory loading auto-generates thumbnails for image extensions");
               Assert
                 (Natural (Item.Thumbnail_Pixels.Length) = 64 * 64 * 4,
                  "image-extension thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "image-extension thumbnail item is loaded");

         --  A cache written before the format changed must still load. The
         --  thumbnails are keyed on the source path and nothing invalidates
         --  them, so a user upgrading has a directory full of ASCII P3 files
         --  that the loader has to keep reading -- otherwise every one of them
         --  silently stops rendering until its source happens to be
         --  re-thumbnailed. Put one there by hand and read it back.
         declare
            Legacy_Source : constant String := Join (Root, "legacy-cached.png");
            Legacy_Cache  : constant String :=
              Files.File_System.Thumbnail_Path_For
                (Legacy_Source,
                 Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                 64);
            Legacy_Load   : Files.File_System.Directory_Load_Result;
            Found_Legacy  : Boolean := False;
            Ascii_Pixels  : Unbounded_String;
         begin
            Write_Binary_File (Legacy_Source, Minimal_Png_Header (8, 8));

            --  2x2 of red, green, blue, white in the old ASCII form.
            Append (Ascii_Pixels, "P3" & ASCII.LF & "2 2" & ASCII.LF & "255" & ASCII.LF);
            Append (Ascii_Pixels, "255 0 0 0 255 0" & ASCII.LF & "0 0 255 255 255 255" & ASCII.LF);
            Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Legacy_Cache));
            Write_File (Legacy_Cache, To_String (Ascii_Pixels));

            Legacy_Load := Files.File_System.Load_Directory (Root, Settings);
            for Item of Legacy_Load.Items loop
               if To_String (Item.Name) = "legacy-cached.png" then
                  Found_Legacy := True;
                  Assert
                    (Item.Thumbnail_Available,
                     "a thumbnail cached in the old ASCII format still loads");
                  Assert
                    (Item.Thumbnail_Width = 2 and then Item.Thumbnail_Height = 2,
                     "and reports the dimensions its own header declares");
                  Assert
                    (Natural (Item.Thumbnail_Pixels.Length) = 2 * 2 * 4,
                     "and yields renderable pixels");
               end if;
            end loop;

            Assert (Found_Legacy, "the legacy-cached item is listed");
         end;
      end;
      Assert
        (Project_Tools.Files.Any_File_Contains ("src", "gdk_pixbuf_new_from_file_at_size")
         or else Project_Tools.Files.Any_File_Contains ("../src", "gdk_pixbuf_new_from_file_at_size")
         or else Project_Tools.Files.Any_File_Contains ("../../src", "gdk_pixbuf_new_from_file_at_size"),
         "JPEG thumbnail decoding is routed through the native image loader binding");

      Write_File
        (Ppm_Thumbnail_Source,
         "P3" & ASCII.LF
         & "# decoded thumbnail fixture" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 0 255 0" & ASCII.LF
         & "0 0 255 255 255 255" & ASCII.LF);
      Thumbnail := Files.File_System.Generate_Thumbnail (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PPM thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PPM thumbnail preserves source pixel colors");

      Thumbnail := Files.File_System.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Assert
        (To_String (Thumbnail.Error_Key) = "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");

      Write_File (Join (Root, "command-delete.txt"), "delete");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-delete.txt");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Permanently_Command, Model),
         "permanent delete command is enabled for selected items");
      Routed :=
        Files.Controller.Execute_Command
          (Files.Commands.Delete_Selected_Permanently_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Delete_Selected_Permanently_Command,
         "permanent delete routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "permanent delete command succeeds");
      Assert
        (not Ada.Directories.Exists (Join (Root, "command-delete.txt")),
         "permanent delete command removes the selected file");

      Write_File
        (Join (Root, "command-thumbnail.ppm"),
         "P3" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-thumbnail.ppm");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Routed := Files.Controller.Execute_Command (Files.Commands.Generate_Thumbnails_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Generate_Thumbnails_Command,
         "thumbnail generation routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "thumbnail command succeeds");
      Assert
        (Ada.Directories.Exists (To_String (Routed.Operation.Path)),
         "thumbnail command writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Routed.Operation.Path), "P6"),
         "thumbnail command writes PPM thumbnail content");
      Assert
        (Files.Model.Selected_Item (Model).Thumbnail_Available,
         "thumbnail command refresh exposes generated thumbnail in the model");
      Assert
        (To_String (Files.Model.Selected_Item (Model).Thumbnail_Path) = To_String (Routed.Operation.Path),
         "thumbnail command refresh records the generated thumbnail path");
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      declare
         Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Files.Rendering.Build_Snapshot (Model, Settings),
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);
         Empty_Text : Files.Rendering.Text_Render_Result;
         Thumbnail_Batch : Guikit.Vulkan.Submission_Batch;
         Found_Thumbnail_Command : Boolean := False;
         Found_Thumbnail_Icon    : Boolean := False;
         Thumbnail_Tile          : Natural := 0;
         Icon_Index              : Natural := 0;
      begin
         for Command of Thumbnail_Frame.Icons loop
            if Length (Command.Icon_Id) < 8
              or else Slice (Command.Icon_Id, 1, 8) /= "toolbar-"
            then
               Icon_Index := Icon_Index + 1;
            end if;
            if To_String (Command.Asset_Path) = To_String (Routed.Operation.Path) then
               Found_Thumbnail_Command := True;
               Thumbnail_Tile := Icon_Index - 1;
               if To_String (Command.Icon_Id) = "thumbnail" then
                  Found_Thumbnail_Icon := True;
               end if;
            end if;
         end loop;

         Assert
           (Found_Thumbnail_Command,
            "large-icons item icon command points at the generated thumbnail artifact");
         Assert
           (Found_Thumbnail_Icon,
            "large-icons item icon command uses a thumbnail-specific icon asset");
         Thumbnail_Batch := Guikit.Vulkan.Build_Submission
           (Rectangles         => Thumbnail_Frame.Rectangles,
            Triangles          => Thumbnail_Frame.Triangles,
            Icons              => Thumbnail_Frame.Icons,
            Overlay_Rectangles => Thumbnail_Frame.Overlay_Rectangles,
            Layout             => Thumbnail_Frame.Layout,
            Theme              => Thumbnail_Frame.Theme_Palette,
            Text               => Empty_Text);
         declare
            Pixel_Offset : constant Positive := Positive (Thumbnail_Tile * 64 * 4 + 1);
         begin
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset) = 255
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 1) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 2) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 3) = 255,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels");
         end;
      end;
      for Mode in Files.Types.Small_Icons .. Files.Types.Details loop
         if Mode /= Files.Types.Large_Icons then
            Files.Model.Set_View_Mode (Model, Mode);
            declare
               Non_Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Files.Rendering.Build_Snapshot (Model, Settings),
                    Width       => 1000,
                    Height      => 800,
                    Line_Height => 20);
            begin
               for Command of Non_Thumbnail_Frame.Icons loop
                  Assert
                    (To_String (Command.Icon_Id) /= "thumbnail",
                     "non-large item icon command keeps filetype icon");
                  Assert
                    (Command.Thumbnail_Width = 0
                     and then Command.Thumbnail_Height = 0
                     and then Command.Thumbnail_Pixels.Is_Empty,
                     "non-large item icon command does not carry thumbnail pixels");
               end loop;
            end;
         end if;
      end loop;
      Restore_Cache;
   exception
      when others =>
         Restore_Cache;
         raise;
   end Test_Advanced_Filesystem_Operations;

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
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Not_Image  : constant String := Join (Root, "notes.txt");
      Cache      : constant String := Join (Root, "explicit-cache");
      Generated  : Files.File_System.Thumbnail_Result;
      Listed     : Files.File_System.Directory_Load_Result;
      Found      : Boolean := False;
      Had_Cache  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache  : Unbounded_String;
   begin
      if Had_Cache then
         Old_Cache := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      Reset_Root;
      Write_File (Not_Image, "just text, no image anywhere in it");
      Ada.Directories.Create_Path (Cache);

      --  The command's own path: generate for whatever is selected, image or not.
      Generated := Files.File_System.Generate_Thumbnail (Not_Image, Cache);
      Assert
        (Generated.Status = Files.File_System.Thumbnail_Generated,
         "the thumbnail command produces something even for a text file");

      --  Point the listing at that cache and read the directory back.
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Join (Root, "explicit-xdg"));
      Ada.Directories.Create_Path (Join (Join (Join (Root, "explicit-xdg"), "files"), "thumbnails"));
      Ada.Directories.Copy_File
        (To_String (Generated.Thumbnail_Path),
         Join (Join (Join (Join (Root, "explicit-xdg"), "files"), "thumbnails"),
               Ada.Directories.Simple_Name (To_String (Generated.Thumbnail_Path))));

      Listed := Files.File_System.Load_Directory (Root, Settings);
      for Item of Listed.Items loop
         if To_String (Item.Name) = "notes.txt" then
            Found := True;
            Assert
              (Item.Thumbnail_Available,
               "a text file with a thumbnail in the cache still shows it when listed");
            Assert
              (Natural (Item.Thumbnail_Pixels.Length) > 0,
               "and the pixels come with it");
         end if;
      end loop;

      Assert (Found, "the text file is listed");

      if Had_Cache then
         Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Cache));
      else
         Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
      end if;
   end Test_Explicit_Thumbnail_Survives_The_Listing;

   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Plain      : constant String := Join (Root, "plain-file.txt");
      Runnable   : constant String := Join (Root, "runnable.sh");
      Sub_Dir    : constant String := Join (Root, "a-directory");

      function Execute_Bit (Path : String) return Character is
         Loaded : constant Files.File_System.Item_Load_Result :=
           Files.File_System.Load_Item (Path, Settings);
         Text   : constant String := To_String (Loaded.Item.Permissions);
      begin
         Assert (Loaded.Success, "the item loads: " & Path);
         Assert (Text'Length = 3, "the permission column has three positions: " & Text);
         return Text (Text'First + 2);
      end Execute_Bit;
   begin
      Reset_Root;
      Write_File (Plain, "not runnable");
      Write_File (Runnable, "#!/bin/sh" & ASCII.LF & "exit 0");
      Ada.Directories.Create_Directory (Sub_Dir);

      --  Whatever the host says about each path is what the column must show.
      Assert
        (Execute_Bit (Plain) = (if Hostkit.Fs.Is_Executable (Plain) then 'x' else '-'),
         "a plain file's execute bit matches the host");
      Assert
        (Execute_Bit (Sub_Dir) = (if Hostkit.Fs.Is_Executable (Sub_Dir) then 'x' else '-'),
         "a directory's execute bit matches the host");

      if Files.File_System.Set_Permissions (Runnable, 8#755#).Success then
         Assert
           (Execute_Bit (Runnable) = (if Hostkit.Fs.Is_Executable (Runnable) then 'x' else '-'),
            "a file the host will run matches the host");

         --  Set_Permissions succeeding is not the same as this host deciding
         --  executability by mode: on Windows it writes an ACL and succeeds,
         --  while what may be run is decided by the extension, so a chmod +x
         --  .sh file is correctly not executable there. Mode_Bits_Are_Native is
         --  the question that was meant, and asking the other one asserted POSIX
         --  of a host that never claimed it.
         if Hostkit.Metadata.Mode_Bits_Are_Native then
            Assert
              (Execute_Bit (Runnable) = 'x',
               "and where mode decides it, chmod +x really does show as executable");
         end if;
      end if;

      --  The read and write positions, across the mode matrix, against the same
      --  host calls the column is built from. This is what says whether those
      --  two answers may be taken from mode bits already read for the item
      --  instead of asked for separately: if the two ever disagreed, the column
      --  would go quietly wrong rather than fail.
      declare
         Probe : constant String := Join (Root, "rw-probe.txt");

         procedure Check_At (Mode : Natural) is
            Applied : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Probe, Mode);
         begin
            if not Applied.Success then
               return;
            end if;

            declare
               Loaded : constant Files.File_System.Item_Load_Result :=
                 Files.File_System.Load_Item (Probe, Settings);
               Text   : constant String := To_String (Loaded.Item.Permissions);
               Label  : constant String := Natural'Image (Mode);
            begin
               Assert (Loaded.Success and then Text'Length = 3, "the probe loads at mode" & Label);
               Assert
                 (Text (Text'First) = (if GNAT.OS_Lib.Is_Owner_Readable_File (Probe) then 'r' else '-'),
                  "the read position matches the host at mode" & Label);
               Assert
                 (Text (Text'First + 1) = (if GNAT.OS_Lib.Is_Owner_Writable_File (Probe) then 'w' else '-'),
                  "the write position matches the host at mode" & Label);
            end;
         end Check_At;
      begin
         Write_File (Probe, "probe");
         Check_At (8#644#);
         Check_At (8#600#);
         Check_At (8#400#);
         Check_At (8#200#);
         Check_At (8#444#);
         Check_At (8#000#);

         --  Leave it removable for Reset_Root.
         declare
            Restored : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Probe, 8#644#);
            pragma Unreferenced (Restored);
         begin
            null;
         end;
      end;
   end Test_Permission_String_Agrees_With_The_Host;

   --  Decode a real colour emoji picture out of a real font.
   --
   --  Textrender reads where the picture is and hands out the bytes; this is the
   --  other side of that seam, and until it worked the colour glyph path had only
   --  ever been driven by a stub returning a known pattern. The bytes here are
   --  whatever Noto Color Emoji actually contains.
   --
   --  Skipped when the font is not installed, so a missing font is not a failure.
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Emoji_Path : constant String :=
        "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf";
      F : Textrender.Fonts.Font;
      use type Textrender.Fonts.Load_Result;
      use type Textrender.Fonts.Colour_Image_Format;
   begin
      if not Ada.Directories.Exists (Emoji_Path) then
         return;
      end if;

      Assert (Textrender.Fonts.Load (F, Emoji_Path) = Textrender.Fonts.Loaded,
              "the emoji font loads");

      declare
         Index : Natural := 0;
         Grinning : constant Textrender.Fonts.Codepoint := 16#1F600#;
      begin
         Assert (Textrender.Fonts.Glyph_Index_Of (F, Grinning, Index),
                 "the font maps the grinning face");

         declare
            Bitmap : constant Textrender.Fonts.Colour_Bitmap :=
              Textrender.Fonts.Colour_Bitmap_For (F, Index, 16);
         begin
            Assert (Bitmap.Format = Textrender.Fonts.Png_Colour_Image,
                    "and has a PNG for it");

            declare
               Data : Ada.Streams.Stream_Element_Array
                 (1 .. Ada.Streams.Stream_Element_Offset (Bitmap.Data_Length));
               Width, Height : Natural := 0;
            begin
               for Offset in 0 .. Bitmap.Data_Length - 1 loop
                  Data (Ada.Streams.Stream_Element_Offset (Offset + 1)) :=
                    Ada.Streams.Stream_Element
                      (Textrender.Fonts.Byte_At (F, Bitmap.Data_Offset + Offset));
               end loop;

               --  The extent must be readable without decoding, and must agree
               --  with what the font's own metrics claimed.
               Assert (Files.File_System.Image_Bytes_Extent (Data, Width, Height),
                       "the PNG header is readable");
               Assert (Width = Bitmap.Width and then Height = Bitmap.Height,
                       "and agrees with the font's metrics:"
                       & Natural'Image (Width) & " x" & Natural'Image (Height)
                       & " against" & Natural'Image (Bitmap.Width)
                       & " x" & Natural'Image (Bitmap.Height));

               declare
                  Decoded : constant Files.File_System.Decoded_Image :=
                    Files.File_System.Decode_Image_Bytes (Data);
                  Opaque_Pixels : Natural := 0;
                  Coloured      : Natural := 0;
               begin
                  Assert (Decoded.Available, "the picture decodes");
                  Assert (Decoded.Width = Width and then Decoded.Height = Height,
                          "at the size its header declared");
                  Assert
                    (Natural (Decoded.Pixels.Length) = Width * Height * 4,
                     "with four bytes per pixel");

                  --  A grinning face is mostly opaque and mostly not grey. Both
                  --  matter: an all-transparent result would satisfy a length
                  --  check, and so would a greyscale one.
                  for Pixel in 0 .. Width * Height - 1 loop
                     declare
                        --  Byte_Vectors is indexed from 1, not 0.
                        R : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 1));
                        G : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 2));
                        B : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 3));
                        A : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 4));
                     begin
                        if A > 200 then
                           Opaque_Pixels := Opaque_Pixels + 1;

                           if abs (R - G) > 40 or else abs (G - B) > 40 then
                              Coloured := Coloured + 1;
                           end if;
                        end if;
                     end;
                  end loop;

                  Assert (Opaque_Pixels > (Width * Height) / 10,
                          "and is substantially opaque, got"
                          & Natural'Image (Opaque_Pixels) & " of"
                          & Natural'Image (Width * Height));
                  Assert (Coloured > 0,
                          "and actually carries colour rather than grey");
               end;
            end;
         end;
      end;

      Textrender.Fonts.Reset (F);
   end Test_Decode_Emoji_Png_From_Font;

   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cache : constant String := Join (Root, "prune-cache");

      --  Distinct sizes so the totals are unambiguous, and written oldest first
      --  with a delay between them so the modification times genuinely order.
      Old_One : constant String := Join (Cache, "thumb_a.ppm");
      Old_Two : constant String := Join (Cache, "thumb_b.ppm");
      Newest  : constant String := Join (Cache, "thumb_c.ppm");

      function Filler (Count : Natural) return String is
         Text : constant String (1 .. Count) := [others => 'x'];
      begin
         return Text;
      end Filler;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Cache);

      Write_File (Old_One, Filler (4_000));
      delay 1.1;
      Write_File (Old_Two, Filler (4_000));
      delay 1.1;
      Write_File (Newest, Filler (4_000));

      --  Comfortably above the total: nothing is touched.
      Files.File_System.Prune_Thumbnail_Cache (Cache, 1_000_000);
      Assert
        (Path_Exists (Old_One) and then Path_Exists (Old_Two) and then Path_Exists (Newest),
         "a cache inside its budget is left alone");

      --  Room for roughly one file: the two oldest go, the newest stays.
      Files.File_System.Prune_Thumbnail_Cache (Cache, 5_000);
      Assert (Path_Exists (Newest), "the most recently written thumbnail survives");
      Assert
        (not Path_Exists (Old_One) and then not Path_Exists (Old_Two),
         "and the older ones are the ones evicted");

      --  Housekeeping must never be a precondition for anything.
      Files.File_System.Prune_Thumbnail_Cache (Join (Root, "no-such-cache"), 1);
      Assert (True, "pruning a cache directory that does not exist is harmless");

      --  Directory_Exists follows symlinks.  Pruning must not consequently
      --  treat an arbitrary link target as cache contents and delete from it.
      declare
         Real_Directory : constant String := Join (Root, "real-prune-target");
         Linked_Cache   : constant String := Join (Root, "linked-prune-cache");
         Kept_File      : constant String := Join (Real_Directory, "keep.txt");
      begin
         Ada.Directories.Create_Path (Real_Directory);
         Write_File (Kept_File, Filler (4_000));

         if Files_Suite.Support.Create_Symlink (Real_Directory, Linked_Cache) then
            Files.File_System.Prune_Thumbnail_Cache (Linked_Cache, 0);
            Assert (Hostkit.Fs.Is_Link (Linked_Cache),
                    "cache pruning leaves a linked cache root in place");
            Assert (File_Has_Bytes (Kept_File, Filler (4_000)),
                    "cache pruning never deletes from a linked directory target");
         end if;
      end;
   end Test_Thumbnail_Cache_Is_Bounded;

   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Host.Kind;

      Browsed    : constant String := Join (Root, "pictures");
      Cache_Home : constant String := Join (Root, "cache-home");

      --  The variable this host keeps its per-user cache root in, and what the
      --  resolver should make of it once XDG_CACHE_HOME is out of the way.
      Host_Variable : constant String :=
        (if Hostkit.Host.Current = Hostkit.Host.Windows then "LOCALAPPDATA" else "HOME");
      Host_Cache_Root : constant String :=
        (case Hostkit.Host.Current is
            when Hostkit.Host.Windows => Cache_Home,
            when Hostkit.Host.MacOS   => Join (Cache_Home, "Library/Caches"),
            when others               => Join (Cache_Home, ".cache"));

      Had_Xdg   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Had_Host  : constant Boolean := Ada.Environment_Variables.Exists (Host_Variable);
      Old_Xdg   : Unbounded_String;
      Old_Host  : Unbounded_String;

      procedure Restore is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Xdg));
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;

         if Had_Host then
            Ada.Environment_Variables.Set (Host_Variable, To_String (Old_Host));
         else
            Ada.Environment_Variables.Clear (Host_Variable);
         end if;
      end Restore;

      function Cache_Directory return String is
        (Files.File_System.Default_Thumbnail_Cache_Directory (Browsed));
   begin
      if Had_Xdg then
         Old_Xdg := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      if Had_Host then
         Old_Host := To_Unbounded_String (Ada.Environment_Variables.Value (Host_Variable));
      end if;

      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Assert
        (Cache_Directory = Join (Join (Cache_Home, "files"), "thumbnails"),
         "an explicit XDG_CACHE_HOME is honoured on every host, got " & Cache_Directory);

      Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
      Ada.Environment_Variables.Set (Host_Variable, Cache_Home);
      Assert
        (Cache_Directory = Join (Join (Host_Cache_Root, "files"), "thumbnails"),
         "without XDG_CACHE_HOME the cache follows this host's convention, got " & Cache_Directory);

      Assert
        (Cache_Directory'Length < Browsed'Length
           or else Cache_Directory (Cache_Directory'First .. Cache_Directory'First + Browsed'Length - 1)
                     /= Browsed,
         "the thumbnail cache is never written into the folder being browsed, got " & Cache_Directory);

      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Thumbnail_Cache_Is_Per_User;

   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Nul_Name : constant String := "bad" & Character'Val (0) & "name.txt";
      Tab_Name : constant String := "bad" & Character'Val (9) & "name.txt";
      C1_Name  : constant String := "bad" & Character'Val (133) & "name.txt";
      Encoded_C1_Name : constant String := "bad" & Byte (16#C2#) & Byte (16#85#) & "name.txt";
      Truncated_UTF8_Name : constant String := "bad" & Byte (16#E2#) & Byte (16#82#) & "name.txt";
      Overlong_UTF8_Name  : constant String := "bad" & Byte (16#C0#) & Byte (16#AF#) & "name.txt";
      NBSP_Name : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      Ideographic_Space_Name : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#3000#));
      Trailing_NBSP_Name : constant String := "trailing-nbsp" & NBSP_Name;
      Trailing_Ideographic_Name : constant String := "trailing-wide" & Ideographic_Space_Name;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Begin_Create_File (Model, "");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects empty names");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "empty create records invalid name");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, ".");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects dot names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "..");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects parent-directory names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create invalid name records error");
      Assert (not Path_Exists (Join (Root, "bad")), "invalid create does not create directories");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid create keeps temporary item active");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid create keeps rename active");

      --  Backslash, colon, wildcard, and trailing-dot names are rejected only
      --  under Windows rules; on a POSIX host they are ordinary filenames, so
      --  the host-gated behaviour is covered directly in Test_Leaf_Name_Rules
      --  rather than through the create operation here.
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "trailing-space.txt ");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "trailing-space.txt ")),
         "invalid trailing-space create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects NBSP-only names");
      Assert (not Ada.Directories.Exists (Join (Root, NBSP_Name)), "invalid NBSP-only create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing NBSP names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects trailing ideographic-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_Ideographic_Name)),
         "invalid trailing ideographic-space create writes no file");

      --  Reserved device names (CON, LPT1, CONIN$ and space-padded variants) are
      --  rejected only under Windows rules; Test_Leaf_Name_Rules covers that.
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Nul_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create NUL name records error");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Tab_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects UTF-8 encoded C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects truncated UTF-8 names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects overlong UTF-8 names");

      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects empty names");

      Files.Model.Set_Rename_Text (Model, ".");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects dot names");

      Files.Model.Set_Rename_Text (Model, "..");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects parent-directory names");

      Files.Model.Set_Rename_Text (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename invalid name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "invalid rename leaves source in place");
      Assert (not Path_Exists (Join (Root, "bad")), "invalid rename does not create directories");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid rename keeps rename active");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "invalid rename keeps selected item");

      --  Backslash, colon, wildcard, and trailing-dot names are Windows-only
      --  rejections -- ordinary filenames on a POSIX host -- so the POSIX/Windows
      --  split is covered directly in Test_Leaf_Name_Rules, not through rename.
      Files.Model.Set_Rename_Text (Model, "renamed ");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing-space names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing-space rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "renamed ")), "invalid trailing-space rename writes no file");

      Files.Model.Set_Rename_Text (Model, Ideographic_Space_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects ideographic-space-only names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "ideographic-space-only rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing NBSP names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing NBSP rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP rename writes no file");

      Files.Model.Set_Rename_Text (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing ideographic-space names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "trailing ideographic-space rename leaves source in place");

      --  Reserved device names (NUL, COM9, CONOUT$ and space-padded variants) are
      --  a Windows-only rejection; the POSIX/Windows split lives in
      --  Test_Leaf_Name_Rules.
      Files.Model.Set_Rename_Text (Model, Nul_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename NUL name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "NUL rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Tab_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "C1 control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects UTF-8 encoded C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "encoded C1 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects truncated UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "truncated UTF-8 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects overlong UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "overlong UTF-8 rename leaves source in place");
   end Test_Invalid_File_Operation_Names;

   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function E (S : String) return String renames Files.File_System.Expand_User_Path;
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then
            Ada.Environment_Variables.Value ("HOME")
         else "");
   begin
      if Home /= "" then
         Assert (E ("~") = Home, "a bare tilde expands to the home directory");
         Assert (E ("~/Downloads") = Home & "/Downloads", "a leading ~/ expands to home");
      end if;
      Assert (E ("/absolute/dir") = "/absolute/dir", "an absolute path is left unchanged");
      Assert (E ("relative/dir") = "relative/dir", "a relative path without a tilde is unchanged");
      Assert (E ("/data/~") = "/data/~", "a tilde that is not the first component is left alone");
      Assert (E ("~user/x") = "~user/x", "a ~user other-home reference is not expanded");
      Assert (E ("") = "", "empty stays empty");
   end Test_Expand_User_Path;

   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Posix (Name : String) return Boolean is
        (Files.File_System.Valid_Leaf_Name (Name, Files.File_System.Posix_Rules));

      function Win (Name : String) return Boolean is
        (Files.File_System.Valid_Leaf_Name (Name, Files.File_System.Windows_Rules));

      Tab : constant String := "bad" & Character'Val (9) & "name";
   begin
      --  Visible characters, reserved device names and a trailing dot are
      --  ordinary on a POSIX filesystem but forbidden on Windows: accepted under
      --  Posix_Rules, rejected under Windows_Rules. Checked directly so both rule
      --  sets are exercised whichever host runs the suite (Host_Rules resolves to
      --  one or the other and cannot exercise the absent one).
      Assert (Posix ("bad\name.txt"), "POSIX allows a backslash in a name");
      Assert (not Win ("bad\name.txt"), "Windows rejects a backslash in a name");
      Assert (Posix ("my:notes.txt"), "POSIX allows a colon in a name");
      Assert (not Win ("my:notes.txt"), "Windows rejects a colon in a name");
      Assert (Posix ("track01?.flac"), "POSIX allows a wildcard character in a name");
      Assert (not Win ("track01?.flac"), "Windows rejects a wildcard character in a name");
      Assert (Posix ("ch*.txt"), "POSIX allows an asterisk in a name");
      Assert (not Win ("ch*.txt"), "Windows rejects an asterisk in a name");
      Assert (Posix ("a|b.txt") and then Posix ("a<b>.txt"), "POSIX allows pipe and angle brackets");
      Assert (not Win ("a|b.txt") and then not Win ("a<b>.txt"), "Windows rejects pipe and angle brackets");
      Assert (Posix ("aux") and then Posix ("CON.txt") and then Posix ("CONIN$"),
              "POSIX allows reserved-device-style names");
      Assert (not Win ("aux") and then not Win ("CON.txt") and then not Win ("CONIN$"),
              "Windows rejects reserved device names");
      Assert (Posix ("ends-with-dot."), "POSIX allows a trailing dot");
      Assert (not Win ("ends-with-dot."), "Windows rejects a trailing dot");

      --  A plain filename is valid under every rule set; the confusing or broken
      --  names are rejected under every rule set, host included.
      for Rules in Files.File_System.Name_Rules loop
         Assert
           (Files.File_System.Valid_Leaf_Name ("ordinary-name.txt", Rules),
            "every rule set accepts an ordinary filename");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("", Rules),
            "no rule set accepts an empty name");
         Assert
           (not Files.File_System.Valid_Leaf_Name (".", Rules)
              and then not Files.File_System.Valid_Leaf_Name ("..", Rules),
            "no rule set accepts the special directory entries");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("a/b.txt", Rules),
            "no rule set accepts a path separator");
         Assert
           (not Files.File_System.Valid_Leaf_Name (Tab, Rules),
            "no rule set accepts a control character");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("trailing ", Rules)
              and then not Files.File_System.Valid_Leaf_Name ("   ", Rules),
            "no rule set accepts trailing or all whitespace");
      end loop;

      --  Resolved against a real destination, Valid_Leaf_Name_At follows that
      --  destination's filesystem: a colon name is accepted exactly when the
      --  filesystem holding the directory is not DOS-ruled. This ties the wiring
      --  to Hostkit's detection and holds on any host (POSIX test root -> valid,
      --  a Windows NTFS root -> not), while the universal rejections stand
      --  regardless of the destination.
      Reset_Root;
      declare
         Dos_Root : constant Boolean := Hostkit.Fs.Uses_Dos_Filename_Rules (Root);
      begin
         Assert
           (Files.File_System.Valid_Leaf_Name_At ("my:notes.txt", Root) = not Dos_Root,
            "a colon name is valid at a destination iff its filesystem is not DOS-ruled");
         Assert
           (Files.File_System.Valid_Leaf_Name_At ("ordinary.txt", Root),
            "an ordinary name is valid at any destination");
         Assert
           (not Files.File_System.Valid_Leaf_Name_At ("a/b.txt", Root),
            "a path separator is rejected at any destination");
      end;
   end Test_Leaf_Name_Rules;

   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Taken    : constant String := Join (Root, "taken.txt");
      Direct_Source : constant String := Join (Root, "direct-source.txt");
      Direct_Target : constant String := Join (Root, "direct-target.txt");
      Missing_Parent_Source : constant String := Join (Root, "missing-parent-source.txt");
      Non_Directory_Source  : constant String := Join (Root, "non-directory-source.txt");
      Utf8_Target : constant String :=
        "renamed-" & Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & ".txt";
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Write_File (Taken, "destination");
      Write_File (Direct_Source, "direct");
      Write_File (Missing_Parent_Source, "missing parent");
      Write_File (Non_Directory_Source, "non-directory parent");
      Ada.Directories.Create_Path (Join (Root, "taken-dir"));
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Join (Root, "taken-dir"));
      Assert (not Mutation.Success, "rename refuses an existing directory destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing directory rename reports invalid destination");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Taken);
      Assert (not Mutation.Success, "direct rename refuses an existing file destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing file direct rename reports invalid destination");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "direct rename preserves existing destination file");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "direct failed rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Join (Root, "missing-source.txt"), Join (Root, "new-missing.txt"));
      Assert (not Mutation.Success, "rename reports missing source failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "missing source rename reports source-missing diagnostic");
      Assert (not Ada.Directories.Exists (Join (Root, "new-missing.txt")), "missing source rename writes no target");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), "");
      Assert (not Mutation.Success, "rename reports empty destination failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "empty destination rename reports invalid destination");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "empty destination rename leaves source in place");
      Mutation :=
        Files.File_System.Rename_Item
          (Root & "/bad" & Character'Val (0) & "same.txt",
           Root & "/bad" & Character'Val (0) & "same.txt");
      Assert (not Mutation.Success, "malformed same-path rename reports failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "malformed same-path rename reports source-missing diagnostic");
      Mutation :=
        Files.File_System.Rename_Item
          (Missing_Parent_Source,
           Join (Join (Root, "missing-parent"), "target.txt"));
      Assert (not Mutation.Success, "rename refuses a missing destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "missing destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Missing_Parent_Source), "missing parent rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Non_Directory_Source, Join (Taken, "target.txt"));
      Assert (not Mutation.Success, "rename refuses a non-directory destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "non-directory destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Non_Directory_Source), "non-directory parent rename leaves source in place");
      Mutation :=
        Files.File_System.Rename_Item (Direct_Source, Join (Root, "bad" & Character'Val (9) & "name.txt"));
      Assert (not Mutation.Success, "direct rename rejects invalid leaf names");
      Assert
        (To_String (Mutation.Error_Key) = "error.name.invalid",
         "direct invalid-name rename reports invalid-name diagnostic");
      Assert (Ada.Directories.Exists (Direct_Source), "direct invalid-name rename leaves source in place");
      Assert
        (not Path_Exists (Join (Root, "bad" & Character'Val (9) & "name.txt")),
         "direct invalid-name rename writes no target");
      Mutation := Files.File_System.Rename_Item (Direct_Source, Direct_Target);
      Assert (Mutation.Success, "direct rename mutation succeeds");
      Assert (To_String (Mutation.Error_Key) = "", "successful direct rename has no error key");
      Assert (not Ada.Directories.Exists (Direct_Source), "direct rename removes source path");
      Assert (Ada.Directories.Exists (Direct_Target), "direct rename creates destination path");
      Mutation := Files.File_System.Rename_Item (Direct_Target, Direct_Target);
      Assert (Mutation.Success, "direct same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct same-path rename keeps source path");
      Mutation :=
        Files.File_System.Rename_Item
          (Direct_Target,
           Files.File_System.Join_Path (Files.File_System.Join_Path (Root, "."), "direct-target.txt"));
      Assert (Mutation.Success, "direct normalized same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct normalized same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct normalized same-path rename keeps source path");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Error (Model, "error.rename.failed");
      Files.Model.Set_Rename_Text (Model, "old.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "same-name rename succeeds without mutation");
      Assert (To_String (Result.Path) = Join (Root, "old.txt"), "same-name rename reports existing path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "same-name rename clears stale error state");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "same-name rename leaves source in place");
      Assert (not Files.Model.Rename_Is_Active (Model), "same-name rename clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "same-name rename keeps selected source");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "taken.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename refuses an existing destination");
      Assert
        (To_String (Result.Error_Key) = "error.rename.invalid_destination",
         "existing destination rename reports invalid destination key");
      Assert (To_String (Result.Path) = Taken, "failed rename reports attempted destination path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.invalid_destination", "failed rename records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "failed rename leaves source in place");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "failed rename preserves destination");
      Assert (Files.Model.Rename_Is_Active (Model), "failed rename keeps rename mode active");
      Assert (Files.Model.Rename_Text (Model) = "taken.txt", "failed rename keeps attempted name");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "failed rename keeps selected source");

      Ada.Directories.Delete_File (Join (Root, "old.txt"));
      Files.Model.Set_Rename_Text (Model, "missing-result.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "disappeared source reports source-missing error key");
      Assert
        (To_String (Result.Path) = Join (Root, "missing-result.txt"),
         "source-missing rename reports attempted destination path");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "disappeared source records source-missing error");
      Assert (not Files.Model.Rename_Is_Active (Model), "source-missing rename clears stale rename mode");
      Assert (Files.Model.Rename_Text (Model) = "", "source-missing rename clears stale attempted name");
      Assert (Files.Model.Selected_Count (Model) = 0, "source-missing rename clears stale selection");
      Assert (Files.Model.Selected_Name (Model) = "", "source-missing rename removes stale selected item");

      Reset_Root;
      Write_File (Join (Root, "same-missing.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "same-missing.txt");
      Files.Model.Toggle_Rename (Model);
      Ada.Directories.Delete_File (Join (Root, "same-missing.txt"));
      Files.Model.Set_Rename_Text (Model, "same-missing.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed,
         "same-name rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "same-name disappeared source reports source-missing error key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "same-name disappeared source records source-missing error");
      Assert
        (not Files.Model.Rename_Is_Active (Model),
         "same-name disappeared source clears stale rename mode");

      Write_File (Join (Root, "missing-parent-source.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "missing-parent-source.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "new.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename succeeds after source is restored");
      Assert (Files.Model.Last_Error_Key (Model) = "", "restored-source rename clears stale error");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "restored-source rename creates new path");
      Assert (To_String (Result.Path) = Join (Root, "new.txt"), "rename commit returns renamed path");
      Assert (not Ada.Directories.Exists (Join (Root, "missing-parent-source.txt")), "rename removes old path");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename commit clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "new.txt", "renamed item is selected after reload");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, Utf8_Target);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename accepts UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Target)), "UTF-8 rename creates new path");
      Assert (not Ada.Directories.Exists (Join (Root, "new.txt")), "UTF-8 rename removes old path");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Target, "UTF-8 renamed item is selected after reload");
   end Test_Commit_Rename;

   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Changed  : Boolean;
   begin
      --  Two files renamed together: appending "Z" before each extension gives
      --  each field a distinct new name via a single broadcast.
      Reset_Root;
      Write_File (Join (Root, "aaa.txt"));
      Write_File (Join (Root, "bbb.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "multi-rename opens a field per selected file");
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "Z");
      Assert (Changed, "broadcast insert edits both rename fields");

      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "committing both renames reports success");
      Assert (Ada.Directories.Exists (Join (Root, "aaaZ.txt")), "the first item is renamed on disk");
      Assert (Ada.Directories.Exists (Join (Root, "bbbZ.txt")), "the second item is renamed on disk");
      Assert (not Ada.Directories.Exists (Join (Root, "aaa.txt")), "the first old name is gone");
      Assert (not Ada.Directories.Exists (Join (Root, "bbb.txt")), "the second old name is gone");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = 2,
         "committing two renames records a two-entry undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "one undo reverses the whole multi-rename");
      Assert (Ada.Directories.Exists (Join (Root, "aaa.txt")), "undo restores the first original name");
      Assert (Ada.Directories.Exists (Join (Root, "bbb.txt")), "undo restores the second original name");
      Assert (not Ada.Directories.Exists (Join (Root, "aaaZ.txt")), "undo removes the first renamed file");
      Assert (not Ada.Directories.Exists (Join (Root, "bbbZ.txt")), "undo removes the second renamed file");

      --  Best-effort: one target collides with an existing file, the other
      --  succeeds. The collision is reported but does not block the good rename.
      Reset_Root;
      Write_File (Join (Root, "one.txt"));
      Write_File (Join (Root, "two.txt"));
      Write_File (Join (Root, "oneZ.txt"), "occupied");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      --  Select only one.txt and two.txt (leave the colliding oneZ.txt out).
      Select_Name (Model, "one.txt");
      declare
         One_Visible : constant Natural := Files.Model.Selected_Index (Model);
      begin
         Files.Model.Select_Visible (Model, One_Visible);
      end;
      --  two.txt sorts after one.txt and oneZ.txt; add it to the selection.
      for Index in 1 .. Files.Model.Visible_Count (Model) loop
         if To_String (Files.Model.Visible_Item (Model, Index).Name) = "two.txt" then
            Files.Model.Toggle_Visible_Selection (Model, Index);
         end if;
      end loop;
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "best-effort rename opens two fields");
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "Z");
      Assert (Changed, "broadcast insert edits both best-effort fields");

      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "a partial multi-rename still reports overall success");
      Assert
        (To_String (Result.Error_Key) = "error.rename.partial",
         "a partial multi-rename reports the partial error key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.partial",
         "a partial multi-rename records the partial error key");
      Assert (Ada.Directories.Exists (Join (Root, "twoZ.txt")), "the non-colliding rename lands");
      Assert (not Ada.Directories.Exists (Join (Root, "two.txt")), "the renamed source is gone");
      Assert (Ada.Directories.Exists (Join (Root, "one.txt")), "the colliding source is left in place");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Join (Root, "oneZ.txt")), "occupied") > 0,
         "the collision preserves the pre-existing destination file");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = 1,
         "a partial multi-rename records undo only for the successful rename");
   end Test_Commit_Multi_Rename;

   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      function Detail_Value
        (Prefix_Key : String;
         Value      : String;
         Suffix_Key : String)
         return String
      is
         Prefix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
         Suffix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
      begin
         if Suffix'Length > 0
           and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
         then
            return Prefix & " " & Value & " " & Suffix;
         else
            return Prefix & " " & Value & Suffix;
         end if;
      end Detail_Value;

      function Detail_Localized_Value
        (Prefix_Key : String;
         Value_Key  : String;
         Suffix_Key : String)
         return String
      is
      begin
         return Detail_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
      end Detail_Localized_Value;

      function Detail_Lines_Encoding
        (Lines_Prefix_Key : String;
         Lines            : String;
         Lines_Suffix_Key : String;
         Encoding_Key     : String)
         return String
      is
      begin
         return
           Detail_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
           & " "
           & Detail_Localized_Value
             ("info.extra.encoding.prefix", Encoding_Key, "info.extra.encoding.suffix");
      end Detail_Lines_Encoding;

      procedure Assert_Localized_Extra
        (Name     : String;
         Filetype : String;
         Token    : String;
         Expected : String;
         Message  : String;
         Kind     : Files.Types.Item_Kind := Files.Types.Regular_File_Item)
      is
         Items : Files.File_System.Item_Vectors.Vector;
         Item  : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => Name,
              Kind        => Kind,
              Filetype    => Filetype);
      begin
         Item.Filetype_Extra := To_Unbounded_String (Token);
         Items.Append (Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) = Expected,
            Message);
      end Assert_Localized_Extra;
   begin
      Reset_Root;
      Write_File (Join (Root, "meta.txt"), "abcd");
      Write_File (Join (Root, "zmarkdown.md"), "# Title" & ASCII.LF & "body");
      Write_Binary_File (Join (Root, "zsheet.xlsx"), "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Join (Root, "zutf8.txt"), "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Join (Root, "zbinary.txt"), "bad" & Character'Val (16#C3#));
      Write_File
        (Join (Root, "zunit.adb"),
         "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Join (Root, "zdata.json"), "{""ok"":true}");
      Write_File (Join (Root, "zdoc.xml"), "<root/>");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      --  Extra info is computed lazily for the selected item when the info pane
      --  is open (the interaction reducer does this after each input).
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 1, "snapshot contains selected item info");
      Assert (Snapshot.Selected_Info.Element (1).Name = To_Unbounded_String ("meta.txt"), "info name is captured");
      Assert (Snapshot.Items.Element (1).Size_Available, "item snapshot captures size availability");
      Assert
        (Snapshot.Items.Element (1).Size = Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "item snapshot captures size value");
      Assert (Snapshot.Items.Element (1).Modified_Available, "item snapshot captures modified availability");
      Assert
        (Snapshot.Items.Element (1).Modified_Time = Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "item snapshot captures modified time value");
      Assert
        (To_String (Snapshot.Items.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "item snapshot captures filesystem-backed filetype extra metadata");
      Assert (not Snapshot.Items.Element (1).Metadata_Error, "item snapshot captures metadata error state");
      Assert (Snapshot.Selected_Info.Element (1).Size_Available, "info size availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Size =
           Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "info size value is captured");
      Assert (Snapshot.Selected_Info.Element (1).Modified_Available, "info modified availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Modified_Time =
           Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "info modified time value is captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Permissions)'Length = 3,
         "info permissions are captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "info pane captures filetype-specific detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "info pane captures loaded text line metadata");
      --  Visit each item so its lazy extra info is computed and cached (as
      --  happens when the selection lands on it with the info pane open), then
      --  rebuild the snapshot so it carries every item's localized extra.
      for Idx in 1 .. Files.Model.Visible_Count (Model) loop
         Files.Model.Select_Visible (Model, Idx);
         Files.Model.Ensure_Selected_Item_Extra (Model);
      end loop;
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      declare
         Found_Utf8_Metadata   : Boolean := False;
         Found_Binary_Metadata : Boolean := False;
         Found_Markdown_Metadata : Boolean := False;
         Found_Xlsx_Metadata   : Boolean := False;
         Found_Ada_Metadata    : Boolean := False;
         Found_Json_Metadata   : Boolean := False;
         Found_Xml_Metadata    : Boolean := False;
      begin
         for Item of Snapshot.Items loop
            if To_String (Item.Name) = "zutf8.txt" then
               Found_Utf8_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.utf8");
            elsif To_String (Item.Name) = "zbinary.txt" then
               Found_Binary_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.binary");
            elsif To_String (Item.Name) = "zmarkdown.md" then
               Found_Markdown_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.markdown.lines.prefix",
                      "2",
                      "info.extra.markdown.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zsheet.xlsx" then
               Found_Xlsx_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.document.spreadsheet")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Value ("info.extra.office.xlsx.prefix", "1", "info.extra.office.entries.suffix");
            elsif To_String (Item.Name) = "zunit.adb" then
               Found_Ada_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.ada")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.ada.prefix",
                      "4",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdata.json" then
               Found_Json_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.json")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.json.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdoc.xml" then
               Found_Xml_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.xml")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.xml.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            end if;
         end loop;

         Assert (Found_Utf8_Metadata, "item snapshot localizes UTF-8 text metadata");
         Assert (Found_Binary_Metadata, "item snapshot localizes binary text metadata");
         Assert (Found_Markdown_Metadata, "item snapshot localizes Markdown metadata");
         Assert (Found_Xlsx_Metadata, "item snapshot localizes XLSX metadata");
         Assert (Found_Ada_Metadata, "item snapshot localizes Ada source metadata");
         Assert (Found_Json_Metadata, "item snapshot localizes JSON source metadata");
         Assert (Found_Xml_Metadata, "item snapshot localizes XML source metadata");
      end;

      Assert_Localized_Extra
        (Name     => "folder",
         Filetype => "inode/directory",
         Token    => "directory.count|7",
         Expected => Detail_Value ("info.extra.directory.count.prefix", "7", "info.extra.directory.count.suffix"),
         Message  => "item snapshot localizes directory count metadata",
         Kind     => Files.Types.Directory_Item);
      Assert_Localized_Extra
        (Name     => "program",
         Filetype => "application/x-executable",
         Token    => "executable.format|elf",
         Expected =>
           Detail_Localized_Value
             ("info.extra.executable.format.prefix",
              "info.extra.executable.format.elf",
              "info.extra.executable.format.suffix"),
         Message  => "item snapshot localizes executable format metadata",
         Kind     => Files.Types.Executable_Item);
      Assert_Localized_Extra
        (Name     => "picture.png",
         Filetype => "image/png",
         Token    => "image.dimensions|32x16",
         Expected =>
           Detail_Value ("info.extra.image.dimensions.prefix", "32x16", "info.extra.image.dimensions.suffix"),
         Message  => "item snapshot localizes image dimension metadata");
      Assert_Localized_Extra
        (Name     => "link",
         Filetype => "inode/symlink",
         Token    => "symlink.target|target.txt",
         Expected =>
           Detail_Value ("info.extra.symlink.target.prefix", "target.txt", "info.extra.symlink.target.suffix"),
         Message  => "item snapshot localizes symlink target metadata",
         Kind     => Files.Types.Symlink_Item);
      Assert_Localized_Extra
        (Name     => "paper.pdf",
         Filetype => "application/pdf",
         Token    => "document.pdf.pages|3",
         Expected =>
           Detail_Value ("info.extra.document.pdf.pages.prefix", "3", "info.extra.document.pdf.pages.suffix"),
         Message  => "item snapshot localizes PDF page metadata");
      Assert_Localized_Extra
        (Name     => "archive.tar",
         Filetype => "application/x-tar",
         Token    => "archive.format|tar",
         Expected =>
           Detail_Localized_Value
             ("info.extra.archive.format.prefix",
              "info.extra.archive.format.tar",
              "info.extra.archive.format.suffix"),
         Message  => "item snapshot localizes archive format metadata");
      Assert_Localized_Extra
        (Name     => "bundle.zip",
         Filetype => "application/zip",
         Token    => "archive.zip.entries|5",
         Expected => Detail_Value ("info.extra.archive.entries.prefix", "5", "info.extra.archive.entries.suffix"),
         Message  => "item snapshot localizes archive entry metadata");
      Assert_Localized_Extra
        (Name     => "report.docx",
         Filetype => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         Token    => "office.docx.entries|9",
         Expected => Detail_Value ("info.extra.office.docx.prefix", "9", "info.extra.office.entries.suffix"),
         Message  => "item snapshot localizes document package metadata");
      Assert_Localized_Extra
        (Name     => "track.mp3",
         Filetype => "audio/mpeg",
         Token    => "media.kind|audio",
         Expected => Files.Localization.Text ("info.extra.media.audio"),
         Message  => "item snapshot localizes audio media metadata");
      Assert_Localized_Extra
        (Name     => "clip.mp4",
         Filetype => "video/mp4",
         Token    => "media.kind|video",
         Expected => Files.Localization.Text ("info.extra.media.video"),
         Message  => "item snapshot localizes video media metadata");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      --  Tall enough that every info-pane row (now including the owner/group
      --  fields) stays within the visible pane rather than being clipped.
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 1200, Line_Height => 20);
      declare
         Found_Name         : Boolean := False;
         Found_Top_Value    : Boolean := False;
         Found_Top_Bold     : Boolean := False;
         Found_Top_Label    : Boolean := False;
         Found_Postfixed_Value : Boolean := False;
         Found_Filetype     : Boolean := False;
         Found_Filetype_Value : Boolean := False;
         Found_Size         : Boolean := False;
         Found_Size_Value   : Boolean := False;
         Found_Created      : Boolean := False;
         Found_Modified     : Boolean := False;
         Found_Permissions  : Boolean := False;
         Found_Perm_Text    : Boolean := False;
         Header_R, Header_W, Header_E : Boolean := False;
         Row_User, Row_Other : Boolean := False;
         Found_Metadata_Key : Boolean := False;
         Found_Kind         : Boolean := False;
         Found_Extra        : Boolean := False;
         Found_Extra_First  : Boolean := False;
         Found_Extra_Second : Boolean := False;
         Extra_First_Y      : Natural := 0;
         Found_Relative_Time : Boolean := False;
         Found_A11y_Section : Boolean := False;
         Info_X             : constant Natural := Frame.Layout.Main_Width + 10;
         Info_Y             : constant Natural := Frame.Layout.Main_Y + 10;
      begin
         for Text of Frame.Text loop
            declare
               Raw    : constant String := To_String (Text.Text);
               Suffix : constant String := " (meta.txt)";
               Postfixed : constant Boolean :=
                 Raw'Length > Suffix'Length
                 and then Raw (Raw'Last - Suffix'Length + 1 .. Raw'Last) = Suffix;
               --  Match against the value with its item-name postfix removed so
               --  the field checks below are unaffected by the postfix.
               Value : constant String :=
                 (if Postfixed then Raw (Raw'First .. Raw'Last - Suffix'Length) else Raw);
            begin
               if Postfixed and then Text.X = Info_X then
                  Found_Postfixed_Value := True;
               end if;

               if Value = Files.Localization.Text ("info.name")
                 and then Text.X >= Info_X
               then
                  --  Must not happen: the info pane's Name field is replaced by
                  --  the postfix (a "Name" column header may exist in the grid).
                  Found_Name := True;
               elsif Value = Files.Localization.Text ("info.filetype")
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y
               then
                  Found_Top_Label := True;
                  Found_Filetype := True;
               elsif Value = Files.Localization.Text ("info.filetype")
                 and then Text.X = Info_X + 1
                 and then Text.Y = Info_Y
               then
                  Found_Top_Bold := True;
               elsif Value = Files.Localization.Text ("info.filetype") then
                  Found_Filetype := True;
               elsif Value = Files.Localization.Text ("info.kind.text")
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y + 20
               then
                  Found_Top_Value := True;
                  Found_Filetype_Value := True;
               elsif Value = Files.Localization.Text ("info.kind.text") then
                  Found_Filetype_Value := True;
               elsif Value = Files.Localization.Text ("info.size") then
                  Found_Size := True;
               elsif Ada.Strings.Fixed.Index
                 (Value, " " & Files.Localization.Text ("details.size.unit.bytes")) > 1
                 and then Value /= Files.Localization.Text ("info.size")
               then
                  Found_Size_Value := True;
               elsif Value = Files.Localization.Text ("info.created") then
                  Found_Created := True;
               elsif Value = Files.Localization.Text ("info.modified") then
                  Found_Modified := True;
               elsif Value = Files.Localization.Text ("info.permissions") then
                  Found_Permissions := True;
               elsif Text.X >= Info_X and then Value = "R" then
                  Header_R := True;
               elsif Text.X >= Info_X and then Value = "W" then
                  Header_W := True;
               elsif Text.X >= Info_X and then Value = "E" then
                  Header_E := True;
               elsif Value = Files.Localization.Text ("info.permissions.user") then
                  Row_User := True;
               elsif Value = Files.Localization.Text ("info.permissions.other") then
                  Row_Other := True;
               elsif Value = Files.Localization.Text ("info.permissions.readable")
                 or else Value = Files.Localization.Text ("info.permissions.writable")
               then
                  --  Must NOT happen: the stacked text summary was replaced by
                  --  the matrix for a single selection.
                  Found_Perm_Text := True;
               elsif Value = Files.Localization.Text ("info.metadata_error") then
                  Found_Metadata_Key := True;
               elsif Value = Files.Localization.Text ("info.kind") then
                  Found_Kind := True;
               elsif Value = Files.Localization.Text ("info.extra") then
                  Found_Extra := True;
               elsif Value =
                 Detail_Value ("info.extra.text.lines.prefix", "1", "info.extra.text.lines.suffix")
               then
                  Found_Extra_First := True;
                  Extra_First_Y := Text.Y;
               elsif Value =
                 Detail_Localized_Value
                   ("info.extra.encoding.prefix",
                    "info.extra.encoding.ascii",
                    "info.extra.encoding.suffix")
               then
                  Found_Extra_Second := Extra_First_Y > 0 and then Text.Y = Extra_First_Y + 20;
               elsif Value = Files.Localization.Text ("time.relative.now")
                 or else Ada.Strings.Fixed.Index
                   (Value, Files.Localization.Text ("time.relative.today") & " ") = 1
               then
                  Found_Relative_Time := True;
               end if;
            end;
         end loop;

         for Node of Frame.Accessibility loop
            if Node.Role = Guikit.Draw.Role_List_Item
              and then To_String (Node.Name) = "meta.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.filetype") & ": " &
                 Files.Localization.Text ("info.kind.text")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.size") & ":") > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.modified") & ":") > 0
            then
               Found_A11y_Section := True;
            end if;
         end loop;

         Assert (not Found_Name, "info pane has no dedicated Name row (name is postfixed onto each value)");
         Assert (Found_Top_Label, "info pane top row is the filetype label");
         Assert (Found_Top_Bold, "info pane label renders with bold offset");
         Assert (Found_Top_Value, "info pane value follows label on next row");
         Assert (Found_Postfixed_Value, "info pane single-item values are postfixed with the item name");
         Assert (Found_Filetype, "info pane frame includes localized filetype row");
         Assert (Found_Filetype_Value, "info pane filetype value is separate from label");
         Assert (Found_Size, "info pane frame includes localized size row");
         Assert (Found_Size_Value, "info pane frame includes size unit");
         Assert (Found_Created, "info pane frame includes localized missing creation row");
         Assert (Found_Modified, "info pane frame includes localized modified row");
         Assert (Found_Permissions, "info pane frame includes localized permissions label");
         Assert (Header_R and then Header_W and then Header_E,
                 "info pane permission matrix has an R/W/E column header");
         Assert (Row_User and then Row_Other,
                 "info pane permission matrix labels its user/group/other rows");
         Assert (not Found_Perm_Text,
                 "single-item permissions show the matrix, not a stacked text summary");
         Assert (Natural (Frame.Permission_Hits.Length) > 0,
                 "the editable single item registers clickable permission cells");
         Assert (not Found_Metadata_Key,
                 "a healthy item shows no Metadata Error row");
         Assert (not Found_Kind, "info pane no longer shows the redundant Kind row");
         Assert (Found_Extra, "info pane frame includes filetype-specific extra metadata row");
         Assert (Found_Extra_First, "info pane details renders first metadata item");
         Assert (Found_Extra_Second, "info pane details renders second metadata item on separate row");
         Assert (Found_Relative_Time, "info pane humanizes recent metadata timestamps");
         Assert (Found_A11y_Section, "info pane frame exposes accessible selected-file section");
      end;

      declare
         Items          : Files.File_System.Item_Vectors.Vector;
         Broken_Item    : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "broken.txt",
              Kind        => Files.Types.Regular_File_Item,
              Filetype    => "text/plain");
         Found_Localized : Boolean := False;
         Found_A11y_Metadata : Boolean := False;
      begin
         Broken_Item.Metadata_Error := True;
         Broken_Item.Error_Key := To_Unbounded_String ("error.metadata.read");
         Items.Append (Broken_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 800, Line_Height => 20);

         for Text of Frame.Text loop
            --  The value is postfixed with " (broken.txt)", so match the prefix.
            if Ada.Strings.Fixed.Index
                 (To_String (Text.Text), Files.Localization.Text ("error.metadata.read")) = 1
            then
               Found_Localized := True;
            end if;
         end loop;
         for Node of Frame.Accessibility loop
            if Node.Role = Guikit.Draw.Role_List_Item
              and then To_String (Node.Name) = "broken.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.metadata_error") & ": "
                 & Files.Localization.Text ("error.metadata.read")) > 0
            then
               Found_A11y_Metadata := True;
            end if;
         end loop;

         Assert (Found_Localized, "info pane localizes metadata error keys");
         Assert (Found_A11y_Metadata, "info pane accessibility describes metadata error keys");
      end;

      Write_File (Join (Root, "blob.bin"), "binary");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "blob.bin");
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Files.Localization.Text ("info.extra.extension.prefix") &
         "bin" &
         Files.Localization.Text ("info.extra.extension.suffix"),
         "info pane captures extension metadata fallback");
      Files.Model.Toggle_Info_Pane (Model);

      Write_File (Join (Root, "run.sh"), "#!/bin/sh" & ASCII.LF);
      declare
         Items : Files.File_System.Item_Vectors.Vector;
         Exec_Item : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "run.sh",
              Kind        => Files.Types.Executable_Item,
              Filetype    => "application/x-executable");
      begin
         Exec_Item.Size_Available := True;
         Exec_Item.Size := Long_Long_Integer (Ada.Directories.Size (Join (Root, "run.sh")));
         Items.Append (Exec_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (Ada.Strings.Fixed.Index
              (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra),
               Files.Localization.Text ("info.extra.executable.size.prefix")) = 1,
            "info pane captures executable snapshot metadata without reading file contents");
      end;

      declare
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append
           (Files.File_System.Make_Item
              (Parent_Path => Join (Root, "missing-parent"),
               Name        => "ghost.bin",
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "application/octet-stream"));
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
            Files.Localization.Text ("info.extra.extension.prefix") &
            "bin" &
            Files.Localization.Text ("info.extra.extension.suffix"),
            "info pane snapshot uses item fields without reading a backing file");
      end;

      Write_File (Join (Root, "more.txt"), "efgh");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Filter (Model, ".txt");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 2, "info snapshot includes all selected items");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Name) = "meta.txt",
         "multi-selection info preserves first selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Name) = "more.txt",
         "multi-selection info preserves second selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes first filetype detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes second filetype detail");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      declare
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
         Info_Layout  : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);
         --  A multi-item selection draws a COALESCED, field-major layout: each
         --  section label appears once and each value row is postfixed with its
         --  item name, so there is no dedicated Name section.
         Name_Label       : constant String := Files.Localization.Text ("info.name");
         Name_Label_Count : Natural := 0;
         Meta_Postfixed   : Boolean := False;
         More_Postfixed   : Boolean := False;

         function Ends_With (Text : Unbounded_String; Suffix : String) return Boolean is
         begin
            return Length (Text) >= Suffix'Length
              and then Slice (Text, Length (Text) - Suffix'Length + 1, Length (Text)) = Suffix;
         end Ends_With;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_Layout.X then
               if To_String (Text.Text) = Name_Label then
                  Name_Label_Count := Name_Label_Count + 1;
               elsif Ends_With (Text.Text, " (meta.txt)") then
                  Meta_Postfixed := True;
               elsif Ends_With (Text.Text, " (more.txt)") then
                  More_Postfixed := True;
               end if;
            end if;
         end loop;

         Assert
           (Name_Label_Count = 0,
            "coalesced info pane has no dedicated Name section");
         Assert
           (Meta_Postfixed and then More_Postfixed,
            "each selected item's rows are postfixed with its own name");
      end;
   end Test_Info_Pane_Metadata_Snapshot;

   --  Each info-pane section label carries a descriptive hover tooltip drawn from
   --  its "<key>.tooltip" catalog entry.
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      function Tooltip_Present (Text : String) return Boolean is
      begin
         for Tip of Frame.Tooltips loop
            if To_String (Tip.Text) = Text then
               return True;
            end if;
         end loop;
         return False;
      end Tooltip_Present;
   begin
      Reset_Root;
      Write_File (Join (Root, "tip.txt"), "hello");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "tip.txt");
      Files.Model.Toggle_Info_Pane (Model);

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 1200, Line_Height => 20);

      Assert (Tooltip_Present (Files.Localization.Text ("info.permissions.tooltip")),
              "the Permissions section has its descriptive tooltip");
      Assert (Tooltip_Present (Files.Localization.Text ("info.filetype.tooltip")),
              "the Filetype section has its descriptive tooltip");
   end Test_Info_Pane_Section_Tooltips;

   --  Clicking the free-space field cycles its display: free -> used -> bar ->
   --  free, tracked by the Show_Used_Space / Show_Space_Bar settings.
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Path     : constant String := Join (Root, "settings.conf");
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
   begin
      Reset_Root;
      Assert (not Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "starts in free-space mode");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "free -> used");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (Settings.Show_Space_Bar, "used -> bar");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (not Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "bar -> free");
   end Test_Free_Space_Display_Cycle;

   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check
        (Field        : Files.Settings.Sort_Field;
         Ascending    : Boolean;
         Expect_Model : Files.Model.Sort_Field;
         Label        : String)
      is
         Model    : Files.Model.Window_Model := Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Settings.Default_View     := Files.Types.Details;
         Settings.Sort_Field_Value := Field;
         Settings.Sort_Ascending   := Ascending;
         Files.Operations.Apply_Ui_State (Model, Settings);
         Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, Label & ": view mode applied");
         Assert (Files.Model.Sort_Field_Of (Model) = Expect_Model, Label & ": sort field applied");
         Assert (Files.Model.Sort_Is_Ascending (Model) = Ascending, Label & ": sort direction applied");
      end Check;
   begin
      --  Every field/direction combination applies exactly. The regression case is
      --  the default field (name) ascending: the previous toggle-based apply flipped
      --  it to descending, leaving the model out of step with the settings so a later
      --  user toggle merely undid the discrepancy and never persisted.
      Check (Files.Settings.Sort_By_Name, True,  Files.Model.Sort_Name, "name ascending");
      Check (Files.Settings.Sort_By_Name, False, Files.Model.Sort_Name, "name descending");
      Check (Files.Settings.Sort_By_Size, True,  Files.Model.Sort_Size, "size ascending");
      Check (Files.Settings.Sort_By_Size, False, Files.Model.Sort_Size, "size descending");
   end Test_Apply_Ui_State_Round_Trip;

   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Read the bundled folder.icon from disk. This confirms the runtime loads
      --  icon definitions from the .icon files (the single edit surface) rather
      --  than only the built-in copies, and that it sees the redesigned shapes.
      Folder : constant String := Files.Icon_Assets.Disk_Icon_Asset ("folder", "");
   begin
      Assert (Folder /= "", "the bundled folder.icon is read from disk");
      Assert (Ada.Strings.Fixed.Index (Folder, "files-icon-v1") > 0,
              "the disk icon carries the files-icon-v1 header");
      Assert (Ada.Strings.Fixed.Index (Folder, "grid=32") > 0,
              "the disk icon uses the finer 32-unit grid");
      Assert (Ada.Strings.Fixed.Index (Folder, "tri=") > 0,
              "the disk icon uses triangle primitives");
   end Test_Icon_Assets_Load_From_Disk;

   --  With several items selected the info pane is coalesced field-major: each
   --  section label is drawn once (not repeated per item) and each selected
   --  item's value follows as its own row.
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Write_File (Join (Root, "alpha.txt"), "aaaa");
      Write_File (Join (Root, "beta.txt"), "bbbb");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "two items are selected");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      --  Wide enough that a short permissions line ("readable, writable") does
      --  not wrap, so the coalesced one-row-per-item layout is what is tested.
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1600, Height => 1200, Line_Height => 20);

      declare
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 1600, Height => 1200, Line_Height => 20);
         Info_Layout : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);

         --  Count the distinct rows a label appears on within the info pane
         --  (the label is drawn twice per row for a faux-bold weight).
         function Label_Rows (Key : String) return Natural is
            Label : constant String := Files.Localization.Text (Key);
            Rows  : Natural := 0;
            Last  : Integer := -1;
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then To_String (Text.Text) = Label
                 and then Integer (Text.Y) /= Last
               then
                  Rows := Rows + 1;
                  Last := Integer (Text.Y);
               end if;
            end loop;
            return Rows;
         end Label_Rows;

         function Value_Present (Value : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X and then To_String (Text.Text) = Value then
                  return True;
               end if;
            end loop;
            return False;
         end Value_Present;

         --  Some info-pane text row ends with the given " (<name>)" postfix.
         function Value_Ends_With (Postfix : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then Length (Text.Text) >= Postfix'Length
                 and then Slice (Text.Text, Length (Text.Text) - Postfix'Length + 1, Length (Text.Text)) = Postfix
               then
                  return True;
               end if;
            end loop;
            return False;
         end Value_Ends_With;

         --  Some info-pane text row contains both substrings.
         function Row_Has_Both (A : String; B : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then Ada.Strings.Fixed.Index (To_String (Text.Text), A) > 0
                 and then Ada.Strings.Fixed.Index (To_String (Text.Text), B) > 0
               then
                  return True;
               end if;
            end loop;
            return False;
         end Row_Has_Both;
      begin
         Assert (Label_Rows ("info.name") = 0, "there is no dedicated Name section");
         Assert (not Value_Present ("alpha.txt") and then not Value_Present ("beta.txt"),
                 "item names appear only as postfixes, not as bare Name rows");
         Assert (Label_Rows ("info.size") = 1, "Size label appears once");
         Assert (Label_Rows ("info.filetype") = 1, "Filetype label appears once");
         Assert (Label_Rows ("info.modified") = 1, "Modified label appears once");
         Assert (Label_Rows ("info.kind") = 0, "the redundant Kind section is removed");
         Assert (Row_Has_Both (Files.Localization.Text ("info.permissions.readable"),
                               Files.Localization.Text ("info.permissions.writable")),
                 "an item's readable and writable permissions share one coalesced row");
         Assert (Value_Ends_With (" (alpha.txt)") and then Value_Ends_With (" (beta.txt)"),
                 "every section row is postfixed with its item name");

         --  No leftover header gap: the first section starts at the pane top.
         declare
            Filetype_Label : constant String := Files.Localization.Text ("info.filetype");
            Top_Y          : Integer := Integer'Last;
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then To_String (Text.Text) = Filetype_Label
                 and then Integer (Text.Y) < Top_Y
               then
                  Top_Y := Integer (Text.Y);
               end if;
            end loop;
            Assert (Top_Y = Info_Layout.Y + 10,
                    "the first info-pane section starts at the pane top with no reserved header gap");
         end;
      end;
   end Test_Info_Pane_Coalesced_Multi;

   --  Filesize is a file-only field: folders show nothing for it, and when every
   --  selected item is a folder the section is dropped entirely. The label is
   --  "Filesize" in the default catalog.
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      --  Distinct rows a label occupies within the info pane.
      function Size_Label_Rows return Natural is
         Label : constant String := Files.Localization.Text ("info.size");
         Info_X : constant Natural := Frame.Layout.Main_Width;
         Rows  : Natural := 0;
         Last  : Integer := -1;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_X
              and then To_String (Text.Text) = Label
              and then Integer (Text.Y) /= Last
            then
               Rows := Rows + 1;
               Last := Integer (Text.Y);
            end if;
         end loop;
         return Rows;
      end Size_Label_Rows;
   begin
      Assert (Files.Localization.Text ("info.size", "en") = "Filesize",
              "the file-size label reads Filesize in the default catalog");

      --  Single folder: no Filesize field (it carries no byte size).
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "onlydir"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Size_Label_Rows = 0, "a single selected folder shows no Filesize field");

      --  All folders: the Filesize section is omitted.
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "d1"));
      Ada.Directories.Create_Path (Join (Root, "d2"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Files.Model.Selected_Count (Model) = 2, "two folders are selected");
      Assert (Size_Label_Rows = 0, "an all-folder selection shows no Filesize section");

      --  Mixed file + folder: the Filesize section appears (once) for the file.
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "mixdir"));
      Write_File (Join (Root, "mixfile.txt"), "data");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Size_Label_Rows = 1, "a mixed selection shows the Filesize section for its file");
   end Test_Info_Pane_Filesize_Files_Only;

   --  The combined selection total is the last line of the Contents section
   --  (below the Contents label and the per-folder rows), not a header above the
   --  sections.
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "fa"));
      Ada.Directories.Create_Path (Join (Root, "fb"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "two folders are selected");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);

      declare
         Info_X         : constant Natural := Frame.Layout.Main_Width;
         Contents_Label : constant String := Files.Localization.Text ("info.folder_size");
         Filetype_Label : constant String := Files.Localization.Text ("info.filetype");
         Total_Prefix   : constant String := Files.Localization.Text ("info.contents.total") & ":";
         Contents_Y     : Integer := -1;
         Filetype_Y     : Integer := -1;
         Total_Y        : Integer := -1;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_X then
               declare
                  V : constant String := To_String (Text.Text);
               begin
                  if V = Contents_Label then
                     Contents_Y := Integer (Text.Y);
                  elsif V = Filetype_Label then
                     Filetype_Y := Integer (Text.Y);
                  elsif Ada.Strings.Fixed.Index (V, Total_Prefix) = 1 then
                     Total_Y := Integer (Text.Y);
                  end if;
               end;
            end if;
         end loop;

         Assert (Total_Y >= 0, "the combined selection total is rendered in the info pane");
         Assert (Contents_Y >= 0, "the Contents section is present for a folder selection");
         Assert (Total_Y > Contents_Y, "the total is below the Contents label (part of that section)");
         Assert (Filetype_Y >= 0 and then Total_Y > Filetype_Y,
                 "the total is no longer a header above the sections");
      end;
   end Test_Info_Pane_Total_In_Contents;

   --  The expensive "extra info" (folder child counts, document scans) must not
   --  be computed on load -- that made navigation slow. It is computed lazily
   --  only for the selected item when the info pane is open.
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;

      --  The generic fallback shown when the child count has not been computed.
      Fallback : constant String := Files.Localization.Text ("info.extra.directory");

      function Folder_Extra return String is
         Snap : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         for Idx in 1 .. Natural (Snap.Items.Length) loop
            if Snap.Items.Element (Idx).Name = To_Unbounded_String ("sub") then
               return To_String (Snap.Items.Element (Idx).Filetype_Extra);
            end if;
         end loop;
         return "";
      end Folder_Extra;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "sub"));
      Write_File (Join (Join (Root, "sub"), "x.txt"), "hi");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "sub");

      --  Info pane closed: the child count is not computed (no subfolder opened),
      --  so the snapshot shows the cheap generic fallback rather than a count.
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Assert (Folder_Extra = Fallback,
              "folder shows the generic fallback, not a child count, while the info pane is closed");

      --  Info pane open: the selected folder's child count is computed lazily,
      --  replacing the fallback with the actual count detail.
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Assert (Folder_Extra /= Fallback and then Folder_Extra'Length > 0,
              "folder child count is computed lazily when the info pane is open");
   end Test_Filetype_Extra_Is_Lazy;

   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Marker : constant String := Join (Root, "size-started");
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_FOLDER_SIZES");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "");
      Started, Previous, Path : Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
      Available, Finished, Cancelled : Boolean;
      Empty : Files.Process_Jobs.Session;
      Before : Ada.Calendar.Time;
      Targets : Files.Folder_Size.Path_Vectors.Vector;

      procedure Restore is
      begin
         Files.Folder_Size.Cancel;
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
         end if;
      end Restore;

      procedure Await_Helper is
         File : Ada.Text_IO.File_Type;
      begin
         for Attempt in 1 .. 5_000 loop
            exit when Ada.Directories.Exists (Marker);
            delay 0.001;
         end loop;
         Assert (Ada.Directories.Exists (Marker), "the size helper reaches stalled filesystem work");
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Marker);
         Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (File), "started"));
         Ada.Text_IO.Close (File);
         Assert (Ada.Directories.Exists (To_String (Started)), "the stalled helper owns its transport");
      end Await_Helper;

      procedure Await_Reaped (Started : Unbounded_String) is
      begin
         for Attempt in 1 .. 5_000 loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Started));
            delay 0.001;
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Started)),
                 "the abandoned size helper is terminated and reaped");
      end Await_Reaped;
   begin
      Reset_Root;
      Files.Folder_Size.Cancel;
      loop
         Files.Folder_Size.Take (Path, Result, Available);
         exit when not Available;
      end loop;
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Request (Join (Root, "unreadable-or-missing"));
      Assert (Ada.Calendar.Clock - Before < 0.25, "posting a size request does not inspect its target");
      Await_Helper;
      Targets.Append (To_Unbounded_String (Join (Root, "unreadable-or-missing")));
      Targets.Append (To_Unbounded_String (Join (Root, "another-window")));
      Before := Ada.Calendar.Clock;
      for Frame in 1 .. 50 loop
         Files.Folder_Size.Set_Targets (Targets);
         Files.Folder_Size.Step;
         Files.Folder_Size.Take (Path, Result, Available);
         Assert (not Available, "a stalled scan does not publish a partial total");
      end loop;
      Assert (Ada.Calendar.Clock - Before < 0.25 and then Files.Folder_Size.Is_Active
              and then Ada.Directories.Exists (To_String (Started)),
              "repeated frame polling preserves the active helper and never waits for its filesystem work");
      Previous := Started;
      Ada.Directories.Delete_File (Marker);
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Request (Join (Root, "another-window"));
      Assert (Ada.Calendar.Clock - Before < 0.25, "retargeting does not join the abandoned scan");
      Await_Helper;
      Assert (Started /= Previous, "retargeting starts a separate helper");
      Await_Reaped (Previous);
      Assert (Ada.Directories.Exists (To_String (Started)), "retargeting leaves the replacement helper active");
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Cancel;
      Files.Folder_Size.Cancel;
      Assert (Ada.Calendar.Clock - Before < 0.25 and then not Files.Folder_Size.Is_Active,
              "repeated cancellation is prompt even while a size read is stalled");
      Await_Reaped (Started);
      Files.Folder_Size.Take (Path, Result, Available);
      Assert (not Available, "cancelled requests never publish stale measurements");
      Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
      Ada.Directories.Create_Path (Join (Root, "ready"));
      Write_Binary_File (Join (Join (Root, "ready"), "data"), "12345678");
      Files.Folder_Size.Request (Join (Root, "ready"));
      for Attempt in 1 .. 5_000 loop
         Files.Folder_Size.Step;
         Files.Folder_Size.Take (Path, Result, Available);
         exit when Available;
         delay 0.001;
      end loop;
      Assert (Available and then To_String (Path) = Join (Root, "ready")
              and then Result.Available and then Result.Total_Bytes = 8 and then Result.File_Count = 1,
              "a fresh request completes normally after a stalled scan was cancelled");
      Files.Folder_Size.Take (Path, Result, Available);
      Assert (not Available, "finished measurements are delivered once");
      for Invalid_Target in 1 .. 2 loop
         declare
            Target : constant String :=
              (if Invalid_Target = 1 then Join (Root, "missing") else Join (Join (Root, "ready"), "data"));
         begin
            Files.Folder_Size.Request (Target);
            Files.Folder_Size.Step (Budget => 0);
            Assert (Files.Folder_Size.Is_Active, "zero budget leaves collection for a later frame");
            for Attempt in 1 .. 5_000 loop
               Files.Folder_Size.Step;
               Files.Folder_Size.Take (Path, Result, Available);
               exit when Available;
               delay 0.001;
            end loop;
            Assert (Available and then To_String (Path) = Target and then not Result.Available,
                    "missing and non-directory roots produce unavailable measurements in the helper");
         end;
      end loop;
      Restore;
   exception
      when others => Restore; raise;
   end Test_Folder_Size_Helper_Cancellation;

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

   procedure Test_Undo_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Old_Dest : constant String := Join (Root, "old-copy");
      Target : constant String := Join (Root, "target");
      Old_Token : Unbounded_String;
   begin
      for Background in Boolean loop
         for Kind in 1 .. 3 loop
            Reset_Root;
            Write_Binary_File (Target, "target bytes");
            case Kind is
               when 1 => Write_Binary_File (Source, "same bytes");
               when 2 =>
                  Ada.Directories.Create_Directory (Source);
                  Write_Binary_File (Join (Source, "child"), "same bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                    (Source, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
               when others =>
                  if not Hostkit.Fs.Create_Link (Target, Source) then
                     return;
                  end if;
            end case;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "original");
            Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
            Await_View (Model, Settings);
            Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
            Assert (Length (Old_Token) > 0, "record a non-following entry identity");
            if Kind = 2 then
               Write_Binary_File (Join (Dest, "user-added"), "new user bytes");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Join (Dest, "child"), "same bytes")
                       and then File_Has_Bytes (Join (Dest, "user-added"), "new user bytes"),
                       "Undo refuses a copied directory after a user adds a child and retains the complete tree");
               Ada.Directories.Delete_File (Join (Dest, "user-added"));
               GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                 (Dest, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
            end if;
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo removes the entry it created");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo republishes the entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Undo uses the new identity recorded by Redo");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Hostkit.Fs.Move_No_Replace (Dest, Old_Dest), "retain the original inode at another path");
            Mutation := Files.File_System.Copy_Tree (Source, Dest);
            Assert (Mutation.Success, "replace the pathname with an identical but unrelated entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo refuses a replacement even when its contents and link target are identical");
            Mutation := Files.File_System.Delete_Permanently (Dest);
            Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Old_Dest, Dest),
                    "put the owned entry back so the action can be retried");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success and then not Files.Model.Undo_Available (Model),
                    "a refused Undo remains retryable when its owned entry is restored");
         end loop;
         Reset_Root;
         Write_Binary_File (Source, "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Source, GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Files.File_System.Tree_Revision (Dest) /= "",
                 "a copied regular file has a recorded revision");
         Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
         declare
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Dest);
            Metadata : constant String := Files.File_Identities.Revision (Dest, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Dest, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Dest, Stamp);
            Assert (Files.File_Identities.Token (Dest) = To_String (Old_Token)
                    and then Files.File_Identities.Revision (Dest, False) = Metadata
                    and then Files.File_System.Tree_Revision (Dest) /= Snapshot,
                    "a same-size edit with restored mtime keeps its old metadata but changes its content digest");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then File_Has_Bytes (Dest, "edited bytes"),
                    "Undo retains a same-size edited copy and its retryable action");
         end;
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "child"), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success,
                 "duplicate a directory containing a regular file");
         declare
            Child : constant String := Join (Dest, "child");
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Child);
            Metadata : constant String := Files.File_Identities.Revision (Child, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Child, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Child, Stamp);
            Assert (Files.File_Identities.Revision (Child, False) = Metadata
                    and then Files.File_System.Tree_Revision (Dest) /= Snapshot,
                    "a copied directory revision tracks same-size edits to a child");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then File_Has_Bytes (Child, "edited bytes"),
                    "Undo retains a copied directory whose child bytes changed");
         end;
      end loop;
      Reset_Root;
      declare
         Unverifiable : constant String := Join (Root, "unverifiable");
         Verifiable   : constant String := Join (Root, "verifiable");
         Older        : constant String := Join (Root, "older");
         Paths, Identities, Revisions, Older_Path : Files.Types.String_Vectors.Vector;
         Recorded : Boolean;
      begin
         Write_Binary_File (Unverifiable, "unverifiable bytes");
         Write_Binary_File (Verifiable, "verifiable bytes");
         Write_Binary_File (Older, "older bytes");
         Files.Model.Initialize
           (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Older_Path.Append (To_Unbounded_String (Older));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Older_Path,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         Paths.Append (To_Unbounded_String (Unverifiable));
         Identities.Append (Null_Unbounded_String);
         Revisions.Append (Null_Unbounded_String);
         Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False,
            Original_Identities => Identities,
            Original_Tree_Revisions => Revisions);
         Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                 "an identity-free action does not replace an older usable Undo entry");
         declare
            Stale : constant String := Join (Root, "stale-snapshot");
            Saved : constant String := Join (Root, "stale-snapshot-saved");
            Prefix : constant String := Join (Root, "verified-prefix");
            Directory_Path : constant String := Join (Root, "snapshot-directory");
            Incomplete : constant String := Join (Root, "incomplete-redo");
            Candidate, Candidate_Identities, Candidate_Revisions : Files.Types.String_Vectors.Vector;
            Old_Identity, Old_Revision : Files.Types.UString;
            Previous : Files.Model.Undo_Entry;
            Found : Boolean;
         begin
            Write_Binary_File (Stale, "owned bytes");
            Old_Identity := To_Unbounded_String (Files.File_Identities.Token (Stale));
            Ada.Directories.Rename (Stale, Saved);
            Write_Binary_File (Stale, "replacement bytes");
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older
                    and then File_Has_Bytes (Stale, "replacement bytes"),
                    "a stale supplied identity cannot enter history or displace an older action");

            Write_Binary_File (Prefix, "verified bytes");
            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Candidate.Append (To_Unbounded_String (Prefix));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Prefix)));
            Candidate_Revisions.Append
              (To_Unbounded_String (Files.File_System.Tree_Revision (Prefix)));
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (Recorded, "admit the first independently verified batch member");
            Files.Model.Take_Undo (Model, Previous, Found);
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions,
               Retain_Verified_Main => 1);
            Assert
              (Recorded
               and then Natural (Files.Model.Undo_From_Paths (Model).Length) = 1
               and then Files.Model.Undo_From_Paths (Model).First_Element = Prefix,
               "a verified prefix does not admit a newly appended stale snapshot");
            Files.Model.Take_Undo (Model, Previous, Found);

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Ada.Directories.Create_Directory (Directory_Path);
            Write_Binary_File (Join (Directory_Path, "first"), "first");
            Candidate.Append (To_Unbounded_String (Directory_Path));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Directory_Path)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "a created directory without a complete tree revision is not recorded");

            Old_Revision := To_Unbounded_String (Files.File_System.Tree_Revision (Directory_Path));
            Write_Binary_File (Join (Directory_Path, "second"), "second");
            Candidate_Revisions.Replace_Element (Candidate_Revisions.First_Index, Old_Revision);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "a stale directory revision cannot enter history");

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Write_Binary_File (Incomplete, "created bytes");
            Candidate.Append (To_Unbounded_String (Incomplete));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Incomplete)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector,
               Create_Kind => Files.Model.Create_Copy,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "an action without its required Redo source is not recorded");
         end;
         Paths.Append (To_Unbounded_String (Verifiable));
         Identities.Append (To_Unbounded_String (Files.File_Identities.Token (Verifiable)));
         Revisions.Append
           (To_Unbounded_String (Files.File_System.Tree_Revision (Verifiable)));
         Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False,
            Original_Identities => Identities,
            Original_Tree_Revisions => Revisions);
         Assert (Recorded
                 and then Natural (Files.Model.Undo_From_Paths (Model).Length) = 1
                 and then Files.Model.Undo_From_Paths (Model).First_Element = Verifiable,
                 "mixed history retains only members with verifiable publication identities");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Unverifiable)
                 and then not Ada.Directories.Exists (Verifiable)
                 and then Files.Model.Undo_Available (Model),
                 "filtered Undo removes its verified member and leaves untracked data intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then not Ada.Directories.Exists (Older),
                 "identity filtering leaves earlier usable history reachable");
      end;
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Background in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Directory (Join (Root, "inbox"));
            Write_Binary_File (Join (Join (Root, "inbox"), "a.txt"), "a bytes");
            Write_Binary_File (Join (Join (Root, "inbox"), "b.txt"), "b bytes");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            declare
               Actions : Files.Paste.Resolved_Action_Vectors.Vector;
               A : constant String := Join (Root, "a.txt");
               B : constant String := Join (Root, "b.txt");
               Saved_A : constant String := Join (Root, "saved-a.txt");
            begin
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Join (Root, "inbox"), "a.txt")), To_Unbounded_String (A), False, False));
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Join (Root, "inbox"), "b.txt")), To_Unbounded_String (B), False, False));
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, False);
               for Attempt in 1 .. 5_000 loop
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                  exit when Files.Model.Paste_Execution_Done (Model) = 1;
                  delay 0.001;
               end loop;
               Assert (Files.Model.Paste_Execution_Done (Model) = 1, "the first paste member commits");
               Assert (Hostkit.Fs.Move_No_Replace (A, Saved_A), "retain the first owned entry between batches");
               Write_Binary_File (A, "unrelated a");
               Step := Complete_Operation (Model, Settings, Step);
               Await_View (Model, Settings);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (A, "unrelated a") and then not Ada.Directories.Exists (B),
                       "later paste steps cannot recapture a replacement as an owned entry");
               Mutation := Files.File_System.Delete_Permanently (A);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved_A, A),
                       "restore the owned first entry");
               Write_Binary_File (B, "unrelated b");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Ada.Directories.Exists (A) and then File_Has_Bytes (B, "unrelated b"),
                       "partial Undo retries preserve unrelated entries at already reversed paths");
            end;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Undo_Entry_Identity;

   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mutation : Files.File_System.Mutation_Result;
      Available : Boolean;
      Mode : Natural;
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "destination");
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         return;
      end if;
      for Directory_Copy in Boolean loop
         Reset_Root;
         if Directory_Copy then
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "run.sh"), "executable bytes");
            Mutation := Files.File_System.Set_Permissions (Join (Source, "run.sh"), 8#750#);
            Assert (Mutation.Success, "prepare nested executable");
         else
            Write_Binary_File (Source, "executable bytes");
         end if;
         Mutation := Files.File_System.Set_Permissions (Source, 8#750#);
         Assert (Mutation.Success, "prepare source access bits");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Mode := Files.File_System.Permission_Bits_Of (Dest, Available);
         Assert (Mutation.Success and then Available and then Mode = 8#750#,
                 "copy preserves ordinary access bits on files and directories");
         if Directory_Copy then
            Mode := Files.File_System.Permission_Bits_Of (Join (Dest, "run.sh"), Available);
            Assert (Available and then Mode = 8#750#
                    and then File_Has_Bytes (Join (Dest, "run.sh"), "executable bytes"),
                    "recursive copies preserve executable bits and content");
         end if;
      end loop;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Mutation := Files.File_System.Set_Permissions (Source, 8#7777#);
      Assert (Mutation.Success, "prepare sticky and privilege bits");
      Mutation := Files.File_System.Copy_Tree (Source, Dest);
      Mode := Files.File_System.Permission_Bits_Of (Dest, Available);
      Assert (Mutation.Success and then Available and then Mode = 8#1777#,
              "directory copies preserve sticky deletion protection while stripping setuid and setgid");
   end Test_Copy_Access_Bits;

   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Saved : constant String := Join (Root, "saved-original");
      Load : Files.File_System.Directory_Load_Result;
      Finished, Cancelled : Boolean;
      Mutation : Files.File_System.Mutation_Result;
      Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
      File : Ada.Streams.Stream_IO.File_Type;
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_LOST_CREATION_METADATA");
      Old_Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_LOST_CREATION_METADATA", "");
      procedure Restore is
      begin
         if Had_Fault then Ada.Environment_Variables.Set ("FILES_TEST_LOST_CREATION_METADATA", Old_Fault);
         else Ada.Environment_Variables.Clear ("FILES_TEST_LOST_CREATION_METADATA"); end if;
      end Restore;
   begin
      for Redo_Recovery in Boolean loop
         Reset_Root;
         Write_Binary_File (Source, "owned bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, False);
         Select_Name (Model, "original");
         if Redo_Recovery then
            Step := Files.Operations.Duplicate_Selected (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare redoable creation");
            Step := Files.Operations.Undo_Last (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare Redo recovery");
         end if;
         Files.Model.Set_Background_Transfers (Model, True);
         Ada.Environment_Variables.Set ("FILES_TEST_LOST_CREATION_METADATA", "1");
         Step := (if Redo_Recovery then Files.Operations.Redo_Last (Model, Settings)
                  else Files.Operations.Duplicate_Selected (Model, Settings));
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
         begin
            for Attempt in 1 .. 5_000 loop
               Files.Process_Jobs.Poll (Job, Finished, Cancelled);
               exit when Finished;
               delay 0.001;
            end loop;
            Assert (Finished and then Ada.Directories.Exists (Dest), "the helper published before metadata failure");
            if Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "history")) then
               Ada.Directories.Delete_File (Files.Process_Jobs.Path (Job, "history"));
            end if;
            Ada.Directories.Create_Directory (Files.Process_Jobs.Path (Job, "history"));
            Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved), "retain the published entry");
            Write_Binary_File (Dest, "unrelated replacement");
            Restore;
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed, "lost final metadata reports failure");
            if Redo_Recovery then
               Assert (Files.Model.Redo_Available (Model), "the interrupted Redo is retryable");
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (Dest, "unrelated replacement")
                       and then Files.Model.Redo_Available (Model),
                       "retry rejects a replacement behind the recovered completion marker");
               Mutation := Files.File_System.Delete_Permanently (Dest);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Dest),
                       "restore the helper's completed publication for retry");
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success,
                       "retry accepts the restored verified publication");
               Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved),
                       "retain the verified publication for the Undo replacement check");
               Write_Binary_File (Dest, "unrelated replacement");
            end if;
            Assert (Files.Model.Undo_Available (Model)
                    and then Files.Model.Undo_History (Model).Last_Element.Created_Identities.First_Element
                      = Files.File_Identities.Token (Saved), "recovery uses the journaled original identity");
         end;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Dest, "unrelated replacement"),
                 "recovered Undo refuses to delete the replacement");
         Mutation := Files.File_System.Delete_Permanently (Dest);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Dest), "restore the owned output");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "recovery remains undoable for its owned output");
      end loop;
      Ada.Directories.Create_Directory (Join (Root, "journal"));
      Files.Job_Context.Initialize (Join (Root, "journal"));
      Files.Job_Context.Record_Created (Source);
      Files.Job_Context.Initialize ("");
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Join (Join (Root, "journal"), "created"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "truncated destination");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities, Tree_Revisions);
      Assert (Natural (Destinations.Length) = 1 and then Natural (Identities.Length) = 1,
              "a truncated journal ignores incomplete records without losing earlier snapshots");
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Join (Join (Root, "journal"), "created"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), Source);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "old source");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities, Tree_Revisions);
      Assert (Destinations.Is_Empty and then Identities.Is_Empty, "identity-free legacy journals fail closed");
      Restore;
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Ada.Streams.Stream_IO.Is_Open (File) then Ada.Streams.Stream_IO.Close (File); end if;
         Restore;
         raise;
   end Test_Recovery_Entry_Identity;

   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "renamed");
      Saved : constant String := Join (Root, "saved-original");
      Link_Target : constant String := Join (Root, "link-target");
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;

      procedure Replace_And_Refuse (Path : String; Forward : Boolean) is
      begin
         Assert (Hostkit.Fs.Move_No_Replace (Path, Saved), "retain the owned history entry");
         Write_Binary_File (Path, "unrelated replacement");
         Step := Complete_Operation (Model, Settings,
           (if Forward then Files.Operations.Redo_Last (Model, Settings)
            else Files.Operations.Undo_Last (Model, Settings)));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Path, "unrelated replacement"), "history refuses to move a replacement");
         Mutation := Files.File_System.Delete_Permanently (Path);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Path), "restore the owned history entry");
      end Replace_And_Refuse;
   begin
      for Background in Boolean loop
         for Paste_Move in Boolean loop
            for Kind in 1 .. 3 loop
               Reset_Root;
               Write_Binary_File (Link_Target, "target bytes");
               case Kind is
                  when 1 => Write_Binary_File (Source, "owned bytes");
                  when 2 =>
                     Ada.Directories.Create_Directory (Source);
                     Write_Binary_File (Join (Source, "child"), "owned bytes");
                  when others =>
                     if not Hostkit.Fs.Create_Link (Link_Target, Source) then return; end if;
               end case;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Paste_Move then
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               else
                  Select_Name (Model, "original");
                  Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
                  Files.Model.Set_Rename_Text (Model, "renamed");
                  Step := Files.Operations.Commit_Rename (Model, Settings);
               end if;
               Step := Complete_Operation (Model, Settings, Step);
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "the initial history move succeeds");
               Replace_And_Refuse (Dest, False);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "Undo can retry the restored entry");
               Replace_And_Refuse (Source, True);
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "Redo can retry the restored entry");
               --  A vanished source and an unrelated target are not evidence
               --  that the history transition already completed.
               Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved), "remove the owned source pathname");
               Write_Binary_File (Source, "unrelated target");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Source, "unrelated target"),
                       "history cannot mark an unrelated existing target as already moved");
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Move_Entry_Identity;

   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "source");
      Destination : constant String := Join (Root, "destination");
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         return;
      end if;
      for Directory_Move in Boolean loop
         Reset_Root;
         if Directory_Move then
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "child"), "private bytes");
            Mutation := Files.File_System.Set_Permissions (Join (Source, "child"), 0);
         else
            Write_Binary_File (Source, "private bytes");
            Mutation := Files.File_System.Set_Permissions (Source, 0);
         end if;
         Assert (Mutation.Success, "prepare an unreadable move source");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, False);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Destination), False, False));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then not Ada.Directories.Exists (Source)
                 and then Ada.Directories.Exists (Destination)
                 and then Files.Model.Undo_Available (Model),
                 "same-device paste moves an unreadable entry and retains Undo");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Source),
                 "Undo returns the unreadable entry by identity");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Destination),
                 "Redo moves the unreadable entry by identity");
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Move_Without_Read_Access;

   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "destination");
      Remote : Unbounded_String;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      File_Time, Directory_Time : Ada.Calendar.Time;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
      procedure Prepare is
      begin
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "timestamp bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "child"), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, GNAT.OS_Lib.GM_Time_Of (2021, 2, 3, 4, 5, 6));
         File_Time := Ada.Directories.Modification_Time (Join (Source, "child"));
         Directory_Time := Ada.Directories.Modification_Time (Source);
      end Prepare;
      procedure Assert_Times (Path : String) is
      begin
         Assert (Ada.Directories.Modification_Time (Path) = Directory_Time
                 and then Ada.Directories.Modification_Time (Join (Path, "child")) = File_Time,
                 "file and directory modification times survive the completed transition");
      end Assert_Times;
   begin
      Reset_Root;
      Prepare;
      Mutation := Files.File_System.Copy_Tree (Source, Dest);
      Assert (Mutation.Success, "copy timestamp fixture");
      Assert_Times (Dest);
      Write_Binary_File (Join (Source, "precise"), "current timestamp with subsecond precision");
      File_Time := Ada.Directories.Modification_Time (Join (Source, "precise"));
      Mutation := Files.File_System.Copy_Tree (Join (Source, "precise"), Join (Root, "precise-copy"));
      Assert (Mutation.Success and then Ada.Directories.Modification_Time (Join (Root, "precise-copy")) = File_Time,
              "timestamp copies preserve the source's subsecond precision");
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then return; end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-timestamps-"));
      Restore_Tmp;
      if Length (Remote) = 0 then return; end if;
      Write_Binary_File (Join (Root, "mount-probe"), "probe");
      begin
         Ada.Directories.Rename (Join (Root, "mount-probe"), Join (To_String (Remote), "mount-probe"));
         Cleanup;
         return;
      exception
         when Ada.Directories.Use_Error => null;
      end;
      for Background in Boolean loop
         Reset_Root;
         Prepare;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (To_String (Remote), "source")), False, False));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Source),
                 "cross-device move publishes a complete destination and removes its source");
         Assert_Times (Join (To_String (Remote), "source"));
         for Cycle in 1 .. 2 loop
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "cross-device Undo refreshes the moved identity");
            Assert_Times (Source);
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "cross-device Redo refreshes the moved identity");
            Assert_Times (Join (To_String (Remote), "source"));
         end loop;
         Project_Tools.Files.Delete_Tree (Join (To_String (Remote), "source"));
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Timestamps;

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

   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote : Unbounded_String;
      Source : constant String := Join (Root, "changing-source");
      Held : constant String := Join (Root, "held-source");
      Paths : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
      Checks : Natural;
      Current : Positive;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      Old_Time : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5);
      Original_Id : Unbounded_String;
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
      function Change_Source return Boolean is
         Change_At : constant Positive := (if Current <= 2 then 4 elsif Current = 4 then 6 else 5);
      begin
         Checks := Checks + 1;
         if Checks = Change_At then
            case Current is
               when 1 =>
                  Assert (Hostkit.Fs.Move_No_Replace (Source, Held), "retain the old source inode");
                  Write_Binary_File (Source, "new bytes");
               when 2 =>
                  Write_Binary_File (Source, "new bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, Old_Time);
                  Assert (Files.File_Identities.Token (Source) = Original_Id, "the edited source keeps its inode");
               when 3 =>
                  Write_Binary_File (Join (Source, "child"), "new bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Source, "child"), Old_Time);
               when 4 => Write_Binary_File (Join (Source, "late-child"), "new bytes");
               when others =>
                  Assert (Hostkit.Fs.Move_No_Replace (Join (Source, "child"), Held), "retain the old child inode");
                  Write_Binary_File (Join (Source, "child"), "new bytes");
            end case;
         end if;
         return False;
      end Change_Source;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then return; end if;
      Reset_Root;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-source-changes-"));
      Restore_Tmp;
      if Length (Remote) = 0 then return; end if;
      Write_Binary_File (Join (Root, "mount-probe"), "probe");
      begin
         Ada.Directories.Rename (Join (Root, "mount-probe"), Join (To_String (Remote), "mount-probe"));
         Cleanup;
         return;
      exception
         when Ada.Directories.Use_Error => null;
      end;
      for Kind in 1 .. 5 loop
         Reset_Root;
         Current := Kind;
         Checks := 0;
         if Kind <= 2 then
            Write_Binary_File (Source, "old bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, Old_Time);
         else
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "child"), "old bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Source, "child"), Old_Time);
         end if;
         Original_Id := To_Unbounded_String (Files.File_Identities.Token (Source));
         Paths.Clear;
         Paths.Append (Files.File_System.Drop_Import_Plan'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (To_String (Remote), "destination")),
            Files.File_System.Drop_Move, True, Null_Unbounded_String));
         Mutation := Files.File_System.Execute_Drop_Import (Paths, Change_Source'Unrestricted_Access);
         Assert (not Mutation.Success and then Ada.Directories.Exists (Source)
                 and then not Ada.Directories.Exists (Join (To_String (Remote), "destination")),
                 "a changed move source is kept and only the owned destination copy is rolled back");
         Assert (File_Has_Bytes
           ((if Kind <= 2 then Source elsif Kind = 4 then Join (Source, "late-child") else Join (Source, "child")),
            "new bytes"), "the uncopied replacement or edit survives failure");
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Move_Source_Changes;

   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "metadata-source");
      Held : constant String := Join (Root, "held-source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Uid, Gid : Natural;
      Available : Boolean;
      procedure Replace_And_Refuse (Forward : Boolean) is
      begin
         Assert (Hostkit.Fs.Move_No_Replace (Source, Held), "retain the metadata history inode");
         Write_Binary_File (Source, "unrelated replacement");
         Mutation := Files.File_System.Set_Permissions (Source, 8#640#);
         Assert (Mutation.Success, "give the replacement independent permissions");
         Step := Complete_Operation (Model, Settings,
           (if Forward then Files.Operations.Redo_Last (Model, Settings)
            else Files.Operations.Undo_Last (Model, Settings)));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed and then Metadata_Mode_Of (Source) = 8#640#
                 and then File_Has_Bytes (Source, "unrelated replacement"),
                 "metadata history refuses a replacement without changing its access bits");
         Assert ((if Forward then Files.Model.Redo_Available (Model) else Files.Model.Undo_Available (Model)),
                 "refused metadata history remains retryable");
         Mutation := Files.File_System.Delete_Permanently (Source);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Held, Source),
                 "restore the owned metadata entry");
      end Replace_And_Refuse;
   begin
      if not Files.File_System.Supports_Permissions then return; end if;
      for Background in Boolean loop
         for Kind in 1 .. 3 loop
            if Kind < 3 or else Files.File_System.Supports_Ownership then
               Reset_Root;
               Write_Binary_File (Source, "owned bytes");
               Mutation := Files.File_System.Set_Permissions (Source, 8#644#);
               Assert (Mutation.Success, "prepare metadata source");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "metadata-source");
               if Kind < 3 then
                  Step := Files.Operations.Set_Permissions_For (Model, (if Kind = 1 then 0 else 8#600#), Settings);
               else
                  Files.File_System.Ownership_Of (Source, Uid, Gid, Available);
                  Assert (Available, "read the current owner");
                  Step := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
               end if;
               Assert (Step.Status = Files.Operations.Operation_Success, "the live metadata change succeeds");
               Replace_And_Refuse (False);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Metadata_Mode_Of (Source) = 8#644#,
                       "metadata Undo can retry the restored inode, even from mode 000");
               Replace_And_Refuse (True);
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "metadata Redo can retry the restored inode");
            end if;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Metadata_History_Identity;

   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "live-source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Uid, Gid : Natural;
      Available : Boolean;
   begin
      if not Files.File_System.Supports_Permissions then return; end if;
      for Background in Boolean loop
         for Toggle in Boolean loop
            Reset_Root;
            Write_Binary_File (Source, "owned bytes");
            Mutation := Files.File_System.Set_Permissions (Source, 8#644#);
            Assert (Mutation.Success, "prepare cached permissions");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "live-source");
            Mutation := Files.File_System.Set_Permissions (Source, 8#600#);
            Assert (Mutation.Success, "simulate a permission change after the directory listing");
            Step := (if Toggle then Files.Operations.Toggle_Permission_Bit (Model, 8, Settings)
                     else Files.Operations.Set_Permissions_For (Model, 8#750#, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Metadata_Mode_Of (Source) =
                      (if Hostkit.Metadata.Mode_Bits_Are_Native
                       then (if Toggle then 8#601# else 8#750#)
                       else (if Toggle then 8#600# else 8#640#)),
                    "permission changes and toggles use current mode bits");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success and then Metadata_Mode_Of (Source) = 8#600#,
                    "Undo restores the live previous mode instead of stale directory metadata");
         end loop;
         if Files.File_System.Supports_Ownership then
            Reset_Root;
            Write_Binary_File (Source, "owned bytes");
            Files.File_System.Ownership_Of (Source, Uid, Gid, Available);
            Assert (Available, "read actual ownership");
            Load := Files.File_System.Load_Directory (Root, Settings);
            declare
               Item : Files.File_System.Directory_Item := Load.Items.First_Element;
            begin
               Item.Owner_Id := (if Uid > 0 then Uid - 1 else 1);
               Item.Group_Id := (if Gid > 0 then Gid - 1 else 1);
               Load.Items.Replace_Element (Load.Items.First_Index, Item);
            end;
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "live-source");
            Step := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "change ownership with a stale cached owner");
            Assert (Ada.Strings.Fixed.Trim
                      (To_String (Files.Model.Undo_To_Paths (Model).First_Element), Ada.Strings.Both)
                    = Ada.Strings.Fixed.Trim (Natural'Image (Uid), Ada.Strings.Both) & " "
                      & Ada.Strings.Fixed.Trim (Natural'Image (Gid), Ada.Strings.Both),
                    "ownership history records the live ids rather than the stale item");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert
              (Step.Status = Files.Operations.Operation_Success,
               "Undo applies the live ownership snapshot: status="
               & Files.Operations.Operation_Status'Image (Step.Status)
               & " uid=" & Natural'Image (Uid)
               & " gid=" & Natural'Image (Gid)
               & " background=" & Boolean'Image (Background));
         end if;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Live_Metadata_History;

   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Join (Root, "inbox"), "entry");
      Dest : constant String := Join (Root, "entry");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_TRANSFER_RESULT_LOSS");
      Old_Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRANSFER_RESULT_LOSS", "");
      procedure Restore is
      begin
         if Had_Fault then Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", Old_Fault);
         else Ada.Environment_Variables.Clear ("FILES_TEST_TRANSFER_RESULT_LOSS"); end if;
      end Restore;
   begin
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Replaced in Boolean loop
            for Fault in 1 .. 4 loop
               Reset_Root;
               Ada.Directories.Create_Directory (Join (Root, "inbox"));
               Write_Binary_File (Source, "source bytes");
               if Replaced then Write_Binary_File (Dest, "original destination"); end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, True);
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replaced));
               Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS",
                 (case Fault is when 1 => "missing", when 2 => "checkpoint", when 3 => "journal",
                  when others => "replacement"));
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model),
                       "an unavailable helper result reports failure but retains committed paste history: "
                       & Files.File_System.Drop_Import_Mode'Image (Mode) & Boolean'Image (Replaced)
                       & Integer'Image (Fault));
               Assert (Ada.Directories.Exists (Source) = (Mode = Files.File_System.Drop_Copy),
                       "recovery recognizes whether the source move committed");
               if Fault = 4 then
                  Assert (Files.Model.Undo_History (Model).Last_Element.Created_Identities.First_Element
                          = Files.File_Identities.Token (Dest & "-saved"),
                          "recovery retains the published identity without recapturing a replacement");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Failed
                          and then File_Has_Bytes (Dest, "unrelated replacement"),
                          "recovered history preserves an unrelated destination replacement");
                  Mutation := Files.File_System.Delete_Permanently (Dest);
                  Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Dest & "-saved", Dest),
                          "restore the published paste entry");
               end if;
               Restore;
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then File_Has_Bytes (Source, "source bytes"),
                       "Undo reverses a committed paste recovered without its final helper result");
               if Replaced then
                  Assert (File_Has_Bytes (Dest, "original destination"),
                          "recovered Undo restores the replacement backup");
               else
                  Assert (not Ada.Directories.Exists (Dest), "recovered Undo vacates the published destination");
               end if;
            end loop;
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         Restore;
         raise;
   end Test_Transfer_Result_Recovery;

   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Stage : constant String := Join (Parent, ".files-work-1");
      Seen : Boolean := False;
      Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
      function Observe return Boolean is
      begin
         if Ada.Directories.Exists (Join (Stage, "payload/secret")) then
            Seen := True;
            Assert (Is_Owner_Only (Stage), "staging remains owner-only while files are copied");
         end if;
         return False;
      end Observe;
   begin
      if not Files.File_System.Supports_Permissions then return; end if;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Ada.Directories.Create_Directory (Parent);
      Write_Binary_File (Join (Source, "secret"), "private content");
      Mutation := Files.File_System.Set_Permissions (Source, 8#700#);
      Assert (Mutation.Success, "make the source directory private");
      Mutation := Files.File_System.Set_Permissions (Join (Source, "secret"), 8#644#);
      Assert (Mutation.Success, "its child relies on the private ancestor");
      --  An existing stage belongs to another operation and must be skipped.
      Ada.Directories.Create_Directory (Stage);
      Write_Binary_File (Join (Stage, "unrelated"), "untouched");
      declare
         New_Stage : constant String := Files.Job_Context.Create_Stage (Parent);
      begin
         Assert (New_Stage /= Stage and then Is_Owner_Only (New_Stage)
                 and then File_Has_Bytes (Join (Stage, "unrelated"), "untouched"),
                 "exclusive private staging does not change existing directories");
         Mutation := Files.File_System.Delete_Permanently (New_Stage);
         Assert (Mutation.Success, "remove the new empty stage");
      end;
      Mutation := Files.File_System.Delete_Permanently (Stage);
      Assert (Mutation.Success, "remove our collision fixture");
      Plans.Append (Files.File_System.Drop_Import_Plan'
        (To_Unbounded_String (Source), To_Unbounded_String (Join (Parent, "copy")),
         Files.File_System.Drop_Copy, True, Null_Unbounded_String));
      Mutation := Files.File_System.Execute_Drop_Import (Plans, Observe'Unrestricted_Access);
      Assert (Mutation.Success and then Seen and then Is_Owner_Only (Join (Parent, "copy")),
              "a private directory remains protected throughout copying and after publication");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      declare
         Backup : Files.Types.UString;
      begin
         Mutation := Files.File_System.Preserve_For_Replace (Join (Parent, "copy"), Backup);
         Assert (Mutation.Success and then Is_Owner_Only
                 (Ada.Directories.Containing_Directory (To_String (Backup))),
                 "replacement recovery directories are private too");
         Mutation := Files.File_System.Restore_From_Trash (To_String (Backup));
         Assert (Mutation.Success, "restore the private replacement fixture");
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
   exception
      when others =>
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         raise;
   end Test_Private_Copy_Stages;

   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "entry");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Selected : Boolean;
   begin
      for Background in Boolean loop
         for Replace in Boolean loop
            Reset_Root;
            Write_Binary_File (Source, "original destination");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            if Replace then
               Ada.Directories.Create_Directory (Join (Root, "inbox"));
               Write_Binary_File (Join (Root, "inbox/entry"), "pasted bytes");
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Root, "inbox/entry")), To_Unbounded_String (Source), False, True));
               Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Paths := Files.Model.Undo_History (Model).Last_Element.Restore_Trash;
            else
               Selected := Files.Model.Select_By_Name (Model, "entry");
               Assert (Selected, "select the trash fixture");
               Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
               Await_View (Model, Settings);
               Paths := Files.Model.Undo_From_Paths (Model);
            end if;
            Assert (Step.Status = Files.Operations.Operation_Success and then not Paths.Is_Empty,
                    "trash or paste-replace records recoverable history");
            declare
               Payload : constant String := To_String (Paths.First_Element);
               Saved : constant String := Payload & "-saved";
            begin
               Assert (Hostkit.Fs.Move_No_Replace (Payload, Saved), "hold the owned trash payload");
               Write_Binary_File (Payload, "unrelated replacement");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Payload, "unrelated replacement")
                       and then not Ada.Directories.Exists (Source),
                       "Undo refuses to restore an unrelated trash payload and retains retryable history");
               Mutation := Files.File_System.Delete_Permanently (Payload);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Payload),
                       "put the original trash payload back");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then File_Has_Bytes (Source, "original destination"),
                       "retry restores the original without repeating completed paste removal");
            end;
         end loop;
      end loop;
   end Test_Trash_History_Identity;

   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Prepare_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_prepare";
      function Check_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_check";
      function Capture_Times (Path, Values : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_copy_times_capture";
      type Times_Array is array (Positive range 1 .. 4) of Interfaces.C.long_long with Convention => C;
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Original_File, Original_Directory : Times_Array;
      Mutation : Files.File_System.Mutation_Result;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      function Times_Of (Path : String) return Times_Array is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
         Values : aliased Times_Array;
      begin
         Assert (Capture_Times (Name'Address, Values'Address) = 1, "capture access and modification times");
         return Values;
      end Times_Of;
      procedure Prepare (Path : String; Directory : Boolean) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Prepare_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                 "prepare extended attributes, ACL and nanosecond timestamp fixtures");
      end Prepare;
      procedure Check (Path : String; Directory : Boolean; Expected : Times_Array) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Check_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                 "preserve populated and empty extended attributes and the file ACL");
         Assert (Times_Of (Path) = Expected, "preserve access and modification timestamps before any read");
      end Check;
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then return; end if;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Write_Binary_File (Join (Source, "child"), "metadata bytes");
      Prepare (Join (Source, "child"), False);
      Prepare (Source, True);
      Original_File := Times_Of (Join (Source, "child"));
      Original_Directory := Times_Of (Source);
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy extended metadata fixture");
      Check (Join (Root, "copy"), True, Original_Directory);
      Check (Join (Root, "copy/child"), False, Original_File);
      if not Ada.Directories.Exists ("/dev/shm") then return; end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-extended-metadata-"));
      Restore_Tmp;
      if Length (Remote) = 0 then return; end if;
      Prepare (Join (Source, "child"), False);
      Prepare (Source, True);
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source),
              "move the metadata tree across filesystems");
      Check (Join (To_String (Remote), "moved"), True, Original_Directory);
      Check (Join (To_String (Remote), "moved/child"), False, Original_File);
      --  Guarded history transitions use the same metadata-preserving fallback.
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "guarded cross-filesystem history move");
      Check (Source, True, Original_Directory);
      Check (Join (Source, "child"), False, Original_File);
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Extended_Metadata;

   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "inbox/entry");
      Remote : Unbounded_String;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_TRANSFER_RESULT_LOSS");
      Old_Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRANSFER_RESULT_LOSS", "");
      procedure Restore is
      begin
         if Had_Fault then Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", Old_Fault);
         else Ada.Environment_Variables.Clear ("FILES_TEST_TRANSFER_RESULT_LOSS"); end if;
      end Restore;
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore;
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current = Hostkit.Host.Linux and then Ada.Directories.Exists ("/dev/shm") then
         Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
         Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-move-commit-"));
         Restore_Tmp;
      end if;
      for Cross_Device in Boolean loop
         if not Cross_Device or else Length (Remote) > 0 then
            declare
               Parent : constant String := (if Cross_Device then To_String (Remote) else Root);
               Dest : constant String := Join (Parent, "entry");
            begin
               for Replace in Boolean loop
                  Reset_Root;
                  Ada.Directories.Create_Directory (Join (Root, "inbox"));
                  Write_Binary_File (Source, "owned original");
                  if Ada.Directories.Exists (Dest) then
                     Mutation := Files.File_System.Delete_Permanently (Dest);
                     Assert (Mutation.Success, "clear the previous recovered destination");
                  end if;
                  if Replace then Write_Binary_File (Dest, "original destination"); end if;
                  Load := Files.File_System.Load_Directory (Parent, Settings);
                  Files.Model.Initialize (Model, Parent, Load.Items, Parent);
                  Files.Model.Clear_Undo (Model);
                  Files.Model.Set_Background_Transfers (Model, True);
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replace));
                  Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", "source-replacement");
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
                  Step := Complete_Operation
                    (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
                  Await_View (Model, Settings);
                  Restore;
                  Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                          and then File_Has_Bytes (Source, "unrelated replacement")
                          and then File_Has_Bytes (Dest, "owned original"),
                          "a committed move retains Undo despite lost results and a recreated source pathname: "
                          & Boolean'Image (Cross_Device) & Boolean'Image (Replace));
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                          and then File_Has_Bytes (Source, "unrelated replacement")
                          and then File_Has_Bytes (Dest, "owned original"),
                          "recovered Undo preserves the new source occupant and remains retryable");
                  Mutation := Files.File_System.Delete_Permanently (Source);
                  Assert (Mutation.Success, "vacate our replacement fixture");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Success
                          and then File_Has_Bytes (Source, "owned original"),
                          "retry reverses the journaled committed move");
                  Assert ((if Replace then File_Has_Bytes (Dest, "original destination")
                           else not Ada.Directories.Exists (Dest)), "retry also restores a replaced destination");
               end loop;
            end;
         end if;
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Move_Commit_Recovery;

   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "entry");
      Redirected : constant String := Join (Root, "redirected");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Selected : Boolean;
      Had_Xdg : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Old_Xdg : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Old_Back : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "xdg");
      procedure Restore is
      begin
         if Had_Xdg then Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else Ada.Environment_Variables.Clear ("XDG_DATA_HOME"); end if;
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
      end Restore;
   begin
      for Background in Boolean loop
         for Scenario in 1 .. 3 loop
            for Fault in 1 .. 3 loop
               Reset_Root;
               Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
               Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", (if Scenario = 3 then "windows" else "xdg"));
               Write_Binary_File (Source, "original bytes");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Scenario = 1 then
                  Selected := Files.Model.Select_By_Name (Model, "entry");
                  Assert (Selected, "select the trash restore fixture");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
                  Await_View (Model, Settings);
                  Paths := Files.Model.Undo_From_Paths (Model);
                  Assert (Files.Model.Undo_To_Paths (Model).First_Element = To_Unbounded_String (Source),
                          "trash history retains its original destination");
               else
                  Ada.Directories.Create_Directory (Join (Root, "inbox"));
                  Write_Binary_File (Join (Root, "inbox/entry"), "pasted bytes");
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Join (Root, "inbox/entry")), To_Unbounded_String (Source), False, True));
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
                  Step := Complete_Operation
                    (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
                  Await_View (Model, Settings);
                  Paths := Files.Model.Undo_History (Model).Last_Element.Restore_Trash;
                  Assert (Files.Model.Undo_History (Model).Last_Element.Restore_Targets.First_Element
                          = To_Unbounded_String (Source), "paste history retains the preserved original destination");
               end if;
               Assert (Step.Status = Files.Operations.Operation_Success and then not Paths.Is_Empty,
                       "record successful trash or replacement history");
               declare
                  Sidecar : constant String :=
                    (if Scenario = 3 then Join (Ada.Directories.Containing_Directory
                       (To_String (Paths.First_Element)), "original")
                     else Join (Root, "xdg/Trash/info/" & Ada.Directories.Simple_Name
                       (To_String (Paths.First_Element)) & ".trashinfo"));
                  File : Ada.Streams.Stream_IO.File_Type;
               begin
                  if Fault = 1 then
                     if Scenario = 3 then
                        Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Sidecar);
                        String'Output (Ada.Streams.Stream_IO.Stream (File), Redirected);
                        Ada.Streams.Stream_IO.Close (File);
                     else
                        Write_Binary_File (Sidecar, "[Trash Info]" & ASCII.LF & "Path=" & Redirected & ASCII.LF);
                     end if;
                  elsif Fault = 2 then
                     Write_Binary_File (Sidecar, "");
                  else
                     Ada.Directories.Delete_File (Sidecar);
                  end if;
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Success
                          and then File_Has_Bytes (Source, "original bytes")
                          and then not Ada.Directories.Exists (Redirected),
                          "Undo restores to its recorded destination despite changed, truncated or missing sidecars");
               end;
            end loop;
         end loop;
      end loop;
      Restore;
   exception
      when others => Restore; raise;
   end Test_Recorded_Restore_Targets;

   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Supplementary_Group return Interfaces.C.long_long
        with Import, Convention => C, External_Name => "files_test_supplementary_group";
      function Set_Group (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_set_copy_group";
      function Entry_Group (Path : System.Address) return Interfaces.C.long_long
        with Import, Convention => C, External_Name => "files_test_entry_group";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Expected : Interfaces.C.long_long;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
      procedure Prepare (Path : String) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Set_Group (Name'Address) = 1, "set a permitted supplementary owning group");
      end Prepare;
      procedure Check (Path : String) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Entry_Group (Name'Address) = Expected, "preserve the owning group without following links");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then return; end if;
      Expected := Supplementary_Group;
      if Expected < 0 then return; end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-move-ownership-"));
      Restore_Tmp;
      if Length (Remote) = 0 then return; end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "group protected bytes");
         Assert (Hostkit.Fs.Create_Link ("child", Join (Source, "link")), "prepare a symlink ownership fixture");
         Prepare (Source);
         Prepare (Join (Source, "child"));
         Prepare (Join (Source, "link"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (To_String (Remote), "source")), False, False));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "move the ownership tree across filesystems");
         for Cycle in 1 .. 2 loop
            Check (Join (To_String (Remote), "source"));
            Check (Join (To_String (Remote), "source/child"));
            Check (Join (To_String (Remote), "source/link"));
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Undo the ownership-preserving move");
            Check (Source);
            Check (Join (Source, "child"));
            Check (Join (Source, "link"));
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo the ownership-preserving move");
         end loop;
         Project_Tools.Files.Delete_Tree (Join (To_String (Remote), "source"));
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Move_Ownership;

   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else Ada.Environment_Variables.Clear ("TMPDIR"); end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then Project_Tools.Files.Delete_Tree (To_String (Remote)); end if;
      end Cleanup;
      procedure Check (Path : String) is
      begin
         Assert (Files.File_Identities.Token (Join (Path, "first")) /= ""
                 and then Files.File_Identities.Token (Join (Path, "first"))
                   = Files.File_Identities.Token (Join (Path, "sub/second"))
                 and then Files.File_Identities.Token (Join (Path, "first"))
                   /= Files.File_Identities.Token (Join (Path, "unrelated")),
                 "preserve hard links across child directories without merging files with equal bytes");
         Write_Binary_File (Join (Path, "first"), "changed through one link");
         Assert (File_Has_Bytes (Join (Path, "sub/second"), "changed through one link")
                 and then File_Has_Bytes (Join (Path, "unrelated"), "linked bytes"),
                 "writes through a copied link update only its actual hard-linked sibling");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then return; end if;
      Reset_Root;
      Ada.Directories.Create_Path (Join (Source, "sub"));
      Write_Binary_File (Join (Source, "first"), "linked bytes");
      Write_Binary_File (Join (Source, "unrelated"), "linked bytes");
      Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "sub/second")),
              "prepare a nested hard-link set");
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy the hard-link tree");
      Check (Join (Root, "copy"));
      Assert (File_Has_Bytes (Join (Source, "first"), "linked bytes"), "a copy's links are independent of the source");
      if not Ada.Directories.Exists ("/dev/shm") then return; end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-hard-link-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then return; end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source), "move the hard-link tree");
      Check (Join (To_String (Remote), "moved"));
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "a guarded history move preserves the hard-link topology");
      Check (Source);
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Hard_Link_Trees;

   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Set_Default_ACL (Path : System.Address; Owner : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_default_acl";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "copy");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");

      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then return; end if;
      for Background in Boolean loop
         for Owner in 0 .. 1 loop
            Reset_Root;
            Ada.Directories.Create_Directory (Parent);
            Write_Binary_File (Source, "copied bytes");
            declare
               Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Parent);
               Stage : Unbounded_String;
            begin
               Assert (Set_Default_ACL (Name'Address, Interfaces.C.int (Owner * 4)) = 1,
                       "prepare owner-none or owner-read-only default ACL on a writable destination");
               declare
                  Job       : Files.Process_Jobs.Session;
                  Transport : Files.Types.UString;
               begin
                  Ada.Environment_Variables.Set ("TMPDIR", Parent);
                  begin
                     Files.Process_Jobs.Reserve (Job);
                     Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
                     Assert
                       (Metadata_Mode_Of (To_String (Transport)) = 8#700#,
                        "job transport is owner-only from creation despite the inherited default ACL");
                     Write_Binary_File (Files.Process_Jobs.Path (Job, "request"), "private request");
                     Assert
                       (File_Has_Bytes (Files.Process_Jobs.Path (Job, "request"), "private request"),
                        "private transport payload remains usable after removing the inherited ACL");
                     Files.Process_Jobs.Reset (Job);
                     Assert
                       (not Ada.Directories.Exists (To_String (Transport)),
                        "private transport remains eligible for guarded cleanup");
                  exception
                     when others =>
                        Files.Process_Jobs.Reset (Job);
                        Restore_Tmp;
                        raise;
                  end;
                  Restore_Tmp;
               end;
               Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Parent));
               Assert (Metadata_Mode_Of (To_String (Stage)) = 8#700#,
                       "private staging restores owner access without granting peer access");
               Mutation := Files.File_System.Delete_Permanently (To_String (Stage));
               Assert (Mutation.Success, "remove the private staging probe");
            end;
            if Background then
               Load := Files.File_System.Load_Directory (Parent, Settings);
               Files.Model.Initialize (Model, Parent, Load.Items, Parent);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, True);
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
               Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success,
                       "background copy through a restrictive default ACL");
            else
               Mutation := Files.File_System.Copy_Tree (Source, Dest);
               Assert (Mutation.Success, "foreground copy through a restrictive default ACL");
            end if;
            Assert (File_Has_Bytes (Dest, "copied bytes") and then File_Has_Bytes (Source, "copied bytes"),
                    "copying succeeds without changing the source or the destination's ACL policy");
         end loop;
      end loop;
      Restore_Tmp;
   exception
      when others =>
         Restore_Tmp;
         raise;
   end Test_Staging_Default_ACL;

   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Child : constant String := Join (Source, "child");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      procedure Check_Source is
      begin
         Load := Files.File_System.Load_Directory (Child, Settings);
         Assert (Load.Success and then Load.Items.Is_Empty,
                 "refusing a descendant copy leaves no staging or recursive copies");
         Assert (File_Has_Bytes (Join (Source, "original"), "original bytes"), "the source is unchanged");
      end Check_Source;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Child);
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Join (Source, "original"), "original bytes");
         Mutation := Files.File_System.Copy_Tree (Source, Join (Child, "copy"));
         Assert (not Mutation.Success, "the copy operation itself refuses its own descendants");
         Check_Source;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "make the original copy");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "Undo the copy");
         Ada.Directories.Delete_Directory (Parent);
         Assert (Hostkit.Fs.Create_Link (Child, Parent), "redirect the destination parent into the source");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Assert (not Mutation.Success, "direct copies resolve destination-parent aliases");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Redo_Available (Model),
                 "Redo refuses a newly redirected descendant and retains retryable history");
         Check_Source;
         Assert (Hostkit.Fs.Delete_Link (Parent), "remove the destination alias");
         Ada.Directories.Create_Directory (Parent);
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then File_Has_Bytes (Join (Dest, "original"), "original bytes"),
                 "Redo can be retried after repairing the destination");
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Copy_Destination_Revalidation;

   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Remove (Path : String) is
         Result : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Created_Entry
           (Path, Files.File_Identities.Token (Path), Files.File_System.Tree_Revision (Path));
      begin
         Assert (Result.Success, "clean up the owned read-only tree");
      end Remove;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Ada.Directories.Exists (Source) then
            Remove (Source);
         end if;
         if Ada.Directories.Exists (Join (Root, "copy")) then
            Remove (Join (Root, "copy"));
         end if;
         if Length (Remote) > 0 then
            Remove (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String) is
      begin
         Assert (Metadata_Mode_Of (Path) = 8#555# and then Metadata_Mode_Of (Join (Path, "locked")) = 8#555#
                 and then Metadata_Mode_Of (Join (Path, "locked/child")) = 8#444#
                 and then File_Has_Bytes (Join (Path, "locked/child"), "read-only bytes"),
                 "publication and history preserve root, child directory and file permissions");
      end Check;
      procedure Check_Backups (Parent : String) is
         Listing : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Parent, Settings);
      begin
         for Item of Listing.Items loop
            declare
               Name : constant String := To_String (Item.Name);
            begin
               Assert (Name'Length < 16 or else Name (Name'First .. Name'First + 15) /= ".files-recovery-",
                       "committed moves remove their private read-only source backups");
            end;
         end loop;
      end Check_Backups;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-read-only-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Source, "locked"));
         Write_Binary_File (Join (Source, "locked/child"), "read-only bytes");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked/child"), 8#444#).Success,
                 "protect the source file");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked"), 8#555#).Success,
                 "protect the child source directory");
         Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "protect the source root");
         Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
         Assert (Mutation.Success, "publish a copy of a read-only directory");
         Check (Source);
         Check (Join (Root, "copy"));
         Remove (Join (Root, "copy"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To
              (Model, Settings, Paths, To_String (Remote), Files.File_System.Drop_Move));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Source),
                 "move a read-only root across filesystems");
         for Cycle in 1 .. 2 loop
            Check (Join (To_String (Remote), "source"));
            Check_Backups (Root);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Undo a read-only directory move");
            Check (Source);
            Check_Backups (To_String (Remote));
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo a read-only directory move");
         end loop;
         Remove (Join (To_String (Remote), "source"));
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Read_Only_Directory_Transfers;

   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Prepare (Path : System.Address; Mixed : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_sparse_prepare";
      function Verify (Path : System.Address; Mixed : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_sparse_check";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "sparse");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "sparse");
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String; Mixed : Interfaces.C.int) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Verify (Name'Address, Mixed) = 1,
                 "sparse transfers retain every byte and the trailing hole without allocating the logical size");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-sparse-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         return;
      end if;
      for Background in Boolean loop
         for Mixed in Interfaces.C.int range 0 .. 1 loop
            Reset_Root;
            Ada.Directories.Create_Directory (Parent);
            declare
               Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
            begin
               Assert (Prepare (Name'Address, Mixed) = 1, "prepare an all-hole or mixed sparse file");
            end;
            Check (Source, Mixed);
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Source));
            Step := Complete_Operation
              (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "copy a sparse file");
            Check (Dest, Mixed);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Undo a sparse copy");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo a sparse copy");
            Check (Dest, Mixed);
            Mutation := Files.File_System.Rename_Item (Dest, Join (To_String (Remote), "moved"));
            Assert (Mutation.Success, "move a sparse file across filesystems");
            Check (Join (To_String (Remote), "moved"), Mixed);
            Mutation := Files.File_System.Rename_Item
              (Join (To_String (Remote), "moved"), Dest,
               Files.File_Identities.Token (Join (To_String (Remote), "moved")));
            Assert (Mutation.Success, "restore a sparse file through the guarded history path");
            Check (Dest, Mixed);
            Check (Source, Mixed);
         end loop;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Sparse_Transfers;

   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String) is
         First : constant String := Join (Path, "first");
         Second : constant String := Join (Path, "sub/second");
         Target : Unbounded_String;
      begin
         Assert (Hostkit.Fs.Is_Link (First) and then Hostkit.Fs.Is_Link (Second)
                 and then Files.File_Identities.Token (First) /= ""
                 and then Files.File_Identities.Token (First) = Files.File_Identities.Token (Second),
                 "copied symbolic links retain their shared inode across child directories");
         Assert (Hostkit.Fs.Read_Link_Target (First, Target) and then To_String (Target) = "missing-target",
                 "hard-link preservation neither resolves nor alters a symbolic link target");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Join (Source, "sub"));
      Assert (Hostkit.Fs.Create_Link ("missing-target", Join (Source, "first")), "create a dangling symbolic link");
      Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "sub/second")),
              "create a hard link to the symbolic link itself");
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy a tree containing hard-linked dangling symbolic links");
      Check (Join (Root, "copy"));
      Assert (Files.File_Identities.Token (Join (Root, "copy/first"))
              /= Files.File_Identities.Token (Join (Source, "first")), "the copied set is independent of its source");
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-linked-symlinks-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source), "move the symbolic link set");
      Check (Join (To_String (Remote), "moved"));
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "restore the hard-linked symbolic link set through the guarded history path");
      Check (Source);
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Hard_Linked_Symbolic_Links;

   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "original");
      Backup : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Backend : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      procedure Cleanup is
      begin
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_FAULT");
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Backend);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
         Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      for Block_Rollback in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "original bytes");
         Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "prepare a read-only original");
         Ada.Environment_Variables.Set
           ("FILES_TEST_DIRECTORY_RESTORE_FAULT", Join (Root, ".files-recovery-1/payload"));
         if Block_Rollback then
            Ada.Environment_Variables.Set ("FILES_TEST_DIRECTORY_RESTORE_BLOCK", Source);
         end if;
         Mutation := Files.File_System.Preserve_For_Replace (Source, Backup);
         Assert (not Mutation.Success, "a failed mode restoration reports failure");
         if Block_Rollback then
            Assert (Length (Backup) > 0 and then File_Has_Bytes (Join (To_String (Backup), "child"),
                    "original bytes"), "a refused rollback retains the original in its private backup");
            Assert (File_Has_Bytes (Join (Source, "replacement"), "replacement bytes"),
                    "rollback never overwrites a replacement at the original pathname");
         else
            Assert (Length (Backup) = 0 and then File_Has_Bytes (Join (Source, "child"), "original bytes")
                    and then Metadata_Mode_Of (Source) = 8#555#,
                    "a failed restoration rolls back the complete original and its mode");
         end if;
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_FAULT");
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
         if Block_Rollback then
            Mutation := Files.File_System.Delete_Permanently (Source);
            Assert (Mutation.Success, "remove the test replacement before retrying recovery");
            Mutation := Files.File_System.Restore_From_Trash
              (To_String (Backup), Files.File_Identities.Token (To_String (Backup)), Source);
            Assert (Mutation.Success and then File_Has_Bytes (Join (Source, "child"), "original bytes")
                    and then Metadata_Mode_Of (Source) = 8#555#, "retry restores the original bytes and mode");
         end if;
         Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
      end loop;
      for Background in Boolean loop
         declare
            Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Model : Files.Model.Window_Model;
            Actions : Files.Paste.Resolved_Action_Vectors.Vector;
            Step : Files.Operations.Operation_Result;
            Copy_Source : constant String := Join (Root, "copy-source");
         begin
            Reset_Root;
            Ada.Directories.Create_Directory (Source);
            Ada.Directories.Create_Directory (Copy_Source);
            Write_Binary_File (Join (Source, "child"), "original bytes");
            Write_Binary_File (Join (Copy_Source, "child"), "replacement copy");
            Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "prepare paste replacement");
            Ada.Environment_Variables.Set
              ("FILES_TEST_DIRECTORY_RESTORE_FAULT", Join (Root, ".files-recovery-1/payload"));
            Ada.Environment_Variables.Set ("FILES_TEST_DIRECTORY_RESTORE_BLOCK", Source);
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Actions.Append (Files.Paste.Resolved_Action'
              (To_Unbounded_String (Copy_Source), To_Unbounded_String (Source), False, True));
            Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
            Step := Complete_Operation
              (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model),
                    "failed replacement retains guarded recovery history in foreground and background");
            Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_FAULT");
            Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
            Assert (Files.File_System.Delete_Permanently (Source).Success, "remove the test rollback obstruction");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then File_Has_Bytes (Join (Source, "child"), "original bytes")
                    and then Metadata_Mode_Of (Source) = 8#555#, "Undo recovers the retained original and mode");
            Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
         exception
            when others =>
               Files.Model.Clear_Paste_Execution (Model);
               Files.Refresh_Jobs.Cancel (Model);
               raise;
         end;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Recovery_Mode_Failure;

   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "changing");
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      procedure Reset_Fault with Import, Convention => C, External_Name => "files_test_fault_reset";
      type Saved_Environment is record
         Name : Unbounded_String;
         Present : Boolean;
         Value : Unbounded_String;
      end record;
      function Save (Name : String) return Saved_Environment is
        ((To_Unbounded_String (Name), Ada.Environment_Variables.Exists (Name),
          To_Unbounded_String (Ada.Environment_Variables.Value (Name, ""))));
      Saved : constant array (Positive range <>) of Saved_Environment :=
        (Save ("TMPDIR"), Save ("XDG_DATA_HOME"), Save ("FILES_TRASH_BACKEND"));
      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_TRIGGER");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_SOURCE");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_FAULT");
         for Item of Saved loop
            if Item.Present then
               Ada.Environment_Variables.Set (To_String (Item.Name), To_String (Item.Value));
            else
               Ada.Environment_Variables.Clear (To_String (Item.Name));
            end if;
         end loop;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-trash-source-"));
      if Saved (1).Present then
         Ada.Environment_Variables.Set ("TMPDIR", To_String (Saved (1).Value));
      else
         Ada.Environment_Variables.Clear ("TMPDIR");
      end if;
      Assert (Length (Remote) > 0, "create an isolated cross-filesystem trash fixture");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (To_String (Remote), "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set
        ("FILES_TEST_TRASH_TRIGGER", Join (To_String (Remote), "data/Trash/files/.files-work-"));
      Ada.Environment_Variables.Set ("FILES_TEST_TRASH_SOURCE", Source);
      for Background in Boolean loop
         for Fault in 1 .. 3 loop
            Reset_Root;
            if Fault = 3 then
               Ada.Directories.Create_Directory (Source);
               Write_Binary_File (Join (Source, "child"), "old bytes");
               Write_Binary_File (Join (Source, "other"), "untouched bytes");
            else
               Write_Binary_File (Source, "old bytes");
            end if;
            Ada.Environment_Variables.Set
              ("FILES_TEST_TRASH_FAULT", (if Fault = 1 then "edit" elsif Fault = 2 then "replace" else "folder"));
            Reset_Fault;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Select_All_Visible (Model);
            Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed,
                    "trash refuses removal when its source changes after copying");
            Assert (File_Has_Bytes ((if Fault = 3 then Join (Source, "child") else Source), "new edits"),
                    "trash retains concurrent source edits or replacements");
            if Fault = 2 then
               Assert (File_Has_Bytes (Source & ".saved", "old bytes"), "the replaced original remains untouched");
            elsif Fault = 3 then
               Assert (File_Has_Bytes (Join (Source, "other"), "untouched bytes"),
                       "refused trash never partially deletes a source tree");
            end if;
            Assert (not Files.Model.Undo_Available (Model), "a rolled-back trash copy records no deletion history");
            Assert (not Ada.Directories.Exists (Join (To_String (Remote), "data/Trash/files/changing"))
                    and then not Ada.Directories.Exists
                      (Join (To_String (Remote), "data/Trash/info/changing.trashinfo")),
                    "refused source removal rolls back the copied trash payload and sidecar");
         end loop;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Trash_Source_Verification;

   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target : constant String := Join (Root, "target");
      Link : constant String := Join (Root, "link");
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Assert (Hostkit.Fs.Create_Link (Target, Link), "create a dangling symbolic link");
         Mutation := Files.File_System.Create_Empty_File (Link);
         Assert (not Mutation.Success and then Hostkit.Fs.Is_Link (Link)
                 and then not Ada.Directories.Exists (Target), "creation preserves a dangling link and its target");
         Write_Binary_File (Target, "existing bytes");
         Mutation := Files.File_System.Create_Empty_File (Link);
         Assert (not Mutation.Success and then File_Has_Bytes (Target, "existing bytes"),
                 "creation preserves a live symbolic link target");
      else
         Write_Binary_File (Target, "existing bytes");
      end if;
      Mutation := Files.File_System.Create_Empty_File (Target);
      Assert (not Mutation.Success and then File_Has_Bytes (Target, "existing bytes"),
              "creation never truncates an existing regular file");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "new"));
      Assert (Mutation.Success and then Ada.Directories.Size (Join (Root, "new")) = 0,
              "exclusive creation still creates an empty new file");
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         declare
            Parent : constant String := Join (Root, "read-only-parent");
            User_Id, Group_Id : Natural;
            Available : Boolean;
         begin
            Ada.Directories.Create_Directory (Parent);
            Files.File_System.Ownership_Of (Parent, User_Id, Group_Id, Available);
            if Available and then User_Id /= 0 then
               Assert (Files.File_System.Set_Permissions (Parent, 8#555#).Success, "prepare a read-only parent");
               Mutation := Files.File_System.Create_Empty_File (Join (Parent, "child"));
               Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.create"
                       and then not Ada.Directories.Exists (Join (Parent, "child")),
                       "a creation access failure reports creation failure without claiming a collision");
            end if;
            Mutation := Files.File_System.Set_Permissions (Parent, 8#755#);
         exception
            when others =>
               Mutation := Files.File_System.Set_Permissions (Parent, 8#755#);
               raise;
         end;
      end if;
   end Test_Exclusive_New_Files;

   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "copy");
      Leaf : Unbounded_String;
      Relative : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load : Files.File_System.Directory_Load_Result;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      for Depth in 1 .. 3 loop
         Reset_Root;
         Relative := Null_Unbounded_String;
         Leaf := To_Unbounded_String (Source);
         Ada.Directories.Create_Directory (Source);
         for N in 1 .. (if Depth = 1 then 128 elsif Depth = 2 then 256 else 1_025) loop
            Append (Leaf, "/d");
            Append (Relative, "/d");
            Ada.Directories.Create_Directory (To_String (Leaf));
         end loop;
         Write_Binary_File (Join (To_String (Leaf), "child"), "deep bytes");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         if Depth < 3 then
            Assert (Mutation.Success and then File_Has_Bytes (Dest & To_String (Relative) & "/child", "deep bytes"),
                    "copying a valid deep directory tree completes without a stack overflow");
         else
            Assert (not Mutation.Success and then not Ada.Directories.Exists (Dest),
                    "exceeding the traversal depth cap fails without publishing an incomplete copy");
         end if;
         Assert (File_Has_Bytes (Join (To_String (Leaf), "child"), "deep bytes"), "deep copies preserve their source");
         Load := Files.File_System.Load_Directory (Root, Settings);
         for Item of Load.Items loop
            Assert (Ada.Strings.Fixed.Index (To_String (Item.Name), ".files-work-") /= 1,
                    "deep copy success or refusal leaves no private staging tree");
         end loop;
      end loop;
   end Test_Deep_Tree_Copy;

   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Step : Files.Operations.Operation_Result;
      First_Stamp : GNAT.OS_Lib.OS_Time;
      First_Revision : Unbounded_String;
      procedure Check is
      begin
         Assert (Files.File_Identities.Token (Join (Parent, "first")) /= ""
                 and then Files.File_Identities.Token (Join (Parent, "first")) =
                   Files.File_Identities.Token (Join (Parent, "second")),
                 "separately selected roots retain hard links");
         Assert (Files.File_Identities.Token (Join (Parent, "first")) /=
                   Files.File_Identities.Token (Join (Source, "first"))
                 and then Files.File_Identities.Token (Join (Parent, "first")) /=
                   Files.File_Identities.Token (Join (Parent, "third")),
                 "the copied family is independent of its source and unrelated identical files");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Join (Source, "first"), "shared bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "first"), GNAT.OS_Lib.Current_Time);
         Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "second")),
                 "prepare two selected roots sharing an inode");
         Write_Binary_File (Join (Source, "third"), "shared bytes");
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Join (Source, "first")));
         Paths.Append (To_Unbounded_String (Join (Source, "second")));
         Paths.Append (To_Unbounded_String (Join (Source, "third")));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "copy a hard-link family as separate roots");
         Check;
         Write_Binary_File (Join (Parent, "first"), "copied edit");
         Assert (File_Has_Bytes (Join (Parent, "second"), "copied edit")
                 and then File_Has_Bytes (Join (Source, "first"), "shared bytes")
                 and then File_Has_Bytes (Join (Parent, "third"), "shared bytes"),
                 "editing a copied alias affects only its copied family");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Join (Parent, "first"), "copied edit")
                 and then Files.Model.Undo_Available (Model),
                 "Undo keeps an edited copied hard-link family");
         Write_Binary_File (Join (Parent, "first"), "shared bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Parent, "first"), GNAT.OS_Lib.File_Time_Stamp (Join (Source, "first")));
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success,
                 "restoring copied bytes permits the hard-link batch Undo");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "Redo the copied hard-link batch");
         Check;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Write_Binary_File (Join (Parent, "second"), "unrelated replacement");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Join (Parent, "second"), "unrelated replacement"),
                 "partial Redo retains completed copies and refuses unrelated replacements");
         Ada.Directories.Delete_File (Join (Parent, "second"));
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "retry a partially completed hard-link Redo");
         Check;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Write_Binary_File (Join (Parent, "second"), "retry obstruction");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed,
                 "prepare another partially completed hard-link Redo");
         First_Stamp := GNAT.OS_Lib.File_Time_Stamp (Join (Parent, "first"));
         First_Revision := To_Unbounded_String
           (Files.File_Identities.Revision (Join (Parent, "first"), False));
         Write_Binary_File (Join (Parent, "first"), "altered byte");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Parent, "first"), First_Stamp);
         Assert
           (Files.File_Identities.Revision (Join (Parent, "first"), False) = To_String (First_Revision),
            "the regression edit preserves every field in the metadata-only revision");
         Ada.Directories.Delete_File (Join (Parent, "second"));
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Join (Parent, "first"), "altered byte")
                 and then not Ada.Directories.Exists (Join (Parent, "second")),
                 "a retry refuses a same-size edited copy even when its modification time is restored");
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Batch_Hard_Link_Copy;

   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Hidden, Visible : Unbounded_String;
      Had_XDG : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Old_XDG : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Backend : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      procedure Restore is
      begin
         if Had_XDG then Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_XDG);
         else Ada.Environment_Variables.Clear ("XDG_DATA_HOME"); end if;
         if Had_Backend then Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Backend);
         else Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND"); end if;
      end Restore;
   begin
      for Background in Boolean loop
         for Show_Hidden in Boolean loop
            Reset_Root;
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
            Write_Binary_File (Join (Root, ".hidden"), "hidden bytes");
            Write_Binary_File (Join (Root, "visible"), "visible bytes");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, ".hidden"), Hidden);
            Assert (Mutation.Success, "trash hidden payload");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, "visible"), Visible);
            Assert (Mutation.Success, "trash visible payload");
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Settings.Show_Hidden_Files := Show_Hidden;
            Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (To_String (Hidden))
                    and then not Ada.Directories.Exists (To_String (Visible))
                    and then not Ada.Directories.Exists
                      (Join (Join (Join (Join (Root, "xdg"), "Trash"), "info"), ".hidden.trashinfo")),
                    "Empty Trash purges hidden and visible payloads and hidden restore metadata");
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Restore; Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Empty_Trash_Hidden;

   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Child : Unbounded_String;
      Search : Files.File_System.Recursive_Search_Result;
   begin
      Reset_Root;
      Child := To_Unbounded_String (Root);
      for Level in 1 .. 66 loop
         Append (Child, "/d");
         Ada.Directories.Create_Directory (To_String (Child));
      end loop;
      Write_Binary_File (Join (To_String (Child), "needle.txt"), "needle");
      for Background in Boolean loop
         for Contents in Boolean loop
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Filter (Model, "needle");
            Files.Model.Set_Background_Transfers (Model, Background);
            Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                     else Files.Operations.Run_Recursive_Search (Model, Settings));
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then To_String (Step.Error_Key) = "error.search.failed"
                    and then Files.Model.Item_Count (Model) = 1
                    and then not Files.Model.Search_Results_Are_Active (Model),
                    "a skipped deep subtree is a failed search, preserving the prior listing");
         end loop;
      end loop;
      Reset_Root;
      Write_Binary_File (Join (Root, "needle-a.txt"), "needle");
      Search := Files.File_System.Search_Recursive (Root, "needle", Settings, Max_Items => 1);
      Assert (Search.Success and then Natural (Search.Items.Length) = 1,
              "an exact final match limit is complete when nothing remains to scan");
      Write_Binary_File (Join (Root, "needle-b.txt"), "needle");
      Search := Files.File_System.Search_Recursive (Root, "needle", Settings, Max_Items => 1);
      Assert (not Search.Success and then To_String (Search.Error_Key) = "error.search.failed",
              "an additional skipped entry makes the search incomplete");
      for Background in Boolean loop
         for Oversized in Boolean loop
            Reset_Root;
            declare
               Bytes : String (1 .. 64 * 1024 + (if Oversized then 1 else 0)) := [others => 'a'];
            begin
               Bytes (Bytes'Last - 5 .. Bytes'Last) := "needle";
               Write_Binary_File (Join (Root, "large.txt"), Bytes);
            end;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Filter (Model, "needle");
            Files.Model.Set_Background_Transfers (Model, Background);
            Step := Complete_Operation (Model, Settings, Files.Operations.Run_Content_Search (Model, Settings));
            Assert (Step.Status = (if Oversized then Files.Operations.Operation_Failed
                                   else Files.Operations.Operation_Success)
                    and then (if Oversized then To_String (Step.Error_Key) = "error.search.failed"
                              else Files.Model.Visible_Count (Model) = 1),
                    "content reads distinguish a complete byte boundary from omitted bytes in helpers too");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); raise;
   end Test_Search_Limit_Errors;

   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Source_Parent : constant String := Join (Root, "source");
      Destination : constant String := Join (Root, "destination");
      Old_XDG : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Had_XDG : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      procedure Restore is
      begin
         if Ada.Directories.Exists (Source_Parent) then
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#755#);
         end if;
         if Had_XDG then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_XDG);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
      end Restore;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      for Background in Boolean loop
         for Replace in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Directory (Source_Parent);
            Ada.Directories.Create_Directory (Destination);
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
            Write_Binary_File (Join (Source_Parent, "item.txt"), "source bytes");
            if Replace then
               Write_Binary_File (Join (Destination, "item.txt"), "original bytes");
            end if;
            Load := Files.File_System.Load_Directory (Destination, Settings);
            Files.Model.Initialize (Model, Destination, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Sources.Clear;
            Sources.Append (To_Unbounded_String (Join (Source_Parent, "item.txt")));
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#555#);
            Assert (Mutation.Success, "deny source unlink and rename");
            Step := Files.Operations.Begin_Paste
              (Model, Settings, Sources, Files.File_System.Drop_Move, False);
            if Replace then
               Step := Files.Operations.Resolve_Paste_Conflict
                 (Model, Settings, Files.Operations.Choice_Replace, True);
            end if;
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#755#);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then File_Has_Bytes (Join (Source_Parent, "item.txt"), "source bytes")
                    and then not Files.Model.Undo_Available (Model),
                    "a refused move leaves its source intact and no unusable Undo entry");
            Assert ((if Replace then File_Has_Bytes (Join (Destination, "item.txt"), "original bytes")
                     else not Ada.Directories.Exists (Join (Destination, "item.txt"))),
                    "the published copy is removed and a replaced destination is restored");
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Restore;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Failed_Move_Rollback;

   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Outcome : Files.Controller.Controller_Result;
      Revision : Natural;
   begin
      for Contents in Boolean loop
         for Stale in Boolean loop
            Reset_Root;
            Write_Binary_File (Join (Root, "alpha.txt"), "alpha bytes");
            Write_Binary_File (Join (Root, "beta.txt"), "beta bytes");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Background_Transfers (Model, True);
            Files.Model.Set_Filter (Model, "alpha");
            Files.Model.Focus_Filter_Input (Model);
            Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                     else Files.Operations.Run_Recursive_Search (Model, Settings));
            Revision := Files.Model.Revision (Model);
            Outcome := Files.Controller.Append_Focused_Text (Model, "x");
            Assert (Outcome.Status = Files.Controller.Controller_Ignored
                    and then Files.Model.Filter_Text (Model) = "alpha"
                    and then Files.Model.Revision (Model) = Revision,
                    "native character input cannot edit the active search snapshot");
            if Stale then
               Files.Model.Set_Filter (Model, "beta");
            end if;
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Files.Model.Search_Results_Are_Active (Model) = not Stale
                    and then Files.Model.Item_Count (Model) = (if Stale then 2 else 1),
                    "changed queries discard old outcomes while unchanged searches apply");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); raise;
   end Test_Search_Input_Snapshot;

   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Denied : Unbounded_String;
      Read_Ok : Boolean;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         return;
      end if;
      for Background in Boolean loop
         for Contents in Boolean loop
            for Case_Id in 1 .. (if Contents then 3 else 2) loop
               Reset_Root;
               Ada.Directories.Create_Directory (Join (Root, "sub"));
               Write_Binary_File (Join (Root, "needle.txt"), "needle bytes");
               Write_Binary_File (Join (Join (Root, "sub"), "needle.txt"), "needle bytes");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Set_Background_Transfers (Model, Background);
               Files.Model.Set_Filter (Model, "needle");
               Denied := To_Unbounded_String
                 ((case Case_Id is when 1 => Root, when 2 => Join (Root, "sub"),
                   when others => Join (Root, "needle.txt")));
               Mutation := Files.File_System.Set_Permissions (To_String (Denied), 0);
               Assert (Mutation.Success, "make the search input unreadable");
               Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                        else Files.Operations.Run_Recursive_Search (Model, Settings));
               Step := Complete_Operation (Model, Settings, Step);
               Mutation := Files.File_System.Set_Permissions (To_String (Denied), 8#755#);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then Files.Model.Item_Count (Model) = 2
                       and then not Files.Model.Search_Results_Are_Active (Model)
                       and then To_String (Step.Error_Key) =
                         (if Case_Id = 1 then "error.directory.load" else "error.search.failed"),
                       "read failures preserve the listing and report an error instead of partial success");
            end loop;
         end loop;
      end loop;
      Write_Binary_File (Join (Root, "empty.txt"), "");
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           (Join (Root, "empty.txt"), 100, Read_Ok);
      begin
         Assert (Read_Ok and then Text = "", "an empty readable file is a successful read");
      end;
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           (Join (Root, "missing.txt"), 100, Read_Ok);
      begin
         Assert (not Read_Ok and then Text = "", "an open failure is distinct from an empty file");
      end;
   exception
      when others =>
         if Length (Denied) > 0 then
            Mutation := Files.File_System.Set_Permissions (To_String (Denied), 8#755#);
         end if;
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Search_Read_Errors;

   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Step : Files.Operations.Operation_Result;
      Revision : Natural;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Write_Binary_File (Join (Root, "b.txt"), "b bytes");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "a.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_End, Guikit.Input.No_Modifiers, 16, Routed);
      Assert (Files.Model.Selected_Name (Model) = "b.txt"
              and then Files.Model.Selected_Item (Model).Filetype_Extra_Loaded
              and then Length (Files.Model.Selected_Item (Model).Filetype_Extra) > 0,
              "keyboard selection populates details for the new selection");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Assert (Files.Model.Selected_Item (Model).Filetype_Extra_Loaded
              and then Length (Files.Model.Selected_Item (Model).Filetype_Extra) > 0,
              "completed refresh repopulates the selected item's details");
      Revision := Files.Model.Revision (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Assert (Revision = Files.Model.Revision (Model), "completed details remain cached");
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Info_Selection_Completion;

   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Status : Zlib.Status_Code;
      Prior : Files.Types.String_Vectors.Vector;
      Created : Files.Types.String_Vectors.Vector;
   begin
      for Background in Boolean loop
         for Extracting in Boolean loop
            for Partial in Boolean loop
               Reset_Root;
               Write_Binary_File (Join (Root, "a.txt"), "a bytes");
               Write_Binary_File (Join (Root, "b.txt"), "b bytes");
               Write_Binary_File (Join (Root, "prior"), "prior action");
               if Extracting then
                  Zlib.ZIP_File (Join (Root, "a.txt"), Join (Root, "a.zip"), "a.txt", Status => Status);
                  Assert (Status = Zlib.Ok, "prepare first archive");
                  Zlib.ZIP_File (Join (Root, "b.txt"), Join (Root, "b.zip"), "b.txt", Status => Status);
                  Assert (Status = Zlib.Ok, "prepare second archive");
               end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Prior.Clear;
               Prior.Append (To_Unbounded_String (Join (Root, "prior")));
               Files.Model.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Prior, Files.Types.String_Vectors.Empty_Vector,
                  Redoable => False);
               Files.Model.Set_Filter (Model, (if Extracting then ".zip" else ".txt"));
               Files.Model.Select_All_Visible (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Partial then
                  if Extracting then
                     Write_Binary_File (Join (Root, "b.zip"), "invalid archive");
                  else
                     Ada.Directories.Delete_File (Join (Root, "b.txt"));
                  end if;
               end if;
               Step := Complete_Operation
                 (Model, Settings, (if Extracting then Files.Operations.Extract_Selected (Model, Settings)
                                    else Files.Operations.Duplicate_Selected (Model, Settings)));
               Await_View (Model, Settings);
               Created := Files.Model.Undo_From_Paths (Model);
               Assert (Step.Status = (if Partial then Files.Operations.Operation_Failed
                                     else Files.Operations.Operation_Success)
                       and then Natural (Files.Model.Undo_History (Model).Length) = 2
                       and then Natural (Created.Length) = (if Partial then 1 else 2),
                       "successful and partial batches add one action without replacing prior history");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               for Path of Created loop
                  Assert (not Ada.Directories.Exists (To_String (Path)),
                          "one Undo removes every committed batch member");
               end loop;
               declare
                  Replacement : constant String := To_String (Created.First_Element);
                  Keep : constant String := (if Extracting then Join (Replacement, "keep.txt") else Replacement);
               begin
                  if Extracting then
                     Ada.Directories.Create_Directory (Replacement);
                  end if;
                  Write_Binary_File (Keep, "unrelated replacement");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Success
                          and then not Files.Model.Undo_Available (Model)
                          and then not Ada.Directories.Exists (Join (Root, "prior"))
                          and then File_Has_Bytes (Keep, "unrelated replacement"),
                          "the next Undo reaches the prior action and never touches a recreated batch path");
               end;
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Batch_Creation_History;

   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Outcome : Files.Controller.Controller_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Finished, Cancelled : Boolean;
   begin
      for Ready in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Join (Root, "inbox"));
         Write_Binary_File (Join (Root, "original.txt"), "original");
         Write_Binary_File (Join (Join (Root, "inbox"), "incoming.txt"), "incoming");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Select_Name (Model, "original.txt");
         Files.Model.Set_Background_Transfers (Model, True);
         Step := Files.Operations.Duplicate_Selected (Model, Settings);
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
            Revision : constant Natural := Files.Model.Revision (Model);
         begin
            if Ready then
               for Attempt in 1 .. 5_000 loop
                  Files.Process_Jobs.Poll (Job, Finished, Cancelled);
                  exit when Finished;
                  delay 0.001;
               end loop;
               Assert (Finished and then not Cancelled, "the first job committed before a drop arrives");
            end if;
            Sources.Clear;
            Sources.Append (To_Unbounded_String (Join (Join (Root, "inbox"), "incoming.txt")));
            Outcome := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
            Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
            Assert (Outcome.Status = Files.Controller.Controller_Ignored
                    and then Step.Status = Files.Operations.Operation_Disabled
                    and then Files.Model.Revision (Model) = Revision
                    and then Files.Process_Jobs.Path (Files.Model.Background_Operation (Model), "") =
                             Files.Process_Jobs.Path (Job, ""),
                    "controller and direct paste calls preserve the active job and its revision");
         end;
         Step := Complete_Operation (Model, Settings, Step);
         Assert (Files.Model.Undo_Available (Model) and then not Ada.Directories.Exists (Join (Root, "incoming.txt")),
                 "blocked drops leave the original job's committed history intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (not Ada.Directories.Exists (Join (Root, "original (copy).txt"))
                 and then File_Has_Bytes (Join (Root, "original.txt"), "original"),
                 "the original job remains undoable after a blocked drop");
      end loop;
      Write_Binary_File (Join (Root, "incoming.txt"), "existing destination");
      Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "prepare a collision dialog");
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Outcome := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
         Assert (Outcome.Status = Files.Controller.Controller_Ignored
                 and then Step.Status = Files.Operations.Operation_Disabled
                 and then Files.Model.Revision (Model) = Revision
                 and then Files.Model.Paste_Conflict_Is_Active (Model),
                 "a second drop cannot reset an unresolved collision dialog");
      end;
      Files.Model.Clear_Paste_Conflict (Model);
   exception
      when others =>
         Files.Model.Clear_Paste_Conflict (Model);
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Drops_While_Busy;

   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Applied : Boolean;
      Revision : Natural;
   begin
      for Unsupported in Boolean loop
         Reset_Root;
         Write_Binary_File (Join (Root, "selected.bin"), "binary data");
         Write_Binary_File (Join (Root, "selected.txt"), "text data");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, True);
         Select_Name (Model, (if Unsupported then "selected.bin" else "selected.txt"));
         Files.Model.Toggle_Info_Pane (Model);
         Write_Binary_File (Join (Root, "new.txt"), "new");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "",
            (Kind => Files.Events.Command_Input_Action, Command => Files.Commands.Refresh_Directory_Command,
             others => <>), 16, Guikit.Input.No_Modifiers, Routed);
         Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)), "the refresh is scheduled");
         Applied := False;
         for Attempt in 1 .. 5_000 loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
            delay 0.001;
         end loop;
         Assert (Applied and then Files.Model.Item_Count (Model) = 3,
                 "info metadata cannot invalidate a manual refresh started by the same action");
         Files.Model.Ensure_Selected_Item_Extra (Model);
         Assert (Files.Model.Selected_Item (Model).Filetype_Extra_Loaded, "even an empty metadata result is cached");
         Revision := Files.Model.Revision (Model);
         for Attempt in 1 .. 20 loop
            Files.Model.Ensure_Selected_Item_Extra (Model);
         end loop;
         Assert (Files.Model.Revision (Model) = Revision, "cached metadata does not repeatedly change the revision");
      end loop;
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Info_Refresh;

   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Status : Zlib.Status_Code;
      Archive : Unbounded_String;
      Verify : constant String := Join (Root, "verify");
   begin
      for Background in Boolean loop
         for Format in Files.Operations.Archive_Format loop
            for Empty_Only in Boolean loop
               Reset_Root;
               Ada.Directories.Create_Path (Join (Join (Join (Root, "bag"), "empty"), "nested"));
               Ada.Directories.Create_Path (Join (Join (Root, "bag"), "other empty"));
               if not Empty_Only then
                  Write_Binary_File (Join (Join (Root, "bag"), "data.txt"), "payload bytes");
               end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "bag");
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Format));
               Archive := To_Unbounded_String
                 (Join (Root, (if Format = Files.Operations.Zip_Archive then "bag.zip" else "bag.7z")));
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Ada.Directories.Exists (To_String (Archive)),
                       "mixed and directory-only selections produce successful ZIP and 7z archives");
               Ada.Directories.Create_Directory (Verify);
               Zlib.Extract_Archive_File_To_Directory (To_String (Archive), Verify, "", Status);
               Assert (Status = Zlib.Ok
                       and then Ada.Directories.Exists (Join (Join (Join (Verify, "bag"), "empty"), "nested"))
                       and then Ada.Directories.Exists (Join (Join (Verify, "bag"), "other empty"))
                       and then (Empty_Only or else
                                 File_Has_Bytes (Join (Join (Verify, "bag"), "data.txt"), "payload bytes")),
                       "round-trip extraction preserves every empty directory and file payload");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Ada.Directories.Exists (To_String (Archive))
                       and then Ada.Directories.Exists (Join (Join (Join (Root, "bag"), "empty"), "nested")),
                       "Undo removes the archive while preserving its source directories");
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Empty_Archive_Directories;

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
   begin
      for Background in Boolean loop
         Reset_Root;
         Write_Binary_File (Join (Root, "a.txt"), "a bytes");
         Write_Binary_File (Join (Root, "b.txt"), "b bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Select_All_Visible (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Ada.Directories.Delete_File (Join (Root, "b.txt"));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then To_String (Step.Error_Key) = "error.compress.failed"
                 and then not Ada.Directories.Exists (Join (Root, "a.zip"))
                 and then not Files.Model.Undo_Available (Model),
                 "a missing selected source cannot produce a successful incomplete archive or Undo entry");
         Await_View (Model, Settings);
      end loop;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Root, "one"));
         Ada.Directories.Create_Path (Join (Root, "two"));
         Write_Binary_File (Join (Join (Root, "one"), "same.txt"), "first source");
         Write_Binary_File (Join (Join (Root, "two"), "same.txt"), "second source");
         Settings := Files.Settings.Default_Settings;
         Files.Settings.Note_Recent (Settings, Join (Join (Root, "one"), "same.txt"));
         Files.Settings.Note_Recent (Settings, Join (Join (Root, "two"), "same.txt"));
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Files.Operations.Navigate_Recent (Model, Settings);
         Files.Model.Select_All_Visible (Model);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then not Ada.Directories.Exists (Join (Join (Root, "two"), "same.zip")),
                 "duplicate archive entry names cannot overwrite or silently replace a selected input");
         Await_View (Model, Settings);
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Archive_Completeness;

   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Original_Cwd : constant String := Ada.Directories.Current_Directory;
      Settings : Files.Settings.Settings_Model;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Archives : Files.File_System.Item_Vectors.Vector;
      Loaded : Files.File_System.Item_Load_Result;
      One : constant String := Join (Root, "one");
      Two : constant String := Join (Root, "two");
      Cwd : constant String := Join (Root, "cwd");
      Zip : constant String := Join (Two, "note.zip");
      Copy_Zip : constant String := Join (One, "copy.zip");
   begin
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (One);
         Ada.Directories.Create_Path (Two);
         Ada.Directories.Create_Path (Cwd);
         Write_Binary_File (Join (One, "report.txt"), "report bytes");
         Write_Binary_File (Join (Two, "note.txt"), "note bytes");
         Write_Binary_File (Join (Cwd, "keep"), "working directory bytes");
         Settings := Files.Settings.Default_Settings;
         Files.Settings.Note_Recent (Settings, Join (One, "report.txt"));
         Files.Settings.Note_Recent (Settings, Join (Two, "note.txt"));
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Files.Operations.Navigate_Recent (Model, Settings);
         Files.Model.Select_All_Visible (Model);
         Ada.Directories.Set_Directory (Cwd);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operations.Operation_Success and then Ada.Directories.Exists (Zip)
                 and then Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 2,
                 "Recent compression publishes beside the first selected source and preserves the complete view");
         Mutation := Files.File_System.Copy_Tree (Zip, Copy_Zip);
         Assert (Mutation.Success, "prepare an archive in another source directory");
         Ada.Directories.Create_Path (Join (Two, "note"));
         Files.Settings.Note_Recent (Settings, Zip);
         Files.Settings.Note_Recent (Settings, Copy_Zip);
         Archives.Clear;
         Loaded := Files.File_System.Load_Item (Zip, Settings);
         Archives.Append (Loaded.Item);
         Loaded := Files.File_System.Load_Item (Copy_Zip, Settings);
         Archives.Append (Loaded.Item);
         Files.Model.Navigate_Recent (Model, Archives);
         Files.Model.Select_All_Visible (Model);
         Step := Complete_Operation (Model, Settings, Files.Operations.Extract_Selected (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success and then Files.Model.In_Recent_View (Model)
                 and then File_Has_Bytes (Join (Join (Two, "note (1)"), "note.txt"), "note bytes")
                 and then File_Has_Bytes (Join (Join (One, "copy"), "report.txt"), "report bytes")
                 and then not Ada.Directories.Exists (Join (Cwd, "note.zip"))
                 and then not Ada.Directories.Exists (Join (Cwd, "note"))
                 and then not Ada.Directories.Exists (Join (Cwd, "copy"))
                 and then File_Has_Bytes (Join (Cwd, "keep"), "working directory bytes"),
                 "each Recent archive extracts beside itself with collision handling and leaves CWD intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then not Ada.Directories.Exists (Join (Two, "note (1)"))
                 and then not Ada.Directories.Exists (Join (One, "copy"))
                 and then Ada.Directories.Exists (Join (Two, "note")) and then Ada.Directories.Exists (Zip),
                 "Undo removes only the newly extracted adjacent folders");
         Ada.Directories.Set_Directory (Original_Cwd);
      end loop;
   exception
      when others =>
         Ada.Directories.Set_Directory (Original_Cwd);
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Recent_Archive_Destinations;

   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model, Other : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Before : Ada.Calendar.Time;
      Folder : constant String := Join (Root, "folder");
      Marker : constant String := Join (Root, "size-started");
      Started : Unbounded_String;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_FOLDER_SIZES");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "");
      File : Ada.Text_IO.File_Type;
      Empty : Files.Process_Jobs.Session;
      Finished, Cancelled : Boolean;
      procedure Restore is
      begin
         Files.Model.Cancel_Folder_Scan (Model);
         Files.Model.Cancel_Folder_Scan (Other);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
         end if;
      end Restore;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_Binary_File (Join (Folder, "data"), "one");
      Write_Binary_File (Join (Root, "ordinary.txt"), "ordinary");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Initialize (Other, Root, Load.Items, Root);
      Select_Name (Model, "folder");
      Select_Name (Other, "ordinary.txt");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Files.Operations.Update_Folder_Size (Model, Settings);
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Marker);
         delay 0.001;
      end loop;
      Assert (Ada.Directories.Exists (Marker), "the first window's size helper reaches stalled reads");
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Marker);
      Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (File), "started"));
      Ada.Text_IO.Close (File);
      Before := Ada.Calendar.Clock;
      for Frame in 1 .. 50 loop
         Files.Operations.Update_Folder_Size (Other, Settings);
         Files.Model.Poll_Folder_Sizes (Other);
         Files.Operations.Update_Folder_Size (Model, Settings);
         Files.Model.Poll_Folder_Sizes (Model);
      end loop;
      Assert (Ada.Calendar.Clock - Before < 0.25 and then Files.Model.Folder_Scan_Is_Active (Model)
              and then Ada.Directories.Exists (To_String (Started)),
              "input and cancellation in another window cannot terminate or restart a stalled scan");
      Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
      Select_Name (Other, "folder");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in 1 .. 5_000 loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
         delay 0.001;
      end loop;
      Assert (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 3
              and then Files.Model.Folder_Scan_Is_Active (Model),
              "a surviving window measures normally while another window's scan remains stalled");
      Write_Binary_File (Join (Folder, "data"), "longer contents");
      Step := Files.Operations.Refresh (Other, Settings);
      Assert (not Files.Model.Folder_Size_Cached_For (Other, Folder), "a successful refresh discards stale totals");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in 1 .. 5_000 loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
         delay 0.001;
      end loop;
      Assert (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 15,
              "refresh remeasures descendant changes even when parent entries were unchanged");
      Files.Model.Cancel_Folder_Scan (Model);
      for Attempt in 1 .. 5_000 loop
         Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
         exit when not Ada.Directories.Exists (To_String (Started));
         delay 0.001;
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Started))
              and then Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 15,
              "closing the stalled window terminates only its measurement and preserves the other's cache");
      Files.Model.Set_Background_Transfers (Other, True);
      Step := Files.Operations.Refresh (Other, Settings);
      Files.Operations.Update_Folder_Size (Other, Settings);
      Files.Model.Poll_Folder_Sizes (Other);
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Other))
              and then not Files.Model.Folder_Scan_Is_Active (Other),
              "size results cannot invalidate a pending listing request by changing its captured revision");
      Await_View (Other, Settings);
      Assert (not Files.Model.Folder_Size_Cached_For (Other, Folder),
              "a completed background refresh also invalidates the prior size");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in 1 .. 5_000 loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
         delay 0.001;
      end loop;
      Assert (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 15,
              "measurement resumes normally after the asynchronous listing was applied");
      Restore;
   exception
      when others => Restore; raise;
   end Test_Window_Folder_Measurements;

   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Watch : Files.Refresh_Jobs.Watch_Session;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Before : Ada.Calendar.Time;
      Started : Unbounded_String;
      Paths, Sources : Files.Types.String_Vectors.Vector;
      Action : Files.Model.Undo_Entry;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_OPERATIONS");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "");
      Old_Xdg : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Prompt_Limit : constant Duration :=
        (if Hostkit.Host.Current = Hostkit.Host.Windows then 1.0 else 0.25);
      type Kind is (Trash_Job, Delete_Job, Restore_Job, Empty_Job, Undo_Job, Redo_Job);
      procedure Restore is
      begin
         Files.Application.Windows.Release_Window_Jobs (Model, Watch);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
         end if;
      end Restore;
   begin
      for Job_Kind in Kind loop
         Reset_Root;
         Write_Binary_File (Join (Root, "victim.txt"), "victim bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, True);
         Select_Name (Model, "victim.txt");
         Paths.Clear;
         Sources.Clear;
         Paths.Append (To_Unbounded_String (Join (Root, "victim.txt")));
         if Job_Kind = Undo_Job then
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Paths, Sources, Redoable => False);
         elsif Job_Kind = Redo_Job then
            Sources := Paths;
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Join (Root, "new-copy.txt")));
            Action := (Kind => Files.Model.Undo_Delete_Created, From => Paths, Forward => Sources,
                       Create_Kind => Files.Model.Create_Copy, others => <>);
            Files.Model.Push_Redo (Model, Action);
         end if;
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
         Before := Ada.Calendar.Clock;
         Step :=
           (case Job_Kind is
               when Trash_Job => Files.Operations.Delete_Selected (Model, Settings),
               when Delete_Job => Files.Operations.Delete_Selected_Permanently (Model, Settings),
               when Restore_Job => Files.Operations.Restore_Selected_From_Trash (Model, Settings),
               when Empty_Job => Files.Operations.Empty_Trash (Model, Settings),
               when Undo_Job => Files.Operations.Undo_Last (Model, Settings),
               when Redo_Job => Files.Operations.Redo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Calendar.Clock - Before < Prompt_Limit
                 and then Files.Model.Paste_Execution_Is_Active (Model),
                 "destructive and history commands launch promptly without filesystem work in the caller");
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
         begin
            Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
         end;
         for Attempt in 1 .. 5_000 loop
            exit when Ada.Directories.Exists (To_String (Started));
            delay 0.001;
         end loop;
         Assert (Ada.Directories.Exists (To_String (Started)), "the destructive helper reaches stalled work");
         if Job_Kind = Undo_Job then
            Files.Operations.Cancel_Paste_Execution (Model);
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
         else
            Before := Ada.Calendar.Clock;
            Files.Application.Windows.Release_Window_Jobs (Model, Watch);
            Assert (Ada.Calendar.Clock - Before < Prompt_Limit,
                    "window closure never joins a stalled destructive helper");
         end if;
         Assert (File_Has_Bytes (Join (Root, "victim.txt"), "victim bytes")
                 and then not Ada.Directories.Exists (Join (Root, "new-copy.txt"))
                 and then Files.Model.Undo_Available (Model) = (Job_Kind = Undo_Job)
                 and then Files.Model.Redo_Available (Model) = (Job_Kind = Redo_Job),
                 "cancellation before execution preserves source bytes and both history stacks");
         Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
      end loop;
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "private-trash"));
      Write_Binary_File (Join (Root, "victim.txt"), "victim bytes");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Clear_Undo (Model);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success and then Files.Model.Undo_Available (Model)
              and then not Ada.Directories.Exists (Join (Root, "victim.txt")),
              "background trash records complete Undo");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then File_Has_Bytes (Join (Root, "victim.txt"), "victim bytes"),
              "background Undo restores trash bytes");
      Select_Name (Model, "victim.txt");
      Ada.Directories.Delete_File (Join (Root, "victim.txt"));
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      for Index in 1 .. Files.Model.Item_Count (Model) loop
         Assert (Files.Model.Visible_Item (Model, Index).Name /= To_Unbounded_String ("victim.txt"),
                 "a failed destructive operation relists the vanished source without invalidating its own refresh");
      end loop;
      Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Last_Error_Key (Model) /= "",
              "the failed operation's error survives its successful background refresh");
      Write_Binary_File (Join (Root, "victim.txt"), "restorable bytes");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Paths := Files.Model.Undo_From_Paths (Model);
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Navigate_To (Model, Files.File_System.Trash_Files_Directory, Load.Items);
      Select_Name (Model, Ada.Directories.Simple_Name (To_String (Paths.First_Element)));
      Step := Complete_Operation (Model, Settings, Files.Operations.Restore_Selected_From_Trash (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then File_Has_Bytes (Join (Root, "victim.txt"), "restorable bytes"),
              "the background restore command restores the complete original");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected_Permanently (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (Join (Root, "victim.txt")),
              "background permanent deletion removes its selected source");
      Write_Binary_File (Join (Root, "victim.txt"), "empty trash bytes");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "victim.txt");
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Await_View (Model, Settings);
      Paths := Files.Model.Undo_From_Paths (Model);
      Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
      Await_View (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (To_String (Paths.First_Element)),
              "background empty trash purges only the private test trash backend");
      Files.Model.Set_Background_Transfers (Model, False);
      Files.Model.Clear_Undo (Model);
      Write_Binary_File (Join (Root, "checkpoint-target"), "preserve original bytes");
      Paths.Clear;
      Sources.Clear;
      Paths.Append (To_Unbounded_String (Join (Root, "checkpoint-target")));
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Paths, Sources, Redoable => False);
      Write_Binary_File (Join (Root, "blocked-transport"), "a file cannot hold a checkpoint");
      Files.Job_Context.Initialize (Join (Root, "blocked-transport"));
      Step := Files.Operations.Undo_Last (Model, Settings);
      Files.Job_Context.Initialize ("");
      Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
              and then File_Has_Bytes (Join (Root, "checkpoint-target"), "preserve original bytes"),
              "a checkpoint failure before mutation retains both the original and its retriable Undo action");
      Step := Files.Operations.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then not Ada.Directories.Exists (Join (Root, "checkpoint-target")),
              "Undo retries successfully once checkpoint transport is available");
      Restore;
   exception
      when others => Files.Job_Context.Initialize (""); Restore; raise;
   end Test_Destructive_Helper_Lifecycle;

   --  Folder sizes used by the info pane and selection total are requested from
   --  Files.Folder_Size. Selecting a folder must leave the recursive walk to the
   --  helper and publish the completed result on a later frame.
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;

      --  Drive the background scan to completion and publish it into the model,
      --  as the frame loop's Poll_All_Folder_Sizes would.
      procedure Drain_Into_Model is
         Path      : Ada.Strings.Unbounded.Unbounded_String;
         Result    : Files.File_System.Directory_Size_Result;
         Available : Boolean := False;
      begin
         loop
            Files.Model.Poll_Folder_Sizes (Model);
            Available := not Files.Model.Folder_Scan_Is_Active (Model);
            exit when Available or else not Files.Model.Folder_Scan_Is_Active (Model);
            delay 0.001;
         end loop;
      end Drain_Into_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "sub"));
      Write_File (Join (Join (Root, "sub"), "x.txt"), "hi");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "sub");
      Files.Model.Cancel_Folder_Scan (Model);
      declare
         Path      : constant String := To_String (Files.Model.Selected_Item (Model).Full_Path);
         Reference : constant Files.File_System.Directory_Size_Result :=
           Files.File_System.Directory_Size (Path);
      begin
         --  Selecting a folder requests its size (so the info pane and the bottom
         --  bar's total can count it), but the walk runs in a helper off the UI
         --  path: nothing is computed synchronously on the input.
         Files.Operations.Update_Folder_Size (Model, Settings);
         Assert (Files.Model.Folder_Scan_Is_Active (Model) and then Files.Model.Folder_Scan_Target (Model) = Path,
                 "selecting a folder requests its size");
         Assert (not Files.Model.Folder_Size_Cached_For (Model, Path),
                 "folder size is not computed synchronously on the input path");

         --  Advancing the background scan to completion publishes the
         --  measurement, which matches the synchronous reference.
         Drain_Into_Model;
         Assert (Files.Model.Folder_Size_Cached_For (Model, Path),
                 "folder size is published once the background scan finishes");
         declare
            Measured : constant Files.File_System.Directory_Size_Result :=
              Files.Model.Folder_Size_Value (Model, Path);
         begin
            Assert (Measured.Available = Reference.Available
                      and then Measured.Total_Bytes = Reference.Total_Bytes
                      and then Measured.File_Count = Reference.File_Count
                      and then Measured.Item_Count = Reference.Item_Count
                      and then Measured.Capped = Reference.Capped,
                    "background folder size matches Directory_Size");
         end;
      end;
   end Test_Folder_Size_Is_Lazy;

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
   procedure Test_Selection_Total_Counts_Folders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Dir_Path : constant String := Join (Root, "adir");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir_Path);
      Write_Binary_File (Join (Root, "afile.bin"), "0123456789");   --  10-byte file
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);                       --  folder + file
      Assert (Files.Model.Selected_Count (Model) = 2, "the folder and file are selected");

      --  Publish a measured folder size (as the background scan would), then the
      --  combined total must count it (folder 500 + file 10). Info pane stays closed.
      Files.Model.Set_Folder_Size
        (Model, Dir_Path, (Available => True, Total_Bytes => 500, others => <>));
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (not Snapshot.Info_Pane_Open, "the info pane is closed");
      Assert (Snapshot.Selection_Total_Bytes = 510,
              "the selection total counts the folder's recursive size plus the file");
      Assert (not Snapshot.Selection_Total_Pending,
              "the total is not pending once every selected folder is measured");
   end Test_Selection_Total_Counts_Folders;

   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Second   : constant String := Join (Root, "second");
      Branch   : constant String := Join (Root, "branch");
      Missing_Home : constant String := Join (Root, "missing-home");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Ada.Directories.Create_Path (Second);
      Ada.Directories.Create_Path (Branch);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (Second, "two.txt"));
      Write_File (Join (Branch, "branch.txt"));
      Load := Files.File_System.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, Missing_Home);
      Files.Model.Begin_Create_File (Model, "failed-home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed home load is reported");
      Assert (To_String (Result.Operation.Path) = Missing_Home, "failed home reports attempted home path");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.path.missing",
         "failed home reports path diagnostic");
      Assert (Files.Model.Current_Path (Model) = First, "failed home preserves current path");
      Assert (Files.Model.Item_Count (Model) = 1, "failed home preserves loaded items");
      Assert (Files.Model.Last_Error_Key (Model) = "error.path.missing", "failed home records path error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed home preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed home preserves rename state");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed home preserves command palette");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Files.Model.Begin_Create_File (Model, "home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "home load succeeds");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "home operation reports normalized home path");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "home clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "home clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "home clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "home clears command palette");
      Write_File (Join (First, "fresh.txt"));
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Scroll_Info_Pane (Model, Lines => 4);
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh operation succeeds");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "refresh operation reports current path");
      Assert (Files.Model.Item_Count (Model) = 2, "refresh loads newly created item");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "refresh clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "refresh clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "refresh clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "refresh clears command palette");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "refresh clears temporary selection");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "refresh resets info pane scroll");
      Files.Model.Select_Visible (Model, 1);
      Write_File (Join (First, "later.txt"));
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second refresh operation succeeds");
      Assert (Files.Model.Item_Count (Model) = 3, "second refresh loads later item");
      Assert (Files.Model.Selected_Count (Model) = 1, "refresh preserves the selection by name");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed refresh is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "failed refresh reports current path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "failed refresh preserves path");
      Assert (Files.Model.Item_Count (Model) = 3, "failed refresh preserves loaded items");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed refresh records load error");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed refresh preserves command palette");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));
      Write_File (Join (First, "later.txt"));

      Load := Files.File_System.Load_Directory (Second, Settings);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Navigate_To (Model, Second, Load.Items);
      Assert (Files.Model.Root_Count (Model) = 0, "direct navigation clears stale root selector entries");
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "back operation reloads target");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "back operation reports restored path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "back restores first path");
      Assert (Files.Model.Item_Count (Model) = 3, "back loads first path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "back clears rename focus");
      Files.Model.Begin_Create_File (Model, "forward-history-pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "forward operation reloads target");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Second),
         "forward operation reports restored path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Second), "forward restores second path");
      Assert (Files.Model.Item_Count (Model) = 1, "forward loads second path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "forward clears rename focus");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Begin_Create_File (Model, "failed-history-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed back reload is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "failed back reports attempted path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Second), "failed back rolls path back");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed back records load error");
      Assert (Files.Model.Can_Go_Back (Model), "failed back preserves back history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed back preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves rename state");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second back operation succeeds");
      Project_Tools.Files.Delete_Tree (Second);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "one-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed forward preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves normal rename state");
      Assert (Files.Model.Rename_Text (Model) = "one-renamed.txt", "failed forward preserves rename text");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "failed forward restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Begin_Create_File (Model, "failed-forward-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed forward reload is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Second),
         "failed forward reports attempted path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "failed forward rolls path back");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed forward records load error");
      Assert (Files.Model.Can_Go_Forward (Model), "failed forward preserves forward history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed forward preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves rename state");
      Ada.Directories.Create_Path (Second);
      Write_File (Join (Second, "two.txt"));
      Files.Model.Cancel_Create_File (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second forward operation succeeds");
      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "two-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed back preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves normal rename state");
      Assert (Files.Model.Rename_Text (Model) = "two-renamed.txt", "failed back preserves rename text");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "failed back restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_L, Ctrl);
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "Control+L focuses path for branch");
      Files.Controller.Replace_Focused_Text (Model, Branch);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "path input navigates to branch");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Branch),
         "branch path input reports normalized path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Branch), "branch navigation loads path");
      Assert (not Files.Model.Can_Go_Forward (Model), "new controller navigation clears forward history");
      Assert (Files.Model.Item_Count (Model) = 1, "branch navigation carries loaded directory items");
   end Test_Controller_Refresh_And_History_Loading;

   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parent_Dir  : constant String := Join (Root, "nav-parent");
      Child_Dir   : constant String := Join (Parent_Dir, "child");
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load        : Files.File_System.Directory_Load_Result;
      Model       : Files.Model.Window_Model;
      Result      : Files.Controller.Controller_Result;
      Full_Parent : constant String := Ada.Directories.Full_Name (Parent_Dir);
      Full_Child  : constant String := Ada.Directories.Full_Name (Child_Dir);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Child_Dir);
      Write_File (Join (Child_Dir, "leaf.txt"));
      Write_File (Join (Parent_Dir, "sibling.txt"));
      Load := Files.File_System.Load_Directory (Full_Child, Settings);
      Files.Model.Initialize (Model, Full_Child, Load.Items, Full_Child);

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Model),
         "navigate-parent is enabled in a nested directory");

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Parent_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Navigated,
         "navigate-parent navigates to the parent");
      Assert
        (Files.Model.Current_Path (Model) = Full_Parent,
         "navigate-parent moves to the parent directory");
      Assert (Files.Model.Can_Go_Back (Model), "navigate-parent records history for back");

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "back returns after navigate-parent");
      Assert
        (Files.Model.Current_Path (Model) = Full_Child,
         "back restores the origin child directory");

      --  At a filesystem root the command is disabled and navigating up is a
      --  safe no-op that leaves the current path untouched.
      declare
         Root_Model : Files.Model.Window_Model;
         Root_Op    : Files.Operations.Operation_Result;
      begin
         Files.Model.Initialize
           (Root_Model, "/", Files.File_System.Item_Vectors.Empty_Vector, Full_Child);
         Assert
           (not Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Root_Model),
            "navigate-parent is disabled at the filesystem root");
         Root_Op := Files.Operations.Navigate_Parent (Root_Model, Settings);
         Assert
           (Root_Op.Status = Files.Operations.Operation_Disabled,
            "navigate-parent at the root is a safe no-op");
         Assert
           (Files.Model.Current_Path (Root_Model) = "/",
            "root navigate-parent keeps the current path");
      end;

      --  In the trash payload view the command is disabled like other
      --  directory-context commands.
      if Files.File_System.Trash_Files_Directory /= "" then
         declare
            Trash_Dir   : constant String := Files.File_System.Trash_Files_Directory;
            Trash_Load  : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Trash_Dir, Settings);
            Trash_Model : Files.Model.Window_Model;
         begin
            if Trash_Load.Success then
               Files.Model.Initialize
                 (Trash_Model, To_String (Trash_Load.Path), Trash_Load.Items, Full_Child);
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Trash_Model),
                  "navigate-parent is disabled in the trash view");
            end if;
         end;
      end if;

      Project_Tools.Files.Delete_Tree (Parent_Dir);
   end Test_Navigate_Parent_Operation;

   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "compress");
      Zip_Path : constant String := Join (Dir, "report.zip");
      Sz_Path  : constant String := Join (Dir, "report.7z");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;

      function First_Bytes (Path : String; Count : Positive) return String is
         Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      begin
         if Raw'Length < Count then
            return Raw;
         end if;
         return Raw (Raw'First .. Raw'First + Count - 1);
      end First_Bytes;

      Zip_Magic : constant String :=
        "PK" & Character'Val (3) & Character'Val (4);
      Sz_Magic  : constant String :=
        Character'Val (16#37#) & Character'Val (16#7A#) & Character'Val (16#BC#)
        & Character'Val (16#AF#) & Character'Val (16#27#) & Character'Val (16#1C#);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "report.txt"), "hello compression payload");
      Write_File (Join (Dir, "notes.txt"), "second file payload");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Compress_Zip_Command, Model),
         "compress-zip command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_Zip_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "compress to zip succeeds");
      Assert (Ada.Directories.Exists (Zip_Path), "zip archive is created next to the first item");
      Assert (First_Bytes (Zip_Path, 4) = Zip_Magic, "zip archive begins with the ZIP local-header signature");

      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_7z_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "compress to 7z succeeds");
      Assert (Ada.Directories.Exists (Sz_Path), "7z archive is created next to the first item");
      Assert (First_Bytes (Sz_Path, 6) = Sz_Magic, "7z archive begins with the 7z signature");
   end Test_Compress_Selected_Operation;

   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir        : constant String := Join (Root, "duplicate");
      Source     : constant String := Join (Dir, "report.txt");
      Copy_Path  : constant String := Join (Dir, "report (copy).txt");
      Payload    : constant String := "duplicate payload contents";
      Load       : Files.File_System.Directory_Load_Result;
      Model      : Files.Model.Window_Model;
      Routed     : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Model),
         "duplicate command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Duplicate_Selected_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "duplicate succeeds");
      Assert (Ada.Directories.Exists (Source), "original item still exists after duplicating");
      Assert (Ada.Directories.Exists (Copy_Path), "duplicate is created with a distinct name");
      Assert
        (Project_Tools.Files.Read_Raw_File (Copy_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "duplicate has identical contents to the original");
   end Test_Duplicate_Selected_Operation;

   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings        : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir             : constant String := Join (Root, "extract");
      Source_Report   : constant String := Join (Dir, "report.txt");
      Source_Notes    : constant String := Join (Dir, "notes.txt");
      Archive_Path    : constant String := Join (Dir, "bundle.zip");
      Dest_Dir        : constant String := Join (Dir, "bundle");
      Out_Report      : constant String := Join (Dest_Dir, "report.txt");
      Out_Notes       : constant String := Join (Dest_Dir, "notes.txt");
      Report_Payload  : constant String := "first extraction payload";
      Notes_Payload   : constant String := "second extraction payload";
      Inputs          : Zlib.Text_Array (1 .. 2);
      Names           : Zlib.Text_Array (1 .. 2);
      Build_Status    : Zlib.Status_Code;
      Load            : Files.File_System.Directory_Load_Result;
      Model           : Files.Model.Window_Model;
      Routed          : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source_Report, Report_Payload);
      Write_File (Source_Notes, Notes_Payload);

      --  Build a real ZIP archive holding both files next to the originals.
      Inputs (1) := To_Unbounded_String (Source_Report);
      Inputs (2) := To_Unbounded_String (Source_Notes);
      Names (1) := To_Unbounded_String ("report.txt");
      Names (2) := To_Unbounded_String ("notes.txt");
      Zlib.ZIP_Files (Inputs, Archive_Path, Names, Status => Build_Status);
      Assert (Build_Status = Zlib.Ok, "test archive is created");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "bundle.zip");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
         "extract command is enabled when an archive is selected");

      Routed := Files.Controller.Execute_Command (Files.Commands.Extract_Archive_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "extract succeeds");
      Assert (Ada.Directories.Exists (Dest_Dir), "destination folder is created from the archive base name");
      Assert (Ada.Directories.Exists (Out_Report), "first archived file is extracted");
      Assert (Ada.Directories.Exists (Out_Notes), "second archived file is extracted");
      Assert
        (Project_Tools.Files.Read_Raw_File (Out_Report)
           = Project_Tools.Files.Read_Raw_File (Source_Report),
         "first extracted file matches the original contents");
      Assert
        (Project_Tools.Files.Read_Raw_File (Out_Notes)
           = Project_Tools.Files.Read_Raw_File (Source_Notes),
         "second extracted file matches the original contents");
   end Test_Extract_Selected_Operation;

   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Original : constant String := Join (Root, "orig.txt");
      Renamed  : constant String := Join (Root, "renamed.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Original, "undo me");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "orig.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "renamed.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename commits before undo");
      Assert (Ada.Directories.Exists (Renamed), "rename produced the new name");
      Assert (not Ada.Directories.Exists (Original), "rename removed the old name");
      Assert (Files.Model.Undo_Available (Model), "undo is available after a rename");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "undo of a rename succeeds");
      Assert (Ada.Directories.Exists (Original), "undo restored the original name");
      Assert (not Ada.Directories.Exists (Renamed), "undo removed the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after undo");
   end Test_Undo_Operations;

   function Mode_Of (Path : String) return Natural is
      Available : Boolean := False;
      Bits      : constant Natural := Files.File_System.Permission_Bits_Of (Path, Available);
   begin
      Assert (Available, "permission bits are readable for " & Path);
      return Bits mod 8#1000#;
   end Mode_Of;

   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "modeable.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert
        (Files.File_System.Set_Permissions (Target, 8#644#).Success,
         "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "modeable.txt");
      Assert (Mode_Of (Target) = 8#644#, "baseline permission bits are 0644");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "set-permissions operation succeeds");
      Assert (Mode_Of (Target) = 8#600#, "mode reads back as 0600 after chmod");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Permissions,
         "set-permissions records a permission undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of chmod succeeds");
      Assert (Mode_Of (Target) = 8#644#, "undo restores the previous 0644 mode");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after chmod undo");
   end Test_Set_Permissions_And_Undo;

   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "vanishing.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert
        (Files.File_System.Set_Permissions (Target, 8#644#).Success,
         "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "vanishing.txt");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "set-permissions operation succeeds");
      Assert (Files.Model.Undo_Available (Model), "chmod records an undo entry");

      --  Delete the file so its restoring chmod cannot apply: the reverse now
      --  fails. Before the fix the popped entry was pushed onto neither stack
      --  and the operation silently vanished from history.
      Ada.Directories.Delete_File (Target);

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Result.Status = Files.Operations.Operation_Failed,
         "undo reports failure when the reverse cannot be applied");
      Assert
        (Files.Model.Undo_Available (Model),
         "a failed undo keeps its entry on the undo stack instead of dropping it");
      Assert
        (not Files.Model.Redo_Available (Model),
         "a failed undo does not leak the entry onto the redo stack");
   end Test_Failed_Undo_Keeps_Entry;

   procedure Test_Multi_Item_Undo_Recompletes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Orig_A   : constant String := Join (Root, "recomplete-orig-a.txt");
      Orig_B   : constant String := Join (Root, "recomplete-orig-b.txt");
      Moved_A  : constant String := Join (Root, "recomplete-moved-a.txt");
      Moved_B  : constant String := Join (Root, "recomplete-moved-b.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      From_V   : Files.Types.String_Vectors.Vector;
      To_V     : Files.Types.String_Vectors.Vector;
   begin
      Reset_Root;
      --  Simulate a completed two-item move: the files now live at Moved_*, and
      --  the recorded undo would move them back to Orig_*.
      Write_File (Moved_A, "a");
      Write_File (Moved_B, "b");
      From_V.Append (To_Unbounded_String (Moved_A));
      From_V.Append (To_Unbounded_String (Moved_B));
      To_V.Append (To_Unbounded_String (Orig_A));
      To_V.Append (To_Unbounded_String (Orig_B));

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Record_Undo (Model, Files.Model.Undo_Move, From_V, To_V);
      Assert (Files.Model.Undo_Available (Model), "the multi-item move records an undo entry");

      --  Occupy the second item's destination so its move-back cannot apply yet.
      Write_File (Orig_B, "occupied");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Result.Status = Files.Operations.Operation_Failed,
         "a partially-blocked multi-item undo reports failure");
      Assert
        (Ada.Directories.Exists (Orig_A) and then not Ada.Directories.Exists (Moved_A),
         "the unblocked item is moved back on the first pass");
      Assert (Ada.Directories.Exists (Moved_B), "the blocked item stays put");
      Assert
        (Files.Model.Undo_Available (Model),
         "the partially-applied entry stays on the undo stack");

      --  Free the destination and retry. The regression this covers: the
      --  already-restored item (Moved_A now gone) used to force failure forever,
      --  so the entry could never re-complete; it now counts as already-undone.
      Ada.Directories.Delete_File (Orig_B);
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "re-running the undo completes the previously-blocked item");
      Assert
        (Ada.Directories.Exists (Orig_B) and then not Ada.Directories.Exists (Moved_B),
         "the previously-blocked item is now moved back");
      Assert (Ada.Directories.Exists (Orig_A), "the already-restored item is untouched by the retry");
      Assert
        (not Files.Model.Undo_Available (Model),
         "the fully-applied entry finally leaves the undo stack");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success,
              "a retried Undo retains the full action for Redo");
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success
              and then Ada.Directories.Exists (Orig_A) and then Ada.Directories.Exists (Orig_B)
              and then not Ada.Directories.Exists (Moved_A) and then not Ada.Directories.Exists (Moved_B),
              "Undo after Redo reverses both items in a fresh cycle");
   end Test_Multi_Item_Undo_Recompletes;

   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      type Scenario_Kind is (Copy_Replace, Move_Replace, Recovery_Only);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Had_Xdg : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg : constant String :=
        (if Had_Xdg then Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      for Native in Boolean loop
         for Scenario in Scenario_Kind loop
            Reset_Root;
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "retry-trash"));
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", (if Native then "windows" else "xdg"));
            declare
               Dest_A : constant String := Join (Root, "retry-dest-a");
               Dest_B : constant String := Join (Root, "retry-dest-b");
               Source_A : constant String := Join (Root, "retry-source-a");
               Source_B : constant String := Join (Root, "retry-source-b");
               Back_A, Back_B : Files.Types.UString;
               From_Paths, To_Paths, Backups : Files.Types.String_Vectors.Vector;
               Model : Files.Model.Window_Model;
               Step : Files.Operations.Operation_Result;
               Mutation : Files.File_System.Mutation_Result;
            begin
               Write_Binary_File (Dest_A, "original A");
               Write_Binary_File (Dest_B, "original B");
               Mutation := Files.File_System.Preserve_For_Replace (Dest_A, Back_A);
               Assert (Mutation.Success, "preserve the first replacement original");
               Mutation := Files.File_System.Preserve_For_Replace (Dest_B, Back_B);
               Assert (Mutation.Success, "preserve the second replacement original");
               Backups.Append (Back_A);
               Backups.Append (Back_B);
               if Scenario /= Recovery_Only then
                  Write_Binary_File (Dest_A, "new A");
                  Write_Binary_File (Dest_B, "new B");
                  From_Paths.Append (To_Unbounded_String (Dest_A));
                  From_Paths.Append (To_Unbounded_String (Dest_B));
                  if Scenario = Move_Replace then
                     To_Paths.Append (To_Unbounded_String (Source_A));
                     To_Paths.Append (To_Unbounded_String (Source_B));
                  end if;
               end if;
               Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
               if Scenario = Recovery_Only then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Restore_Trash, Backups, To_Paths, Redoable => False);
               else
                  Files.Model.Record_Undo
                    (Model,
                     (if Scenario = Move_Replace then Files.Model.Undo_Move else Files.Model.Undo_Delete_Created),
                     From_Paths, To_Paths, Redoable => False, Restore_Trash => Backups);
               end if;
               declare
                  Held : constant String := Join (Ada.Directories.Containing_Directory (To_String (Back_B)),
                                                  "held-payload");
               begin
                  --  Make the second backup unavailable without OS-specific permission assumptions.
                  Assert (Hostkit.Fs.Move_No_Replace (To_String (Back_B), Held), "temporarily block one restore");
                  for Attempt in 1 .. 2 loop
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                     Assert (Step.Status = Files.Operations.Operation_Failed
                             and then Files.Model.Undo_Available (Model),
                             "an unfinished restore stays available for another Undo attempt");
                     Assert (File_Has_Bytes (Dest_A, "original A"),
                             "a failed Undo retry never deletes or relocates an already-restored original");
                     Assert (File_Has_Bytes (Held, "original B"), "the blocked original remains recoverable");
                     if Scenario = Move_Replace then
                        Assert (File_Has_Bytes (Source_A, "new A") and then File_Has_Bytes (Source_B, "new B"),
                                "a replacement move is reversed once while original restores are retried");
                     end if;
                  end loop;
                  Assert (Hostkit.Fs.Move_No_Replace (Held, To_String (Back_B)), "unblock the remaining restore");
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Assert (Step.Status = Files.Operations.Operation_Success,
                          "Undo completes after the remaining original becomes available");
                  Assert (File_Has_Bytes (Dest_A, "original A") and then File_Has_Bytes (Dest_B, "original B"),
                          "all originals survive the successful retry");
                  Assert (not Files.Model.Undo_Available (Model) and then not Files.Model.Redo_Available (Model),
                          "the completed replacement recovery consumes its Undo-only entry");
               end;
            end;
         end loop;
      end loop;
      Restore_Environment;
   exception
      when others => Restore_Environment; raise;
   end Test_Replace_Undo_Retry;

   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plain    : constant String := Join (Root, "plain.txt");
      Cased    : constant String := Join (Root, "Plain.txt");
      Lower    : constant String := Join (Root, "data.txt");
      Upper    : constant String := Join (Root, "DATA.txt");
      Other    : constant String := Join (Root, "other.txt");
      Link     : Files.File_System.Mutation_Result;
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;

      --  A case-changing rename with no existing destination takes the ordinary
      --  path and succeeds: the case flip works whenever nothing aliases it (the
      --  only case-only shape reproducible on a case-sensitive filesystem).
      Write_File (Plain, "hello");
      Mutation := Files.File_System.Rename_Item (Plain, Cased);
      Assert (Mutation.Success, "a case change with a free destination renames normally");
      if not Case_Insensitive_Filesystem then
         --  On a case-insensitive filesystem plain.txt and Plain.txt name the
         --  same entry, so the old-case name still resolves after the flip; the
         --  "source is gone" invariant only holds where case distinguishes names.
         Assert (not Ada.Directories.Exists (Plain), "the old-case source name no longer exists");
      end if;
      Assert (Ada.Directories.Exists (Cased), "the case-changed destination exists");

      --  The hazardous shape: data.txt and DATA.txt as two hard links to one
      --  inode reproduce the identity a case-insensitive filesystem reports for a
      --  case-only rename. On a case-sensitive host they are two independent
      --  directory entries, so the scratch-name second hop cannot land -- but the
      --  two-step must roll back cleanly and NEVER lose the file (the earlier
      --  naive fix dropped into Copy_Tree + delete here and destroyed the source).
      --  A case-insensitive filesystem cannot hold two such entries at once, and
      --  the free-destination flip above is already its native case-only rename,
      --  so this hand-built simulation only runs where case distinguishes names.
      if not Case_Insensitive_Filesystem then
         Write_File (Lower, "payload");
         Link := Files.File_System.Create_Hard_Link (Lower, Upper);
         Assert (Link.Success, "hard link creation succeeds on the test filesystem");

         Mutation := Files.File_System.Rename_Item (Lower, Upper);
         Assert (Ada.Directories.Exists (Lower), "the case-only rename leaves the source intact on rollback");
         Assert (Ada.Directories.Exists (Upper), "the case-only rename leaves the aliased name intact");
         Assert
           (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Lower), "payload") > 0,
            "no data is lost when the case-only rename rolls back");
         Assert
           (not Path_Exists (Lower & ".files-case-rename-0"),
            "the scratch rename name is not left behind");
      end if;

      --  A genuinely distinct existing destination is still refused as a collision.
      --  Ensure that destination exists first: on a case-insensitive filesystem
      --  the simulation above is skipped, so it did not leave data.txt behind.
      if not Ada.Directories.Exists (Lower) then
         Write_File (Lower, "payload");
      end if;
      Write_File (Other, "distinct");
      Mutation := Files.File_System.Rename_Item (Other, Lower);
      Assert (not Mutation.Success, "renaming onto a distinct existing file is still refused");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "the distinct-destination collision reports invalid destination");
      Assert (Ada.Directories.Exists (Other), "the refused collision leaves the source in place");

      --  Equal file identities do not make different directory entries a no-op.
      --  Both hard links and symbolic links can name the same file this way.
      for Symbolic in Boolean loop
         Reset_Root;
         declare
            Shared : constant String := Join (Root, "shared");
            Left_Directory : constant String := Join (Root, "left");
            Right_Directory : constant String := Join (Root, "right");
            Left_Name : constant String := Join (Left_Directory, "alias");
            Right_Name : constant String := Join (Right_Directory, "alias");
            Created_Left, Created_Right : Boolean;
         begin
            Ada.Directories.Create_Directory (Left_Directory);
            Ada.Directories.Create_Directory (Right_Directory);
            Write_File (Shared, "shared bytes");
            if Symbolic then
               Created_Left := Hostkit.Fs.Create_Link (Shared, Left_Name);
               Created_Right := Created_Left and then Hostkit.Fs.Create_Link (Shared, Right_Name);
            else
               Created_Left := Hostkit.Fs.Create_Hard_Link (Shared, Left_Name);
               Created_Right := Created_Left and then Hostkit.Fs.Create_Hard_Link (Shared, Right_Name);
            end if;
            if Created_Right then
               Mutation := Files.File_System.Rename_Item (Left_Name, Right_Name);
               Assert (not Mutation.Success
                       and then To_String (Mutation.Error_Key) = "error.rename.invalid_destination"
                       and then (if Symbolic then Hostkit.Fs.Is_Link (Left_Name)
                                 and then Hostkit.Fs.Is_Link (Right_Name)
                                 else Ada.Directories.Exists (Left_Name)
                                   and then Ada.Directories.Exists (Right_Name))
                       and then File_Has_Bytes (Shared, "shared bytes"),
                       "two entries with one target cannot be mistaken for a no-op rename");
            end if;
         end;
      end loop;

      Reset_Root;
      declare
         Source_Link : constant String := Join (Root, "link");
         Case_Link : constant String := Join (Root, "LINK");
      begin
         if Case_Insensitive_Filesystem then
            if Hostkit.Fs.Create_Link ("missing-target", Source_Link) then
               Mutation := Files.File_System.Rename_Item (Source_Link, Case_Link);
               Assert (Mutation.Success and then Hostkit.Fs.Is_Link (Case_Link),
                       "case-only rename moves a dangling link on a case-insensitive filesystem");
            end if;
         else
            Write_File (Join (Root, "shared"), "shared bytes");
            if Hostkit.Fs.Create_Link (Join (Root, "shared"), Source_Link)
              and then Hostkit.Fs.Create_Link (Join (Root, "shared"), Case_Link)
            then
               Mutation := Files.File_System.Rename_Item (Source_Link, Case_Link);
               Assert (not Mutation.Success
                       and then To_String (Mutation.Error_Key) = "error.rename.invalid_destination"
                       and then Hostkit.Fs.Is_Link (Source_Link)
                       and then Hostkit.Fs.Is_Link (Case_Link),
                       "different links to one target are a collision even when names differ only by case");
            end if;
         end if;
      end;
   end Test_Case_Only_Rename_Is_Safe;

   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Settings_Var : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sub        : constant String := Join (Root, "perm_dir");
      Width      : constant Natural := 1400;
      Height     : constant Natural := 1000;
      Load       : Files.File_System.Directory_Load_Result;
      Model      : Files.Model.Window_Model;
      Target_Bit : constant Natural := 4;  --  group-write cell
      Mask       : constant Natural := 2 ** (8 - Target_Bit);
      Found_Cell : Boolean := False;
      Cell_X     : Natural := 0;
      Cell_Y     : Natural := 0;
   begin
      if not Files.File_System.Supports_Permissions then
         return;
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Assert (Files.File_System.Set_Permissions (Sub, 8#755#).Success, "baseline dir mode 0755");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "perm_dir");
      Files.Model.Toggle_Info_Pane (Model);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height);
      begin
         Assert (Snapshot.Permissions_Editable, "single directory selection is permission-editable");
         for Index in 1 .. Natural (Frame.Permission_Hits.Length) loop
            declare
               Cell : constant Files.Rendering.Permission_Hit_Region :=
                 Frame.Permission_Hits.Element (Positive (Index));
            begin
               if Cell.Bit = Target_Bit then
                  Found_Cell := True;
                  Cell_X := Cell.X + Cell.Width / 2;
                  Cell_Y := Cell.Y + Cell.Height / 2;
               end if;
            end;
         end loop;
      end;

      Assert (Found_Cell, "the group-write permission cell has a hit region");

      declare
         Before : constant Natural := Mode_Of (Sub);
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action : constant Files.Events.Input_Action :=
           Files_Suite.Support.Click_Action (Snapshot, Cell_X, Cell_Y, Width, Height);
         Result : Files.Interaction.Interaction_Result;
      begin
         Assert
           (Action.Kind = Files.Events.Permission_Toggle_Input_Action,
            "clicking a permission cell yields a permission-toggle action");
         Assert (Action.Item_Index = Target_Bit, "the toggle action carries the clicked cell bit");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);

         Assert
           ((Mode_Of (Sub) / Mask) mod 2 /= (Before / Mask) mod 2,
            "the clicked permission bit is toggled after the reducer applies the action");
      end;
   end Test_Permission_Grid_Click;

   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "ownable.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "own me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "ownable.txt");

      --  Setting ownership to the file's OWN uid/gid is permitted even for a
      --  non-root process, so this exercises the primitive and undo plumbing.
      Result := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "identity chown to the file's own owner succeeds");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Ownership,
         "set-ownership records an ownership undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of chown succeeds");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after chown undo");

      declare
         New_Uid, New_Gid : Natural := 0;
         Now_Avail        : Boolean := False;
      begin
         Files.File_System.Ownership_Of (Target, New_Uid, New_Gid, Now_Avail);
         Assert
           (Now_Avail and then New_Uid = Uid and then New_Gid = Gid,
            "ownership is unchanged after identity chown and undo");
      end;
   end Test_Set_Ownership_Identity_And_Undo;

   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "denied.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "deny me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "denied.txt");

      --  Attempt to give the file to root. A non-root process is refused with
      --  error.ownership.denied; a root test process would instead succeed.
      --  Either way there must be no crash.
      Result := Files.Operations.Set_Ownership_For (Model, 0, 0, Settings);
      if Result.Status = Files.Operations.Operation_Success then
         Assert (Uid = 0, "unexpected chown-to-root success only permitted when running as root");
      else
         Assert
           (Result.Status = Files.Operations.Operation_Failed,
            "chown to a different owner reports a failure");
         Assert
           (To_String (Result.Error_Key) = "error.ownership.denied",
            "chown denial surfaces error.ownership.denied");
         declare
            Now_Uid, Now_Gid : Natural := 0;
            Now_Avail        : Boolean := False;
         begin
            Files.File_System.Ownership_Of (Target, Now_Uid, Now_Gid, Now_Avail);
            Assert
              (Now_Avail and then Now_Uid = Uid and then Now_Gid = Gid,
               "a denied chown leaves the file ownership unchanged");
         end;
      end if;
   end Test_Set_Ownership_Denied;

   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Found : Boolean := False;
      Id    : Natural := 0;
   begin
      if not Files.File_System.Supports_Ownership then
         return;
      end if;

      if Files.Platform.Current_API_Profile.Adapter
           = Files.File_System.Native_Adapter_Windows
      then
         --  There is no "root" on Windows and no uid 0: an account is a SID, and
         --  the number the interface hands out is that SID's relative identifier.
         --  So assert the property that actually holds -- the identity of a file
         --  we just made round-trips through a name and back.
         declare
            Owned : constant String := Join (Root, "owned.txt");
            Uid, Gid : Natural := 0;
            Avail    : Boolean := False;
            Round    : Natural := 0;
         begin
            Reset_Root;
            Write_File (Owned, "owned");
            Files.File_System.Ownership_Of (Owned, Uid, Gid, Avail);
            Assert (Avail, "a file we just created has an owner");

            declare
               Name : constant String := Files.File_System.User_Name_For_Id (Uid);
            begin
               Assert (Name /= "", "the owning identity resolves to a name");
               Round := Files.File_System.User_Id_For_Name (Name, Found);
               Assert (Found and then Round = Uid,
                       "that name resolves back to the same identity");
            end;
         end;
      else
         Id := Files.File_System.User_Id_For_Name ("root", Found);
         Assert (Found and then Id = 0, "user name root resolves to uid 0");

         Id := Files.File_System.Group_Id_For_Name ("root", Found);
         --  The root group is gid 0 on Linux; on some systems it is named
         --  "wheel", so accept a successful resolution to 0 or a not-found result
         --  rather than asserting a fixed gid that may vary by distribution.
         if Found then
            Assert (Id = 0, "group name root, when present, resolves to gid 0");
         end if;
      end if;

      Id := Files.File_System.User_Id_For_Name ("no_such_user_xyzzy_42", Found);
      Assert (not Found and then Id = 0, "a bogus user name reports Found => False");

      Id := Files.File_System.Group_Id_For_Name ("no_such_group_xyzzy_42", Found);
      Assert (not Found and then Id = 0, "a bogus group name reports Found => False");

      --  Reverse resolution: uid 0 is root on any normal Linux system; gid 0 is
      --  "root" or "wheel" depending on distribution, so only assert non-empty.
      --  Neither number means anything on Windows.
      if Files.Platform.Current_API_Profile.Adapter
           /= Files.File_System.Native_Adapter_Windows
      then
         Assert (Files.File_System.User_Name_For_Id (0) = "root", "uid 0 resolves to root");
         Assert (Files.File_System.Group_Name_For_Id (0) /= "", "gid 0 resolves to a group name");
      end if;
      Assert (Files.File_System.User_Name_For_Id (2_000_000_000) = "",
              "an unassigned uid resolves to the empty string");
      Assert (Files.File_System.Group_Name_For_Id (2_000_000_000) = "",
              "an unassigned gid resolves to the empty string");
   end Test_Ownership_Name_Resolution;

   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Settings_Var : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target       : constant String := Join (Root, "reducer_own.txt");
      Width        : constant Natural := 1400;
      Height       : constant Natural := 1000;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Uid, Gid     : Natural := 0;
      Avail        : Boolean := False;
      Found_Owner  : Boolean := False;
      Owner_X      : Natural := 0;
      Owner_Y      : Natural := 0;
   begin
      if not Files.File_System.Supports_Ownership then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "reduce me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "reducer_own.txt");
      Files.Model.Toggle_Info_Pane (Model);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height);
      begin
         Assert (Snapshot.Ownership_Editable, "single non-trash selection is ownership-editable");
         for Index in 1 .. Natural (Frame.Ownership_Hits.Length) loop
            declare
               Cell : constant Files.Rendering.Ownership_Hit_Region :=
                 Frame.Ownership_Hits.Element (Positive (Index));
            begin
               if not Cell.Is_Group then
                  Found_Owner := True;
                  Owner_X := Cell.X + Cell.Width / 2;
                  Owner_Y := Cell.Y + Cell.Height / 2;
               end if;
            end;
         end loop;
      end;

      Assert (Found_Owner, "the owner value has a click hit region");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action : constant Files.Events.Input_Action :=
           Files_Suite.Support.Click_Action (Snapshot, Owner_X, Owner_Y, Width, Height);
         Reduce : Files.Interaction.Interaction_Result;
         Routed : Files.Controller.Controller_Result;
      begin
         Assert
           (Action.Kind = Files.Events.Ownership_Edit_Input_Action,
            "clicking the owner value yields an ownership-edit action");
         Assert (Action.Item_Index = 0, "the owner action targets the owner (not group)");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Reduce);

         Assert
           (Files.Model.Focus (Model) = Files.Types.Focus_Ownership_Input,
            "the reducer focuses the ownership editor");

         --  Type the file's own numeric uid (a bare number is accepted as an
         --  id) and commit with Enter through the controller.
         Files.Controller.Replace_Focused_Text
           (Model, Ada.Strings.Fixed.Trim (Natural'Image (Uid), Ada.Strings.Both));
         Routed := Files.Controller.Handle_Key (Model, Settings_Var, Guikit.Input.Key_Return);

         Assert
           (Routed.Operation.Status = Files.Operations.Operation_Success,
            "committing the identity ownership edit through the reducer seam succeeds");
         Assert
           (Files.Model.Focus (Model) = Files.Types.Focus_None,
            "committing the ownership edit clears the editor focus");
      end;
   end Test_Ownership_Edit_Through_Reducer;

   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Tree     : constant String := Join (Root, "tree");
      Nested   : constant String := Join (Tree, "nested");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Size     : Files.File_System.Directory_Size_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Nested);
      Write_Binary_File (Join (Tree, "a.txt"), "12345");   --  5 bytes
      Write_Binary_File (Join (Tree, "b.txt"), "678");     --  3 bytes
      Write_Binary_File (Join (Nested, "c.txt"), "90");    --  2 bytes

      Size := Files.File_System.Directory_Size (Tree);
      Assert (Size.Available, "recursive size is available for a real directory");
      Assert (Size.Total_Bytes = 10, "recursive size sums all descendant file bytes");
      Assert (Size.File_Count = 3, "recursive size counts every descendant regular file");
      Assert (not Size.Capped, "a small tree does not trip the entry/depth cap");

      --  A symlink cycle must not hang or be followed. Measure with the loop
      --  present, then remove the link before any assertion so a failure cannot
      --  leave a self-referential tree that later cleanup cannot delete.
      if Files_Suite.Support.Create_Symlink (Tree, Join (Tree, "loop")) then
         declare
            Guarded : constant Files.File_System.Directory_Size_Result :=
              Files.File_System.Directory_Size (Tree);
         begin
            --  A link to a directory is a directory entry on Windows, so
            --  Delete_File will not take it. Delete_Tree removes a link without
            --  following it, whichever kind of entry the platform made it.
            Project_Tools.Files.Delete_Tree (Join (Tree, "loop"));
            Assert (Guarded.Available, "size walk completes despite a symlink cycle");
            Assert (Guarded.Total_Bytes = 10, "symlinked directory is not descended into");
         end;
      end if;

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "tree");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Cancel_Folder_Scan (Model);
      Files.Operations.Update_Folder_Size (Model, Settings);

      --  The measurement now runs in a helper off the UI path; drive it to
      --  completion and publish it, as the frame loop would, before snapshotting.
      declare
         Done_Path : Ada.Strings.Unbounded.Unbounded_String;
         Measured  : Files.File_System.Directory_Size_Result;
         Available : Boolean := False;
      begin
         loop
            Files.Model.Poll_Folder_Sizes (Model);
            Available := not Files.Model.Folder_Scan_Is_Active (Model);
            exit when Available or else not Files.Model.Folder_Scan_Is_Active (Model);
            delay 0.001;
         end loop;
      end;

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, 1400, 1000);
         Label    : constant String := Files.Localization.Text ("info.folder_size");
         Found    : Boolean := False;
      begin
         Assert
           (Snapshot.Selected_Info.Element (1).Folder_Size_Available,
            "the info snapshot carries the measured folder size");
         Assert
           (Snapshot.Selected_Info.Element (1).Folder_Size_Bytes = 10,
            "the info snapshot folder-size total is correct");
         for Command of Frame.Text loop
            if Ada.Strings.Fixed.Index (To_String (Command.Text), Label) > 0 then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the info pane emits the folder-size row for a selected directory");
      end;
   end Test_Recursive_Folder_Size;

   --  Copy_Tree must reproduce symlinks as links, never dereference them: a link
   --  to an ancestor would otherwise recurse until PATH_MAX (a copy explosion),
   --  and any link would be replaced by a full copy of its target. Regression
   --  guard for the src/ symlink-preservation fix.
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Tree   : constant String := Join (Root, "src_tree");
      Nested : constant String := Join (Tree, "nested");
      Dest   : constant String := Join (Root, "dst_tree");
      Result : Files.File_System.Mutation_Result;

      Copied_Ok  : Boolean := False;
      File_Ok    : Boolean := False;
      Nested_Ok  : Boolean := False;
      Alias_Link : Boolean := False;
      Loop_Link  : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Nested);
      Write_Binary_File (Join (Tree, "a.txt"), "12345");
      Write_Binary_File (Join (Nested, "c.txt"), "90");

      --  A self-referential link (points at an ancestor) plus a plain file link.
      --  If symlinks are unsupported on this host, there is nothing to assert.
      if not Files_Suite.Support.Create_Symlink (Tree, Join (Tree, "loop")) then
         return;
      end if;
      declare
         Aliased_Link : constant Boolean :=
           Files_Suite.Support.Create_Symlink (Join (Tree, "a.txt"), Join (Tree, "alias"));
         pragma Unreferenced (Aliased_Link);
      begin
         null;
      end;

      Result := Files.File_System.Copy_Tree (Tree, Dest);

      --  Capture every outcome BEFORE cleanup, so an assertion failure cannot skip
      --  the cleanup and leave symlink-bearing fixtures that Reset_Root then trips
      --  over (a dangling link poisons every later test in the run).
      Copied_Ok  := Result.Success;
      File_Ok    := Files_Suite.Support.Path_Exists (Join (Dest, "a.txt"));
      Nested_Ok  := Files_Suite.Support.Path_Exists (Join (Join (Dest, "nested"), "c.txt"));
      Alias_Link := Hostkit.Fs.Is_Link (Join (Dest, "alias"));
      Loop_Link  := Hostkit.Fs.Is_Link (Join (Dest, "loop"));

      --  Fully remove both trees while their link targets still exist (so no link
      --  is left dangling for the delete), leaving nothing behind.
      Project_Tools.Files.Delete_Tree (Dest);
      Project_Tools.Files.Delete_Tree (Tree);

      Assert (Copied_Ok, "Copy_Tree completes despite a symlink cycle (no explosion)");
      Assert (File_Ok, "Copy_Tree copies regular files");
      Assert (Nested_Ok, "Copy_Tree recurses into real subdirectories");
      Assert
        (Alias_Link,
         "Copy_Tree reproduces a file symlink as a link, not a copy of its target");
      Assert
        (Loop_Link,
         "Copy_Tree reproduces the ancestor-cycle symlink as a link, not following it");
   end Test_Copy_Tree_Preserves_Symlinks;

   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "symlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Payload   : constant String := "symlink payload contents";
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Symlink_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "create-symlink succeeds");
      Assert (Ada.Directories.Exists (Source), "original item still exists after linking");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "a symbolic link is created next to the source");
      Assert
        (Project_Tools.Files.Read_Raw_File (Link_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "the symbolic link resolves to the original contents");
      Assert (Files.Model.Undo_Available (Model), "undo is available after creating a link");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "undo of a created symlink succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created symlink");
      Assert (not Hostkit.Fs.Is_Link (Link_Path), "undo leaves no dangling symlink entry");
      Assert (Ada.Directories.Exists (Source), "undo keeps the original source item");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after undo");
   end Test_Create_Symlink_Operation;

   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "hardlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Payload   : constant String := "hard link payload contents";
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "create-hard-link succeeds");
      Assert (Ada.Directories.Exists (Source), "original file still exists after linking");
      Assert (Ada.Directories.Exists (Link_Path), "a hard link is created next to the source");
      Assert (not Hostkit.Fs.Is_Link (Link_Path), "a hard link is a regular directory entry");
      Assert
        (Project_Tools.Files.Read_Raw_File (Link_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "the hard link shares the original contents");
      Assert (Files.Model.Undo_Available (Model), "undo is available after creating a hard link");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "undo of a created hard link succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created hard link");
      Assert (Ada.Directories.Exists (Source), "undo keeps the original file");
   end Test_Create_Hardlink_Operation;

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

   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      A0     : constant String := Join (Root, "a0.txt");
      A1     : constant String := Join (Root, "a1.txt");
      B0     : constant String := Join (Root, "b0.txt");
      B1     : constant String := Join (Root, "b1.txt");
      B2     : constant String := Join (Root, "b2.txt");
      C0     : constant String := Join (Root, "c0.txt");
      C1     : constant String := Join (Root, "c1.txt");
      Load   : Files.File_System.Directory_Load_Result;
      Model  : Files.Model.Window_Model;
      Result : Files.Operations.Operation_Result;

      procedure Rename (From_Name, To_Name : String) is
         Step : Files.Operations.Operation_Result;
      begin
         Select_Name (Model, From_Name);
         Files.Model.Toggle_Rename (Model);
         Files.Model.Set_Rename_Text (Model, To_Name);
         Step := Files.Operations.Commit_Rename (Model, Settings);
         Assert
           (Step.Status = Files.Operations.Operation_Success,
            "rename " & From_Name & " to " & To_Name & " commits");
      end Rename;
   begin
      Reset_Root;
      Write_File (A0, "A");
      Write_File (B0, "B");
      Write_File (C0, "C");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);

      --  Three undoable operations are pushed in order.
      Rename ("a0.txt", "a1.txt");
      Rename ("b0.txt", "b1.txt");
      Rename ("c0.txt", "c1.txt");
      Assert (Files.Model.Undo_Available (Model), "undo is available after three renames");
      Assert (not Files.Model.Redo_Available (Model), "no redo is pending before undoing");

      --  Undo unwinds last-in-first-out: C, then B, then A.
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "first undo succeeds");
      Assert
        (Ada.Directories.Exists (C0) and then not Ada.Directories.Exists (C1),
         "the first undo reverses the most recent rename (C)");
      Assert (Ada.Directories.Exists (B1), "earlier renames stay applied after one undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Ada.Directories.Exists (B0) and then not Ada.Directories.Exists (B1),
         "the second undo reverses B");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert
        (Ada.Directories.Exists (A0) and then not Ada.Directories.Exists (A1),
         "the third undo reverses A");
      Assert (not Files.Model.Undo_Available (Model), "the undo stack empties after unwinding all three");
      Assert (Files.Model.Redo_Available (Model), "redo becomes available after undoing");

      --  Redo re-applies forward across all levels: A, then B, then C.
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert
        (Ada.Directories.Exists (A1) and then not Ada.Directories.Exists (A0),
         "the first redo re-applies A");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Ada.Directories.Exists (B1), "the second redo re-applies B");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Ada.Directories.Exists (C1), "the third redo re-applies C");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying all three");
      Assert (Files.Model.Undo_Available (Model), "undo is available again after redoing");

      --  undo -> redo -> undo round-trips the current top action.
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Ada.Directories.Exists (C0), "round-trip: undo returns C to its original name");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Ada.Directories.Exists (C1), "round-trip: redo re-applies C");
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Ada.Directories.Exists (C0), "round-trip: undo again returns C");

      --  A new undoable operation clears the pending redo history.
      Assert (Files.Model.Redo_Available (Model), "redo is still pending before the new operation");
      Rename ("b1.txt", "b2.txt");
      Assert (Ada.Directories.Exists (B2), "the new rename applies");
      Assert (not Files.Model.Redo_Available (Model), "a new operation clears the redo stack");
   end Test_Undo_Redo_History;

   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Undo_Create_Kind;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source_A : constant String := Join (Root, "redo-source-a");
      Source_B : constant String := Join (Root, "redo-source-b");
      Dest_A : constant String := Join (Root, "redo-dest-a");
      Dest_B : constant String := Join (Root, "redo-dest-b");
      Held_A : constant String := Join (Root, "held-a");
      Held_B : constant String := Join (Root, "held-b");
      Saved_A : constant String := Join (Root, "saved-redo-dest-a");
   begin
      for Kind in Files.Model.Create_Copy .. Files.Model.Create_Hard_Link loop
         for Missing_Source in Boolean loop
            Reset_Root;
            declare
               Model : Files.Model.Window_Model;
               Step : Files.Operations.Operation_Result;
               Destinations, Sources : Files.Types.String_Vectors.Vector;

               function Create (Source, Dest : String) return Boolean is
               begin
                  return
                    (case Kind is
                        when Files.Model.Create_Copy => Files.File_System.Copy_Tree (Source, Dest).Success,
                        when Files.Model.Create_Symbolic_Link =>
                          Files.File_System.Create_Symbolic_Link (Source, Dest).Success,
                        when Files.Model.Create_Hard_Link => Files.File_System.Create_Hard_Link (Source, Dest).Success);
               end Create;
            begin
               Write_Binary_File (Source_A, "original a");
               Write_Binary_File (Source_B, "original b");
               Assert (Create (Source_A, Dest_A) and then Create (Source_B, Dest_B), "prepare two created items");
               Destinations.Append (To_Unbounded_String (Dest_A));
               Destinations.Append (To_Unbounded_String (Dest_B));
               Sources.Append (To_Unbounded_String (Source_A));
               Sources.Append (To_Unbounded_String (Source_B));
               Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
               Files.Model.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Destinations,
                  Files.Types.String_Vectors.Empty_Vector, Forward => Sources, Create_Kind => Kind);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Success, "Undo removes both creations before Redo");
               if Missing_Source then
                  Ada.Directories.Rename (Source_B, Held_B);
               else
                  Write_Binary_File (Dest_B, "unrelated collision");
               end if;
               for Attempt in 1 .. 2 loop
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  Assert (Step.Status = Files.Operations.Operation_Failed
                          and then File_Has_Bytes (Dest_A, "original a")
                          and then Files.Model.Redo_Available (Model)
                          and then not Files.Model.Undo_Available (Model),
                          "partial Redo retains completed A and the pending action across repeated failures");
                  if not Missing_Source then
                     Assert (File_Has_Bytes (Dest_B, "unrelated collision"),
                             "a pending Redo never claims or overwrites an unrelated destination");
                  end if;
               end loop;
               Ada.Directories.Delete_File (Dest_A);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (Dest_A, "original a")
                       and then Files.Model.Redo_Available (Model),
                       "a partial Redo recreates an output missing behind its completion marker");
               Assert
                 (Hostkit.Fs.Move_No_Replace (Dest_A, Saved_A),
                  "move the completed output aside without following links");
               if Kind = Files.Model.Create_Symbolic_Link then
                  Assert
                    (Hostkit.Fs.Is_Link (Saved_A),
                     "moving a completed symbolic link preserves the link");
               end if;
               Write_Binary_File (Dest_A, "unrelated replacement");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (Dest_A, "unrelated replacement")
                       and then Files.Model.Redo_Available (Model),
                       "a stale completion marker does not claim or overwrite a replacement");
               Ada.Directories.Delete_File (Dest_A);
               Assert
                 (Hostkit.Fs.Move_No_Replace (Saved_A, Dest_A),
                  "restore the completed output without following links");
               if Kind = Files.Model.Create_Symbolic_Link then
                  Assert
                    (Hostkit.Fs.Is_Link (Dest_A),
                     "restoring a completed symbolic link preserves the link");
               end if;
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (Dest_A, "original a")
                       and then Files.Model.Redo_Available (Model),
                       "restoring the verified output makes the invalidated marker retryable");
               if Missing_Source then
                  Ada.Directories.Rename (Held_B, Source_B);
               else
                  Ada.Directories.Delete_File (Dest_B);
               end if;
               --  Completed A no longer needs its source to finish B.
               Ada.Directories.Rename (Source_A, Held_A);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Files.Model.Redo_Available (Model)
                       and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Dest_B, "original b"),
                       "unblocking B completes Redo despite A's now-missing source and returns it to Undo history: "
                       & Files.Model.Undo_Create_Kind'Image (Kind)
                       & " missing=" & Boolean'Image (Missing_Source)
                       & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                       & " redo=" & Boolean'Image (Files.Model.Redo_Available (Model))
                       & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                       & " b=" & Boolean'Image (File_Has_Bytes (Dest_B, "original b")));
               Ada.Directories.Rename (Held_A, Source_A);
               Assert (File_Has_Bytes (Dest_A, "original a"), "completed A retains its original bytes");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Ada.Directories.Exists (Dest_A) and then not Hostkit.Fs.Is_Link (Dest_A)
                       and then not Ada.Directories.Exists (Dest_B) and then not Hostkit.Fs.Is_Link (Dest_B),
                       "Undo reverses the entire recovered action");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then File_Has_Bytes (Dest_A, "original a") and then File_Has_Bytes (Dest_B, "original b"),
                       "a new Redo cycle re-creates both items instead of reusing stale progress");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Assert (Step.Status = Files.Operations.Operation_Success,
                       "the second full Redo also records a usable Undo action");
            end;
         end loop;
      end loop;
   end Test_Partial_Redo_Creation;

   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source_A : constant String := Join (Root, "redo-move-source-a");
      Source_B : constant String := Join (Root, "redo-move-source-b");
      Dest_A : constant String := Join (Root, "redo-move-dest-a");
      Dest_B : constant String := Join (Root, "redo-move-dest-b");
      Saved_A : constant String := Join (Root, "saved-redo-move-dest-a");
      type Scenario_Kind is (Move_Action, Rename_Action);
   begin
      for Scenario in Scenario_Kind loop
         Reset_Root;
         declare
            Model : Files.Model.Window_Model;
            Step : Files.Operations.Operation_Result;
            Destinations, Sources : Files.Types.String_Vectors.Vector;
         begin
            Write_Binary_File (Dest_A, "original a");
            Write_Binary_File (Dest_B, "original b");
            Destinations.Append (To_Unbounded_String (Dest_A));
            Destinations.Append (To_Unbounded_String (Dest_B));
            Sources.Append (To_Unbounded_String (Source_A));
            Sources.Append (To_Unbounded_String (Source_B));
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Record_Undo
              (Model, (if Scenario = Move_Action then Files.Model.Undo_Move else Files.Model.Undo_Rename),
               Destinations, Sources);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare a two-item move or rename Redo");
            Write_Binary_File (Dest_B, "unrelated collision");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed and then File_Has_Bytes (Dest_A, "original a")
                    and then not Ada.Directories.Exists (Source_A), "the first forward move completes before B fails");
            Write_Binary_File (Source_A, "unrelated new source");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then File_Has_Bytes (Dest_A, "original a")
                    and then File_Has_Bytes (Dest_B, "unrelated collision"),
                    "repeated partial Redo leaves completed moves and unrelated paths intact");
            Ada.Directories.Rename (Dest_A, Saved_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then not Ada.Directories.Exists (Dest_A)
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then Files.Model.Redo_Available (Model),
                    "a missing completed move invalidates its marker without moving a replacement source");
            Ada.Directories.Rename (Saved_A, Dest_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then File_Has_Bytes (Dest_A, "original a")
                    and then Files.Model.Redo_Available (Model),
                    "restoring the moved entry makes its invalidated marker retryable");
            Ada.Directories.Delete_File (Dest_B);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Files.Model.Undo_Available (Model) and then not Files.Model.Redo_Available (Model)
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then File_Has_Bytes (Dest_B, "original b"),
                    "unblocking B completes Redo without moving the unrelated recreated source A");
            Ada.Directories.Delete_File (Source_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then File_Has_Bytes (Source_A, "original a") and then File_Has_Bytes (Source_B, "original b"),
                    "Undo reverses both moves after a recovered Redo");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then File_Has_Bytes (Dest_A, "original a") and then File_Has_Bytes (Dest_B, "original b")
                    and then not Ada.Directories.Exists (Source_A) and then not Ada.Directories.Exists (Source_B),
                    "a fresh Redo cycle moves both items after its progress was cleared");
         end;
      end loop;
   end Test_Partial_Redo_Move;

   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "redo-symlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
      Result    : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "payload");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Symlink_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "create-symlink succeeds");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "the symbolic link is created");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of a created link succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created link");
      Assert (Files.Model.Redo_Available (Model), "a created link is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "redo of a created link succeeds");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "redo re-creates the symbolic link from its source");
      Assert (Ada.Directories.Exists (Source), "redo keeps the original source item");
      Assert (Files.Model.Undo_Available (Model), "the re-created link is undoable again");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying");
   end Test_Redo_Symlink_Creation;

   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "redo-mode.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert (Files.File_System.Set_Permissions (Target, 8#644#).Success, "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "redo-mode.txt");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "chmod to 0600 succeeds");
      Assert (Mode_Of (Target) = 8#600#, "mode reads back as 0600 after chmod");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of chmod succeeds");
      Assert (Mode_Of (Target) = 8#644#, "undo restores the previous 0644 mode");
      Assert (Files.Model.Redo_Available (Model), "chmod is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "redo of chmod succeeds");
      Assert (Mode_Of (Target) = 8#600#, "redo re-applies the new 0600 mode");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying chmod");
   end Test_Redo_Set_Permissions;

   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "redo-owner.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         return;
      end if;

      Reset_Root;
      Write_File (Target, "own me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "redo-owner.txt");

      --  An identity chown to the file's own uid/gid is permitted without root
      --  and exercises the undo/redo ownership plumbing.
      Result := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "identity chown succeeds");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Ownership,
         "set-ownership records an ownership undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of chown succeeds");
      Assert (Files.Model.Redo_Available (Model), "chown is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "redo of chown succeeds");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying chown");

      declare
         New_Uid, New_Gid : Natural := 0;
         Now_Avail        : Boolean := False;
      begin
         Files.File_System.Ownership_Of (Target, New_Uid, New_Gid, Now_Avail);
         Assert
           (Now_Avail and then New_Uid = Uid and then New_Gid = Gid,
            "ownership is unchanged after identity chown undo and redo");
      end;
   end Test_Redo_Set_Ownership_Identity;

   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "redo-move-src");
      Dest_Dir : constant String := Join (Root, "redo-move-dest");
      Source   : constant String := Join (Src_Dir, "m.txt");
      Dest     : constant String := Join (Dest_Dir, "m.txt");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Source, "MOVE");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Source),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => False));

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the move paste finalizes");
      Assert
        (Ada.Directories.Exists (Dest) and then not Ada.Directories.Exists (Source),
         "the move relocates the file to the destination");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Move,
         "a move paste records an Undo_Move entry");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "undo of the move succeeds");
      Assert
        (Ada.Directories.Exists (Source) and then not Ada.Directories.Exists (Dest),
         "undo moves the file back to its source");
      Assert (Files.Model.Redo_Available (Model), "a move is redoable");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "redo of the move succeeds");
      Assert
        (Ada.Directories.Exists (Dest) and then not Ada.Directories.Exists (Source),
         "redo re-applies the move to the destination");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying the move");
   end Test_Redo_Paste_Move;

   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home  : constant String := Root & "_replace_xdg";
      Had_Xdg     : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home    : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg     : Unbounded_String;
      Old_Home    : Unbounded_String;
      Old_Backend : Unbounded_String;

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg then
         Old_Xdg := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      --  Sandbox the trash so Clear_Replaced_Destination can trash the overwritten
      --  original into a scratch location and the undo can restore it from there.
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Copy-replace: the destination holds "old"; pasting "new" over it overwrites
      --  the file, and undo must bring "old" back (not merely delete the pasted copy).
      declare
         Src_Dir  : constant String := Join (Root, "rep-copy-src");
         Dest_Dir : constant String := Join (Root, "rep-copy-dest");
         Source   : constant String := Join (Src_Dir, "report.txt");
         Dest     : constant String := Join (Dest_Dir, "report.txt");
         Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
         Load     : Files.File_System.Directory_Load_Result;
         Model    : Files.Model.Window_Model;
         Step     : Files.Operations.Operation_Result;
      begin
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Source, "new");
         Write_File (Dest, "old");
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Source),
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => True));

         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the copy-replace paste finalizes");
         Assert
           (Files.File_System.Read_Preview_Text (Dest, 3) = "new",
            "the copy-replace overwrites the destination with the pasted content");

         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         if Step.Status = Files.Operations.Operation_Success then
            Assert
              (Ada.Directories.Exists (Dest)
                 and then Files.File_System.Read_Preview_Text (Dest, 3) = "old",
               "undo of a copy-replace restores the overwritten original at the destination");
            Assert
              (not Files.Model.Redo_Available (Model),
               "a copy paste that replaced an existing file is not redoable");
         end if;
      end;

      --  Move-replace: same overwrite, but the source is relocated. Undo must both
      --  return the source and restore the overwritten original at the destination.
      declare
         Src_Dir  : constant String := Join (Root, "rep-move-src");
         Dest_Dir : constant String := Join (Root, "rep-move-dest");
         Source   : constant String := Join (Src_Dir, "report.txt");
         Dest     : constant String := Join (Dest_Dir, "report.txt");
         Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
         Load     : Files.File_System.Directory_Load_Result;
         Model    : Files.Model.Window_Model;
         Step     : Files.Operations.Operation_Result;
      begin
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Source, "new");
         Write_File (Dest, "old");
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Source),
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => True));

         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the move-replace paste finalizes");
         Assert
           (Files.File_System.Read_Preview_Text (Dest, 3) = "new"
              and then not Ada.Directories.Exists (Source),
            "the move-replace overwrites the destination and consumes the source");

         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         if Step.Status = Files.Operations.Operation_Success then
            Assert
              (Ada.Directories.Exists (Source)
                 and then Files.File_System.Read_Preview_Text (Source, 3) = "new",
               "undo of a move-replace returns the source to its origin");
            Assert
              (Ada.Directories.Exists (Dest)
                 and then Files.File_System.Read_Preview_Text (Dest, 3) = "old",
               "undo of a move-replace restores the overwritten original at the destination");
            Assert
              (not Files.Model.Redo_Available (Model),
               "a move paste that replaced an existing file is not redoable");
         end if;
      end;

      Restore_Environment;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Undo_Paste_Replace;

   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Had_Terminal : constant Boolean := Ada.Environment_Variables.Exists ("TERMINAL");
      Old_Terminal : Unbounded_String;
      Shell_Path   : constant String := "/bin/sh";
      Missing_Path : constant String := Join (Root, "no-such-terminal-binary");
   begin
      Reset_Root;
      if Had_Terminal then
         Old_Terminal := To_Unbounded_String (Ada.Environment_Variables.Value ("TERMINAL"));
      end if;

      if Ada.Directories.Exists (Shell_Path) then
         Ada.Environment_Variables.Set ("TERMINAL", Shell_Path);
         Assert
           (Files.Operations.Detected_Terminal = Shell_Path,
            "an available TERMINAL override selects the configured terminal executable");
      end if;

      Ada.Environment_Variables.Set ("TERMINAL", Missing_Path);
      Assert
        (Files.Operations.Detected_Terminal /= Missing_Path,
         "an unavailable TERMINAL override is ignored");

      --  Windows and macOS always have one, and used to be offered none: the
      --  candidate list held Linux emulators only, so Open Terminal could not
      --  succeed on either. Not asserted on Linux, where a headless CI box
      --  legitimately has no terminal emulator installed at all.
      if Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS then
         Assert
           (Files.Operations.Detected_Terminal /= "",
            "this host always has a terminal to open, and one is found");
      end if;

      if Had_Terminal then
         Ada.Environment_Variables.Set ("TERMINAL", To_String (Old_Terminal));
      else
         Ada.Environment_Variables.Clear ("TERMINAL");
      end if;
   end Test_Detected_Terminal_Helper;

   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LF         : constant Character := ASCII.LF;
      App_Base   : constant String := Join (Root, "xdg_apps");
      Apps_Dir   : constant String := Join (App_Base, "applications");
      System_Base : constant String := Join (Root, "xdg_system");
      System_Apps : constant String := Join (System_Base, "applications");
      Try_Exec    : constant String := Files_Suite.Support.No_Op_Executable;
      Had_Home   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Dirs   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_DIRS");
      Had_Desktop : constant Boolean :=
        Ada.Environment_Variables.Exists ("XDG_CURRENT_DESKTOP");
      Had_Locale : constant Boolean :=
        Ada.Environment_Variables.Exists ("LC_ALL");
      Old_Home   : Unbounded_String;
      Old_Dirs   : Unbounded_String;
      Old_Desktop : Unbounded_String;
      Old_Locale : Unbounded_String;
      Original_Directory : constant String := Ada.Directories.Current_Directory;

      function Desktop_Escape (Value : String) return String is
         Result : Unbounded_String;
      begin
         for Character_Value of Value loop
            if Character_Value = '\' then
               Append (Result, "\\");
            else
               Append (Result, Character_Value);
            end if;
         end loop;
         return To_String (Result);
      end Desktop_Escape;

      function Desktop_Exec_Escape (Value : String) return String is
         Result : Unbounded_String;
      begin
         --  A desktop value decoder and the Exec tokenizer each consume one
         --  escaping layer. Preserve Windows separators through both layers.
         for Character_Value of Value loop
            if Character_Value = '\' then
               Append (Result, "\\\\");
            else
               Append (Result, Character_Value);
            end if;
         end loop;
         return To_String (Result);
      end Desktop_Exec_Escape;

      procedure Restore_Environment is
      begin
         if Had_Home then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Dirs then
            Ada.Environment_Variables.Set ("XDG_DATA_DIRS", To_String (Old_Dirs));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_DIRS");
         end if;
         if Had_Desktop then
            Ada.Environment_Variables.Set
              ("XDG_CURRENT_DESKTOP", To_String (Old_Desktop));
         else
            Ada.Environment_Variables.Clear ("XDG_CURRENT_DESKTOP");
         end if;
         if Had_Locale then
            Ada.Environment_Variables.Set ("LC_ALL", To_String (Old_Locale));
         else
            Ada.Environment_Variables.Clear ("LC_ALL");
         end if;
      end Restore_Environment;

      function Find
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Applications.Application is
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               return App;
            end if;
         end loop;
         return
           (Name         => Null_Unbounded_String,
            Exec         => Null_Unbounded_String,
            Icon         => Null_Unbounded_String,
            Desktop_File => Null_Unbounded_String);
      end Find;

      function Count_Name
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String) return Natural
      is
         Result : Natural := 0;
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count_Name;
   begin
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Dirs then
         Old_Dirs := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_DIRS"));
      end if;
      if Had_Desktop then
         Old_Desktop := To_Unbounded_String
           (Ada.Environment_Variables.Value ("XDG_CURRENT_DESKTOP"));
      end if;
      if Had_Locale then
         Old_Locale := To_Unbounded_String
           (Ada.Environment_Variables.Value ("LC_ALL"));
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Apps_Dir);
      Ada.Directories.Create_Path (System_Apps);

      Write_File
        (Join (Apps_Dir, "editor.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Text Editor" & LF & "Exec=editor %F" & LF);
      Write_File
        (Join (Apps_Dir, "viewer.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Image Viewer" & LF & "Exec=viewer --open %U" & LF
         & "TryExec=" & Desktop_Escape (Try_Exec) & LF
         & "Terminal=false" & LF);
      Write_File
        (Join (Apps_Dir, "multi-marker.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Multi Target Marker" & LF
         & "Exec=" & Desktop_Exec_Escape (Files_Suite.Support.Marker_Executable)
         & " %f" & LF);
      Write_File
        (Join (Apps_Dir, "quoted.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Quoted App" & LF & "Icon=quoted-icon" & LF
         & "Exec=""/opt/Quoted Editor/bin/editor"" ""--mode=two words"""
         & " %F --after %% %c %i %k" & LF);
      Write_File
        (Join (Apps_Dir, "nodisplay.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Hidden Display" & LF & "NoDisplay=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "hidden.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Gone" & LF & "Hidden=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "link.desktop"),
         "[Desktop Entry]" & LF & "Type=Link" & LF
         & "Name=A Link" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "noexec.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=No Command" & LF & "Exec=%F" & LF);
      Write_File
        (Join (Apps_Dir, "unknown-field.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Unknown Field" & LF & "Exec=viewer %Z" & LF);
      Write_File
        (Join (Apps_Dir, "unterminated.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Unterminated" & LF & "Exec=viewer ""broken" & LF);
      Write_File
        (Join (Apps_Dir, "invalid-boolean.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Invalid Boolean" & LF & "Hidden=FALSE" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-key.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Key" & LF & "Hidden=true" & LF
         & "Hidden=false" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Link" & LF
         & "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Group" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-auxiliary-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Auxiliary Group" & LF & "Exec=viewer %F" & LF
         & "[Extra]" & LF & "Value=one" & LF
         & "[Extra]" & LF & "Value=two" & LF);
      Write_File
        (Join (Apps_Dir, "malformed-line.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Malformed Line" & LF & "Hidden true" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "malformed-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Malformed Group" & LF & "Exec=viewer %F" & LF
         & "[Broken" & LF);
      Write_File
        (Join (Apps_Dir, "localized-name-only.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name[da]=Localized Name Only" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "localized-icon-only.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Localized Icon Only" & LF & "Icon[da]=localized-icon" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "missing.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Z Missing" & LF
         & "Exec=/tmp/files-open-with-definitely-missing %F" & LF);
      Write_File
        (Join (Apps_Dir, "same-one.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Shared Name" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "same-two.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Shared Name" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "masked.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Masked User Entry" & LF & "Hidden=true" & LF
         & "Exec=nope" & LF);
      Write_File
        (Join (System_Apps, "masked.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Should Stay Masked" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (System_Apps, "editor.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=System Editor" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "try-missing.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Try Missing" & LF & "Exec=viewer %F" & LF
         & "TryExec="
         & Desktop_Escape (Join (Root, "definitely-missing-try-exec")) & LF);
      Write_File
        (Join (Apps_Dir, "only-current.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=V Current Desktop" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "only-other.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Only Other Desktop" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "not-current.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Not Current Desktop" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "not-other.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=W Other Desktop Exclusion" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "both-visibility.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=X Both Visibility Lists" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF & "NotShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "escaped-desktop.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Y Escaped Desktop Name" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=Escaped\;Desktop;" & LF);
      Write_File
        (Join (Apps_Dir, "invalid-list-escape.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Invalid List Escape" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=FilesTest\q;" & LF);
      Write_File
        (Join (Apps_Dir, "overlapping-visibility.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Overlapping Visibility Lists" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF & "NotShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "localized.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Fallback\sName" & LF
         & "Name[da]=Dansk\sNavn" & LF
         & "Name[da_DK]=Dansk\sProgram" & LF
         & "Icon=base\\icon" & LF
         & "Icon[da]=danish\\icon" & LF
         & "Icon[da_DK]=regional\\icon" & LF
         & "Exec=viewer --label=%c ""C:\\\\Temp"" %F %i" & LF);

      --  Application discovery is recursive, but a linked child must never
      --  become a traversal edge back to an ancestor.
      declare
         Loop_Created : constant Boolean :=
           Files_Suite.Support.Create_Symlink (Apps_Dir, Join (Apps_Dir, "loop"));
         pragma Unreferenced (Loop_Created);
      begin
         null;
      end;

      --  A malformed or hostile application tree must also have a finite
      --  recursion cost even where directory links are unavailable.
      declare
         Deep : Unbounded_String := To_Unbounded_String (Join (Apps_Dir, "deep"));
      begin
         for Level in 1 .. 66 loop
            Append
              (Deep,
               "/" & Character'Val
                 (Character'Pos ('a') + Level mod 26));
         end loop;
         Ada.Directories.Create_Path (To_String (Deep));
         Write_File
           (Join (To_String (Deep), "too-deep.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Too Deep" & LF & "Exec=viewer %F" & LF);
      end;

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", App_Base);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_DIRS", System_Base);
      Ada.Environment_Variables.Set
        ("XDG_CURRENT_DESKTOP", "FilesTest:GNOME:Escaped;Desktop");
      Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");

      declare
         Apps : constant Files.Applications.Application_Vectors.Vector :=
           Files.Applications.Available_Applications;
         Editor : constant Files.Applications.Application := Find (Apps, "Text Editor");
         Viewer : constant Files.Applications.Application := Find (Apps, "Image Viewer");
         Quoted : constant Files.Applications.Application := Find (Apps, "Quoted App");
         Localized : constant Files.Applications.Application :=
           Find (Apps, "Dansk Program");
      begin
         Assert
           (Natural (Apps.Length) = 12,
            "valid desktop IDs are returned without collapsing shared display names");
         Assert
           (To_String (Apps.First_Element.Name) = "Dansk Program",
            "applications use and sort by the best localized decoded name");
         Assert
           (Count_Name (Apps, "Shared Name") = 2,
            "distinct desktop IDs may expose the same application name");
         Assert
           (To_String (Find (Apps, "Should Stay Masked").Exec) = ""
            and then To_String (Find (Apps, "System Editor").Exec) = "",
            "higher-priority desktop IDs mask lower-priority system entries");
         Assert
           (To_String (Find (Apps, "Try Missing").Exec) = "",
            "an unavailable TryExec keeps an application out of the picker");
         Assert
           (To_String (Find (Apps, "Invalid Boolean").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Key").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Group").Exec) = "",
            "invalid booleans, duplicate keys, and duplicate groups are rejected");
         Assert
           (To_String (Find (Apps, "Duplicate Auxiliary Group").Exec) = ""
            and then To_String (Find (Apps, "Malformed Line").Exec) = ""
            and then To_String (Find (Apps, "Malformed Group").Exec) = "",
            "malformed syntax and duplicate auxiliary groups are rejected");
         Assert
           (To_String (Find (Apps, "Localized Name Only").Exec) = ""
            and then To_String (Find (Apps, "Localized Icon Only").Exec) = "",
            "localized values require their unlocalized base keys");
         Assert
           (To_String (Find (Apps, "V Current Desktop").Exec) /= ""
            and then To_String (Find (Apps, "Only Other Desktop").Exec) = ""
            and then To_String (Find (Apps, "Not Current Desktop").Exec) = ""
            and then To_String
              (Find (Apps, "W Other Desktop Exclusion").Exec) /= "",
            "desktop visibility keys are applied to every current desktop name");
         Assert
           (To_String (Find (Apps, "X Both Visibility Lists").Exec) /= ""
            and then To_String (Find (Apps, "Y Escaped Desktop Name").Exec) /= ""
            and then To_String (Find (Apps, "Invalid List Escape").Exec) = ""
            and then To_String
              (Find (Apps, "Overlapping Visibility Lists").Exec) = "",
            "visibility lists decode escapes and permit only disjoint coexistence");
         Assert
           (To_String (Editor.Exec) = "editor %F",
            "the desktop Exec template is retained for positional expansion");
         Assert
           (To_String (Viewer.Exec) = "viewer --open %U",
            "base arguments and their target field position are retained");

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Localized, Targets);
            Assert
              (To_String (Localized.Icon) = "regional\icon"
               and then Natural (Action.Arguments.Length) = 6
               and then To_String (Action.Arguments.Element (1)) =
                 "--label=Dansk Program"
               and then To_String (Action.Arguments.Element (2)) = "C:\Temp"
               and then To_String (Action.Arguments.Element (5)) = "--icon"
               and then To_String (Action.Arguments.Element (6)) =
                 "regional\icon",
               "localized values and two-stage desktop escapes expand correctly");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Viewer, Targets);
            Assert
              (To_String (Action.Executable) = "viewer",
               "action executable is the first Exec token");
            Assert
              (not Action.Use_Shell,
               "open-with action is not shell-wrapped");
            Assert
              (Natural (Action.Arguments.Length) = 3,
               "arguments are remaining Exec tokens followed by each target");
            Assert
              (To_String (Action.Arguments.Element (1)) = "--open",
               "base Exec argument is preserved");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a.txt",
               "first target path is appended");
            Assert
              (To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "second target path is appended");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Quoted, Targets);
            Assert
              (To_String (Action.Executable) = "/opt/Quoted Editor/bin/editor",
               "a quoted desktop executable remains one executable token");
            Assert
              (Natural (Action.Arguments.Length) = 9,
               "quoted arguments and desktop field codes expand to the expected vector");
            Assert
              (To_String (Action.Arguments.Element (1)) = "--mode=two words",
               "a quoted desktop argument remains one argument");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a file.txt"
               and then To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "a list field code expands in place with argument boundaries intact");
            Assert
              (To_String (Action.Arguments.Element (4)) = "--after",
               "arguments after the target field keep their position");
            Assert
              (To_String (Action.Arguments.Element (5)) = "%",
               "a doubled percent becomes one literal percent argument");
            Assert
              (To_String (Action.Arguments.Element (6)) = "Quoted App",
               "the application-name field expands as one argument");
            Assert
              (To_String (Action.Arguments.Element (7)) = "--icon"
               and then To_String (Action.Arguments.Element (8)) = "quoted-icon",
               "the icon field expands to its two specified arguments");
            Assert
              (Hostkit.Metadata.Same_File
                 (To_String (Action.Arguments.Element (9)),
                  Join (Apps_Dir, "quoted.desktop")),
               "the desktop-file field expands to the source desktop entry");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Single_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Single Target"),
               Exec         => To_Unbounded_String ("viewer --before %f --after"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Percent_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Percent Executable"),
               Exec         => To_Unbounded_String ("viewer%%tool %F"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Actions : Files.Applications.Open_Action_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Actions := Files.Applications.Build_Open_Actions (Single_App, Targets);
            Assert
              (Natural (Actions.Length) = 2
               and then Natural (Actions.Element (1).Arguments.Length) = 3
               and then To_String (Actions.Element (1).Arguments.Element (2)) =
                 "/tmp/a.txt"
               and then Natural (Actions.Element (2).Arguments.Length) = 3
               and then To_String (Actions.Element (2).Arguments.Element (2)) =
                 "/tmp/b.txt",
               "single-file fields produce one positional launch per selected target");

            Actions := Files.Applications.Build_Open_Actions (Viewer, Targets);
            Assert
              (Natural (Actions.Length) = 1
               and then Natural (Actions.First_Element.Arguments.Length) = 3,
               "multi-file fields retain one launch containing every target");

            Action := Files.Applications.Build_Open_Action (Percent_App, Targets);
            Assert
              (To_String (Action.Executable) = "viewer%tool"
               and then Natural (Action.Arguments.Length) = 2,
               "a doubled percent is decoded in the executable token");
         end;

         declare
            Model      : Files.Model.Window_Model;
            Targets    : Files.Types.String_Vectors.Vector;
            Routed     : Files.Controller.Controller_Result;
            Marker_One : constant String := Join (Root, "open-with-first-marker");
            Marker_Two : constant String := Join (Root, "open-with-second-marker");
         begin
            Targets.Append (To_Unbounded_String (Marker_One));
            Targets.Append (To_Unbounded_String (Marker_Two));
            Files.Model.Initialize
              (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Open_Command_Palette (Model);
            Files.Model.Set_Open_With_Targets (Model, Targets);
            Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Palette_Set_Query (Model, "Multi Target Marker");
            Files.Model.Palette_Select_First (Model);

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Assert
              (Routed.Operation.Status = Files.Operations.Operation_Action_Executed
               and then Routed.Operation.Execution_Attempted
               and then Routed.Operation.Executable_Found,
               "Open With launches a single-target application for multiple selections: "
               & "status=" & Files.Operations.Operation_Status'Image (Routed.Operation.Status)
               & " attempted=" & Boolean'Image (Routed.Operation.Execution_Attempted)
               & " found=" & Boolean'Image (Routed.Operation.Executable_Found)
               & " exit=" & Integer'Image (Routed.Operation.Exit_Status)
               & " executable=" & To_String (Routed.Operation.Action_Executable));
            Assert
              (To_String (Routed.Operation.Path) = Marker_One
               and then Routed.Operation.Action_Arguments = 1
               and then To_String (Routed.Operation.Action.Arguments.First_Element) =
                 Marker_One,
               "a multi-launch result retains the first target's action metadata");

            for Attempt in 1 .. 5_000 loop
               exit when Ada.Directories.Exists (Marker_One)
                 and then Ada.Directories.Exists (Marker_Two);
               delay 0.001;
            end loop;
            Assert
              (Ada.Directories.Exists (Marker_One)
               and then Ada.Directories.Exists (Marker_Two),
               "Open With executes one %f launch for every selected target");
         end;

         declare
            Model   : Files.Model.Window_Model;
            Targets : Files.Types.String_Vectors.Vector;
            Routed  : Files.Controller.Controller_Result;
         begin
            Files.Model.Initialize
              (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Files.Model.Open_Command_Palette (Model);
            Files.Model.Set_Open_With_Targets (Model, Targets);
            Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Palette_Select_Last (Model);
            Assert
              (Files.Model.Palette_Selected_Id (Model) = 12,
               "the missing executable fixture is selected from the Open With palette");

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Assert
              (Routed.Operation.Status = Files.Operations.Operation_Failed
               and then To_String (Routed.Operation.Error_Key) =
                 "error.open_action.executable_missing",
               "Open With reports a missing application executable as failure");
            Assert
              (not Routed.Operation.Execution_Attempted
               and then not Routed.Operation.Executable_Found,
               "Open With rejects the application before attempting a process");
            Assert
              (To_String (Routed.Operation.Path) = "/tmp/a file.txt"
               and then Routed.Operation.Action_Arguments = 1,
               "the failed Open With result retains its target and action metadata");
            Assert
              (Files.Model.Last_Error_Key (Model) =
                 "error.open_action.executable_missing"
               and then not Files.Model.Command_Palette_Is_Open (Model),
               "Open With exposes the diagnostic and closes the handled picker");
         end;
      end;

      --  XDG base-directory variables never make relative paths meaningful.
      --  Change the process directory so a buggy implementation would find
      --  both fixtures, while a conforming one still sees the absolute system
      --  component that follows the invalid relative component.
      declare
         Relative_Home : constant String := Join (Root, "relative-home");
         Relative_Dirs : constant String := Join (Root, "relative-system");
         Apps : Files.Applications.Application_Vectors.Vector;
      begin
         Ada.Directories.Create_Path (Join (Relative_Home, "applications"));
         Ada.Directories.Create_Path (Join (Relative_Dirs, "applications"));
         Write_File
           (Join (Join (Relative_Home, "applications"), "relative-home.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Home" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (Join (Relative_Dirs, "applications"), "relative-dir.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Directory" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (System_Apps, "absolute-system.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Absolute System Directory" & LF & "Exec=viewer %F" & LF);

         Ada.Directories.Set_Directory (Root);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", "relative-home");
         Ada.Environment_Variables.Set
           ("XDG_DATA_DIRS", "relative-system:" & System_Base);
         Apps := Files.Applications.Available_Applications;
         Assert
           (To_String (Find (Apps, "Relative Data Home").Exec) = ""
            and then To_String (Find (Apps, "Relative Data Directory").Exec) = ""
            and then To_String (Find (Apps, "Absolute System Directory").Exec) /= "",
            "application discovery ignores relative XDG paths and keeps absolute components");
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;

      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Available_Applications;

   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "hidden-toggle");
      Settings_Path : constant String := Join (Root, "hidden-toggle-settings.txt");
      Settings      : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load          : Files.File_System.Directory_Load_Result;
      Model         : Files.Model.Window_Model;
      Result        : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "visible.txt"));
      Write_File (Join (Dir, ".hidden"));

      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Dir);
      Assert
        (Files.Model.Item_Count (Model) = 1,
         "dotfile is hidden while show-hidden is disabled");

      Result := Files.Controller.Toggle_Hidden_Files (Model, Settings, Settings_Path);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "toggle hidden files reports success");
      Assert
        (Settings.Show_Hidden_Files,
         "toggle hidden files flips the live setting to enabled");
      Assert
        (Files.Model.Item_Count (Model) = 2,
         "reloaded model includes the previously hidden dotfile");
      Assert
        (Ada.Directories.Exists (Settings_Path),
         "toggle hidden files writes the settings file to disk");

      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Load_File (Settings_Path);
      begin
         Assert (Reloaded.Success, "persisted settings file parses successfully");
         Assert
           (Reloaded.Settings.Show_Hidden_Files,
            "persisted settings file records the enabled show-hidden flag");
      end;
   end Test_Toggle_Hidden_Files;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Operation_Test_Case));
      return Result;
   end Suite;

   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Work_Item (Name : String) return Files.Paste.Work_Item is
      begin
         return
           (Source_Path => To_Unbounded_String (Join ("/src", Name)),
            Dest_Dir    => To_Unbounded_String ("/dest"),
            Dest_Name   => To_Unbounded_String (Name));
      end Work_Item;

      Items    : Files.Paste.Work_Item_Vectors.Vector;
      Existing : Files.Types.String_Vectors.Vector;
      None     : constant Files.Paste.Item_Decision_Vectors.Vector :=
        Files.Paste.Item_Decision_Vectors.Empty_Vector;
   begin
      --  a.txt and b.txt already exist at the destination; c.txt does not.
      Items.Append (Work_Item ("a.txt"));
      Items.Append (Work_Item ("b.txt"));
      Items.Append (Work_Item ("c.txt"));
      Existing.Append (To_Unbounded_String ("/dest/a.txt"));
      Existing.Append (To_Unbounded_String ("/dest/b.txt"));

      --  Replace_All: every item is written; the colliding two overwrite.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Replace_All, None, Existing);
      begin
         Assert (not Actions.Element (1).Skip and then Actions.Element (1).Replaced,
                 "replace-all overwrites the first colliding item");
         Assert (not Actions.Element (2).Skip and then Actions.Element (2).Replaced,
                 "replace-all overwrites the second colliding item");
         Assert (not Actions.Element (3).Skip and then not Actions.Element (3).Replaced
                   and then To_String (Actions.Element (3).Dest_Path) = "/dest/c.txt",
                 "replace-all writes the non-colliding item unchanged");
      end;

      --  Skip_All: colliding ones are skipped, the free one is written.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Skip_All, None, Existing);
      begin
         Assert (Actions.Element (1).Skip, "skip-all skips the first colliding item");
         Assert (Actions.Element (2).Skip, "skip-all skips the second colliding item");
         Assert (not Actions.Element (3).Skip
                   and then To_String (Actions.Element (3).Dest_Path) = "/dest/c.txt",
                 "skip-all still writes the non-colliding item");
      end;

      --  Rename_All: colliding ones are written under uniquified names.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Rename_All, None, Existing);
      begin
         Assert (not Actions.Element (1).Skip and then not Actions.Element (1).Replaced
                   and then To_String (Actions.Element (1).Dest_Path) = "/dest/a 2.txt",
                 "rename-all uniquifies the first colliding item");
         Assert (not Actions.Element (2).Skip and then not Actions.Element (2).Replaced
                   and then To_String (Actions.Element (2).Dest_Path) = "/dest/b 2.txt",
                 "rename-all uniquifies the second colliding item");
         Assert (To_String (Actions.Element (3).Dest_Path) = "/dest/c.txt",
                 "rename-all leaves the non-colliding name alone");
      end;

      --  No conflicts: every policy writes each item to its desired path.
      declare
         Empty_Existing : Files.Types.String_Vectors.Vector;
         Actions        : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Ask, None, Empty_Existing);
      begin
         Assert (not Actions.Element (1).Skip and then To_String (Actions.Element (1).Dest_Path) = "/dest/a.txt",
                 "with no conflicts the first item is written to its desired path");
         Assert (not Actions.Element (2).Skip and then To_String (Actions.Element (2).Dest_Path) = "/dest/b.txt",
                 "with no conflicts the second item is written to its desired path");
         Assert (not Actions.Element (3).Skip,
                 "with no conflicts the third item is written");
      end;
   end Test_Paste_Conflict_Resolution_Core;

   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "conflict-src");
      Dest_Dir : constant String := Join (Root, "conflict-dest");

      --  Read a file, dropping the line terminator Write_File leaves behind so the
      --  payload compares cleanly against the written text. That terminator is
      --  CRLF on Windows, not LF, and dropping only the LF left a stray CR that
      --  made every content comparison fail there.
      function Read (Path : String) return String is
         Raw  : constant String := Project_Tools.Files.Read_Raw_File (Path);
         Last : Natural := Raw'Last;
      begin
         if Last >= Raw'First and then Raw (Last) = ASCII.LF then
            Last := Last - 1;
         end if;
         if Last >= Raw'First and then Raw (Last) = ASCII.CR then
            Last := Last - 1;
         end if;
         return Raw (Raw'First .. Last);
      end Read;

      procedure Arm_Model
        (Model : out Files.Model.Window_Model;
         Names : Files.Types.String_Vectors.Vector)
      is
         Load  : Files.File_System.Directory_Load_Result;
         Paths : Files.Types.String_Vectors.Vector;
      begin
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         for Name of Names loop
            Paths.Append (To_Unbounded_String (Join (Src_Dir, To_String (Name))));
         end loop;
         Files.Model.Set_Clipboard (Model, Paths, Files.Model.Clipboard_Copy);
      end Arm_Model;

      One_File : Files.Types.String_Vectors.Vector;
      Two_File : Files.Types.String_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Resolved : Files.Operations.Operation_Result;
   begin
      One_File.Append (To_Unbounded_String ("a.txt"));
      Two_File.Append (To_Unbounded_String ("a.txt"));
      Two_File.Append (To_Unbounded_String ("b.txt"));

      --  Replace: the paste overwrites the destination.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      pragma Unreferenced (Routed);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "a colliding paste arms the conflict dialog");
      Assert (Files.Model.Paste_Conflict_Name (Model) = "a.txt", "the dialog names the colliding item");
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, False);
      Assert (Resolved.Status = Files.Operations.Operation_Success, "replace resolves successfully");
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "SRC",
              "replace overwrites the destination with the source; destination holds "
              & Read (Join (Dest_Dir, "a.txt")));

      --  Skip: the destination is left untouched and the source remains.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Skip, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "skip clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "skip leaves the destination untouched");
      Assert (Ada.Directories.Exists (Join (Src_Dir, "a.txt")), "skip leaves the source in place");

      --  Rename: a uniquely named copy is created and the original is kept.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "rename clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "rename keeps the original destination");
      Assert (Read (Join (Dest_Dir, "a 2.txt")) = "SRC", "rename writes the source under a unique name");

      --  Undo of the completed rename paste removes the created copy.
      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")), "undo removes the pasted copy");
      Assert (Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "undo keeps the pre-existing original");

      --  Apply-to-all: one decision resolves every remaining conflict.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRCA");
      Write_File (Join (Src_Dir, "b.txt"), "SRCB");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Write_File (Join (Dest_Dir, "b.txt"), "DEST");
      Arm_Model (Model, Two_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "two collisions arm the dialog");
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, True);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "apply-to-all resolves both without a second prompt");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "SRCA", "apply-to-all replaces the first item");
      Assert (Read (Join (Dest_Dir, "b.txt")) = "SRCB", "apply-to-all replaces the second item");

      --  Cancel: the whole paste aborts with no filesystem change.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Cancel, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "cancel clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "cancel changes nothing at the destination");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")), "cancel writes no copy");
      Assert (Files.Model.Clipboard_Has_Items (Model), "cancel keeps the clipboard for a retry");
   end Test_Paste_Conflict_Flow;

   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "exec-src");
      Dest_Dir : constant String := Join (Root, "exec-dest");
      Count    : constant := 5;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      function Img (N : Integer) return String is
      begin
         return Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both);
      end Img;

      function Src (N : Positive) return String is (Join (Src_Dir, "f" & Img (N) & ".txt"));
      function Dest (N : Positive) return String is (Join (Dest_Dir, "f" & Img (N) & ".txt"));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Src (N), "S" & Img (N));
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Src (N)),
               Dest_Path   => To_Unbounded_String (Dest (N)),
               Skip        => False,
               Replaced    => False));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "arming a paste execution activates it");
      Assert (Files.Model.Paste_Execution_Total (Model) = Count, "the total counts every write action");
      Assert (Files.Model.Paste_Execution_Done (Model) = 0, "nothing is done before the first advance");

      --  Max_Items = 2 over 5 actions => completes after ceil(5 / 2) = 3 calls.
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (Step.Status = Files.Operations.Operation_Success, "the first batch reports success");
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "the execution is still in progress after one batch");
      Assert (Files.Model.Paste_Execution_Done (Model) = 2, "the first batch completes two writes");

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "the execution is still in progress after two batches");
      Assert (Files.Model.Paste_Execution_Done (Model) = 4, "progress advances to four writes");

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the third batch finalizes the execution");

      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Dest (N)), "every source is copied to the destination");
         Assert (Ada.Directories.Exists (Src (N)), "a copy leaves the sources in place");
      end loop;

      Assert (Files.Model.Undo_Available (Model), "the completed paste records an undo");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Delete_Created,
         "a copy paste is undone by deleting the created copies");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = Count,
         "one undo covers the whole completed set");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "undo of the paste succeeds");
      for N in 1 .. Count loop
         Assert (not Ada.Directories.Exists (Dest (N)), "undo removes each pasted copy");
      end loop;
   end Test_Paste_Execution_Batches;

   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "cancel-src");
      Dest_Dir : constant String := Join (Root, "cancel-dest");
      Count    : constant := 4;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);

      function Img (N : Integer) return String is
      begin
         return Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both);
      end Img;

      function Src (N : Positive) return String is (Join (Src_Dir, "f" & Img (N) & ".txt"));
      function Dest (N : Positive) return String is (Join (Dest_Dir, "f" & Img (N) & ".txt"));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Src (N), "S" & Img (N));
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Src (N)),
               Dest_Path   => To_Unbounded_String (Dest (N)),
               Skip        => False,
               Replaced    => False));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (Files.Model.Paste_Execution_Done (Model) = 2, "two writes complete before cancelling");

      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "a cancelled paste finalizes on the next advance");

      Assert (Ada.Directories.Exists (Dest (1)), "the first completed copy is kept");
      Assert (Ada.Directories.Exists (Dest (2)), "the second completed copy is kept");
      Assert (not Ada.Directories.Exists (Dest (3)), "cancelling writes none of the remaining sources");
      Assert (not Ada.Directories.Exists (Dest (4)), "cancelling writes none of the remaining sources");
      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Src (N)), "all sources remain after a cancelled copy");
      end loop;

      Assert (Files.Model.Undo_Available (Model), "a cancelled paste still records an undo for completed items");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = 2,
         "the undo covers only the two completed writes");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (not Ada.Directories.Exists (Dest (1)), "undo removes the first completed copy");
      Assert (not Ada.Directories.Exists (Dest (2)), "undo removes the second completed copy");
   end Test_Paste_Execution_Cancel;

   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "small-src");
      Dest_Dir : constant String := Join (Root, "small-dest");
      Source   : constant String := Join (Src_Dir, "only.txt");
      Dest     : constant String := Join (Dest_Dir, "only.txt");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Source, "ONLY");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Source),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => False));

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);

      --  A single-item paste finishes within the first advance and leaves no
      --  lingering execution state (so no progress overlay is ever shown).
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
      Assert (Step.Status = Files.Operations.Operation_Success, "the one-item paste reports success");
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the one-item paste clears its execution state");
      Assert (Ada.Directories.Exists (Dest), "the one item is copied to the destination");
   end Test_Paste_Execution_Small_Op;

   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "dropc-src");
      Dest_Dir : constant String := Join (Root, "dropc-dest");
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;

      --  The terminator Write_File leaves is CRLF on Windows, not LF.
      function Read (Path : String) return String is
         Raw  : constant String := Project_Tools.Files.Read_Raw_File (Path);
         Last : Natural := Raw'Last;
      begin
         if Last >= Raw'First and then Raw (Last) = ASCII.LF then
            Last := Last - 1;
         end if;
         if Last >= Raw'First and then Raw (Last) = ASCII.CR then
            Last := Last - 1;
         end if;
         return Raw (Raw'First .. Last);
      end Read;

      --  Reset the fixture and initialize the model on the destination directory
      --  (the drop target), returning the single external source to drop.
      function Prepare return Files.Types.String_Vectors.Vector is
         Load    : Files.File_System.Directory_Load_Result;
         Sources : Files.Types.String_Vectors.Vector;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, "a.txt"), "SRC");
         Write_File (Join (Dest_Dir, "a.txt"), "DEST");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Sources.Append (To_Unbounded_String (Join (Src_Dir, "a.txt")));
         return Sources;
      end Prepare;
   begin
      --  Replace: the dropped source overwrites the colliding destination.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Assert
           (Routed.Operation.Status = Files.Operations.Operation_Success,
            "an armed drop conflict reports success without writing");
         Assert (Files.Model.Paste_Conflict_Is_Active (Model), "a colliding drop arms the conflict dialog");
         Assert (Files.Model.Paste_Conflict_Name (Model) = "a.txt", "the drop dialog names the colliding item");
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, False);
         Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving the drop clears the dialog");
         Assert (Read (Join (Dest_Dir, "a.txt")) = "SRC",
              "replace overwrites the destination with the dropped source; destination holds "
              & Read (Join (Dest_Dir, "a.txt")));
      end;

      --  Skip: the destination and the source both stay untouched.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Skip, False);
         Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "skip leaves the drop destination untouched");
         Assert (Ada.Directories.Exists (Join (Src_Dir, "a.txt")), "skip leaves the dropped source in place");
      end;

      --  Rename: a uniquely named copy is written, then undo removes it.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
         Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "rename keeps the original drop destination");
         Assert (Read (Join (Dest_Dir, "a 2.txt")) = "SRC", "rename writes the dropped source under a unique name");
         Routed.Operation := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert
           (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")),
            "undo reverses a completed drag-and-drop import");
         Assert (Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "undo keeps the pre-existing original");
      end;

      --  A drag-and-drop move must not clear an unrelated clipboard selection.
      declare
         Load      : Files.File_System.Directory_Load_Result;
         Sources   : Files.Types.String_Vectors.Vector;
         Clip      : Files.Types.String_Vectors.Vector;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, "m.txt"), "MOVE");
         Write_File (Join (Dest_Dir, "clip.txt"), "CLIP");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Clip.Append (To_Unbounded_String (Join (Dest_Dir, "clip.txt")));
         Files.Model.Set_Clipboard (Model, Clip, Files.Model.Clipboard_Copy);
         Sources.Append (To_Unbounded_String (Join (Src_Dir, "m.txt")));
         Routed :=
           Files.Controller.Handle_Drop_Import (Model, Settings, Sources, Files.File_System.Drop_Move);
         Assert
           (Routed.Operation.Status = Files.Operations.Operation_Success,
            "a collision-free dropped move succeeds");
         Assert
           (Ada.Directories.Exists (Join (Dest_Dir, "m.txt")),
            "a collision-free dropped move imports the source");
         Assert (not Ada.Directories.Exists (Join (Src_Dir, "m.txt")), "a dropped move removes the source");
         Assert
           (Files.Model.Clipboard_Has_Items (Model),
            "a dropped move does not clear the unrelated clipboard selection");
      end;
   end Test_Drop_Import_Conflict_Flow;

   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "dropp-src");
      Dest_Dir : constant String := Join (Root, "dropp-dest");
      Count    : constant := 40;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Sources  : Files.Types.String_Vectors.Vector;
      Routed   : Files.Controller.Controller_Result;
      Step     : Files.Operations.Operation_Result;

      function Img (N : Integer) return String is
      begin
         return Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both);
      end Img;

      function Src (N : Positive) return String is (Join (Src_Dir, "f" & Img (N) & ".txt"));
      function Dest (N : Positive) return String is (Join (Dest_Dir, "f" & Img (N) & ".txt"));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Src (N), "S" & Img (N));
         Sources.Append (To_Unbounded_String (Src (N)));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);

      --  A collision-free drop arms the resumable executor and runs the first
      --  batch; a set larger than one batch keeps the progress state active.
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "large drop import reports success");
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "a large drop keeps the progress executor active");
      Assert (Files.Model.Paste_Execution_Total (Model) = Count, "the drop progress total counts every source");
      Assert (Files.Model.Paste_Execution_Done (Model) < Count, "the first drop batch does not finish the whole set");

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, Count);
      Assert (Step.Status = Files.Operations.Operation_Success, "advancing the drop executor reports success");
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the drop executor finalizes after the last batch");

      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Dest (N)), "every dropped source is imported to the destination");
         Assert (Ada.Directories.Exists (Src (N)), "a dropped copy leaves the sources in place");
      end loop;
      Assert (Files.Model.Item_Count (Model) = Count, "the collision-free drop refreshes the destination model");
   end Test_Drop_Import_Progress;

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

   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "copyto-src");
      Dest_Dir : constant String := Join (Root, "copyto-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      B_Src    : constant String := Join (Src_Dir, "b.txt");
      A_Dest   : constant String := Join (Dest_Dir, "a.txt");
      B_Dest   : constant String := Join (Dest_Dir, "b.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Undone   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");
      Write_File (B_Src, "BBB");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Copy_To_Command, Model),
         "copy-to is enabled with a real selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "copy-to command starts the picker");
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "copy-to opens the folder tree");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the destination picker is active");
      Assert
        (Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Copy,
         "the picker records copy intent");
      Assert
        (Natural (Files.Model.Tree_Pick_Sources (Model).Length) = 2,
         "the picker captured both selected sources");

      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);
      Confirm_Pick (Model, Settings);

      Assert (Ada.Directories.Exists (A_Dest), "a.txt is copied to the destination");
      Assert (Ada.Directories.Exists (B_Dest), "b.txt is copied to the destination");
      Assert (Ada.Directories.Exists (A_Src), "a.txt original is kept");
      Assert (Ada.Directories.Exists (B_Src), "b.txt original is kept");
      Assert (not Files.Model.Tree_Pick_Is_Active (Model), "confirming clears the picker");
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "confirming closes the folder tree");

      Undone := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Undone.Status = Files.Operations.Operation_Success, "the copy is undoable");
      Assert (not Ada.Directories.Exists (A_Dest), "undo removes the a.txt copy");
      Assert (not Ada.Directories.Exists (B_Dest), "undo removes the b.txt copy");
      Assert (Ada.Directories.Exists (A_Src), "undo keeps the a.txt original");
   end Test_Copy_To_Picker_Flow;

   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "moveto-src");
      Dest_Dir : constant String := Join (Root, "moveto-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      A_Dest   : constant String := Join (Dest_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Undone   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Move_To_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "move-to command starts the picker");
      Assert
        (Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Move,
         "the picker records move intent");

      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);
      Confirm_Pick (Model, Settings);

      Assert (Ada.Directories.Exists (A_Dest), "a.txt is moved to the destination");
      Assert (not Ada.Directories.Exists (A_Src), "a.txt is removed from the source");

      Undone := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Undone.Status = Files.Operations.Operation_Success, "the move is undoable");
      Assert (Ada.Directories.Exists (A_Src), "undo returns a.txt to the source");
      Assert (not Ada.Directories.Exists (A_Dest), "undo removes a.txt from the destination");
   end Test_Move_To_Picker_Flow;

   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "selfguard-src");
      Box_Dir  : constant String := Join (Src_Dir, "box");
      Inside   : constant String := Join (Box_Dir, "inside.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Box_Dir);
      Write_File (Inside, "IN");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "box");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "copy-to command starts the picker");

      --  Target the selected directory itself: copying it into itself must fail.
      Files.Model.Set_Tree_Pick_Target (Model, Box_Dir);
      Confirm_Pick (Model, Settings);

      Assert
        (Files.Model.Last_Error_Key (Model) = "error.drop.into_self",
         "targeting inside the selection reports the into-self error");
      Assert (not Ada.Directories.Exists (Join (Box_Dir, "box")), "nothing is copied into the selected folder");
      Assert (Ada.Directories.Exists (Inside), "the selected folder is unchanged");
   end Test_Copy_To_Into_Self_Guard;

   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "cancel-src");
      Dest_Dir : constant String := Join (Root, "cancel-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "copy-to command starts the picker");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker is active after the command");
      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);

      --  Cancel is routed through the tree-toggle command (also used by the
      --  Cancel button and the panel close box): it closes the tree and clears
      --  the picker without writing anything.
      Routed := Files.Controller.Execute_Command (Files.Commands.Toggle_Folder_Tree_Command, Model, Settings);
      Assert
        (Routed.Status = Files.Controller.Controller_Command_Executed, "the cancel command is executed");
      Assert (not Files.Model.Tree_Pick_Is_Active (Model), "cancelling clears the picker");
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "cancelling closes the folder tree");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "cancelling copies nothing");
      Assert (Ada.Directories.Exists (A_Src), "cancelling leaves the source unchanged");
   end Test_Copy_To_Cancel;

   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "label-src");
      Dest_Dir : constant String := Join (Root, "label-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker is active after the command");

      --  Reseed the tree with the destination as its only node so the label
      --  click has a deterministic target.
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Dest_Dir), Name => To_Unbounded_String ("label-dest")));
      Files.Model.Seed_Tree (Model, Seeds);

      --  A label click (Toggle => False) while picking sets the target and must
      --  not navigate the main view away from the source directory.
      Routed := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => False);
      Assert
        (Routed.Status = Files.Controller.Controller_Command_Executed,
         "the label click is handled");
      Assert
        (Files.Model.Tree_Pick_Target (Model) = Dest_Dir,
         "the label click sets the highlighted target");
      Assert
        (Files.Model.Current_Path (Model) = Src_Dir,
         "the label click does not navigate the main view");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker stays active after choosing a target");
   end Test_Copy_To_Tree_Label_Sets_Target;

   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Old_Cwd : constant String := Ada.Directories.Current_Directory;
      Dir_A : constant String := Join (Root, "recent-duplicate-a");
      Dir_B : constant String := Join (Root, "recent-duplicate-b");
      Cwd : constant String := Join (Root, "unrelated-cwd");
      Source_A : constant String := Join (Dir_A, "report.txt");
      Source_B : constant String := Join (Dir_B, "report.txt");
      Existing : constant String := Join (Dir_A, "report (copy).txt");
      Copy_A : constant String := Join (Dir_A, "report (copy 2).txt");
      Copy_B : constant String := Join (Dir_B, "report (copy).txt");
      Bundle : constant String := Join (Dir_B, "bundle");
      Copy_Bundle : constant String := Join (Dir_B, "bundle (copy)");
      Unselected : constant String := Join (Dir_A, "unselected.txt");
   begin
      for Background in Boolean loop
         Reset_Root;
         declare
            Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Model : Files.Model.Window_Model;
            Step : Files.Operations.Operation_Result;
            Expected_Rows : Files.Types.String_Vectors.Vector;

            procedure Check_Recent is
            begin
               Assert (Files.Model.In_Recent_View (Model) and then Files.Model.Current_Path (Model) = ""
                       and then Files.Model.Visible_Count (Model) = Natural (Expected_Rows.Length),
                       "Duplicate and history operations retain the complete Recent view");
               for Index in Expected_Rows.First_Index .. Expected_Rows.Last_Index loop
                  Assert (Files.Model.Visible_Item (Model, Index).Full_Path = Expected_Rows.Element (Index),
                          "Recent keeps its order and its unselected rows after helper completion");
               end loop;
               Assert (Files.File_System.Directory_State (Cwd).Entry_Count = 1
                       and then File_Has_Bytes (Join (Cwd, "keep.txt"), "unrelated cwd bytes"),
                       "Duplicate never writes to the process working directory");
            end Check_Recent;

            procedure Check_Copies is
            begin
               Assert (File_Has_Bytes (Copy_A, "source a bytes") and then File_Has_Bytes (Copy_B, "source b bytes"),
                       "same-name Recent files duplicate beside their own sources with independent collision handling");
               Assert (File_Has_Bytes (Join (Copy_Bundle, "payload.txt"), "bundle bytes"),
                       "a Recent directory duplicates beside its source with complete contents");
               Assert (File_Has_Bytes (Existing, "existing copy bytes")
                       and then File_Has_Bytes (Source_A, "source a bytes")
                       and then File_Has_Bytes (Source_B, "source b bytes")
                       and then File_Has_Bytes (Unselected, "unselected bytes"),
                       "Duplicate preserves sources, existing copies and unselected items");
            end Check_Copies;

            procedure Await_Refresh is
               Applied : Boolean := False;
            begin
               if Background then
                  for Attempt in 1 .. 5_000 loop
                     Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
                     exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
                     delay 0.001;
                  end loop;
                  Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                          "history refresh applies to the Recent view after a duplicate");
               end if;
            end Await_Refresh;
         begin
            Ada.Directories.Create_Path (Dir_A);
            Ada.Directories.Create_Path (Bundle);
            Ada.Directories.Create_Path (Cwd);
            Write_Binary_File (Source_A, "source a bytes");
            Write_Binary_File (Source_B, "source b bytes");
            Write_Binary_File (Existing, "existing copy bytes");
            Write_Binary_File (Join (Bundle, "payload.txt"), "bundle bytes");
            Write_Binary_File (Unselected, "unselected bytes");
            Write_Binary_File (Join (Cwd, "keep.txt"), "unrelated cwd bytes");
            Files.Settings.Note_Recent (Settings, Source_A);
            Files.Settings.Note_Recent (Settings, Source_B);
            Files.Settings.Note_Recent (Settings, Bundle);
            Files.Settings.Note_Recent (Settings, Unselected);
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Step := Files.Operations.Navigate_Recent (Model, Settings);
            Files.Model.Select_All_Visible (Model);
            for Index in 1 .. Files.Model.Visible_Count (Model) loop
               Expected_Rows.Append (Files.Model.Visible_Item (Model, Index).Full_Path);
               if Files.Model.Visible_Item (Model, Index).Full_Path = To_Unbounded_String (Unselected) then
                  Files.Model.Toggle_Visible_Selection (Model, Index);
               end if;
            end loop;
            Assert (Files.Model.Selected_Count (Model) = 3, "select files from two folders and one directory");
            Files.Model.Set_Background_Transfers (Model, Background);
            Ada.Directories.Set_Directory (Cwd);
            Step := Files.Operations.Duplicate_Selected (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Recent Duplicate starts or completes successfully");
            if Background then
               for Attempt in 1 .. 5_000 loop
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                  exit when not Files.Model.Paste_Execution_Is_Active (Model);
                  delay 0.001;
               end loop;
            end if;
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Files.Model.Paste_Execution_Is_Active (Model)
                    and then Files.Model.Last_Error_Key (Model) = ""
                    and then Files.Model.Undo_Available (Model),
                    "Recent Duplicate reports success and records all created paths for Undo");
            Check_Recent;
            Check_Copies;
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (Copy_A) and then not Ada.Directories.Exists (Copy_B)
                    and then not Ada.Directories.Exists (Copy_Bundle),
                    "Undo removes every adjacent copy from its source folder");
            Await_Refresh;
            Check_Recent;
            Assert (File_Has_Bytes (Existing, "existing copy bytes"), "Undo preserves the pre-existing copy collision");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Redo re-creates the recorded adjacent destinations");
            Await_Refresh;
            Check_Recent;
            Check_Copies;
            Ada.Directories.Set_Directory (Old_Cwd);
         end;
      end loop;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Cwd);
         raise;
   end Test_Recent_Duplicate;

   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir       : constant String := Join (Root, "recent-dir");
      File_Name : constant String := Join (Root, "recent-file.txt");
      Missing   : constant String := Join (Root, "recent-gone.txt");
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items     : Files.File_System.Item_Vectors.Vector;
      Model     : Files.Model.Window_Model;
      Result    : Files.Operations.Operation_Result;
      Dir_Index : Natural := 0;

      function Find_Visible (Name : String) return Natural is
      begin
         for I in 1 .. Files.Model.Item_Count (Model) loop
            if Files.Model.Visible_Item (Model, I).Name = To_Unbounded_String (Name) then
               return I;
            end if;
         end loop;
         return 0;
      end Find_Visible;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (File_Name);

      --  Seed the recent list: folder, then file, then a now-missing path. The
      --  missing entry must be skipped when the view materializes.
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (Dir));
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (File_Name));
      Files.Settings.Note_Recent (Settings, Missing);

      --  Start from an ordinary directory so entering the view records history.
      Items.Append (Files.File_System.Make_Item (Root, "recent-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);

      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Navigated, "entering the recent view navigates");
      Assert (Files.Model.In_Recent_View (Model), "the recent view is active after Navigate_Recent");
      Assert (Files.Model.Item_Count (Model) = 2, "the missing recent path is skipped from the listing");
      Assert (Find_Visible ("recent-file.txt") > 0, "the recent file is listed");
      Assert (Find_Visible ("recent-dir") > 0, "the recent folder is listed");
      Assert (Files.Model.Can_Go_Back (Model), "entering the recent view records back history");

      --  Double-click the folder: it opens (navigates in) and leaves the view.
      Dir_Index := Find_Visible ("recent-dir");
      declare
         Routed : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Item_Click
             (Model, Settings, Visible_Index => Dir_Index, Activate => True);
      begin
         Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated,
                 "double-clicking a recent folder opens it");
         Assert (not Files.Model.In_Recent_View (Model), "opening a folder leaves the recent view");
         Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir),
                 "opening a recent folder navigates into it");
      end;

      --  Re-enter, then clear: the view rebuilds empty.
      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Files.Model.Item_Count (Model) = 2, "re-entering the recent view relists the items");
      Files.Settings.Clear_Recent (Settings);
      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Files.Model.In_Recent_View (Model), "the view stays active after clearing");
      Assert (Files.Model.Item_Count (Model) = 0, "clearing empties the recent listing");
   end Test_Recent_View_Operation;

   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Search_Root : constant String := Join (Root, "content-search");
      Nested      : constant String := Join (Search_Root, "nested");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Routed   : Files.Controller.Controller_Result;
      Big      : String (1 .. 70_000) := [others => 'a'];
   begin
      --  Pure match seam: case-insensitive substring, binary and empty handled.
      Assert (Files.Operations.Content_Matches ("The Needle is here", "needle"),
              "content match is case-insensitive");
      Assert (not Files.Operations.Content_Matches ("nothing relevant", "needle"),
              "content match misses when the query is absent");
      Assert (not Files.Operations.Content_Matches ("needle", ""),
              "an empty query never matches");
      Assert (not Files.Operations.Content_Matches ("", "needle"),
              "empty bytes never match");
      Assert
        (not Files.Operations.Content_Matches ("nee" & Character'Val (0) & "dle needle", "needle"),
         "binary bytes (NUL) are skipped even when the query text is present");

      Reset_Root;
      Ada.Directories.Create_Path (Search_Root);
      Ada.Directories.Create_Path (Nested);
      Write_File (Join (Search_Root, "top-match.txt"), "alpha NEEDLE omega");
      Write_File (Join (Nested, "deep-match.txt"), "hidden needle inside");
      Write_File (Join (Search_Root, "plain.txt"), "nothing to see here");
      Write_Binary_File
        (Join (Search_Root, "binary.dat"), "needle" & Character'Val (0) & "needle");
      Big (Big'Last - 5 .. Big'Last) := "needle";

      Load := Files.File_System.Load_Directory (Search_Root, Settings);
      Files.Model.Initialize (Model, Search_Root, Load.Items, Root);

      --  Default scope is Filter_Here and the command is disabled without a query.
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "a freshly loaded directory defaults to the Filter_Here scope");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Search_Contents_Command, Model),
         "content search is disabled without filter text");

      Files.Model.Set_Filter (Model, "needle");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Search_Contents_Command, Model),
         "content search is enabled once the filter has text");

      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Search_Contents_Command,
         "content search routes through the command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "content search command succeeds");
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Contents,
         "running content search sets the Search_Contents scope");
      Assert (Files.Model.Search_Results_Are_Active (Model), "content search shows search results");
      Assert
        (Files.Model.Item_Count (Model) = 2,
         "content search returns only the two textual files whose contents match, "
         & "skipping binary and non-matching files");

      Assert (Files.Model.Visible_Count (Model) = 2,
              "content-search matches stay visible even when the filenames do not match the query");

      --  Search_Recursive_Command uses the Names scope on the same query.
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Names,
         "recursive name search sets the Search_Names scope");

      --  Clearing the filter returns to Filter_Here and drops search-results state.
      Files.Commands.Execute (Files.Commands.Clear_Filter_Command, Model);
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "clearing the filter returns to the Filter_Here scope");
      Assert
        (not Files.Model.Search_Results_Are_Active (Model),
         "clearing the filter drops the search-results state");

      --  A byte cap cannot silently omit a match beyond the preview window.
      Write_File (Join (Search_Root, "oversize.txt"), Big);
      Files.Model.Set_Filter (Model, "needle");
      Routed := Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Failed
              and then Files.Model.Last_Error_Key (Model) = "error.search.failed",
              "content search reports an incomplete oversized file instead of silently skipping it");

      --  An empty query performs no search.
      Files.Model.Set_Filter (Model, "");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Disabled,
         "an empty query performs no content search");
   end Test_Content_Search_Operation;

   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "chunk-source");
      Dest   : constant String := Join (Root, "chunk-dest");
      Plans  : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Result : Files.File_System.Mutation_Result;
      Checks : Natural := 0;

      function Cancelled return Boolean is
      begin
         Checks := Checks + 1;
         if Checks = 4 then
            Assert (Ada.Directories.Size (Join (Join (Root, ".files-work-1"), "payload")) = 65_536,
                    "cancellation occurs after the first chunk has been written");
         end if;
         return Checks >= 4;
      end Cancelled;
   begin
      Reset_Root;
      Write_Binary_File (Source, [1 .. 262_144 => 'x']);
      Plans.Append
        (Files.File_System.Drop_Import_Plan'
           (Source_Path      => To_Unbounded_String (Source),
            Destination_Path => To_Unbounded_String (Dest),
            Mode             => Files.File_System.Drop_Copy,
            Valid            => True,
            Error_Key        => Null_Unbounded_String));
      Result := Files.File_System.Execute_Drop_Import (Plans, Cancelled'Unrestricted_Access);
      Assert (not Result.Success and then Checks >= 4, "cancellation interrupts a file after copying begins");
      Assert (not Ada.Directories.Exists (Dest), "cancellation removes the incomplete destination");
      Assert (Ada.Directories.Size (Source) = 262_144, "the complete source survives cancellation");

      --  A destination created after planning is someone else's data.
      Write_Binary_File (Dest, "keep");
      Result := Files.File_System.Execute_Drop_Import (Plans);
      Assert (not Result.Success, "a late destination collision fails");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "keep", "collision cleanup never removes unrelated data");
      Plans.Clear;
      Plans.Append
        (Files.File_System.Drop_Import_Plan'
           (Source_Path      => To_Unbounded_String (Source),
            Destination_Path => To_Unbounded_String (Source),
            Mode             => Files.File_System.Drop_Copy,
            Valid            => True,
            Error_Key        => Null_Unbounded_String));
      Result := Files.File_System.Execute_Drop_Import (Plans);
      Assert (not Result.Success, "copying onto the source is refused");
      Assert (Ada.Directories.Size (Source) = 262_144, "a self-copy never truncates or deletes its source");
   end Test_Transfer_Cancellation;

   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "worker-source");
      Dest_Dir : constant String := Join (Root, "worker-dest");
      Dest     : constant String := Join (Dest_Dir, "worker-source");
      Action   : Files.Paste.Resolved_Action;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Job      : Files.Transfer_Jobs.Session;
      Finished : Boolean := False;
      Outcome  : Files.Transfer_Jobs.Job_Result;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dest_Dir);
      Write_Binary_File (Source, [1 .. 262_144 => 'w']);
      Action := (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False);
      Files.Transfer_Jobs.Start (Job, Action, Files.File_System.Drop_Copy);
      declare
         Other_Owner : constant Files.Transfer_Jobs.Session := Job;
      begin
         Files.Transfer_Jobs.Reset (Job);
         for Attempt in 1 .. 5_000 loop
            Files.Transfer_Jobs.Poll (Other_Owner, Finished, Outcome);
            exit when Finished;
            delay 0.001;
         end loop;
         Assert (Finished and then Outcome.Mutation.Success, "a copied session keeps its worker alive");
      end;
      Assert
        (Project_Tools.Files.Read_Raw_File (Dest) = Project_Tools.Files.Read_Raw_File (Source),
         "the worker copies every byte");

      Ada.Directories.Delete_File (Dest);
      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Actions.Append (Action);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      for Attempt in 1 .. 5_000 loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
         delay 0.001;
      end loop;
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the UI collects a completed background action");
      Assert (Step.Status = Files.Operations.Operation_Success, "background completion reports success");
      Assert (Files.Model.Undo_Available (Model), "background writes record undo on the UI thread");
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (not Ada.Directories.Exists (Dest), "undo removes a background copy");

      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "cancellation before launch finalizes immediately");
      Assert (not Ada.Directories.Exists (Dest), "a cancelled background action writes nothing");

      --  Cancellation of an already-started worker must never publish a partial
      --  file. A worker that won the race may legitimately finish the whole copy.
      declare
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : constant Ada.Streams.Stream_Element_Array (1 .. 65_536) := [others => 42];
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Source);
         for Chunk in 1 .. 128 loop
            Ada.Streams.Stream_IO.Write (File, Buffer);
         end loop;
         Ada.Streams.Stream_IO.Close (File);
      end;
      Files.Transfer_Jobs.Start (Job, Action, Files.File_System.Drop_Copy);
      Files.Transfer_Jobs.Cancel (Job);
      for Attempt in 1 .. 5_000 loop
         Files.Transfer_Jobs.Poll (Job, Finished, Outcome);
         exit when Finished;
         delay 0.001;
      end loop;
      Assert (Finished, "an already-started worker responds to cancellation");
      Assert (Ada.Directories.Size (Source) = 8_388_608, "worker cancellation retains the complete source");
      if Outcome.Mutation.Success then
         Assert (Ada.Directories.Size (Dest) = 8_388_608, "a worker completing before cancellation keeps a full copy");
      else
         Assert (Outcome.Cancelled, "an interrupted worker reports cancellation");
         Assert (not Ada.Directories.Exists (Dest), "an interrupted worker removes its incomplete output");
      end if;
      Files.Transfer_Jobs.Reset (Job);
   end Test_Background_Transfers;

   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "replacement-source");
      Dest     : constant String := Join (Root, "replacement-original");
      Blocker  : constant String := Join (Root, "trash-blocker");
      Had_Xdg  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg  : constant String :=
        (if Had_Xdg then
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      Reset_Root;
      Write_Binary_File (Source, "new");
      Write_Binary_File (Dest, "original");
      Write_Binary_File (Blocker, "not a directory");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Blocker);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, True));
      for Background in Boolean loop
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, Background);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
         for Attempt in 1 .. 5_000 loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
            delay 0.001;
         end loop;
         Assert (not Files.Model.Paste_Execution_Is_Active (Model), "a failed Replace finishes its execution");
         Assert (Step.Status = Files.Operations.Operation_Failed, "a trash failure aborts Replace");
         Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "Replace keeps the original on trash failure");
      end loop;
      Restore_Environment;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Restore_Environment;
         raise;
   end Test_Replace_Trash_Failure;

   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Unbounded_String;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      Tree     : constant String := Join (Root, "recovery-tree");
      Locked   : constant String := Join (Tree, "locked");
      Had_Xdg  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg  : constant String :=
        (if Had_Xdg then
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Paths    : Files.Types.String_Vectors.Vector;
      Plans    : Files.File_System.Drop_Import_Result;
      Result   : Files.File_System.Mutation_Result;
      Trashed  : Unbounded_String;

      procedure Unlock (Path : String) is
         Result : constant Files.File_System.Mutation_Result := Files.File_System.Set_Permissions (Path, 8#755#);
         pragma Unreferenced (Result);
      begin
         null;
      end Unlock;

      procedure Cleanup is
      begin
         Files.Job_Context.Initialize ("");
         Unlock (Locked);
         if Length (Trashed) > 0 then
            Unlock (Join (To_String (Trashed), "locked"));
         end if;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
         Restore_Tmp;
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Cleanup;

      procedure Prepare_Tree is
      begin
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Tree, "a.txt"), "complete");
         Write_Binary_File (Join (Locked, "b.txt"), "locked");
      end Prepare_Tree;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Reset_Root;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-recovery-"));
      Restore_Tmp;
      Assert (Length (Remote) > 0, "create a unique cross-device recovery fixture");
      Write_Binary_File (Join (Root, "mount-probe"), "probe");
      begin
         Ada.Directories.Rename (Join (Root, "mount-probe"), Join (To_String (Remote), "mount-probe"));
         Cleanup;
         return; --  No distinct filesystem available on this host.
      exception
         when Ada.Directories.Use_Error => null;
      end;
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock source deletion but permit copying");
      Paths.Append (To_Unbounded_String (Tree));
      Plans := Files.File_System.Plan_Drop_Import (Paths, To_String (Remote), Files.File_System.Drop_Move);
      Result := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "a copied directory move commits by atomically vacating the source pathname");
      Assert
        (Project_Tools.Files.Read_Raw_File (Join (Join (To_String (Remote), "recovery-tree"), "a.txt")) = "complete"
         and then File_Has_Bytes
           (Join (Join (Join (To_String (Remote), "recovery-tree"), "locked"), "b.txt"), "locked"),
         "refused source cleanup cannot invalidate the complete move destination");
      Unlock (Join (Join (Join (Root, ".files-recovery-1"), "payload"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (Root, ".files-recovery-1"));
      Unlock (Join (Join (To_String (Remote), "recovery-tree"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (To_String (Remote), "recovery-tree"));

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (To_String (Remote), "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock the trash source deletion");
      Result := Files.File_System.Move_To_Trash (Tree, Trashed);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "read-only descendants do not cause partial source deletion during trash");
      Assert
        (Project_Tools.Files.Read_Raw_File (Join (To_String (Trashed), "a.txt")) = "complete",
         "cross-device trash retains its complete payload");
      Assert
        (Ada.Directories.Exists
           (Join (Join (Join (Join (To_String (Remote), "data"), "Trash"), "info"), "recovery-tree.trashinfo")),
         "cross-device trash retains the restore sidecar");
      Unlock (Locked);
      Unlock (Join (To_String (Trashed), "locked"));
      Project_Tools.Files.Delete_Tree (Tree);
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Assert (Result.Success, "cross-device trash remains recoverable");
      Unlock (Locked);
      Project_Tools.Files.Delete_Tree (Tree);

      Prepare_Tree;
      Result := Files.File_System.Move_To_Trash (Tree, Trashed);
      Assert (Result.Success, "prepare a cross-device restore");
      Assert
        (Files.File_System.Set_Permissions (Join (To_String (Trashed), "locked"), 8#000#).Success,
         "make the restore fail after it begins copying");
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Assert (not Result.Success, "a partial restore reports failure");
      Assert (not Ada.Directories.Exists (Tree), "a partial restore never publishes the original path");
      Assert (not Ada.Directories.Exists (Join (Root, ".files-work-1")),
              "failed restore staging is removed through guarded job staging");
      Unlock (Join (To_String (Trashed), "locked"));
      Ada.Directories.Create_Directory (Join (Root, "cancelled-recovery"));
      Write_Binary_File (Join (Join (Root, "cancelled-recovery"), "cancel"), "cancel");
      Files.Job_Context.Initialize (Join (Root, "cancelled-recovery"));
      Assert (Files.Job_Context.Cancelled, "the restore retry runs after helper cancellation");
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Files.Job_Context.Initialize ("");
      Assert (Result.Success, "restoring can retry after a partial copy failure and cancellation");
      Assert (Project_Tools.Files.Read_Raw_File (Join (Tree, "a.txt")) = "complete", "retry restores full content");
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Cross_Device_Recovery;
   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "race-source");
      Dest   : constant String := Join (Root, "race-dest");
      Target : constant String := Join (Root, "race-target");
      type Entry_Kind is (File_Entry, Directory_Entry, Link_Entry);
      Current : Entry_Kind;
      Created : Boolean;
      Checks  : Natural;
      Plans   : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Result  : Files.File_System.Mutation_Result;

      function Race return Boolean is
      begin
         Checks := Checks + 1;
         if Checks = 1 then
            case Current is
               when File_Entry => Write_Binary_File (Dest, "unrelated");
               when Directory_Entry =>
                  Ada.Directories.Create_Directory (Dest);
                  Write_Binary_File (Join (Dest, "keep"), "unrelated");
               when Link_Entry => Created := Hostkit.Fs.Create_Link (Target, Dest);
            end case;
         end if;
         return False;
      end Race;
   begin
      Reset_Root;
      Write_Binary_File (Source, "source");
      Write_Binary_File (Target, "unrelated");
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Kind in Entry_Kind loop
            Current := Kind;
            Created := True;
            Checks := 0;
            Plans.Clear;
            Plans.Append (Files.File_System.Drop_Import_Plan'
                            (To_Unbounded_String (Source), To_Unbounded_String (Dest), Mode, True,
                             Null_Unbounded_String));
            Result := Files.File_System.Execute_Drop_Import (Plans, Race'Unrestricted_Access);
            if Created then
               Assert (not Result.Success, "a collision after validation fails without overwriting");
               case Kind is
                  when File_Entry =>
                     Assert (Project_Tools.Files.Read_Raw_File (Dest) = "unrelated", "the raced file is preserved");
                  when Directory_Entry =>
                     Assert (Project_Tools.Files.Read_Raw_File (Join (Dest, "keep")) = "unrelated",
                             "the raced directory and its contents are preserved");
                  when Link_Entry => Assert (Hostkit.Fs.Is_Link (Dest), "the raced symlink is preserved");
               end case;
               Assert (Project_Tools.Files.Read_Raw_File (Source) = "source",
                       "the source is never deleted on collision");
               Result := Files.File_System.Delete_Permanently (Dest);
               Assert (Result.Success, "the owned collision fixture is cleaned");
            else
               --  Hosts without link privileges may complete this copy or move.
               if not Ada.Directories.Exists (Source) then
                  Ada.Directories.Rename (Dest, Source);
               elsif Ada.Directories.Exists (Dest) then
                  Ada.Directories.Delete_File (Dest);
               end if;
            end if;
         end loop;
      end loop;
      Assert (Project_Tools.Files.Read_Raw_File (Target) = "unrelated", "link targets remain untouched");
      Ada.Directories.Create_Directory (Join (Root, "source-dir"));
      Ada.Directories.Create_Directory (Join (Root, "target-dir"));
      Write_Binary_File (Join (Join (Root, "source-dir"), "keep"), "source");
      Assert (not Hostkit.Fs.Move_No_Replace (Join (Root, "source-dir"), Join (Root, "target-dir")),
              "a directory move refuses to replace even an empty existing directory");
      Assert (Ada.Directories.Exists (Join (Join (Root, "source-dir"), "keep")),
              "the directory source survives an atomic move collision");
   end Test_Destination_Races;

   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      for Via_Helper in Boolean loop
         for Mode in Files.File_System.Drop_Import_Mode loop
            for Replaced in Boolean loop
               Reset_Root;
               declare
                  Source : constant String := Join (Root, "journal-source");
                  Dest : constant String := Join (Root, "journal-dest");
                  Transport : constant String := Join (Root, "journal-transport");
                  Action : constant Files.Paste.Resolved_Action :=
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replaced);
                  Actions : Files.Paste.Resolved_Action_Vectors.Vector;
                  Model : Files.Model.Window_Model;
                  Step : Files.Operations.Operation_Result;
                  Outcome : Files.Transfer_Jobs.Job_Result;
               begin
                  Write_Binary_File (Source, "source bytes");
                  if Replaced then
                     Write_Binary_File (Dest, "original bytes");
                  end if;
                  --  Refuse journal writes while keeping result transport usable.
                  Ada.Directories.Create_Path (Join (Transport, "created"));
                  Files.Job_Context.Initialize (Transport);
                  if Via_Helper then
                     Ada.Streams.Stream_IO.Create
                       (File, Ada.Streams.Stream_IO.Out_File, Join (Transport, "request"));
                     Files.Paste.Resolved_Action'Output (Ada.Streams.Stream_IO.Stream (File), Action);
                     Files.File_System.Drop_Import_Mode'Output (Ada.Streams.Stream_IO.Stream (File), Mode);
                     Ada.Streams.Stream_IO.Close (File);
                     Files.Transfer_Jobs.Run_Helper (Transport);
                     Ada.Streams.Stream_IO.Open
                       (File, Ada.Streams.Stream_IO.In_File, Join (Transport, "result"));
                     Outcome := Files.Transfer_Jobs.Job_Result'Input (Ada.Streams.Stream_IO.Stream (File));
                     Ada.Streams.Stream_IO.Close (File);
                     Assert (Outcome.Mutation.Success and then not Outcome.Cancelled
                             and then Length (Outcome.Mutation.Error_Key) = 0,
                             "the helper acknowledges a committed mutation despite a journal failure");
                     Assert (Length (Outcome.Created_Identity) > 0
                             and then Outcome.Created_Identity = Files.File_Identities.Token (Dest),
                             "the helper result retains ownership without a publication journal");
                     if Replaced then
                        Assert (Length (Outcome.Trashed) > 0
                                and then File_Has_Bytes (To_String (Outcome.Trashed), "original bytes"),
                                "the successful helper result retains the replacement original for Undo");
                     end if;
                  else
                     Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
                     Actions.Append (Action);
                     Files.Model.Begin_Paste_Execution (Model, Actions, Mode);
                     Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                     Assert (Step.Status = Files.Operations.Operation_Success
                             and then not Files.Model.Paste_Execution_Is_Active (Model)
                             and then Files.Model.Last_Error_Key (Model) = "",
                             "paste completion reports the committed mutation accurately");
                     Assert (Files.Model.Undo_Available (Model),
                             "paste still records Undo when the publication journal is unavailable");
                  end if;
                  Assert (File_Has_Bytes (Dest, "source bytes"), "the completed destination retains all source bytes");
                  Assert (Ada.Directories.Exists (Source) = (Mode = Files.File_System.Drop_Copy),
                          "a committed move removes its source while a copy preserves it");
                  if Mode = Files.File_System.Drop_Copy then
                     Assert (not Ada.Directories.Exists (Join (Root, ".files-work-1")),
                             "a journal failure does not retain copy staging or remove the published output");
                  end if;
                  Files.Job_Context.Initialize ("");
                  if not Via_Helper then
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                     Assert (Step.Status = Files.Operations.Operation_Success
                             and then File_Has_Bytes (Source, "source bytes"),
                             "Undo reverses the committed operation without losing the source bytes");
                     if Replaced then
                        Assert (File_Has_Bytes (Dest, "original bytes"),
                                "replacement Undo restores the retained original after journal failure");
                     else
                        Assert (not Ada.Directories.Exists (Dest), "Undo vacates the created destination");
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Publication_Journal_Failure;

   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Path : constant String := Join (Root, "recent-trash-undo.txt");
      Applied : Boolean := False;
   begin
      Reset_Root;
      Write_Binary_File (Path, "original recent bytes");
      Files.Settings.Note_Recent (Settings, Path);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Step := Files.Operations.Navigate_Recent (Model, Settings);
      Files.Model.Select_All_Visible (Model);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then Files.Model.Item_Count (Model) = 0
              and then not Ada.Directories.Exists (Path), "trashing the Recent item removes it from the view");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then File_Has_Bytes (Path, "original recent bytes"),
              "Undo restores the trashed bytes before the asynchronous listing is ready");
      for Attempt in 1 .. 5_000 loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         delay 0.001;
      end loop;
      Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
              and then Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1
              and then Files.Model.Visible_Item (Model, 1).Full_Path = To_Unbounded_String (Path)
              and then Files.Model.Last_Error_Key (Model) = "",
              "Undo's refresh immediately relists the restored Recent item without manual refresh or watcher fallback");
   end Test_Recent_Trash_Undo_Refresh;

   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source_Dir : constant String := Join (Root, "history-source");
      Dest_Dir : constant String := Join (Root, "history-dest");
      Source_A : constant String := Join (Source_Dir, "a.txt");
      Source_B : constant String := Join (Source_Dir, "b.txt");
      Dest_A : constant String := Join (Dest_Dir, "a.txt");
      Dest_B : constant String := Join (Dest_Dir, "b.txt");
   begin
      for Recent in Boolean loop
         for Background in Boolean loop
            for Blocked in Boolean loop
               Reset_Root;
               declare
                  Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
                  Model : Files.Model.Window_Model;
                  Load : Files.File_System.Directory_Load_Result;
                  Step : Files.Operations.Operation_Result;
                  Sources, Destinations : Files.Types.String_Vectors.Vector;

                  function Listed (Path : String) return Boolean is
                  begin
                     for Index in 1 .. Files.Model.Visible_Count (Model) loop
                        if Files.Model.Visible_Item (Model, Index).Full_Path = To_Unbounded_String (Path) then
                           return True;
                        end if;
                     end loop;
                     return False;
                  end Listed;

                  procedure Check_Refresh (Error_Key : String) is
                     Applied : Boolean := False;
                  begin
                     if Background then
                        Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "the history action schedules a background refresh");
                        for Attempt in 1 .. 5_000 loop
                           Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
                           exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
                           delay 0.001;
                        end loop;
                        Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "Undo or Redo's own refresh applies without a fallback poll or manual reload");
                     else
                        Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "headless history actions still reload synchronously");
                     end if;
                     Assert (Files.Model.Last_Error_Key (Model) = Error_Key,
                             "refresh preserves the history action's final success or failure state");
                     Assert (Files.Model.In_Recent_View (Model) = Recent, "history refresh preserves the active view");
                  end Check_Refresh;
               begin
                  Ada.Directories.Create_Path (Source_Dir);
                  Ada.Directories.Create_Path (Dest_Dir);
                  Write_Binary_File (Dest_A, "original a");
                  Write_Binary_File (Dest_B, "original b");
                  if Blocked then
                     Write_Binary_File (Source_B, "unrelated source collision");
                  end if;
                  Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
                  Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
                  if Recent then
                     Files.Settings.Note_Recent (Settings, Source_A);
                     Files.Settings.Note_Recent (Settings, Source_B);
                     Step := Files.Operations.Navigate_Recent (Model, Settings);
                  end if;
                  Sources.Append (To_Unbounded_String (Source_A));
                  Sources.Append (To_Unbounded_String (Source_B));
                  Destinations.Append (To_Unbounded_String (Dest_A));
                  Destinations.Append (To_Unbounded_String (Dest_B));
                  Files.Model.Record_Undo (Model, Files.Model.Undo_Move, Destinations, Sources);
                  Files.Model.Set_Background_Transfers (Model, Background);
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  if Blocked then
                     Assert (Step.Status = Files.Operations.Operation_Failed,
                             "the blocked Undo reports partial failure");
                     Check_Refresh ("error.undo.failed");
                     Assert ((if Recent then Listed (Source_A) and then Listed (Source_B)
                              else not Listed (Dest_A) and then Listed (Dest_B)),
                             "a partial Undo refresh shows its completed mutation");
                     Assert (File_Has_Bytes (Source_B, "unrelated source collision"),
                             "the blocked Undo preserves the occupying source");
                     Ada.Directories.Delete_File (Source_B);
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  end if;
                  Assert (Step.Status = Files.Operations.Operation_Success, "the full Undo succeeds");
                  Check_Refresh ("");
                  Assert ((if Recent then Listed (Source_A) and then Listed (Source_B)
                           else Files.Model.Item_Count (Model) = 0),
                          "Undo immediately relists restored Recent paths or empties the original directory");
                  if Blocked then
                     Write_Binary_File (Dest_B, "unrelated destination collision");
                  end if;
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  if Blocked then
                     Assert (Step.Status = Files.Operations.Operation_Failed,
                             "the blocked Redo reports partial failure");
                     Check_Refresh ("error.undo.failed");
                     Assert ((if Recent then not Listed (Source_A) and then Listed (Source_B)
                              else Listed (Dest_A) and then Listed (Dest_B)),
                             "a partial Redo refresh shows its completed mutation");
                     Assert (File_Has_Bytes (Dest_B, "unrelated destination collision"),
                             "the blocked Redo preserves the occupying destination");
                     Ada.Directories.Delete_File (Dest_B);
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  end if;
                  Assert (Step.Status = Files.Operations.Operation_Success, "the full Redo succeeds");
                  Check_Refresh ("");
                  Assert ((if Recent then Files.Model.Item_Count (Model) = 0
                           else Listed (Dest_A) and then Listed (Dest_B)),
                          "Redo removes moved Recent paths or relists the full destination directory");
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Assert (Step.Status = Files.Operations.Operation_Success,
                          "Undo works again after the refreshed Redo");
                  Check_Refresh ("");
                  Assert (File_Has_Bytes (Source_A, "original a") and then File_Has_Bytes (Source_B, "original b"),
                          "the refreshed history cycle preserves the original bytes");
               end;
            end loop;
         end loop;
      end loop;
   end Test_History_Refresh;

   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      View : constant String := Join (Root, "view");
      Held : constant String := Join (Root, "held");
      Signature : Files.File_System.Directory_Signature;

      procedure Await_Refresh (Expected_Reload : Boolean) is
         Applied : Boolean := False;
      begin
         for Attempt in 1 .. 5_000 loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
            delay 0.001;
         end loop;
         Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
                 and then Applied = Expected_Reload, "the matching refresh completes with the expected listing update");
      end Await_Refresh;

      procedure Start_Refresh (Manual : Boolean) is
      begin
         Step := (if Manual then Files.Operations.Refresh (Model, Settings)
                  else Files.Operations.Refresh_If_Changed (Model, Settings));
      end Start_Refresh;

      procedure Await_Ready is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in 1 .. 5_000 loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
            delay 0.001;
         end loop;
         Assert (Finished and then not Cancelled, "the recovery snapshot is ready before a later error is recorded");
      end Await_Ready;
   begin
      for Background in Boolean loop
         for Manual in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Path (View);
            Write_Binary_File (Join (View, "alpha"), "alpha");
            Load := Files.File_System.Load_Directory (View, Settings);
            Files.Model.Initialize (Model, View, Load.Items, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Signature := Files.File_System.Directory_State (View);
            Files.Model.Set_Directory_Signature (Model, Signature);
            Select_Name (Model, "alpha");
            Ada.Directories.Rename (View, Held);
            for Retry in 1 .. 2 loop
               Start_Refresh (Manual);
               if Background then
                  Await_Refresh (False);
               else
                  Assert (Step.Status = Files.Operations.Operation_Failed, "unavailable refresh fails synchronously");
               end if;
               Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load"
                       and then Files.Model.Item_Count (Model) = 1,
                       "a repeated failed refresh retains the load error and displayed items");
            end loop;
            Ada.Directories.Rename (Held, View);
            Assert (not Files.File_System.Detect_Directory_Change (Signature, View).Changed,
                    "restoring the same directory leaves the previous signature unchanged");
            Start_Refresh (Manual);
            if Background then
               Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load",
                       "posting a retry retains the load error until success is confirmed");
               Await_Refresh (True);
            else
               Assert (Step.Status = Files.Operations.Operation_Success, "the synchronous recovery succeeds");
            end if;
            Assert (Files.Model.Last_Error_Key (Model) = "" and then Files.Model.Item_Count (Model) = 1
                    and then Files.Model.Selected_Name (Model) = "alpha",
                    "successful manual and automatic refreshes clear obsolete errors and preserve selection");
         end loop;
      end loop;
      Files.Model.Set_Background_Transfers (Model, True);
      for Manual in Boolean loop
         Files.Model.Set_Error (Model, "error.trash.restore_exists");
         Start_Refresh (Manual);
         Await_Refresh (Manual);
         Assert (Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists",
                 "changed and unchanged successful refreshes retain file operation errors");
      end loop;
      Files.Model.Set_Error (Model, "error.directory.load");
      Start_Refresh (False);
      Await_Ready;
      Files.Model.Set_Error (Model, "error.undo.failed");
      Await_Refresh (False);
      Assert (Files.Model.Last_Error_Key (Model) = "error.undo.failed",
              "an old successful recovery cannot erase a newer operation error");
      Files.Model.Set_Error (Model, "error.directory.load");
      Start_Refresh (True);
      Files.Refresh_Jobs.Cancel (Model);
      Await_Refresh (False);
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load",
              "cancelling a retry does not clear an unconfirmed load error");
      Files.Settings.Note_Recent (Settings, Join (View, "alpha"));
      Files.Model.Navigate_Recent (Model, Files.File_System.Item_Vectors.Empty_Vector);
      for Operation_Error in Boolean loop
         Files.Model.Set_Error
           (Model, (if Operation_Error then "error.trash.restore_exists" else "error.directory.load"));
         Start_Refresh (True);
         Await_Refresh (True);
         Assert (Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1
                 and then Files.Model.Last_Error_Key (Model) =
                   (if Operation_Error then "error.trash.restore_exists" else ""),
                 "successful Recent refresh clears load errors while retaining operation errors");
      end loop;
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Refresh_Error_Recovery;

   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;

      procedure Await_Refresh (Expected : Boolean) is
         Applied : Boolean := False;
      begin
         for Attempt in 1 .. 5_000 loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
            delay 0.001;
         end loop;
         Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                 "the background read finishes without synchronous enumeration");
         Assert (Applied = Expected, "only a matching changed snapshot replaces the visible listing");
      end Await_Refresh;

      procedure Await_Ready is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in 1 .. 5_000 loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
            delay 0.001;
         end loop;
         Assert (Finished and then not Cancelled, "the stale snapshot is ready before the view changes");
      end Await_Ready;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "alpha"), "alpha");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));
      Select_Name (Model, "alpha");
      Write_Binary_File (Join (Root, "beta"), "beta");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
              and then Files.Model.Item_Count (Model) = 1,
              "watch polling schedules a read while retaining the displayed items");
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Selected_Name (Model) = "alpha",
              "a changed snapshot adds the new item and preserves selection");
      Files.Interaction.Apply_Context_Menu_Command
        (Model, Settings, "", Files.Commands.Refresh_Directory_Command, 16, Guikit.Input.No_Modifiers, Routed);
      Await_Refresh (True);
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Refresh (False);

      Write_Binary_File (Join (Root, "gamma"), "gamma");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Ready;
      Files.Model.Set_Filter (Model, "alpha");
      Await_Refresh (False);
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Visible_Count (Model) = 1,
              "a completed old read cannot overwrite a later model edit");
      Files.Model.Set_Filter (Model, "");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 3, "the next matching read includes the new file");

      Write_Binary_File (Join (Root, ".hidden"), "hidden");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Settings.Show_Hidden_Files := True;
      Await_Refresh (False);
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 4, "settings changes reject old snapshots and apply a fresh read");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists",
              "a successful refresh preserves a mutation recovery error");

      Ada.Directories.Create_Directory (Join (Root, "other"));
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Load := Files.File_System.Load_Directory (Join (Root, "other"), Settings);
      Files.Model.Navigate_To (Model, Join (Root, "other"), Load.Items);
      Await_Refresh (False);
      Assert (Files.Model.Item_Count (Model) = 0
              and then Files.Model.Current_Path (Model) = Join (Root, "other"),
              "navigation prevents an old directory snapshot from replacing the new view");
      Files.Settings.Note_Recent (Settings, Join (Root, "alpha"));
      Files.Model.Navigate_Recent (Model, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_F5, Current_Font_Size => 16, Result => Routed);
      Await_Refresh (True);
      Assert (Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1,
              "explicit Recent refresh also loads its items in a helper");
   end Test_Background_Refresh;

   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Watch : Files.Refresh_Jobs.Watch_Session;
      Step : Files.Operations.Operation_Result;
      Load : Files.File_System.Directory_Load_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Before : Ada.Calendar.Time;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_READS");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_READS", "");

      procedure Cleanup is
      begin
         Files.Refresh_Jobs.Cancel (Model);
         Files.Refresh_Jobs.Release_Watch (Watch);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_READS");
         end if;
      end Cleanup;

      procedure Await_Stall is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
      begin
         for Attempt in 1 .. 5_000 loop
            exit when Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "started"));
            delay 0.001;
         end loop;
         Assert (Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "started")),
                 "the refresh helper has entered deliberately stalled filesystem work");
      end Await_Stall;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "source"), "source");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", "1");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Files.Refresh_Jobs.Watch_Path (Watch, Root);
      Await_Stall;
      Before := Ada.Calendar.Clock;
      for Attempt in 1 .. 100 loop
         Assert (not Files.Refresh_Jobs.Advance (Model, Settings), "stalled reads leave the current listing intact");
         Assert (not Files.Refresh_Jobs.Poll_Watch (Watch), "watch polling never waits for registration or I/O");
      end loop;
      Assert (Ada.Calendar.Clock - Before < 0.5, "repeated UI polls return promptly while helpers are stalled");
      Files.Model.Set_Filter (Model, "source");
      Assert (not Files.Refresh_Jobs.Advance (Model, Settings)
              and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "a model edit cancels even a refresh that cannot finish");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Stall;
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Join (Root, "source")),
                         To_Unbounded_String (Join (Root, "dest")), False, False));
      Before := Ada.Calendar.Clock;
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "starting paste immediately releases an outstanding read");
      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
      Assert (Ada.Calendar.Clock - Before < 0.5
              and then not Files.Model.Paste_Execution_Is_Active (Model)
              and then not Ada.Directories.Exists (Join (Root, "dest")),
              "paste cancellation finalizes promptly without waiting for a directory reload");
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "paste finalization schedules its directory refresh independently");
      Await_Stall;
      Before := Ada.Calendar.Clock;
      Cleanup;
      Assert (Ada.Calendar.Clock - Before < 0.25
              and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "window cleanup releases stalled refresh and native-watch helpers without waiting");
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Stalled_Refresh;

   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "link-target");
      Link     : constant String := Join (Root, "trash-link");
      Renamed  : constant String := Join (Root, "renamed-link");
      Had_Xdg  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg  : constant String :=
        (if Had_Xdg then
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Trashed  : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Paths    : Files.Types.String_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      Reset_Root;
      Write_Binary_File (Target, "target");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "link-data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      for Kind in 1 .. 4 loop
         if not Hostkit.Fs.Create_Link
           ((case Kind is
                when 1 => Target,
                when 2 => Join (Root, "missing-target"),
                when 3 => Files.File_System.Trash_Files_Directory,
                when others => Root), Link)
         then
            Restore_Environment;
            return;
         end if;
         Result := Files.File_System.Move_To_Trash (Link, Trashed);
         Assert (Result.Success and then Hostkit.Fs.Is_Link (To_String (Trashed)), "trash preserves the link itself");
         Assert (not Hostkit.Fs.Is_Link (Link), "trash removes the original link pathname");
         Assert (not Files.File_System.Move_To_Trash_Preflight (To_String (Trashed)).Success,
                 "an already-trashed link is identified by its own location");
         Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                 "restore uses the link pathname, including dangling links");
         Result := Files.File_System.Delete_Permanently (Link);
         Assert (Result.Success and then not Hostkit.Fs.Is_Link (Link), "permanent deletion removes dangling links");
         Assert (Project_Tools.Files.Read_Raw_File (Target) = "target",
                 "trashing, restoring and deleting never touch the target");
      end loop;
      if Hostkit.Fs.Create_Link (Join (Root, "missing-target"), Link) then
         declare
            Identity : constant String := Files.File_Identities.Token (Link);
            Planned : Files.File_System.Drop_Import_Result;
            Sources : Files.Types.String_Vectors.Vector;
            Output  : constant String := Join (Root, "link-copies");
         begin
            Assert (Identity /= "", "identify a dangling link before renaming it");
            Result := Files.File_System.Rename_Item (Link, Link);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                    "a no-op rename accepts a dangling link");
            Result := Files.File_System.Rename_Item (Link, Renamed);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Renamed)
                    and then not Hostkit.Fs.Is_Link (Link),
                    "rename moves a dangling link without following its missing target");
            Result := Files.File_System.Rename_Item (Renamed, Link, Identity);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                    "guarded rename restores the same dangling link by identity");
            Ada.Directories.Create_Directory (Output);
            Sources.Append (To_Unbounded_String (Link));
            Planned := Files.File_System.Plan_Drop_Import (Sources, Output);
            Assert (Planned.Success and then Planned.Plans.First_Element.Valid,
                    "drop planning accepts a dangling source link");
            Result := Files.File_System.Execute_Drop_Import (Planned.Plans);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Join (Output, "trash-link")),
                    "a dropped dangling link is copied as a link");
            declare
               Listing : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (Output, Settings);
               Single : constant Files.File_System.Item_Load_Result :=
                 Files.File_System.Load_Item (Join (Output, "trash-link"), Settings);
            begin
               Assert (Listing.Success and then Natural (Listing.Items.Length) = 1
                       and then Listing.Items.First_Element.Kind = Files.Types.Symlink_Item,
                       "folder listings show dangling links as links");
               Assert (Single.Success and then Single.Item.Kind = Files.Types.Symlink_Item,
                       "single-item loading accepts a dangling link");
               Assert (Files.File_System.Directory_State (Output).Entry_Count = 1,
                       "refresh signatures count dangling links");
            end;
            declare
               Nested : constant String := Join (Output, "nested");
               Copied : constant String := Join (Root, "copied-link-tree");
            begin
               Ada.Directories.Create_Directory (Nested);
               Assert (Hostkit.Fs.Create_Link ("../missing", Join (Nested, "broken")),
                       "create a nested dangling-link fixture");
               Result := Files.File_System.Copy_Tree (Output, Copied);
               Assert (Result.Success and then Hostkit.Fs.Is_Link (Join (Copied, "trash-link"))
                       and then Hostkit.Fs.Is_Link (Join (Join (Copied, "nested"), "broken")),
                       "recursive copies preserve every nested dangling link");
               Result := Files.File_System.Delete_Permanently (Copied);
               Assert (Result.Success and then not Ada.Directories.Exists (Copied),
                       "recursive deletion removes folders containing dangling links");
               Assert (Hostkit.Fs.Is_Link (Join (Nested, "broken")),
                       "deleting the copied tree preserves the source link");
            end;
         end;
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Paths.Append (To_Unbounded_String (Link));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths, Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success and then not Hostkit.Fs.Is_Link (Link),
                 "Undo removes a created dangling link");
      end if;
      Restore_Environment;
   exception
      when others => Restore_Environment; raise;
   end Test_Symlink_Recovery;

   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "native-source");
      Dest     : constant String := Join (Root, "native-dest");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Backup   : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Paths    : Files.Types.String_Vectors.Vector;

      procedure Restore_Environment is
      begin
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      Reset_Root;
      declare
         Fake_Stage : constant String := Join (Root, ".files-recovery-900");
         Fake_Payload : constant String := Join (Fake_Stage, "payload");
      begin
         Ada.Directories.Create_Directory (Fake_Stage);
         Write_Binary_File (Fake_Payload, "unowned");
         Write_Binary_File (Join (Fake_Stage, "original"), Dest);
         Assert
           (not Files.File_System.Is_Recovery_Payload (Fake_Payload),
            "a matching filename without an ownership record is not recovery data");
         Assert
           (Ada.Directories.Exists (Fake_Payload),
            "the recovery gate leaves recovery-shaped user data alone");
         Project_Tools.Files.Delete_Tree (Fake_Stage);
      end;
      Write_Binary_File (Source, "new");
      Write_Binary_File (Dest, "original");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, True));
      for Backend of Files.Types.String_Vectors.Vector'([To_Unbounded_String ("windows"),
                                                       To_Unbounded_String ("macos")]) loop
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Backend));
         for Background in Boolean loop
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
            for Attempt in 1 .. 5_000 loop
               Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               exit when not Files.Model.Paste_Execution_Is_Active (Model);
               delay 0.001;
            end loop;
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Replace succeeds with a restorable native-backend backup");
            Assert (Project_Tools.Files.Read_Raw_File (Dest) = "new", "Replace publishes the new copy");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success, "native-backend Replace is undoable");
            Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "Undo restores the overwritten original");
            Assert (not Files.Model.Redo_Available (Model), "Replace with a backup remains undo-only");
         end loop;
      end loop;
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "the rollback failure fixture preserves the original");
      declare
         Registered : constant Files.Types.String_Vectors.Vector :=
           Files.File_System.Registered_Recovery_Payloads;
         Found : Boolean := False;
         Intruder : constant String := Join
           (Ada.Directories.Containing_Directory (To_String (Backup)), "unrelated");
      begin
         for Payload of Registered loop
            Found := Found or else Payload = Backup;
         end loop;
         Assert (Found, "native recovery is discoverable without knowing its parent directory");
         Ada.Directories.Delete_File
           (Join (Ada.Directories.Containing_Directory (To_String (Backup)), "original"));
         Assert
           (Files.File_System.Trash_Original_Path (To_String (Backup)) = Dest,
            "the ownership record retains the original path when the legacy sidecar is lost");
         Write_Binary_File (Intruder, "must survive");
         Result := Files.File_System.Delete_Trashed_Item (To_String (Backup));
         Assert
           (not Result.Success and then Ada.Directories.Exists (Intruder),
            "discard refuses a recovery directory containing unknown data");
         Ada.Directories.Delete_File (Intruder);
      end;
      Write_Binary_File (Dest, "unrelated");
      Result := Files.File_System.Restore_From_Trash (To_String (Backup));
      Assert (not Result.Success and then Ada.Directories.Exists (To_String (Backup)),
              "a failed rollback preserves its backup for retry");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "unrelated", "rollback never overwrites a collision");
      Paths.Append (Backup);
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Paths, Files.Types.String_Vectors.Empty_Vector, Redoable => False);
      Ada.Directories.Delete_File (Dest);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "recovery Undo can retry after a rollback collision");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "recovery retry restores the original bytes");
      Restore_Environment;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Restore_Environment; raise;
   end Test_Native_Replace_Recovery;

   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Had_Stall : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_OPERATIONS");
      Old_Stall : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_OPERATIONS", "");

      procedure Restore_Stall is
      begin
         if Had_Stall then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", Old_Stall);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_OPERATIONS");
         end if;
      end Restore_Stall;

      procedure Finish is
      begin
         Assert (Files.Model.Paste_Execution_Is_Active (Model),
                 "a long operation returns with its progress overlay open");
         for Attempt in 1 .. 10_000 loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
            delay 0.001;
         end loop;
         Assert (not Files.Model.Paste_Execution_Is_Active (Model),
                 "the UI collects the helper result without blocking");
         Assert (Step.Status = Files.Operations.Operation_Success, "the background operation completes successfully");
      end Finish;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "needle");
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Join (Root, "nested"), "needle-name.txt"), "needle");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "a.txt");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Finish;
      Assert (Project_Tools.Files.Read_Raw_File (Join (Root, "a (copy).txt")) = "needle",
              "background duplicate copies bytes");
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
              "a (copy).txt")),
              "background duplicate records Undo on the owning window");
      for Format in Files.Operations.Archive_Format loop
         Select_Name (Model, "a.txt");
         Step := Files.Operations.Compress_Selected (Model, Settings, Format);
         Finish;
         declare
            Archive : constant String :=
              (if Format = Files.Operations.Zip_Archive then "a.zip" else "a.7z");
         begin
            Assert (Ada.Directories.Exists (Join (Root, Archive)),
                    "background compression publishes a complete archive");
            Select_Name (Model, Archive);
            Step := Files.Operations.Extract_Selected (Model, Settings);
            Finish;
            Assert (Project_Tools.Files.Read_Raw_File (Join (Join (Root, "a"), "a.txt")) = "needle",
                    "background extraction publishes the complete directory");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
                    "a")),
                    "background extraction is undoable");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (Join (Root, Archive)),
                    "background archive creation is undoable");
         end;
      end loop;
      Files.Model.Set_Filter (Model, "needle");
      Step := Files.Operations.Run_Recursive_Search (Model, Settings);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
              "background name search returns recursive results");
      Step := Files.Operations.Run_Content_Search (Model, Settings);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 2
                and then Files.Model.Visible_Count (Model) = 2,
              "background content search returns matches regardless of filename");
      Files.Model.Set_Filter (Model, "");
      Step := Files.Operations.Refresh (Model, Settings);
      Select_Name (Model, "a.txt");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Marker : constant String := Files.Process_Jobs.Path (Job, "started");
      begin
         for Attempt in 1 .. 5_000 loop
            exit when Ada.Directories.Exists (Marker);
            delay 0.001;
         end loop;
         Assert (Ada.Directories.Exists (Marker),
                 "the duplicate helper reaches the pre-work cancellation point");
      end;
      Restore_Stall;
      Files.Operations.Cancel_Paste_Execution (Model);
      Finish;
      Assert (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
              "cancellation before work publishes no duplicate");
   exception
      when others =>
         Restore_Stall;
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Background_Operations;

   procedure Test_Window_Job_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Closing, Remaining : Files.Model.Window_Model;
      Closing_Watch, Remaining_Watch : Files.Refresh_Jobs.Watch_Session;
      Empty : Files.Process_Jobs.Session;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Started, Other_Started : Unbounded_String;
      Before : Ada.Calendar.Time;
      Step : Files.Operations.Operation_Result;
      Finished, Cancelled : Boolean;
      Had_Reads : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_READS");
      Old_Reads : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_READS", "");
      Had_Transfers : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_TRANSFERS");
      Old_Transfers : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_TRANSFERS", "");
      type Scenario_Kind is (Operation_Job, Transfer_Job, Refresh_Job);

      procedure Cleanup is
      begin
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Files.Application.Windows.Release_Window_Jobs (Remaining, Remaining_Watch);
         if Had_Reads then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", Old_Reads);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_READS");
         end if;
         if Had_Transfers then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_TRANSFERS", Old_Transfers);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_TRANSFERS");
         end if;
      end Cleanup;

      procedure Await_Started (Path : String) is
      begin
         for Attempt in 1 .. 5_000 loop
            exit when Ada.Directories.Exists (Path);
            delay 0.001;
         end loop;
         Assert (Ada.Directories.Exists (Path), "the helper enters stalled work before window closure: " & Path);
      end Await_Started;

      procedure Attach_Operation (Model : in out Files.Model.Window_Model; Marker : out Unbounded_String) is
         Job : Files.Process_Jobs.Session;
      begin
         Files.Process_Jobs.Reserve (Job);
         Marker := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
         Files.Process_Jobs.Launch (Job, "--files-test-blocked");
         Await_Started (To_String (Marker));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
         Files.Model.Set_Background_Operation (Model, Job, "command.file.duplicate");
         Files.Process_Jobs.Reset (Job); --  The window is now its helper's only owner.
      end Attach_Operation;
   begin
      for Scenario in Scenario_Kind loop
         Reset_Root;
         Write_Binary_File (Join (Root, "source.txt"), "source bytes");
         Files.Model.Initialize (Closing, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Initialize (Remaining, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Set_Background_Transfers (Closing, True);
         Files.Model.Set_Background_Transfers (Remaining, True);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
                           (To_Unbounded_String (Join (Root, "source.txt")),
                            To_Unbounded_String (Join (Root, "destination.txt")), False, False));
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", "1");
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_TRANSFERS", Join (Root, "transfer-started"));
         Attach_Operation (Remaining, Other_Started);
         case Scenario is
            when Operation_Job => Attach_Operation (Closing, Started);
            when Transfer_Job =>
               Files.Model.Begin_Paste_Execution (Closing, Actions, Files.File_System.Drop_Copy);
               Step := Files.Operations.Advance_Paste_Execution (Closing, Settings, 1);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Files.Model.Paste_Execution_Is_Active (Closing), "start the stalled transfer");
               Await_Started (Join (Root, "transfer-started"));
               declare
                  Marker : Ada.Text_IO.File_Type;
               begin
                  Ada.Text_IO.Open (Marker, Ada.Text_IO.In_File, Join (Root, "transfer-started"));
                  Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (Marker), "started"));
                  Ada.Text_IO.Close (Marker);
               end;
               Await_Started (To_String (Started));
            when Refresh_Job =>
               Step := Files.Operations.Refresh (Closing, Settings);
               declare
                  Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Closing);
               begin
                  Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
                  Await_Started (To_String (Started));
               end;
         end case;
         Files.Refresh_Jobs.Watch_Path (Closing_Watch, Root);
         Before := Ada.Calendar.Clock;
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Files.Application.Windows.Release_Window_Jobs (Closing, Closing_Watch);
         Assert (Ada.Calendar.Clock - Before < 0.25
                 and then not Files.Model.Paste_Execution_Is_Active (Closing)
                 and then not Files.Process_Jobs.Active (Files.Model.Background_Operation (Closing))
                 and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Closing)),
                 "repeated window closure releases all jobs promptly without joining stalled helpers");
         declare
            Other : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Remaining);
         begin
            Files.Process_Jobs.Poll (Other, Finished, Cancelled);
            Assert (not Finished and then not Cancelled and then Files.Model.Paste_Execution_Is_Active (Remaining)
                    and then Ada.Directories.Exists (To_String (Other_Started)),
                    "closing one window leaves the surviving window and its helper active");
         end;
         for Attempt in 1 .. 5_000 loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Started));
            delay 0.001;
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Started)),
                 "the closed window's helper is terminated and reaped while another window stays open");
         Assert (File_Has_Bytes (Join (Root, "source.txt"), "source bytes")
                 and then not Ada.Directories.Exists (Join (Root, "destination.txt")),
                 "a stopped stalled transfer never writes after its window closes");
         Files.Application.Windows.Release_Window_Jobs (Remaining, Remaining_Watch);
         for Attempt in 1 .. 5_000 loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Other_Started));
            delay 0.001;
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Other_Started)),
                 "the surviving helper also closes independently");
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Window_Job_Shutdown;

   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Spawn.Spawn_Outcome;
      use type Hostkit.Spawn.Wait_State;
      Before : constant String := Join
        (Hostkit.Fs.Temp_Directory, "files-job-77777777777777777777777777777777");
      After : constant String := Join
        (Hostkit.Fs.Temp_Directory, "files-job-88888888888888888888888888888888");
      Held : constant String := Join
        (Hostkit.Fs.Temp_Directory, "files-job-99999999999999999999999999999999");
      Control : constant String := Join (Root, "held-transport-creator");
      Job : Files.Process_Jobs.Session;
      Child : Hostkit.Spawn.Process_Handle := Hostkit.Spawn.Invalid_Process;
      Arguments : Hostkit.String_Vectors.Vector;
      Exit_Status : Integer;
      Status : Hostkit.Spawn.Status;
      Found : Boolean := False;
      Finished, Cancelled : Boolean;
      Rejected : Boolean := False;
      File : Ada.Text_IO.File_Type;

      procedure Remove (Path : String) is
         Simple : constant String := Ada.Directories.Simple_Name (Path);
         Witness : constant String := Join
           (Hostkit.Fs.Temp_Directory,
            ".files-job-creation-" & Simple (Simple'First + 10 .. Simple'Last));
      begin
         if Ada.Directories.Exists (Path) then
            Project_Tools.Files.Delete_Tree (Path);
         end if;
         if Ada.Directories.Exists (Witness) then
            Ada.Directories.Delete_File (Witness);
         end if;
      end Remove;

      procedure Signal_Release is
      begin
         if not Ada.Directories.Exists (Control & ".release") then
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Control & ".release");
            Ada.Text_IO.Close (File);
         end if;
      end Signal_Release;
   begin
      Reset_Root;
      Remove (Before);
      Remove (After);
      Remove (Held);
      Files.Process_Jobs.Reserve (Job);
      begin
         Files.Process_Jobs.Launch (Job, "--files-test-blocked");
         Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "a second launch cannot replace the tracked helper handle");
      Ada.Directories.Create_Directory (Files.Process_Jobs.Path (Job, "cancel"));
      Rejected := False;
      begin
         Files.Process_Jobs.Cancel (Job);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      Assert (Rejected and then not Cancelled,
              "a failed cancellation file creation leaves the request retryable");
      Ada.Directories.Delete_Directory (Files.Process_Jobs.Path (Job, "cancel"));
      Files.Process_Jobs.Cancel (Job);
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      Assert (Cancelled and then Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "cancel")),
              "retry publishes the cancellation file before marking the session cancelled");
      Files.Process_Jobs.Reset (Job);

      Arguments.Append (To_Unbounded_String ("--files-test-crash-before-marker"));
      Arguments.Append (To_Unbounded_String (Before));
      Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
              and then Exit_Status = 0, "the pre-lease crash fixture exits cleanly");
      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-crash-after-lease"));
      Arguments.Append (To_Unbounded_String (After));
      Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
              and then Exit_Status = 0, "the pre-marker lease crash fixture exits cleanly");
      Assert (Ada.Directories.Exists (Before) and then Ada.Directories.Exists (After),
              "both interrupted creation phases leave recoverable directories");
      Found := Files.Job_Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
      Assert (not Ada.Directories.Exists (Before) and then not Ada.Directories.Exists (After),
              "recovery removes both witnessed markerless crash states");

      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-hold-before-marker"));
      Arguments.Append (To_Unbounded_String (Held));
      Arguments.Append (To_Unbounded_String (Control));
      Assert (Hostkit.Spawn.Start
        (Hostkit.Fs.Own_Executable, Arguments, (others => <>), Child) = Hostkit.Spawn.Spawn_Ok,
        "start a creator paused before marker publication");
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Control & ".started");
         delay 0.001;
      end loop;
      Assert (Ada.Directories.Exists (Control & ".started"), "the creator holds its witness");
      declare
         Identity : Files.Types.UString;
         Claim : Files.Job_Transports.Lease;
      begin
         Assert (Files.Job_Transports.Claim_Incomplete
           (Held, Identity, Claim, Minimum_Age => 0.0) = Files.Job_Transports.Claim_Deferred,
           "recovery cannot claim a creator still between directory and marker publication");
      end;
      Signal_Release;
      for Attempt in 1 .. 5_000 loop
         Found := Hostkit.Spawn.Wait (Child, Hostkit.Spawn.Wait_Poll, Status);
         exit when Found and then Status.State in Hostkit.Spawn.Wait_Exited
           | Hostkit.Spawn.Wait_Signalled | Hostkit.Spawn.Wait_Lost;
         delay 0.001;
      end loop;
      Assert (Found and then Status.State = Hostkit.Spawn.Wait_Exited
              and then Status.Exit_Code = 0, "the paused creator exits after release");
      Hostkit.Spawn.Release (Child);
      Found := Files.Job_Scavenger.Run (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
      Assert (not Ada.Directories.Exists (Held), "recovery reclaims the creator after its lock closes");

      --  Simulate a failed witness unlink after a successful publication,
      --  followed by loss of the marker while the transport owner is live.
      --  A published witness must never be mistaken for pre-marker proof.
      declare
         function Create_Native (Name : System.Address) return Interfaces.C.long_long
           with Import, Convention => C, External_Name => "files_transport_lease_create";
         function Publish_Witness (Handle : Interfaces.C.long_long) return Interfaces.C.int
           with Import, Convention => C, External_Name => "files_transport_lease_publish_witness";
         procedure Release_Native (Handle : Interfaces.C.long_long)
           with Import, Convention => C, External_Name => "files_transport_lease_release";
         Owner : Files.Job_Transports.Lease;
         Directory, Identity : Files.Types.UString;
         Claim : Files.Job_Transports.Lease;
         Incomplete_Identity : Files.Types.UString;
      begin
         Files.Job_Transports.Create (Directory, Identity, Owner);
         declare
            Path : constant String := To_String (Directory);
            Simple : constant String := Ada.Directories.Simple_Name (Path);
            Witness : aliased Interfaces.C.char_array := Interfaces.C.To_C
              (Join (Hostkit.Fs.Temp_Directory,
               ".files-job-creation-" & Simple (Simple'First + 10 .. Simple'Last)));
            Handle : constant Interfaces.C.long_long := Create_Native (Witness'Address);
         begin
            Assert (Handle /= 0, "a leftover published witness can be constructed");
            if Handle /= 0 then
               declare
                  Published : constant Boolean := Publish_Witness (Handle) = 1;
               begin
                  Release_Native (Handle);
                  Assert (Published, "the leftover witness records publication");
               end;
            end if;
            Ada.Directories.Delete_File (Join (Path, ".files-job-transport"));
            Assert
              (Files.Job_Transports.Claim_Incomplete
                 (Path, Incomplete_Identity, Claim, Minimum_Age => 0.0) =
                   Files.Job_Transports.Claim_Unrecoverable,
               "a published witness cannot authorize markerless cleanup");
            Found := Files.Job_Scavenger.Run
              (Minimum_Unmarked_Age => 0.0, Wait_For_Grace => False);
            Assert (Ada.Directories.Exists (Path),
                    "scavenging preserves a live transport with a published witness");
            Files.Job_Transports.Release (Owner);
            Remove (Path);
         exception
            when others =>
               Files.Job_Transports.Release (Owner);
               Remove (Path);
               raise;
         end;
      end;

      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Arguments.Clear;
         Arguments.Append (To_Unbounded_String ("--files-test-no-btime-transport"));
         Assert (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
                 and then Exit_Status = 0,
                 "transport creation and staged copies fail closed without Linux birth time");
      end if;
      Remove (Before);
      Remove (After);
      Remove (Held);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Files.Process_Jobs.Reset (Job);
         Signal_Release;
         raise;
   end Test_Transport_Protocol_Gaps;

   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job       : Files.Process_Jobs.Session;
      Started   : Files.Types.UString;
      Before    : Ada.Calendar.Time;
      Finished  : Boolean;
      Cancelled : Boolean;
   begin
      declare
         Arguments : Hostkit.String_Vectors.Vector;
         Exit_Status : Integer;
      begin
         Arguments.Append (To_Unbounded_String ("--files-test-drain-reaper"));
         Assert
           (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
            and then Exit_Status = 0,
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
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (To_String (Started));
         delay 0.001;
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)), "the shutdown fixture enters blocked helper work");
      declare
         Keeper : Files.Process_Jobs.Session := Job;
      begin
         Files.Process_Jobs.Reset (Job);
         Files.Process_Jobs.Poll (Keeper, Finished, Cancelled);
         Assert (not Finished, "a copied session keeps its helper alive");
         Before := Ada.Calendar.Clock;
         Files.Process_Jobs.Reset (Keeper);
         Assert (Ada.Calendar.Clock - Before < 0.25, "closing the last session never waits for blocked helper work");
      end;
      for Attempt in 1 .. 5_000 loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when not Ada.Directories.Exists (To_String (Started));
         delay 0.001;
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Started)),
              "terminated helpers are reaped and their transport is cleaned");
      Files.Process_Jobs.Reserve (Job);
      Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
      Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (To_String (Started));
         delay 0.001;
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)), "the cancellation fixture enters blocked helper work");
      Before := Ada.Calendar.Clock;
      Files.Process_Jobs.Cancel (Job);
      for Attempt in 1 .. 5_000 loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when Finished;
         delay 0.001;
      end loop;
      Assert (Finished and then Cancelled and then Ada.Calendar.Clock - Before < 3.5,
              "cancellation detaches stalled helpers after its bounded grace period");
      Files.Process_Jobs.Reset (Job);

      Files.Process_Jobs.Reserve (Job);
      Started := To_Unbounded_String (Files.Process_Jobs.Path (Job, "started"));
      Files.Process_Jobs.Launch (Job, "--files-test-blocked");
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (To_String (Started));
         delay 0.001;
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)),
              "the failed-stop fixture enters blocked helper work");
      Files.Process_Jobs.Testing.Simulate_Failed_Stop (Job);
      for Attempt in 1 .. 5_000 loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when Finished;
         delay 0.001;
      end loop;
      Assert
        (Finished and then not Cancelled,
         "polling retries a failed initial stop request and reaps the helper");
      Files.Process_Jobs.Reset (Job);
   end Test_Helper_Shutdown;

   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Flag_Had  : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_CLEANUP_WORKER");
      Flag_Old  : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_CLEANUP_WORKER", "");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;
      Before    : Ada.Calendar.Time;

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

      procedure Restore is
      begin
         if Flag_Had then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_CLEANUP_WORKER", Flag_Old);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_CLEANUP_WORKER");
         end if;
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Touch (Item ("release-cleanup-worker"));
            for Attempt in 1 .. 5_000 loop
               exit when not Ada.Directories.Exists (To_String (Transport));
               delay 0.001;
            end loop;
         end if;
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
      end Restore;
   begin
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_CLEANUP_WORKER", "1");
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Item ("stages"));

      Before := Ada.Calendar.Clock;
      Files.Process_Jobs.Reset (Job);
      Assert
        (Ada.Calendar.Clock - Before < 0.25,
         "session disposal returns without waiting for the cleanup worker");
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Item ("cleanup-worker-started"));
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Item ("cleanup-worker-started"))
         and then Ada.Directories.Exists (To_String (Transport)),
         "the stalled worker remains owned after disposal returns");

      Touch (Item ("release-cleanup-worker"));
      for Attempt in 1 .. 5_000 loop
         exit when not Ada.Directories.Exists (To_String (Transport));
         delay 0.001;
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Transport)),
         "cleanup completes without a later process-jobs API call");

      if Hostkit.Host.Current = Hostkit.Host.Linux
        and then Ada.Directories.Exists ("/proc/thread-self/children")
      then
         declare
            Children_Before : constant String :=
              Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children");
            Launcher_Id : Integer;
            Resumed : Boolean;
            Id_File : Ada.Text_IO.File_Type;
         begin
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_CLEANUP_WORKER", "stop");
            Files.Process_Jobs.Reserve (Job);
            Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
            Ada.Directories.Create_Directory (Item ("stages"));
            Files.Process_Jobs.Reset (Job);
            for Attempt in 1 .. 5_000 loop
               exit when Ada.Directories.Exists (Item ("cleanup-worker-started"));
               delay 0.001;
            end loop;
            Assert
              (Ada.Directories.Exists (Item ("cleanup-worker-started")),
               "the stopped cleanup worker publishes its process id");
            --  Let the uncatchable stop take effect before the autonomous
            --  reaper observes its state.
            delay 0.05;
            Ada.Text_IO.Open
              (Id_File, Ada.Text_IO.In_File, Item ("cleanup-worker-started"));
            Launcher_Id := Integer'Value (Ada.Text_IO.Get_Line (Id_File));
            Ada.Text_IO.Close (Id_File);
            Resumed := Hostkit.Signals.Send_To_Process
              (Launcher_Id, Hostkit.Signals.Signal_Continue);
            Assert (Resumed, "the stopped cleanup worker remains resumable");
            for Attempt in 1 .. 5_000 loop
               exit when not Ada.Directories.Exists (To_String (Transport))
                 and then Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                   Children_Before;
               delay 0.001;
            end loop;
            Assert
              (not Ada.Directories.Exists (To_String (Transport))
               and then Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 Children_Before,
               "stopped and continued cleanup workers stay owned until reaped");
         end;
      end if;
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Autonomous_Cleanup_Worker;

   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_SKIP_CLEANUP_ONCE";
      Had_Value : constant Boolean := Ada.Environment_Variables.Exists (Variable);
      Old_Value : constant String := Ada.Environment_Variables.Value (Variable, "");
      Marker    : constant String := Join (Root, "cleanup-worker-skipped");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;

      procedure Restore is
      begin
         if Had_Value then
            Ada.Environment_Variables.Set (Variable, Old_Value);
         else
            Ada.Environment_Variables.Clear (Variable);
         end if;
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
         if Ada.Directories.Exists (Marker) then
            Ada.Directories.Delete_File (Marker);
         end if;
      end Restore;
   begin
      Reset_Root;
      Ada.Environment_Variables.Set (Variable, Marker);
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Join (To_String (Transport), "stages"));
      Files.Process_Jobs.Reset (Job);

      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Marker);
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Marker)
         and then Ada.Directories.Exists (To_String (Transport)),
         "a zero-exit cleanup helper can leave its transport behind");

      for Attempt in 1 .. 10_000 loop
         exit when not Ada.Directories.Exists (To_String (Transport));
         delay 0.001;
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Transport)),
         "the reaper retries when a zero-exit cleanup helper leaves its transport behind");
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Cleanup_Exit_Verification;

   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_FAIL_CLEANUP_WORKER";
      Had_Value : constant Boolean := Ada.Environment_Variables.Exists (Variable);
      Old_Value : constant String := Ada.Environment_Variables.Value (Variable, "");
      Marker    : constant String := Join (Root, "cleanup-worker-failures");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;

      function Failure_Count return Natural is
         Count : Natural := 0;
      begin
         if not Ada.Directories.Exists (Marker) then
            return 0;
         end if;
         declare
            Content : constant String := Project_Tools.Files.Read_Raw_File (Marker);
         begin
            for Character of Content loop
               if Character = Ada.Characters.Latin_1.LF then
                  Count := Count + 1;
               end if;
            end loop;
         end;
         return Count;
      end Failure_Count;

      procedure Restore is
      begin
         if Had_Value then
            Ada.Environment_Variables.Set (Variable, Old_Value);
         else
            Ada.Environment_Variables.Clear (Variable);
         end if;
         if Length (Transport) > 0 then
            if Hostkit.Fs.Is_Link (To_String (Transport)) then
               Ada.Directories.Delete_File (To_String (Transport));
            elsif Ada.Directories.Exists (To_String (Transport)) then
               Project_Tools.Files.Delete_Tree (To_String (Transport));
            end if;
         end if;
         if Ada.Directories.Exists (Marker) then
            Ada.Directories.Delete_File (Marker);
         end if;
      end Restore;
   begin
      Reset_Root;
      Ada.Environment_Variables.Set (Variable, Marker);
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Join (To_String (Transport), "stages"));
      Files.Process_Jobs.Reset (Job);

      for Attempt in 1 .. 10_000 loop
         exit when Failure_Count >= 2;
         delay 0.001;
      end loop;
      Assert (Failure_Count = 2, "the parent makes its one bounded cleanup relaunch");

      delay 3.0;
      Assert
        (Failure_Count = 2 and then Ada.Directories.Exists (To_String (Transport)),
         "persistent cleanup refusal stops worker churn and leaves durable recovery state");
      Restore;

      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Reset_Root;
         Ada.Environment_Variables.Set (Variable, Marker);
         Files.Process_Jobs.Reserve (Job);
         Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Project_Tools.Files.Delete_Tree (To_String (Transport));
         Assert
           (Hostkit.Fs.Create_Link (Join (Root, "missing-transport-target"),
                                   To_String (Transport)),
            "replace a released transport with a dangling link");
         Files.Process_Jobs.Reset (Job);
         for Attempt in 1 .. 5_000 loop
            exit when Failure_Count >= 1;
            delay 0.001;
         end loop;
         Assert
           (Failure_Count >= 1 and then Hostkit.Fs.Is_Link (To_String (Transport)),
            "idle cleanup retains a dangling transport link for guarded retry");
         Restore;
      end if;
   exception
      when others =>
         Restore;
         raise;
   end Test_Cleanup_Retry_Bound;

   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      Invalid_Temp : constant String := Join (Root, "not-a-temp-directory");
      Job          : Files.Process_Jobs.Session;
      Failed       : Boolean := False;

      procedure Restore_Temp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Temp;
   begin
      if Hostkit.Host.Current not in Hostkit.Host.Linux | Hostkit.Host.MacOS then
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Invalid_Temp, "ordinary file");
      Ada.Environment_Variables.Set ("TMPDIR", Invalid_Temp);
      begin
         Files.Process_Jobs.Reserve (Job);
      exception
         when others => Failed := True;
      end;
      Assert
        (Failed and then not Files.Process_Jobs.Active (Job),
         "a transport creation failure frees the preallocated session state");

      Restore_Temp;
      Files.Process_Jobs.Reserve (Job);
      Assert
        (Files.Process_Jobs.Active (Job)
         and then Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "")),
         "the same session remains reusable after reservation rollback");
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Restore_Temp;
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Reserve_Exception_Safety;

   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;
      Result    : Files.File_System.Mutation_Result;

      procedure Restore is
      begin
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Result := Files.File_System.Set_Permissions (To_String (Transport), 8#700#);
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
      end Restore;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else Hostkit.Host.Is_Elevated then
         return;
      end if;

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Write_Binary_File (Files.Process_Jobs.Path (Job, "ordinary-result"), "result");
      Result := Files.File_System.Set_Permissions (To_String (Transport), 0);
      Assert (Result.Success, "prepare an unreadable ordinary transport");

      Files.Process_Jobs.Reset (Job);
      Assert (Ada.Directories.Exists (To_String (Transport)),
              "the initial ordinary transport removal is forced to fail");
      Result := Files.File_System.Set_Permissions (To_String (Transport), 8#700#);
      Assert (Result.Success, "restore access for the cleanup retry");

      for Attempt in 1 .. 5_000 loop
         exit when not Ada.Directories.Exists (To_String (Transport));
         delay 0.001;
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Transport)),
              "ordinary transport removal retries without a later job API call");

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Files.Process_Jobs.Testing.Release_Owner (Job);
      declare
         Marker : constant String := Join (To_String (Transport), ".files-job-transport");
         Identity : Files.Types.UString;
         Read_Error : Boolean;
         Complete : Boolean;
      begin
         Result := Files.File_System.Set_Permissions (Marker, 0);
         Assert (Result.Success, "prepare a temporarily unreadable transport marker");
         Files.Job_Transports.Inspect_Marker (To_String (Transport), Identity, Read_Error);
         Assert (Read_Error and then Length (Identity) = 0,
                 "marker inspection distinguishes read failure from invalid data");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (not Complete and then Ada.Directories.Exists (To_String (Transport)),
                 "scavenging retries an unreadable marker instead of skipping it");
         Result := Files.File_System.Set_Permissions (Marker, 8#600#);
         Assert (Result.Success, "restore transport marker access");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (Complete and then not Ada.Directories.Exists (To_String (Transport)),
                 "scavenging removes the transport after marker access returns");
      end;
      Files.Process_Jobs.Reset (Job);

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Files.Process_Jobs.Testing.Release_Owner (Job);
      declare
         Lease_Path : constant String := Join (To_String (Transport), ".files-job-owner");
         Complete : Boolean;
      begin
         Result := Files.File_System.Set_Permissions (Lease_Path, 0);
         Assert (Result.Success, "prepare a temporarily inaccessible transport lease");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (not Complete and then Ada.Directories.Exists (To_String (Transport)),
                 "scavenging retries a lease access failure");
         Result := Files.File_System.Set_Permissions (Lease_Path, 8#600#);
         Assert (Result.Success, "restore transport lease access");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (Complete and then not Ada.Directories.Exists (To_String (Transport)),
                 "scavenging removes the transport after lease access returns");
      end;
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Restore;
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Transport_Cleanup_Retry;

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

   procedure Test_Crash_Transport_Scavenging (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Active_Path     : Files.Types.UString;
      Fallback_Path   : Files.Types.UString;
      Retry_Path      : Files.Types.UString;
      Delayed_Path    : Files.Types.UString;
      Missing_Lease_Path : Files.Types.UString;
      Abandoned_Path  : Files.Types.UString;
      Pre_Lease_Path  : Files.Types.UString;
      Before_Lease_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-11111111111111111111111111111111"));
      After_Lease_Path : Files.Types.UString;
      Young_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-22222222222222222222222222222222"));
      Payload_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-33333333333333333333333333333333"));
      Similar_Path : constant Files.Types.UString := To_Unbounded_String
        (Join (Hostkit.Fs.Temp_Directory, "files-job-not-a-current-transport"));
      Report_Path     : constant String := Join (Root, "abandoned-transport");
      Fallback_Report : constant String := Join (Root, "fallback-transport");
      Retry_Report    : constant String := Join (Root, "retry-transport");
      Retry_Control   : constant String := Join (Root, "failed-scavenge-coordinator");
      Delayed_Report  : constant String := Join (Root, "delayed-transport");
      Delayed_Control : constant String := Join (Root, "delayed-scavenge-coordinator");
      Missing_Lease_Report : constant String := Join (Root, "missing-lease-transport");
      Had_Scavenge_Failure : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_FAIL_SCAVENGER_ONCE");
      Old_Scavenge_Failure : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_ONCE", "");
      Had_Delayed_Failure : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
      Old_Delayed_Failure : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_FAIL_SCAVENGER_UNTIL", "");
      Pre_Lease_Report : constant String := Join (Root, "pre-lease-transport");
      Scavenge_Control : constant String := Join (Root, "scavenge-coordinator");
      Shutdown_Control : constant String := Join (Root, "shutdown-coordinator");
      Had_Scavenge_Stall : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_SCAVENGER");
      Old_Scavenge_Stall : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER", "");

      procedure Create_Abandoned (Report : String; Path : out Files.Types.UString) is
         Arguments   : Hostkit.String_Vectors.Vector;
         Exit_Status : Integer;
         File        : Ada.Text_IO.File_Type;
      begin
         Arguments.Append (To_Unbounded_String ("--files-test-abandon-transport"));
         Arguments.Append (To_Unbounded_String (Report));
         Assert
           (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
            and then Exit_Status = 0,
            "the crash fixture creates a transport and exits without finalization");
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report);
         Path := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end Create_Abandoned;

      procedure Remove_Fixture (Path : Files.Types.UString) is
      begin
         if Length (Path) > 0 and then Ada.Directories.Exists (To_String (Path)) then
            Project_Tools.Files.Delete_Tree (To_String (Path));
         end if;
      end Remove_Fixture;

      procedure Restore is
      begin
         if Had_Scavenge_Stall then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Old_Scavenge_Stall);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_SCAVENGER");
         end if;
         if Had_Scavenge_Failure then
            Ada.Environment_Variables.Set
              ("FILES_TEST_FAIL_SCAVENGER_ONCE", Old_Scavenge_Failure);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_ONCE");
         end if;
         if Had_Delayed_Failure then
            Ada.Environment_Variables.Set
              ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Old_Delayed_Failure);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
         end if;
         if Ada.Directories.Exists (Scavenge_Control & ".started")
           and then not Ada.Directories.Exists (Scavenge_Control & ".release")
         then
            Write_Binary_File (Scavenge_Control & ".release", "release");
         end if;
         if Ada.Directories.Exists (Shutdown_Control & ".started")
           and then not Ada.Directories.Exists (Shutdown_Control & ".release")
         then
            Write_Binary_File (Shutdown_Control & ".release", "release");
         end if;
         Files.Process_Jobs.Reset (Active);
         Remove_Fixture (Fallback_Path);
         Remove_Fixture (Retry_Path);
         Remove_Fixture (Delayed_Path);
         Remove_Fixture (Missing_Lease_Path);
         Remove_Fixture (Abandoned_Path);
         Remove_Fixture (Pre_Lease_Path);
         Remove_Fixture (Before_Lease_Path);
         Remove_Fixture (After_Lease_Path);
         Remove_Fixture (Young_Path);
         Remove_Fixture (Payload_Path);
         Remove_Fixture (Similar_Path);
      end Restore;
   begin
      Reset_Root;
      Files.Process_Jobs.Reserve (Active);
      Active_Path := To_Unbounded_String (Files.Process_Jobs.Path (Active, ""));

      Create_Abandoned (Fallback_Report, Fallback_Path);
      declare
         Marker : constant String := Join (To_String (Fallback_Path), ".files-job-transport");
         Restricted : constant Boolean :=
           Hostkit.Host.Current = Hostkit.Host.Linux and then not Hostkit.Host.Is_Elevated;
         Result : Files.File_System.Mutation_Result;
         Before : Ada.Calendar.Time;
      begin
         if Restricted then
            Result := Files.File_System.Set_Permissions (Marker, 0);
            Assert (Result.Success, "make the fallback scan wait for marker access");
         end if;
         Before := Ada.Calendar.Clock;
         Files.Job_Scavenger.Scavenge (Join (Root, "missing-scavenge-coordinator"));
         Assert
           (Ada.Calendar.Clock - Before < 0.25,
            "startup returns promptly even when the coordinator cannot launch");
         if Restricted then
            Result := Files.File_System.Set_Permissions (Marker, 8#600#);
            Assert (Result.Success, "restore fallback marker access");
         end if;
         for Attempt in 1 .. 5_000 loop
            exit when not Ada.Directories.Exists (To_String (Fallback_Path));
            delay 0.001;
         end loop;
         Assert
           (not Ada.Directories.Exists (To_String (Fallback_Path))
            and then Ada.Directories.Exists (To_String (Active_Path)),
            "the monitor completes fallback recovery after startup continues");
      exception
         when others =>
            if Restricted then
               Result := Files.File_System.Set_Permissions (Marker, 8#600#);
            end if;
            raise;
      end;

      Create_Abandoned (Missing_Lease_Report, Missing_Lease_Path);
      declare
         Lease_Path : constant String := Join (To_String (Missing_Lease_Path), ".files-job-owner");
         Identity : constant String := Files.Job_Transports.Recorded_Identity
           (To_String (Missing_Lease_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Ada.Directories.Delete_File (Lease_Path);
         Assert
           (Files.Job_Transports.Claim_Abandoned
              (To_String (Missing_Lease_Path), Identity, Claim) =
                Files.Job_Transports.Claim_Unrecoverable
            and then Files.Job_Scavenger.Run (Wait_For_Grace => False)
            and then Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a missing lease is reported as terminal and its transport is preserved");
         Write_Binary_File (Lease_Path, "");
         Assert
           (Files.Job_Scavenger.Run (Wait_For_Grace => False)
            and then Ada.Directories.Exists (To_String (Missing_Lease_Path)),
            "a replacement lease cannot make a missing original safe to reclaim");
      end;

      Create_Abandoned (Retry_Report, Retry_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_ONCE", Retry_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in 1 .. 10_000 loop
         exit when Ada.Directories.Exists (Retry_Control)
           and then not Ada.Directories.Exists (To_String (Retry_Path));
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Retry_Control)
         and then not Ada.Directories.Exists (To_String (Retry_Path)),
         "startup recovery observes a failed coordinator and relaunches one bounded retry");
      if Had_Scavenge_Failure then
         Ada.Environment_Variables.Set
           ("FILES_TEST_FAIL_SCAVENGER_ONCE", Old_Scavenge_Failure);
      else
         Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_ONCE");
      end if;

      Create_Abandoned (Delayed_Report, Delayed_Path);
      Ada.Environment_Variables.Set ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Delayed_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in 1 .. 10_000 loop
         exit when Ada.Directories.Exists (Delayed_Control & ".attempts")
           and then Ada.Strings.Fixed.Count
             (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
              "failed coordinator") >= 2;
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Delayed_Control & ".attempts")
         and then Ada.Strings.Fixed.Count
           (Project_Tools.Files.Read_Raw_File (Delayed_Control & ".attempts"),
            "failed coordinator") >= 2
         and then Ada.Directories.Exists (To_String (Delayed_Path)),
         "temporary coordinator failure survives both immediate attempts");
      Write_Binary_File (Delayed_Control, "release");
      for Attempt in 1 .. 10_000 loop
         exit when not Ada.Directories.Exists (To_String (Delayed_Path));
         delay 0.001;
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Delayed_Path)),
         "the idle coordinator retries autonomously after access returns");
      if Had_Delayed_Failure then
         Ada.Environment_Variables.Set
           ("FILES_TEST_FAIL_SCAVENGER_UNTIL", Old_Delayed_Failure);
      else
         Ada.Environment_Variables.Clear ("FILES_TEST_FAIL_SCAVENGER_UNTIL");
      end if;

      Create_Abandoned (Report_Path, Abandoned_Path);
      Create_Abandoned (Pre_Lease_Report, Pre_Lease_Path);
      Assert
        (Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "abnormal exits leave their transports for startup recovery");
      declare
         Marker_Header : constant String := "files-job-transport-4";
         Marker_Path   : constant String := Join (To_String (Pre_Lease_Path), ".files-job-transport");
         Marker_Data   : String := Project_Tools.Files.Read_Raw_File (Marker_Path);
         Header_At     : constant Natural := Ada.Strings.Fixed.Index (Marker_Data, Marker_Header);
      begin
         Assert (Header_At > 0, "the fixture starts with the current transport marker");
         Marker_Data (Header_At + Marker_Header'Length - 1) := '3';
         Write_Binary_File (Marker_Path, Marker_Data);
         declare
            Identity : constant String := Files.Job_Transports.Recorded_Identity
              (To_String (Pre_Lease_Path));
            Claim : Files.Job_Transports.Lease;
         begin
            Assert
              (Identity /= ""
               and then Files.Job_Transports.Claim_Abandoned
                 (To_String (Pre_Lease_Path), Identity, Claim) =
                   Files.Job_Transports.Claim_Unrecoverable,
               "truncated-ID markers cannot claim a transport lease");
         end;
         Marker_Data (Header_At + Marker_Header'Length - 1) := '1';
         Write_Binary_File (Marker_Path, Marker_Data);
      end;
      declare
         Identity : constant String := Files.Job_Transports.Recorded_Identity
           (To_String (Pre_Lease_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Assert
           (Identity /= ""
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Pre_Lease_Path), Identity, Claim) =
                Files.Job_Transports.Claim_Unrecoverable,
            "development-format markers never create an independent lease");
      end;
      declare
         Active_Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Active_Path));
         Claim : Files.Job_Transports.Lease;
      begin
         Assert
           (Active_Identity /= ""
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Active_Path), Active_Identity, Claim) =
                Files.Job_Transports.Claim_Busy
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Active_Path), "wrong identity", Claim) =
                Files.Job_Transports.Claim_Refused,
            "lease claims distinguish a live owner from invalid identity input");
      end;
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         declare
            Replacement_Job : Files.Process_Jobs.Session;
            Directory : Files.Types.UString;
            Identity : Files.Types.UString;
            Claim : Files.Job_Transports.Lease;
         begin
            Files.Process_Jobs.Reserve (Replacement_Job);
            Directory := To_Unbounded_String
              (Files.Process_Jobs.Path (Replacement_Job, ""));
            Identity := To_Unbounded_String
              (Files.Job_Transports.Recorded_Identity (To_String (Directory)));
            Ada.Directories.Delete_File
              (Join (To_String (Directory), ".files-job-owner"));
            Write_Binary_File
              (Join (To_String (Directory), ".files-job-owner"), "substitute lease");
            Assert
              (Files.Job_Transports.Claim_Abandoned
                 (To_String (Directory), To_String (Identity), Claim) =
                   Files.Job_Transports.Claim_Unrecoverable
               and then Ada.Directories.Exists (To_String (Directory)),
               "a new inode at the lease pathname cannot claim a live job");
            Files.Process_Jobs.Reset (Replacement_Job);
            Remove_Fixture (Directory);
         end;
         declare
            Directory : Files.Types.UString;
            Identity : Files.Types.UString;
            Owner : Files.Job_Transports.Lease;
         begin
            Files.Job_Transports.Create (Directory, Identity, Owner);
            Assert
              (Files.Job_Transports.Holds (Owner, To_String (Directory)),
               "a newly created transport holds its published lease");
            Ada.Directories.Delete_File
              (Join (To_String (Directory), ".files-job-owner"));
            Write_Binary_File
              (Join (To_String (Directory), ".files-job-owner"), "substitute lease");
            Assert
              (not Files.Job_Transports.Holds (Owner, To_String (Directory)),
               "a held lock does not authorize stage cleanup after lease replacement");
            Files.Job_Transports.Release (Owner);
            Remove_Fixture (Directory);
         end;
      end if;

      declare
         Identity : constant String :=
           Files.Job_Transports.Recorded_Identity (To_String (Abandoned_Path));
         First, Second : Files.Job_Transports.Lease;
      begin
        Assert
          (Files.Job_Transports.Claim_Abandoned
              (To_String (Abandoned_Path), Identity, First) =
                Files.Job_Transports.Claim_Acquired
            and then Files.Job_Transports.Holds
              (First, To_String (Abandoned_Path))
            and then Files.Job_Transports.Claim_Abandoned
              (To_String (Abandoned_Path), Identity, Second) =
                Files.Job_Transports.Claim_Busy,
            "an abandoned transport has one acquired claim and reports later claims as busy");
      end;

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Scavenge_Control);
      Files.Job_Scavenger.Scavenge;
      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Scavenge_Control & ".started");
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Scavenge_Control & ".started")
         and then Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup recovery uses one bounded coordinator before processing transports");
      declare
         First_Child : constant String :=
           Project_Tools.Files.Read_Raw_File (Scavenge_Control & ".started");
         Returned_Before_Release : Boolean := False;
         Same_Child : Boolean;

         task Second_Scan;
         task body Second_Scan is
         begin
            Files.Job_Scavenger.Scavenge;
            Write_Binary_File (Scavenge_Control & ".second-returned", "returned");
         end Second_Scan;
      begin
         for Attempt in 1 .. 500 loop
            exit when Ada.Directories.Exists (Scavenge_Control & ".second-returned");
            delay 0.001;
         end loop;
         Returned_Before_Release :=
           Ada.Directories.Exists (Scavenge_Control & ".second-returned");
         Same_Child := Project_Tools.Files.Read_Raw_File
           (Scavenge_Control & ".started") = First_Child;
         Write_Binary_File (Scavenge_Control & ".release", "release");
         Assert (Returned_Before_Release and then Same_Child,
                 "a repeated scan returns promptly without starting another coordinator");
      exception
         when others =>
            Write_Binary_File (Scavenge_Control & ".release", "release");
            raise;
      end;
      for Attempt in 1 .. 5_000 loop
         exit when not Ada.Directories.Exists (To_String (Abandoned_Path));
         delay 0.001;
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Abandoned_Path))
         and then Ada.Directories.Exists (To_String (Pre_Lease_Path)),
         "startup scavenging removes abandoned jobs but preserves unprovable development transports");
      Assert
        (Ada.Directories.Exists (To_String (Active_Path)),
         "startup scavenging preserves a transport whose owner is still live");

      --  Exercise both sides of marker publication. A lease-free directory
      --  could belong to a paused creator, while a released lease with no
      --  marker proves its owner has stopped.
      Remove_Fixture (Before_Lease_Path);
      Remove_Fixture (Young_Path);
      Remove_Fixture (Payload_Path);
      Remove_Fixture (Similar_Path);
      Files.Private_Directories.Create (To_String (Before_Lease_Path));
      Write_Binary_File
        (Join (To_String (Before_Lease_Path), ".files-job-transport.tmp"), "partial marker");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Before_Lease_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
      declare
         Incomplete_Identity : Files.Types.UString;
         Incomplete_Owner    : Files.Job_Transports.Lease;
      begin
         Files.Job_Transports.Create
           (After_Lease_Path, Incomplete_Identity, Incomplete_Owner);
         Ada.Directories.Delete_File
           (Join (To_String (After_Lease_Path), ".files-job-transport"));
         Files.Job_Transports.Release (Incomplete_Owner);
      end;
      Files.Private_Directories.Create (To_String (Young_Path));
      Files.Private_Directories.Create (To_String (Payload_Path));
      Write_Binary_File (Join (To_String (Payload_Path), "keep"), "unrelated");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Payload_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
      Files.Private_Directories.Create (To_String (Similar_Path));
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Similar_Path), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));

      declare
         Candidate_Identity : Files.Types.UString;
         Candidate_Owner    : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Young_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 60.0) = Files.Job_Transports.Claim_Unrecoverable,
            "a directory without this version's witness is not claimed by age alone");
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Before_Lease_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 0.0) = Files.Job_Transports.Claim_Unrecoverable,
            "age never authorizes a second lease for a potentially live creator");
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Payload_Path), Candidate_Identity, Candidate_Owner,
               Minimum_Age => 0.0) = Files.Job_Transports.Claim_Refused,
            "an unmarked directory with non-protocol payload is classified as refused");
      end;

      declare
         Complete : constant Boolean :=
           Files.Job_Scavenger.Run (Wait_For_Grace => False);
      begin
         Assert
           (Complete,
            "scavenging reports unproven exact-name transports without retrying forever");
      end;
      Assert
        (Ada.Directories.Exists (To_String (Before_Lease_Path)),
         "scavenging preserves a pre-lease creator even when its directory is old");
      Assert
        (Ada.Directories.Exists (To_String (After_Lease_Path)),
         "a markerless lease is preserved because its inode was not published");
      Assert
        (Ada.Directories.Exists (To_String (Young_Path)),
         "a missing witness preserves an unproven pre-lease directory");
      Assert
        (Ada.Directories.Exists (To_String (Payload_Path))
         and then Project_Tools.Files.Read_Raw_File
           (Join (To_String (Payload_Path), "keep")) = "unrelated",
         "unmarked recovery refuses directories containing non-protocol payloads");
      Assert
        (Ada.Directories.Exists (To_String (Similar_Path)),
         "unmarked recovery requires the complete generated transport name format");

      Write_Binary_File
        (Join (To_String (Young_Path), ".files-job-transport.tmp"), "partial marker");
      declare
         Complete : constant Boolean := Files.Job_Scavenger.Run;
      begin
         Assert
           (Complete,
            "scavenging does not retry permanently refused non-protocol transports");
      end;
      Assert
        (Ada.Directories.Exists (To_String (Young_Path)),
         "an expired grace period reports but never deletes a pre-lease directory");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (To_String (Young_Path), GNAT.OS_Lib.GM_Time_Of (2099, 1, 2, 3, 4, 5));
      declare
         Candidate_Identity : Files.Types.UString;
         Candidate_Owner : Files.Job_Transports.Lease;
      begin
         Assert
           (Files.Job_Transports.Claim_Incomplete
              (To_String (Young_Path), Candidate_Identity, Candidate_Owner) =
                Files.Job_Transports.Claim_Unrecoverable,
            "a future timestamp cannot keep a pre-lease directory retrying forever");
      end;

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
         Assert
           (Result.Started and then not Result.Timed_Out
            and then Result.Exit_Status = 0
            and then Ada.Strings.Fixed.Index
              (Project_Tools.Files.Read_Raw_File (Errors), To_String (Young_Path)) > 0,
            "an invalid marker is preserved and reported with its pathname");
         Assert
           (Files.Job_Scavenger.Has_Unrecoverable,
            "the desktop can observe unsafe recovery reported by its child");
      end;

      Assert
        (Files.Private_Directories.Try_Create (Root) =
           Files.Private_Directories.Collision,
         "private directory creation reports an existing pathname as a collision");
      declare
         Unexpected_Success : Boolean := False;
      begin
         begin
            declare
               Result : constant Files.Private_Directories.Create_Result :=
                 Files.Private_Directories.Try_Create
                   (Join (Join (Root, "missing-parent"), "candidate"));
               pragma Unreferenced (Result);
            begin
               Unexpected_Success := True;
            end;
         exception
            when Ada.Directories.Use_Error => null;
         end;
         Assert
           (not Unexpected_Success,
            "private directory setup failures are not misreported as collisions");
      end;

      Remove_Fixture (Payload_Path);
      Remove_Fixture (Similar_Path);
      Assert
        (Files.Job_Scavenger.Run (Wait_For_Grace => False),
         "scavenging reports completion when only a live claimed transport remains");

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Shutdown_Control);
      for Attempt in 1 .. 100 loop
         Files.Job_Scavenger.Scavenge;
         exit when Ada.Directories.Exists (Shutdown_Control & ".started");
         delay 0.05;
      end loop;
      Assert (Ada.Directories.Exists (Shutdown_Control & ".started"),
              "shutdown fixture starts a coordinator that waits for release");
      declare
         File : Ada.Text_IO.File_Type;
         Child_Id : Integer;
         Reaped : Boolean;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Shutdown_Control & ".started");
         Child_Id := Integer'Value (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
         Files.Job_Scavenger.Shutdown (Reaped);
         Assert (Reaped, "shutdown reports a reaped coordinator");
         if Hostkit.Host.Current = Hostkit.Host.Linux
           and then Ada.Directories.Exists ("/proc/self")
         then
            Assert
              (not Ada.Directories.Exists
                 ("/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Child_Id), Ada.Strings.Both)),
               "shutdown reaps the coordinator before returning");
         end if;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end;
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Crash_Transport_Scavenging;

   procedure Test_Stage_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Transport_Job : Files.Process_Jobs.Session;
      Transport_Path : Files.Types.UString;
      function Transport return String is (To_String (Transport_Path));
      Unrelated : constant String := Join (Root, "unrelated");
      Unowned   : constant String := Join (Root, ".files-work-9001");
      Link      : constant String := Join (Root, ".files-work-9002");
      Saved     : constant String := Join (Root, "saved-stage");
      Stage     : Files.Types.UString;
      Identity  : Files.Types.UString;
      File      : Ada.Streams.Stream_IO.File_Type;
      Linked    : Boolean;
      Children_Before : Files.Types.UString;
      Transport_Identity : Files.Types.UString;
      Before    : Ada.Calendar.Time;

      procedure Add_Stage_Record
        (Record_Name, Path, Expected_Identity : String;
         Corrupt : Boolean := False)
      is
         Record_Directory : constant String :=
           Join (Join (Transport, "stages"), Record_Name);
         Record_File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Directories.Create_Directory (Record_Directory);
         Ada.Streams.Stream_IO.Create
           (Record_File, Ada.Streams.Stream_IO.Out_File, Join (Record_Directory, "data"));
         String'Output
           (Ada.Streams.Stream_IO.Stream (Record_File),
            (if Corrupt then "damaged-stage-record" else "files-stage-3"));
         if not Corrupt then
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Path);
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Expected_Identity);
         end if;
         Ada.Streams.Stream_IO.Close (Record_File);
      end Add_Stage_Record;
   begin
      Reset_Root;

      --  The cleanup entry point must fail closed even when an arbitrary
      --  directory's current identity is supplied by its caller.
      declare
         Victim : constant String := Join (Root, "cleanup-victim");
      begin
         Ada.Directories.Create_Directory (Victim);
         Write_Binary_File (Join (Victim, "keep"), "unrelated");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (Victim, Files.File_Identities.Token (Victim), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Ada.Directories.Exists (Victim)
            and then Project_Tools.Files.Read_Raw_File (Join (Victim, "keep")) = "unrelated",
            "cleanup refuses an arbitrary unmarked directory");
      end;

      declare
         Link_Path : constant String := Join (Root, "dangling-transport-link");
         Linked : constant Boolean := Hostkit.Fs.Create_Link
           (Join (Root, "missing-link-target"), Link_Path);
      begin
         if Linked then
            Assert
              (Hostkit.Fs.Is_Link (Link_Path)
               and then not Files.Job_Helpers.Run_Cleanup
                 (Link_Path, "untrusted", Attempt_Limit => 1,
                  Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
               and then Hostkit.Fs.Is_Link (Link_Path),
               "cleanup never reports a dangling symlink as a removed transport");
            Ada.Directories.Delete_File (Link_Path);
         end if;
      end;

      --  A marked transport is removed through the symlink-safe owned-tree
      --  path, so injected links cannot redirect recursive cleanup.
      declare
         Job       : Files.Process_Jobs.Session;
         Owned     : Files.Types.UString;
         Target    : constant String := Join (Root, "cleanup-link-target");
         Link_Path : Files.Types.UString;
         Linked    : Boolean;
      begin
         Ada.Directories.Create_Directory (Target);
         Write_Binary_File (Join (Target, "keep"), "target");
         Files.Process_Jobs.Reserve (Job);
         Owned := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Link_Path := To_Unbounded_String (Join (To_String (Owned), "injected-link"));
         Linked := Hostkit.Fs.Create_Link (Target, To_String (Link_Path));
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Ada.Directories.Exists (To_String (Owned)),
            "cleanup refuses a marked transport while its owner holds the lease");
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Assert
           (Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then not Ada.Directories.Exists (To_String (Owned)),
            "cleanup removes an abandoned marked transport under its own claim");
         Assert
           (not Linked or else Project_Tools.Files.Read_Raw_File (Join (Target, "keep")) = "target",
            "transport cleanup unlinks an injected symlink without following it");
      end;

      --  A marker copied from the genuine directory does not authorize a
      --  replacement subsequently installed at the same pathname.
      declare
         Job      : Files.Process_Jobs.Session;
         Original : Files.Types.UString;
         Saved    : Files.Types.UString;
         Expected : Files.Types.UString;
         Marker   : constant String := ".files-job-transport";

         procedure Restore is
         begin
            --  Windows refuses to remove the transport while its lease handle
            --  is open, so release the session before restoring the fixture.
            Files.Process_Jobs.Reset (Job);
            if Length (Original) > 0 and then Ada.Directories.Exists (To_String (Original)) then
               Project_Tools.Files.Delete_Tree (To_String (Original));
            end if;
            if Length (Saved) > 0 and then Ada.Directories.Exists (To_String (Saved)) then
               Ada.Directories.Rename (To_String (Saved), To_String (Original));
            end if;
         end Restore;
      begin
         Files.Process_Jobs.Reserve (Job);
         Original := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Saved := Original & "-saved";
         Expected := To_Unbounded_String (Files.File_Identities.Token (To_String (Original)));
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Ada.Directories.Rename (To_String (Original), To_String (Saved));
         Ada.Directories.Create_Directory (To_String (Original));
         Write_Binary_File
           (Join (To_String (Original), Marker),
            Project_Tools.Files.Read_Raw_File (Join (To_String (Saved), Marker)));
         Write_Binary_File (Join (To_String (Original), "keep"), "replacement");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Original), To_String (Expected), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Project_Tools.Files.Read_Raw_File
              (Join (To_String (Original), "keep")) = "replacement"
            and then Ada.Directories.Exists (To_String (Saved)),
            "cleanup refuses a replacement carrying the original transport marker");
         Restore;
      exception
         when others => Restore; raise;
      end;

      Files.Process_Jobs.Reserve (Transport_Job);
      Transport_Path := To_Unbounded_String (Files.Process_Jobs.Path (Transport_Job, ""));
      Transport_Identity := To_Unbounded_String (Files.File_Identities.Token (Transport));
      Ada.Directories.Create_Directory (Unrelated);
      Ada.Directories.Create_Directory (Unowned);
      Write_Binary_File (Join (Unrelated, "keep"), "unrelated");
      Files.Job_Context.Initialize (Transport);
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Stage)));
      Ada.Directories.Rename (To_String (Stage), Saved);
      Ada.Directories.Create_Directory (To_String (Stage));
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Join (To_String (Stage), ".files-owner"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-owner-1");
      String'Output (Ada.Streams.Stream_IO.Stream (File), Transport);
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (Ada.Directories.Exists (To_String (Stage)) and then Ada.Directories.Exists (Saved)
              and then Ada.Directories.Exists (Join (Transport, "stages")),
              "cleanup preserves a replacement and retains its ownership record for retry");
      Ada.Directories.Delete_File (Join (To_String (Stage), ".files-owner"));
      Ada.Directories.Delete_Directory (To_String (Stage));
      Ada.Directories.Rename (Saved, To_String (Stage));
      declare
         Unheld : Files.Job_Transports.Lease;
      begin
         Files.Job_Context.Clean_Stages (Transport, Unheld);
         Assert (Ada.Directories.Exists (To_String (Stage)),
                 "an unclaimed stage cleanup cannot delete a live stage");
      end;
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (Join (Transport, "stages")),
              "cleanup retries and removes the restored owned stage");

      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "partial");
      --  Simulate termination after the owner marker was published but before
      --  the write-ahead record was finalized with its identity.
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File,
         Join (Join (Join (Transport, "stages"), "stage-1"), "data"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-3");
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Stage));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "");
      Ada.Streams.Stream_IO.Close (File);
      Linked := Hostkit.Fs.Create_Link (Unrelated, Link);
      Add_Stage_Record ("stage-unrelated", Unrelated, Files.File_Identities.Token (Unrelated));
      Add_Stage_Record ("stage-unowned", Unowned, Files.File_Identities.Token (Unowned));
      Add_Stage_Record ("stage-absent", Join (Root, ".files-work-8000"), "");
      if Linked then
         Add_Stage_Record ("stage-link", Link, Files.File_Identities.Token (Link));
      end if;
      Add_Stage_Record ("stage-corrupt", "", "", Corrupt => True);
      Add_Stage_Record ("stage-truncated", "", "");
      Write_Binary_File
        (Join (Join (Join (Transport, "stages"), "stage-truncated"), "data"),
         "truncated");
      Files.Process_Jobs.Clean_Stages (Transport_Job);
      Assert (not Ada.Directories.Exists (To_String (Stage)), "cleanup removes its own partial staging directory");
      Assert (Project_Tools.Files.Read_Raw_File (Join (Unrelated, "keep")) = "unrelated",
              "cleanup preserves unrelated data");
      Assert (Ada.Directories.Exists (Unowned), "cleanup refuses an unowned staging-shaped pathname");
      Assert (not Linked or else Hostkit.Fs.Is_Link (Link), "cleanup never follows or deletes a substituted symlink");
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt"))
         and then not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-truncated")),
         "malformed stage records are discarded without trusting their contents");
      Assert (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-absent")),
              "a write-ahead reservation with no created pathname is discarded safely");
      Assert
        (not Files.Job_Helpers.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 1,
            Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
         and then Ada.Directories.Exists (Join (Transport, "stages")),
         "bounded cleanup cannot consume stage records while the creator is live");
      Files.Process_Jobs.Testing.Release_Owner (Transport_Job);
      if Hostkit.Host.Current = Hostkit.Host.Linux
        and then not Hostkit.Host.Is_Elevated
      then
         declare
            Data : constant String :=
              Join (Join (Join (Transport, "stages"), "stage-unreadable"), "data");
            Result : Files.File_System.Mutation_Result;
            Outcome : Files.Job_Cleanup.Cleanup_Outcome;
            use type Files.Job_Cleanup.Cleanup_Outcome;
         begin
            Add_Stage_Record
              ("stage-unreadable", Join (Root, ".files-work-missing"), "");
            Result := Files.File_System.Set_Permissions (Data, 0);
            Assert (Result.Success, "make a stage record temporarily unreadable");
            Outcome := Files.Job_Cleanup.Run
              (Transport, To_String (Transport_Identity),
               Attempt_Limit => 1, Discard_Unreadable_On_Last_Attempt => False);
            Assert
              (Outcome = Files.Job_Cleanup.Cleanup_Failed
               and then Ada.Directories.Exists
                 (Join (Join (Transport, "stages"), "stage-unreadable")),
               "one fallback pass keeps an unreadable stage record for later retry");
            Result := Files.File_System.Set_Permissions (Data, 8#600#);
            Assert (Result.Success, "restore stage record access for cleanup");
         end;
      end if;
      Before := Ada.Calendar.Clock;
      Assert
        (not Files.Job_Helpers.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 2,
            Initial_Retry_Delay => 0.001, Maximum_Retry_Delay => 0.001)
         and then Ada.Calendar.Clock - Before < 0.25
         and then not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt"))
         and then not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-truncated")),
         "bounded cleanup does not retry permanently malformed stage records");
      Files.Job_Context.Initialize ("");
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "foreground partial");
      Assert (Files.Job_Context.Discard_Stage (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Stage)),
              "foreground staging records its identity and cleans through the same guarded path");
      Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Stage)));
      if Ada.Directories.Exists ("/proc/thread-self/children") then
         Children_Before := To_Unbounded_String
           (Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children"));
      end if;
      declare
         Owner_Directory : Files.Types.UString;
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Join (To_String (Stage), ".files-owner"));
         Assert (String'Input (Ada.Streams.Stream_IO.Stream (File)) = "files-stage-owner-1",
                 "foreground stage publishes its owner marker atomically");
         Owner_Directory := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
         Ada.Streams.Stream_IO.Close (File);
         Ada.Directories.Rename (To_String (Stage), Saved);
         Ada.Directories.Create_Directory (To_String (Stage));
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Join (To_String (Stage), ".files-owner"));
         String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-owner-1");
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Owner_Directory));
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
         Ada.Streams.Stream_IO.Close (File);
         Assert (not Files.Job_Context.Discard_Stage (To_String (Stage))
                 and then Ada.Directories.Exists (To_String (Stage)),
                 "foreground cleanup refuses a replacement and schedules its owned stage for retry");
         Ada.Directories.Delete_File (Join (To_String (Stage), ".files-owner"));
         Ada.Directories.Delete_Directory (To_String (Stage));
         Ada.Directories.Rename (Saved, To_String (Stage));
         for Attempt in 1 .. 5_000 loop
            exit when not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Owner_Directory));
            delay 0.001;
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Stage))
                 and then not Ada.Directories.Exists (To_String (Owner_Directory)),
                 "idle foreground cleanup retries its durable record and removes its transport");
         if Ada.Directories.Exists ("/proc/thread-self/children") then
            for Attempt in 1 .. 5_000 loop
               exit when Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 To_String (Children_Before);
               delay 0.001;
            end loop;
            Assert
              (Project_Tools.Files.Read_Raw_File ("/proc/thread-self/children") =
                 To_String (Children_Before),
               "idle cleanup leaves no child process waiting for a later job API call");
         end if;
      end;
   exception
      when others => Files.Job_Context.Initialize (""); raise;
   end Test_Stage_Ownership;
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Remote   : constant String :=
        "/dev/shm/files_aunit_replace_recovery-" & Ada.Directories.Simple_Name (Root);
      Tree     : constant String := Join (Root, "replace-source");
      Locked   : constant String := Join (Tree, "locked");
      Dest     : constant String := Join (Remote, "replace-target");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String :=
        (if Had_Back then Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Result   : Files.File_System.Mutation_Result;

      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Result := Files.File_System.Set_Permissions (Root, 8#755#);
         Result := Files.File_System.Set_Permissions (Locked, 8#755#);
         Project_Tools.Files.Delete_Tree (Remote);
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         return;
      end if;
      Reset_Root;
      begin
         Ada.Directories.Create_Directory (Remote);
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error => return;
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Tree), To_Unbounded_String (Dest), False, True));
      for Background in Boolean loop
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Locked, "keep"), "complete");
         Write_Binary_File (Dest, "original");
         Result := Files.File_System.Set_Permissions (Locked, 8#555#);
         Assert (Result.Success, "preserve a readonly nested directory in the copied destination");
         Result := Files.File_System.Set_Permissions (Root, 8#555#);
         Assert (Result.Success, "the fixture permits copying but refuses atomic source removal");
         Files.Model.Initialize (Model, Remote, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
         for Attempt in 1 .. 10_000 loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
            delay 0.001;
         end loop;
         Result := Files.File_System.Set_Permissions (Root, 8#755#);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model)
                 and then Step.Status = Files.Operations.Operation_Failed,
                 "refused source removal completes as a failed replacement");
         Assert (not Files.Model.Undo_Available (Model)
                 and then File_Has_Bytes (Dest, "original")
                 and then File_Has_Bytes (Join (Locked, "keep"), "complete"),
                 "rollback restores the original, preserves the source and leaves no unusable history");
         Await_View (Model, Settings);
         Result := Files.File_System.Set_Permissions (Locked, 8#755#);
         Project_Tools.Files.Delete_Tree (Tree);
         Ada.Directories.Delete_File (Dest);
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Failed_Replace_Rollback;

end Files_Suite.Operations;

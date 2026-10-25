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
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Zlib;

with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Process;
with Hostkit.Signals;
with Hostkit.Spawn;

with Files.Application;
with Files.Application.Windows;
with Files.Desktop_Applications;
with Files.Archive_Writing;
with Files.Commands;
with Files.Controller;
with Files.Copy_Context;
with Files.Exclusive_Streams;
with Files.Events;
with Files.File_System;
with Files.Io_Errors;
with Files.Folder_Size;
with Files.Folder_Tree;
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
with Files_Suite.Support;

package body Files_Suite.Operations is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.Private_Directories.Create_Result;
   use type Files.Job_Transports.Claim_Outcome;
   use type Files.Events.Input_Action_Kind;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Guikit.Draw.Accessibility_Role;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Interfaces.C.long_long;
   use type Hostkit.Lease_Files.Open_Outcome;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.String_Vectors.Vector;
   use type Files.Types.Search_Scope;
   use type Files.Types.View_Mode;
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
      for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
         Result := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the background filesystem operation completes");
      return Result;
   end Complete_Operation;

   --  Make Directory read-only and say whether that refuses a new entry: as
   --  root, or on a host whose mode bits this suite does not drive, a create
   --  still succeeds and a refused write has nothing to observe.
   --  @param Directory Existing directory to lock.
   --  @return True when a file can no longer be created in Directory.
   function Lock_Directory (Directory : String) return Boolean;

   --  Give Directory its owner's write access back.
   --  @param Directory Directory Lock_Directory locked.
   procedure Unlock_Directory (Directory : String);

   procedure Unlock_Directory (Directory : String) is
      Unlocked : constant Files.File_System.Mutation_Result :=
        Files.File_System.Set_Permissions (Directory, 8#755#);
      pragma Unreferenced (Unlocked);
   begin
      null;
   end Unlock_Directory;

   function Lock_Directory (Directory : String) return Boolean is
      use type GNAT.OS_Lib.File_Descriptor;
      Probe : constant String := Join (Directory, ".write-probe");
      Descriptor : GNAT.OS_Lib.File_Descriptor;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux
        or else Hostkit.Host.Is_Elevated
        or else not Files.File_System.Set_Permissions (Directory, 8#555#).Success
      then
         return False;
      end if;
      Descriptor := GNAT.OS_Lib.Create_New_File (Probe, GNAT.OS_Lib.Binary);
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return True;
      end if;
      GNAT.OS_Lib.Close (Descriptor);
      Unlock_Directory (Directory);
      Ada.Directories.Delete_File (Probe);
      return False;
   end Lock_Directory;

   procedure Test_Io_Error_Classifier (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Rename_Trash_Delete_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Save_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Exec_Quoted_Percent (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Destructive_Helper_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Pending_Create_Mutation_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Duplicate_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Same_Size_Edits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Plain_Listing_Makes_No_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Move_Source_Changes_Off_Volume (T : in out AUnit.Test_Cases.Test_Case'Class);
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

   --  Saves XDG_DATA_HOME, HOME and FILES_TRASH_BACKEND, resets Root and the
   --  XDG trash fixture, runs Check, removes the trash fixtures, and restores
   --  the environment (also when Check raises).
   procedure With_Trash_Environment (Check : not null access procedure);
   procedure Test_Trash_Deletion_Date (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Backend_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Native_Trash_Adapters (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Xdg_Trash_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Name_Collisions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Backspace_And_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Selection_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Nested_Trash_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_File_Open_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Shell_Environment (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Click_Selects_Without_Opening (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Explicit_Shell_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Executable_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Return_And_Double_Click_Open (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recursive_Search (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Change_Watcher (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Execution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Import_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permanent_Delete_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Backslash_Executable_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Png_Thumbnail_Decoding (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Load_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Entries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Command_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_Create_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_Rename_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Type_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Localized_Extras (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Frame_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Word_Wrap (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Item_Field_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Multi_Selection_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   --  Info-pane detail text as the renderer composes it: localized prefix, value, localized suffix.
   function Detail_Value (Prefix_Key : String; Value : String; Suffix_Key : String) return String;
   --  Detail_Value with the value itself looked up in the localization catalog.
   function Detail_Localized_Value (Prefix_Key : String; Value_Key : String; Suffix_Key : String) return String;
   --  A line-count detail followed by the localized encoding detail.
   function Detail_Lines_Encoding
     (Lines_Prefix_Key : String;
      Lines            : String;
      Lines_Suffix_Key : String;
      Encoding_Key     : String)
      return String;
   --  Write the info-pane metadata fixtures (text, source, office, PDF, PNG, JPEG) into Root.
   procedure Write_Info_Metadata_Fixtures;
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
   procedure Test_Controller_Home_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   --  Saves the XDG and locale variables, resets Root, writes the desktop-entry
   --  fixture under it, points the XDG/locale variables at it, runs Check, and
   --  restores the environment (also when Check raises).
   procedure With_Desktop_Application_Fixture (Check : not null access procedure);
   --  The application named Name, or one with every field empty.
   function Find_Application
     (Apps : Files.Desktop_Applications.Application_Vectors.Vector;
      Name : String)
      return Files.Desktop_Applications.Application;
   procedure Test_Desktop_Application_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Exec_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_With_Palette_Launch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Relative_Xdg_Application_Paths (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Stale_Background_Results (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Result_Mismatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Protocol_Gaps (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Journal_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Request_Path_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Item_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Job_Item_Large_Account_Ids (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Operation_Result_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transfer_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Replacement_Checkpoint_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Truncated_Persisted_Records (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Helper_Lease_Survives_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   --  Runs this executable's abandon-transport crash fixture, which reports the
   --  transport it left behind in the file Report; Path receives that pathname.
   procedure Create_Abandoned_Transport (Report : String; Path : out Files.Types.UString);
   --  Deletes the transport directory Path when it is set and exists.
   procedure Remove_Transport_Fixture (Path : Files.Types.UString);
   procedure Test_Exclusive_Stream_Hardlink (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_Operation_Result_Record_Validation'Access, "operation results reject inconsistent action metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Transfer_Record_Validation'Access,
         "transfer results and requests reject inconsistent or multiply-linked records");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replacement_Checkpoint_Validation'Access,
         "replacement checkpoints reject trailing fields and linked files");
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
        (T, Test_Transfer_Cancellation'Access, "a transfer cancels between chunks without losing its source");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Transfers'Access, "background transfers preserve content, ownership, and cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Replace_Trash_Failure'Access, "a failed trash operation during Replace preserves the original");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cross_Device_Recovery'Access,
         "cross-device move, trash, and restore failures preserve recoverable data");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Deletion_Date'Access, "trash deletion dates format whole seconds without rounding up");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Backend_Selection'Access,
         "the trash backend, availability and preflight follow the environment and path identity");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_Trash_Adapters'Access,
         "native Windows and macOS trash adapters report their support per host");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Xdg_Trash_Move'Access, "Delete moves the selected item into an owner-only XDG trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Name_Collisions'Access, "trash name collisions choose a suffixed name and metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Backspace_And_Encoding'Access,
         "Backspace trashes too and trashinfo percent-encodes the original path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_Selection_Trash'Access,
         "multi-selection trash moves every item or, on preflight failure, none");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Nested_Trash_Preflight'Access, "trash refuses to move a directory into its own trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Macos_Home_Trash_Fallback'Access, "a macOS-style ~/.Trash is used directly as a fallback");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stray_Home_Trash_Stays_Freedesktop'Access,
         "a stray ~/.Trash outside macOS leaves the freedesktop trash in use");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Volume_Trash'Access,
         "an item on another volume goes to that volume's trash, listed, restored and deleted from there");
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
        (T, Test_Open_Action_Policy'Access, "open-action policy records its execution contract");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_File_Prepares_Action'Access, "open file executes configured action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_File_Open_Preflight'Access, "multi-file open preflights every action before spawning");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Shell_Environment'Access, "open-action shell follows the host shell environment");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Click_Selects_Without_Opening'Access, "item click selects without opening and keeps focus rules");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Explicit_Shell_Open_Actions'Access, "explicit shell open actions quote arguments and launch detached");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Executable_Preflight'Access,
         "open actions reject missing, directory and placeholder executables");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Return_And_Double_Click_Open'Access, "Return and double-click run the modifier-specific open action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Missing_Open_Action_Reports_Error'Access, "missing open action reports localized error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_File'Access, "commit create-file temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_Folder'Access, "commit create-folder temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Does_Not_Overwrite'Access, "create-file refuses existing destination");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recursive_Search'Access, "recursive search finds nested matches and routes through commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Change_Watcher'Access, "directory watcher detects changes and refreshes the model");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Execution'Access, "drop import copies, moves and arms the conflict dialog");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Import_Guards'Access, "drop import handles same-directory, into-self and same-name sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permanent_Delete_Guards'Access, "permanent delete refuses unsafe targets and unlinks symlinks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Backslash_Executable_Lookup'Access, "a POSIX executable containing a backslash is found on PATH");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Generation'Access, "thumbnail generation writes safe owner-only cache artifacts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Png_Thumbnail_Decoding'Access, "PNG thumbnails decode, bound inflate and composite transparency");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Load_Thumbnails'Access, "the generating listing auto-generates image thumbnails");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Entries'Access, "thumbnail cache entries are validated when loaded");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Command_Rendering'Access, "thumbnail command output reaches the large-icons atlas only");
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
        (T, Test_Invalid_Create_Names'Access, "create rejects invalid names without writing anything");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_Rename_Names'Access, "rename rejects invalid names and leaves the source in place");
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
        (T, Test_Info_Pane_Type_Metadata'Access, "item snapshots localize per-filetype metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Localized_Extras'Access, "info pane localizes every extra-info token kind");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Frame_Layout'Access, "info pane frame lays out heading, rows and permission matrix");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Word_Wrap'Access, "info metadata wraps at word boundaries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Item_Field_Fallbacks'Access, "info pane reports metadata errors and item-field fallbacks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Multi_Selection_Snapshot'Access, "info snapshot covers every selected item, coalesced");
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
        (T, Test_Controller_Home_Loading'Access, "controller home loads items, and a failed home keeps the view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Refresh_Loading'Access,
         "controller refresh loads items, and a failed refresh keeps the view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_History_Loading'Access,
         "controller back, forward and path input load items and roll back on failure");
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
        (T, Test_Desktop_Application_Discovery'Access,
         "open-with discovers valid desktop entries and rejects malformed or hidden ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Exec_Expansion'Access, "desktop Exec templates expand into launch argument vectors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_With_Palette_Launch'Access,
         "the Open With palette launches per target and reports a missing executable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Relative_Xdg_Application_Paths'Access,
         "application discovery ignores relative XDG data paths");
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
        (T, Test_Duplicate_Undo_Identity'Access, "Undo protects replaced files, folders and links across Redo cycles");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Same_Size_Edits'Access, "Undo refuses copies changed by a same-size edit with restored mtime");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Admits_Verified_Identities'Access,
         "history admits only entries with verifiable publication identities");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Undo_Identity'Access, "partial paste Undo never removes replacements of its entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Keeps_Place'Access,
         "a refresh keeps the scroll and Quick Look, and waits while the palette is open");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Navigation_Defers_Thumbnails'Access,
         "opening a folder never waits on new thumbnails: a background listing makes them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Plain_Listing_Makes_No_Thumbnails'Access,
         "a plain directory listing decodes no image and writes no thumbnail cache file");
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
        (T, Test_Move_Source_Changes_Off_Volume'Access,
         "a folder moved off another volume keeps its source when a child changes during the copy, on FAT too");
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Io_Error_Classifier'Access,
         "each errno a user can act on names its cause; others keep the generic key");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_Read_Only_Cause'Access, "creating in a read-only folder reports permission denied");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Read_Only_Cause'Access, "copying into a read-only folder reports permission denied");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Read_Only_Cause'Access,
         "a paste into a read-only folder reports permission denied, in a helper too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Rename_Trash_Delete_Read_Only_Cause'Access,
         "rename, trash and delete in a read-only folder report permission denied");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Save_Read_Only_Cause'Access,
         "saving settings into a read-only folder reports permission denied");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Exec_Quoted_Percent'Access,
         "a quoted %% in a desktop Exec line is a literal percent sign");
   end Register_Tests;

   procedure With_Trash_Environment (Check : not null access procedure) is separate;

   procedure Test_Trash_Deletion_Date (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Backend_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Native_Trash_Adapters (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Xdg_Trash_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Name_Collisions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Backspace_And_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Selection_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Nested_Trash_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_File_Open_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Shell_Environment (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Click_Selects_Without_Opening (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Explicit_Shell_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Executable_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Return_And_Double_Click_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recursive_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Directory_Change_Watcher (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Import_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permanent_Delete_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Backslash_Executable_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Png_Thumbnail_Decoding (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Directory_Load_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Entries (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Command_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   --  Names no host accepts, shared by the create and rename checks.
   function Nul_Name return String is ("bad" & Character'Val (0) & "name.txt");
   function Tab_Name return String is ("bad" & Character'Val (9) & "name.txt");
   function C1_Name return String is ("bad" & Character'Val (133) & "name.txt");
   function Encoded_C1_Name return String is ("bad" & Byte (16#C2#) & Byte (16#85#) & "name.txt");
   function Truncated_UTF8_Name return String is ("bad" & Byte (16#E2#) & Byte (16#82#) & "name.txt");
   function Overlong_UTF8_Name return String is ("bad" & Byte (16#C0#) & Byte (16#AF#) & "name.txt");
   function NBSP_Name return String is
     (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#)));
   function Ideographic_Space_Name return String is
     (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#3000#)));
   function Trailing_NBSP_Name return String is ("trailing-nbsp" & NBSP_Name);
   function Trailing_Ideographic_Name return String is ("trailing-wide" & Ideographic_Space_Name);

   procedure Test_Invalid_Create_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Invalid_Rename_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Chained_Rename_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Detail_Value (Prefix_Key : String; Value : String; Suffix_Key : String) return String is separate;

   function Detail_Localized_Value (Prefix_Key : String; Value_Key : String; Suffix_Key : String) return String
     is separate;

   function Detail_Lines_Encoding
     (Lines_Prefix_Key : String;
      Lines            : String;
      Lines_Suffix_Key : String;
      Encoding_Key     : String)
      return String is separate;

   procedure Write_Info_Metadata_Fixtures is separate;

   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Type_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Localized_Extras (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Frame_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Word_Wrap (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Item_Field_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Multi_Selection_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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
      for Attempt in Files_Suite.Support.Polling loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings);
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
      end loop;
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "the operation's reload completes");
   end Await_View;

   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Plain_Listing_Makes_No_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Duplicate_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Same_Size_Edits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Move_Source_Changes_Off_Volume (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Pending_Create_Mutation_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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
   procedure Test_Background_Folder_Size_Matches_Reference (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  A multi-item selection measures every selected directory: each folder's
   --  recursive size is cached under its own path so the info pane can show a
   --  per-folder size and a combined selection total.
   procedure Test_Folder_Size_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The combined selection total (shown in the bottom bar) counts the recursive
   --  size of selected folders, not just selected files -- and it is computed for
   --  any selection, independent of the info pane.
   procedure Test_Selection_Total_Counts_Folders (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Home_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Hardlink_Dangling_Symlink (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unreadable_Hardlink_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure With_Desktop_Application_Fixture (Check : not null access procedure) is separate;

   function Find_Application
     (Apps : Files.Desktop_Applications.Application_Vectors.Vector;
      Name : String)
      return Files.Desktop_Applications.Application is separate;

   procedure Test_Desktop_Application_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Exec_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_With_Palette_Launch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Relative_Xdg_Application_Paths (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Operation_Test_Case));
      return Result;
   end Suite;

   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   --  Drive a background operation to completion the way the UI does:
   --  its progress overlay is open, and it is collected without blocking.
   procedure Finish_Background_Operation
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Step     : in out Files.Operations.Operation_Result) is
   begin
      Assert (Files.Model.Paste_Execution_Is_Active (Model),
              "a long operation returns with its progress overlay open");
      for Attempt in Files_Suite.Support.Polling loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Assert (not Files.Model.Paste_Execution_Is_Active (Model),
              "the UI collects the helper result without blocking");
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "the background operation completes successfully");
   end Finish_Background_Operation;

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

   procedure Test_Transfer_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Replacement_Checkpoint_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Truncated_Persisted_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Autonomous_Cleanup_Worker (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Helper_Lease_Survives_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Create_Abandoned_Transport (Report : String; Path : out Files.Types.UString) is separate;

   procedure Remove_Transport_Fixture (Path : Files.Types.UString) is separate;

   procedure Test_Exclusive_Stream_Hardlink (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Io_Error_Classifier (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Rename_Trash_Delete_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Save_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Exec_Quoted_Percent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

end Files_Suite.Operations;

with Files.File_System.Thumbnails;
with Files.Items;
with Files.Model.Testing;
with Files.File_Identities;
with Files.Process_Jobs;
with Files.Resources;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces.C.Strings;
with Files.Quick_Look;
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
with Hostkit.Process;
with Files.Desktop_Applications;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Io_Errors;
with Files.History_Journal;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Model.History;
with Files.Icon_Assets;
with Files.Operations;
with Files.Operations.Testing;
with Hostkit.Fs;
with Hostkit.Metadata;
with Guikit.Draw;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files.Model.Pasting;
with Files.Resources.Testing;

package body Files_Suite.Operations is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Thumbnails.Thumbnail_Status;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.Search_Scope;
   use type Files.Types.View_Mode;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Operation_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Operation_Test_Case);

   procedure Test_Io_Error_Classifier (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Io_Error_Code_Per_Task (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Rename_Trash_Delete_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Save_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Exec_Quoted_Percent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Terminal_Entries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Long_Path_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Pending_Create_Mutation_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Batch_Undo_Records (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Environment_Guard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_User_Visible_Mount_Points (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permanent_Delete_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Builtin_Icons_Match_Share (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Merge_Keeps_Unjournaled (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hardlink_Dangling_Symlink (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Unreadable_Hardlink_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Fifo_Never_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Host_Hidden_Flag_Hides (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Registry_Changes_Wait_For_Its_Lock (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_View_Refresh_And_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stale_Click_Matches_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlay_Order_Is_Drawing_Order (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Change_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_When_Already_Unloadable (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Persist_Applied_Settings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sort_Is_Total_Order (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Select_Visible_Set (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files operations");
   end Name;

   overriding procedure Register_Tests (T : in out Operation_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Registry_Changes_Wait_For_Its_Lock'Access,
         "a recovery registry change waits for the registry's lock and goes ahead once it is let go");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_User_Visible_Mount_Points'Access,
         "the root list shows what is mounted under the mount containers, never the containers themselves");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permanent_Delete_Guards'Access, "permanent delete refuses unsafe targets and unlinks symlinks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Permission_String_Agrees_With_The_Host'Access,
         "the permission column's execute bit matches what the host says");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Labels_Forget_Deleted_And_Follow_Background'Access,
         "a permanent delete forgets labels and favorites, and a background Undo carries labels back");
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
        (T, Test_Builtin_Icons_Match_Share'Access,
         "the compiled-in icon definitions equal the bundled icon files and guikit holds none");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Duplicate_Selected_Operation'Access, "duplicate selected item into a uniquely named copy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Merge_Keeps_Unjournaled'Access,
         "A background helper's history merges back without losing what its journal left out");
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
        (T, Test_Toggle_Hidden_Files'Access, "toggle hidden files persists and reloads with new visibility");
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
        (T, Test_Fifo_Never_Blocks'Access,
         "a FIFO lists, searches, previews, thumbnails and copies without blocking anything");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Host_Hidden_Flag_Hides'Access,
         "a file the host marks hidden (or a dot file) is hidden in the listing and counted as hidden");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_View_Operation'Access,
         "recent view lists stored paths (missing skipped), records opens, and clears");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Duplicate'Access, "Recent duplicates stay beside each source and retain the view and Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_View_Refresh_And_Rollback'Access,
         "The recent view refreshes in place and a failed Back returns to it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stale_Click_Matches_Path'Access,
         "A stale click finds the drawn item by its path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlay_Order_Is_Drawing_Order'Access,
         "Overlay input, Escape and drawing follow one order");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Change_Policy'Access,
         "Every settings change follows one save policy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_When_Already_Unloadable'Access,
         "Settings that already do not load still take a small change");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Persist_Applied_Settings'Access,
         "Settings applied by a drag or the wheel are saved as they stand");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sort_Is_Total_Order'Access,
         "Equal names sort the same whatever their input order");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Select_Visible_Set'Access,
         "Selecting a set of visible rows at once");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Pending_Create_Mutation_Guards'Access,
         "pending inline creation blocks direct selection mutations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Batch_Undo_Records'Access,
         "a batch records its Undo at most once a second, and reports a batch it cannot record for Undo");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Environment_Guard'Access, "the test environment guard restores variables, on an exception too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Io_Error_Classifier'Access,
         "each errno a user can act on names its cause; others keep the generic key");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Io_Error_Code_Per_Task'Access,
         "an error code recorded by one task is not cleared by another task's reset");
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Terminal_Entries'Access,
         "Terminal=true desktop entries run inside a terminal, and Path is read");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Long_Path_Operations'Access,
         "every file operation works in a folder past the Windows path limit");
   end Register_Tests;

   procedure Test_User_Visible_Mount_Points (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permanent_Delete_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Clicking the free-space field cycles its display: free -> used -> bar ->
   --  free, tracked by the Show_Used_Space / Show_Space_Bar settings.
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Builtin_Icons_Match_Share (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Batch_Undo_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Environment_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Pending_Create_Mutation_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  A FIFO opened for reading blocks until a writer arrives, so every path
   --  that reads a listed entry must refuse it or open it without waiting.
   procedure Test_Host_Hidden_Flag_Hides (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Fifo_Never_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Special_Entry_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Hardlink_Dangling_Symlink (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Unreadable_Hardlink_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Merge_Keeps_Unjournaled (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_View_Refresh_And_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stale_Click_Matches_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlay_Order_Is_Drawing_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Change_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_When_Already_Unloadable (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Persist_Applied_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sort_Is_Total_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Select_Visible_Set (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Registry_Changes_Wait_For_Its_Lock (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Io_Error_Classifier (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Io_Error_Code_Per_Task (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Copy_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Rename_Trash_Delete_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Save_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Exec_Quoted_Percent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Terminal_Entries (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Long_Path_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Operation_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Operations;

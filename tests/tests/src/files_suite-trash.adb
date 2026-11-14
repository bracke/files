with Files.Items;
with Files.File_Identities;
with Files.Process_Jobs;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Ada.Strings;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with Hostkit.Host;
with Hostkit.Process;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Interaction;
with Files.Model;
with Files.Model.Selection;
with Files.Model.History;
with Files.Operations;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Trash is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.File_System.Trash_Backend;
   use type Files.Operations.Operation_Status;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Types.Item_Kind;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Trash_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Trash_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Trash_Test_Case);

   procedure Test_Restore_Keeps_Trash_Until_Synced (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Deletion_Date (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Backend_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Native_Trash_Adapters (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recycle_Bin_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Xdg_Trash_Move (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Name_Collisions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Backspace_And_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Selection_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Nested_Trash_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Input_Opens_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Input_Relative_To_View (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Long_Name (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_Checks_Trashed_Identity (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Trash_Refuses_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Trash_Already_Restored (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Trash_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files trash");
   end Name;

   overriding procedure Register_Tests (T : in out Trash_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Trash_Undo_Refresh'Access, "Undo immediately relists a Recent item restored from trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Symlink_Recovery'Access, "trash, permanent delete and Undo operate on valid and dangling links");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Deletion_Date'Access, "trash deletion dates format whole seconds without rounding up");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Backend_Selection'Access,
         "the trash backend, availability and preflight follow the environment and path identity");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_Trash_Adapters'Access,
         "native Windows and macOS trash adapters report their support per host");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recycle_Bin_Trash_View'Access,
         "the windows recycle bin is the trash view, restored from, undone and deleted from");
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
        (T, Test_Path_Input_Opens_Trash_View'Access,
         "typing the trash's path into the path bar opens the trash view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Input_Relative_To_View'Access,
         "a relative path typed into the path bar is taken from the folder on screen");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Long_Name'Access,
         "a name too long for the trash's own additions is trashed shortened and restored whole");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash'Access, "restore operation returns trashed item to original path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash_Guards'Access,
         "restore refuses (keeping the payload) when the destination or its parent is unavailable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_Checks_Trashed_Identity'Access,
         "Undo's restore checks the trashed item's identity");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Refuses_Volume_Trash'Access,
         "A volume trash and what is in it are not trashed");
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
        (T, Test_Labels_Travel_Through_Trash'Access,
         "a trashed file's label goes into the trash with it, comes back on restore, and goes with Empty Trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Trash_Already_Restored'Access,
         "Undo of a trash whose item is already back succeeds");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_Keeps_Trash_Until_Synced'Access,
         "a restore across devices keeps the trash's copy until the restored one is synced");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Trash_Source_Verification'Access,
         "cross-device trash retains edited and replaced sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Trash_Hidden'Access, "Empty Trash purges hidden payloads regardless of display preferences");
   end Register_Tests;

   procedure Test_Trash_Deletion_Date (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Backend_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Native_Trash_Adapters (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recycle_Bin_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Xdg_Trash_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Name_Collisions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Backspace_And_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Selection_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Nested_Trash_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stray_Home_Trash_Stays_Freedesktop (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Input_Opens_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Input_Relative_To_View (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Long_Name (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_Checks_Trashed_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Refuses_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Undo_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_Keeps_Trash_Until_Synced (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Trash_Already_Restored (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Trash_Undo_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Trash_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Trash;

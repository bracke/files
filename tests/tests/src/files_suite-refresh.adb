with Files.Items;
with Files.Model.Testing;
with Files.Process_Jobs;
with Files.Refresh_Jobs;
with Files.Refresh_Jobs.Testing;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Interaction;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Operations;
with Files.Paste;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files.Model.Pasting;

package body Files_Suite.Refresh is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Refresh_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Refresh_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Refresh_Test_Case);

   procedure Test_Tree_Subdirectories (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Applies_With_Refused_Settings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Keeps_Info_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Named_Selection_Revealed (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Change_Watcher (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Watch_Pacing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Home_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Native_Watch_End_To_End (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Refresh_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files refresh and navigation");
   end Name;

   overriding procedure Register_Tests (T : in out Refresh_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Error_Recovery'Access,
         "refresh recovery clears load errors and preserves operation errors and newer state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Refresh'Access, "background refresh applies matching snapshots and rejects stale reads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Owed_Reloads'Access,
         "edits within a view discard stale background results but never the reload they owe");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stalled_Refresh'Access, "stalled refresh and native watches never hold polling or paste cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_Watch_End_To_End'Access, "a change in a watched folder reaches the window through its helper");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Change_Watcher'Access, "directory watcher detects changes and refreshes the model");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Watch_Pacing'Access, "watch refreshes are paced and a failed load is retried slowly");
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
        (T, Test_Tree_Subdirectories'Access,
         "the folder tree's lean listing names the folders a full listing does");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Applies_With_Refused_Settings'Access,
         "a background refresh applies in a session whose settings failed to load");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Keeps_Place'Access,
         "a refresh keeps the scroll and Quick Look, and waits while the palette is open");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Refresh_Keeps_Info_Pane'Access,
         "a watch refresh keeps the info pane's scroll and the details read for an unchanged item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Named_Selection_Revealed'Access,
         "a selection set by name, by a reload or a command, is marked to be scrolled into view");
   end Register_Tests;

   procedure Test_Directory_Change_Watcher (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Watch_Pacing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Keeps_Info_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Named_Selection_Revealed (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Subdirectories (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Applies_With_Refused_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Home_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Native_Watch_End_To_End (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Owed_Reloads (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Refresh_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Refresh;

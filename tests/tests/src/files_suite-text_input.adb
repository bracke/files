with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Root_Selector;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Guikit.Layout;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for the text fields: typing, focusing clicks, and what a
--  focused field keeps from the grid, through the real input pipeline (the
--  rules in Files_Suite.Interaction_Support).
package body Files_Suite.Text_Input is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Types.Focus_Target;
   use type Files.Types.Search_Scope;
   use Files_Suite.Interaction_Support;

   type Text_Input_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Text_Input_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Text_Input_Test_Case);

   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Entry_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Focus_Blocks_File_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Text_Input_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files text input");
   end Name;

   overriding procedure Register_Tests (T : in out Text_Input_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Entry_Updates_Focused_Input'Access,
         "typed text routes to the focused filter and command-palette inputs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Entry_Contained_By_Overlays'Access,
         "non-text overlays contain native character input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Input_Click_Focuses'Access, "toolbar input click focuses the field and sets the cursor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Focus_Blocks_File_Shortcuts'Access,
         "file shortcuts never fire behind a focused text field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Scope_Chip_Cycles'Access,
         "clicking the filter-bar scope chip cycles the scope, re-runs the query, "
         & "and does not focus the filter input");
   end Register_Tests;

   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Entry_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Focus_Blocks_File_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Text_Input_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Text_Input;

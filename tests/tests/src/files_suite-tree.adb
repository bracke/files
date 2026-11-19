with Files.Items;
with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Files.Breadcrumbs;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Folder_Tree;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Root_Selector;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files.UI_Types;
with Files_Config;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for the breadcrumbs, the folder tree and the root
--  (favourites) selector, through the real input pipeline (the rules in
--  Files_Suite.Interaction_Support).
package body Files_Suite.Tree is

   use AUnit.Assertions;
   use type Files.Controller.Controller_Status;
   use type Files.File_System.Path_Status;
   use type Files.UI_Types.Focus_Target;
   use Files_Suite.Interaction_Support;

   type Tree_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Tree_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Tree_Test_Case);

   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Toggle_Reseeds_Tree (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Unreadable_Folder_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Reexpand_Rereads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Reread_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Pick_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Panel_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Right_On_Empty_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Large_Folder_Tree (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Tree_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files folder tree and root selector");
   end Name;

   overriding procedure Register_Tests (T : in out Tree_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Click_Navigates'Access, "root-selector row click navigates to the chosen root");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Toggle_Reseeds_Tree'Access,
         "starring or unstarring a favorite with the tree shown reseeds its roots");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Selector_Star_And_Clicks'Access,
         "the selector stars favorites; a folder favorite navigates in and a file favorite opens its parent selected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Stale_Entry_Is_Skipped'Access,
         "clicking a stale favorite does not crash and is skipped");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Breadcrumb_Segments_And_Elide'Access,
         "a path segments into (label, ancestor) pairs and a long path elides to root plus tail");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Breadcrumb_Click_Navigates'Access,
         "clicking a breadcrumb segment navigates to that ancestor directory");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Expand_Collapse_And_Hidden'Access,
         "expanding a tree node loads subdirectories, flattens with depths, collapses, and respects hidden files");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Unreadable_Folder_Keeps_Children'Access,
         "re-expanding a folder that cannot be read keeps its children and reports why");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Reexpand_Rereads'Access,
         "a folder expanded again shows what it holds now");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Reread_Keeps_Children'Access,
         "a re-read folder keeps its children's nodes, subtrees and expanded state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Toggle_Command_And_Click'Access,
         "the tree toggle command flips the panel and a label click navigates through the reducer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Pick_Keyboard'Access,
         "the destination-pick tree navigates by arrows, expands/collapses, and confirms on Enter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Panel_Keyboard'Access,
         "Tab reaches the folder tree, whose rows then take the arrows, Enter and Escape");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Right_On_Empty_Folder'Access,
         "Right on an expanded folder with no children keeps the tree highlight");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Large_Folder_Tree'Access,
         "a folder tree of 150,000 shown folders flattens without exhausting the stack");
   end Register_Tests;

   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Toggle_Reseeds_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Unreadable_Folder_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Reexpand_Rereads (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Reread_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Pick_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Panel_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Right_On_Empty_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Large_Folder_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Tree_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Tree;

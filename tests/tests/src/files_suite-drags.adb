with Files.Items;
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
with Files.Model;
with Files.Model.Selection;
with Files.Model.Root_Selector;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Guikit.Layout;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for pointer drags (scrollbar, column resize and reorder,
--  marquee) and file drops, through the real input pipeline (the rules in
--  Files_Suite.Interaction_Support).
package body Files_Suite.Drags is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use Files_Suite.Interaction_Support;

   type Drags_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Drags_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Drags_Test_Case);

   procedure Test_Drop_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Width_Reference_Units (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Resize_Persists_On_Release (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Waits_For_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Drags_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files drags and drops");
   end Name;

   overriding procedure Register_Tests (T : in out Drags_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Contained_By_Overlays'Access,
         "input-owning overlays contain native file drops");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scrollbar_Drag_Begin'Access, "scrollbar thumb click begins a drag the shell owns");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Resize_Drag'Access,
         "a header separator press begins a resize (not a sort) and drag persists the new width");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Width_Reference_Units'Access,
         "a column dragged at a 2x line height is stored in reference units and drawn back at the dragged pixel width");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Resize_Persists_On_Release'Access,
         "a column-resize drag writes the settings once, when it ends, not on every move");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Reorder_Drag'Access,
         "a header cell press begins a reorder that drops+persists, while a plain click still sorts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee_Selection_Drag'Access,
         "an empty-space press begins a marquee that selects the items it touches and unions when additive");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Waits_For_Overlay'Access,
         "a drop made while an overlay owns the input waits for it to close");
   end Register_Tests;

   procedure Test_Drop_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Width_Reference_Units (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Resize_Persists_On_Release (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drop_Waits_For_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Drags_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Drags;

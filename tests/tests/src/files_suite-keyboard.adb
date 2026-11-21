with Files.Operations;
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
with Files.Model.Rename;
with Files.Model.History;
with Guikit.Draw;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.UI_Types;
with Guikit.Settings_Panel;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for key dispatch: shortcuts, navigation keys, zoom, undo
--  and redo keys, and keyboard-driven overlays, through the real input
--  pipeline (the rules in Files_Suite.Interaction_Support).
package body Files_Suite.Keyboard is

   use AUnit.Assertions;
   use type Files.Controller.Controller_Status;
   use type Guikit.Draw.Accessibility_Role;
   use type Guikit.Settings_Panel.Field_Kind;
   use Files_Suite.Interaction_Support;

   type Keyboard_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Keyboard_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Keyboard_Test_Case);

   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mirrored_Layout_Keys_And_Pointer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Picker_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Descending_Sort_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Descending_Grid_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Keyboard_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files keyboard dispatch");
   end Name;

   overriding procedure Register_Tests (T : in out Keyboard_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Keyboard_Shortcut_Command'Access, "keyboard shortcut routes to its command and model effect");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Alt_Up_Navigates_Parent'Access,
         "alt+up routes to navigate-parent while plain up moves the selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Keyboard_Dispatch_Path'Access,
         "live key dispatch flows through Files.Interaction.Handle_Key for view, settings-path, and toggle keys");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Capture_Routing'Access,
         "an armed shortcut row captures the next chord via the key seam; Esc/Backspace/Delete cancel/unbind/reset");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Tab_Keys'Access,
         "Ctrl+Tab and Ctrl+Shift+Tab cycle the settings section tabs, wrapping at the ends");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Grid_Nav_Keys'Access,
         "Home/End/PageUp/PageDown page the grid selection through the key seam");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mirrored_Layout_Keys_And_Pointer'Access,
         "in a mirrored window Left and Right trade places except in a text field, and the pointer is reflected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Keyboard_Zoom'Access,
         "Ctrl+plus/equal grows, Ctrl+minus shrinks and Ctrl+0 resets the font size through the key seam");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Color_Label_Picker_Keyboard'Access,
         "the color-label picker navigates by arrows and applies on Enter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Shortcut_Ctrl_Z'Access,
         "Ctrl+Z through the key seam routes to Undo_Command and restores the original name");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Shortcut_Ctrl_Shift_Z'Access,
         "Ctrl+Shift+Z through the key seam routes to Redo_Command and re-applies the rename");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Descending_Sort_Arrows_Follow_Display'Access,
         "Up/Down follow the displayed order under descending sort (not reversed)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Descending_Grid_Arrows_Follow_Display'Access,
         "grid Up/Down follow the displayed order under descending sort (not reversed)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Settings_Command_Updates_Open_Pane'Access,
         "a settings command run by its shortcut with the settings pane open updates the pane too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Space_Seam'Access,
         "Space opens and closes Quick Look for a single selection and types into a focused field");
   end Register_Tests;

   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Mirrored_Layout_Keys_And_Pointer (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Label_Picker_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Descending_Sort_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Descending_Grid_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Keyboard_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Keyboard;

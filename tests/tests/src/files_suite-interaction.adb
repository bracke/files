with Files.Controller.Operation_Commands;
with Files.Preference_Types;
with Files.Events;
with Files.Input_Actions;
with Files.Controller.Testing;
with Files.Operations;
with Files.Items;
with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Folder_Tree;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Model.Folder_Sizes;
with Guikit.Draw;
with Files.Rendering;
with Files.Settings;
with Files.Application.Settings_Sharing;
with Files.Application.Event_Wait;
with Guikit.Input;
with Ada.Real_Time;
with Files.Types;
with Files.UI_Types;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for clicks, scrolling, settings sharing and the
--  remaining reducer paths, through the real input pipeline (the rules in
--  Files_Suite.Interaction_Support).
package body Files_Suite.Interaction is

   --  The command entry points the tests drive, by a short name.
   package Operation_Commands renames Files.Controller.Operation_Commands;

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Input_Actions.Input_Action_Kind;
   use type Files.Input_Actions.Scroll_Target;
   use type Guikit.Draw.Accessibility_Role;
   use type Files.Preference_Types.Color_Label;
   use type Files.UI_Types.Focus_Target;
   use Files_Suite.Interaction_Support;

   type Interaction_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Interaction_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Interaction_Test_Case);

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mouse_Release_Held_For_Bounce (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shared_Settings_Reach_Other_Window (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shared_Settings_Keep_Search_Results (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shared_Settings_Keep_Edits_And_Order (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shared_Hidden_Toggle_Restores_Results (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Shared_Once_Across_Windows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Commands_Bump_Revision (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Event_Wait_Follows_Held_Release (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Event_Wait_Folds_Over_Windows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Adoption_Drops_Frames (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Adopted_Shortcut_Relists_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shift_Click_Anchors_At_Ctrl_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Metadata_Clicks_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlay_Clicks_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scroll_Targets_Pane_Under_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlays_Contain_Wheel_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Wheel_Follows_Overlay_Stack (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Window_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Follow_Moves_And_Stay_Loadable (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Moves_Refused_When_Full (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Writes_Report_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Refused_After_Failed_Load (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Interaction_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files interaction reducer");
   end Name;

   overriding procedure Register_Tests (T : in out Interaction_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Left_Click_Selects'Access, "left-click selects an item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mouse_Release_Held_For_Bounce'Access,
         "a left release waits out its debounce window, so a later bounce press still withdraws it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shared_Settings_Reach_Other_Window'Access,
         "settings shared from another window refresh an open pane's draft and reload a listing they change");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shared_Settings_Keep_Search_Results'Access,
         "settings shared into a window showing search results apply to them in place, and keep folder sizes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shared_Settings_Keep_Edits_And_Order'Access,
         "shared settings keep a rename and Quick Look, reach a folder view's sort, and are not written back stale");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shared_Hidden_Toggle_Restores_Results'Access,
         "hidden files hidden and shown again from another window keep and restore hidden search matches");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Shared_Once_Across_Windows'Access,
         "a settings change in one window reaches every other window once, and the latest of two changes wins");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Commands_Bump_Revision'Access,
         "every settings change -- hidden files, pane save, zoom, column resize, sort -- bumps the settings revision");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Event_Wait_Follows_Held_Release'Access,
         "the event loop's wait is cut to a held mouse release's remaining debounce time, and no further");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Event_Wait_Folds_Over_Windows'Access,
         "over several windows the event loop waits the shortest any window allows, never past the normal wait");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Adoption_Drops_Frames'Access,
         "every window adopting shared settings takes them and drops its cached frame; the source keeps its own");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Adopted_Shortcut_Relists_Palette'Access,
         "a window adopting shared settings lists its open palette again, with a shortcut's new keys");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ctrl_Click_Multi_Selection'Access, "ctrl-click builds and toggles a multi-selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shift_Click_Range_Selection'Access, "shift-click selects the inclusive range from the anchor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shift_Click_Anchors_At_Ctrl_Click'Access,
         "a shift-click ranges from the item the last ctrl-click chose, and a further shift-click keeps that anchor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Metadata_Clicks_Contained_By_Overlays'Access,
         "input-owning overlays contain stale metadata clicks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlay_Clicks_Dispatch'Access,
         "a settings-panel click and a palette-row click are dispatched, the palette's settings command saved");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scroll_Targets_Pane_Under_Cursor'Access, "scroll targets the pane under the cursor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Scroll_Contained_By_Overlay'Access,
         "controller scroll entry points cannot move content behind a non-scrolling overlay");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlays_Contain_Wheel_Input'Access,
         "non-scrolling overlays swallow wheel input; the folder tree scrolls within itself");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Wheel_Follows_Overlay_Stack'Access,
         "the wheel goes to the overlay on top of the overlay stack");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Hidden_Toggle'Access,
         "bottom-bar hidden-count click flips Show_Hidden_Files, persists, and reloads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Sort_Persists'Access,
         "a bottom-bar sort command persists the sort field and direction to settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Toggle_On_Selection'Access,
         "favorite toggle adds/removes the selected item's path and falls back to the current folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Window_Policy'Access,
         "window policy: key repeat, display scale, text size, accessibility requests and publishing, zoom saving");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Group_Toggle_Multi_Selection'Access,
         "favorite group-toggles a multi-selection: stars a mixed selection then un-stars it as a whole");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Color_Label_Picker_Applies_To_Selection'Access,
         "the label picker opens and applies/clears a color label across the selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Labels_Follow_Moves_And_Stay_Loadable'Access,
         "labels and favorites follow a rename, a folder move and Undo, and never outgrow the settings file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Moves_Refused_When_Full'Access,
         "Labels do not follow a move the settings file cannot hold");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Writes_Report_Failure'Access,
         "settings toggles apply without a settings file, and a failed write is reported");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Star_Click_Toggles_Current_Dir'Access,
         "clicking the path-bar star toggles and persists the current directory favorite without focusing the path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Palette_Close_Button_Closes'Access,
         "command-palette close (X) button click closes the palette");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Close_Button_Closes'Access,
         "info-pane close (X) button click closes the info pane");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_And_Group_Commands'Access,
         "column-toggle and group-by commands mutate settings and grouping inserts header rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Command_Updates_Open_Pane'Access,
         "a settings command run with the settings pane open updates the pane, so its save keeps the change");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Record_Open_Persists_Recent'Access,
         "opening an item through the reducer records it at the front of recents and persists");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Refused_After_Failed_Load'Access,
         "after a failed settings load changes apply but report they are not saved");
   end Register_Tests;

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Mouse_Release_Held_For_Bounce (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shared_Settings_Reach_Other_Window (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shared_Settings_Keep_Search_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Shared_Settings_Keep_Edits_And_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shared_Hidden_Toggle_Restores_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Shared_Once_Across_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Commands_Bump_Revision (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Event_Wait_Follows_Held_Release (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Event_Wait_Folds_Over_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Adoption_Drops_Frames (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Adopted_Shortcut_Relists_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shift_Click_Anchors_At_Ctrl_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Metadata_Clicks_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlay_Clicks_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scroll_Targets_Pane_Under_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlays_Contain_Wheel_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Wheel_Follows_Overlay_Stack (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Window_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Follow_Moves_And_Stay_Loadable (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Moves_Refused_When_Full (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Writes_Report_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Refused_After_Failed_Load (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Interaction_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Interaction;

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Zlib;

with Files.Breadcrumbs;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Folder_Tree;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Paste;
with Guikit.Draw;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Guikit.Layout;
with Guikit.Settings_Panel;
with Files_Config;

with Files_Suite.Support;

--  Headless coverage for the interaction reducer (Files.Interaction). Each test
--  drives the REAL pipeline the GLFW shell drives -- Sample_Model ->
--  Build_Snapshot -> Build_Frame_Commands -> a layout/hit-test function ->
--  Files.Events.Translate_* -> Files.Interaction.Apply_* -> assert -- so it
--  proves the relocated orchestration behaves as it did inline in
--  application-windows.adb, without any GPU/GLFW dependency.
--
--  Anti-fragility rules (the whole point of this seam):
--
--  a. Derive every coordinate from a layout/hit-test function -- never hardcode
--     a pixel (Item_At, Context_Menu_Row_At, Settings_Hit_At, Calculate_Layout;
--     center = Cell.X + Cell.Width/2, ...).
--  b. Assert semantic outcomes only -- Command_Id identity, Model/Settings
--     fields, menu-open/selection state, Interaction_Result flags; prefer
--     Frame_Commands.Accessibility nodes (Role/Selected/Focused/Enabled) over
--     rectangle/color geometry.
--  c. No framebuffer/pixel-hash, no exact-color, no exact-coordinate assertions
--     (geometry is a hit-test input, never an assertion target).
--  d. Exercise the real dispatch functions (Translate_* ->
--     Files.Interaction.Apply_*); never reimplement dispatch or shortcut to a
--     Controller leaf -- that is what lets tests drift.
--  e. Do not copy Has_Rectangle_Colored (Frame, Selection_Color) (rendering
--     test, color identity); use the accessibility-node boolean instead
--     (theme-proof).
package body Files_Suite.Interaction is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Path_Status;
   use type Files.Model.Clipboard_Mode;
   use type Guikit.Draw.Accessibility_Role;
   use type Files.Types.Color_Label;
   use type Files.Types.Focus_Target;
   use type Files.Types.Search_Scope;
   use type Files.Types.View_Mode;
   use type Guikit.Settings_Panel.Field_Kind;

   Window_W   : constant Natural  := 1000;
   Window_H   : constant Natural  := 800;
   Line       : constant Positive := 20;
   Base_Font  : constant Positive := 16;

   Ctrl : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Control_Key => True, others => False];

   Shift : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Shift_Key => True, others => False];

   Alt : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Alt_Key => True, others => False];

   Ctrl_Shift : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Control_Key => True, Guikit.Input.Shift_Key => True, others => False];

   type Interaction_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Interaction_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Interaction_Test_Case);

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Entry_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Contained_By_Overlays (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Metadata_Clicks_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scroll_Targets_Pane_Under_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlays_Contain_Wheel_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Labels_Follow_Moves_And_Stay_Loadable (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Moves_Refused_When_Full (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Writes_Report_Failure (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Picker_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Resize_Persists_On_Release (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   --  Pass 2 -- context-menu contents/enablement per state.
   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Conflict_Action_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class);
   --  Pass 2 -- deep multi-step sequences.
   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Descending_Sort_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Descending_Grid_Arrows_Follow_Display (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   --  Gap #3 -- clickable breadcrumbs and the folder-tree sidebar.
   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Pick_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Panel_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Focus_Blocks_File_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_Ctrl_Click_Multi_Selection'Access, "ctrl-click builds and toggles a multi-selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shift_Click_Range_Selection'Access, "shift-click selects the inclusive range from the anchor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Entry_Updates_Focused_Input'Access,
         "typed text routes to the focused filter and command-palette inputs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Entry_Contained_By_Overlays'Access,
         "non-text overlays contain native character input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Contained_By_Overlays'Access,
         "input-owning overlays contain native file drops");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Metadata_Clicks_Contained_By_Overlays'Access,
         "input-owning overlays contain stale metadata clicks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Right_Click_Opens_Menu'Access, "right-click selects and opens the context menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Menu_Row_Dispatch'Access, "context-menu row dispatches its command and closes");
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
        (T, Test_Keyboard_Zoom'Access,
         "Ctrl+plus/equal grows, Ctrl+minus shrinks and Ctrl+0 resets the font size through the key seam");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scroll_Targets_Pane_Under_Cursor'Access, "scroll targets the pane under the cursor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Scroll_Contained_By_Overlay'Access,
         "controller scroll entry points cannot move content behind a non-scrolling overlay");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlays_Contain_Wheel_Input'Access,
         "non-scrolling overlays swallow wheel input; the folder tree scrolls within itself");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Hidden_Toggle'Access,
         "bottom-bar hidden-count click flips Show_Hidden_Files, persists, and reloads");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Sort_Persists'Access,
         "a bottom-bar sort command persists the sort field and direction to settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Click_Navigates'Access, "root-selector row click navigates to the chosen root");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Toggle_On_Selection'Access,
         "favorite toggle adds/removes the selected item's path and falls back to the current folder");
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
        (T, Test_Color_Label_Picker_Keyboard'Access,
         "the color-label picker navigates by arrows and applies on Enter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Selector_Star_And_Clicks'Access,
         "the selector stars favorites; a folder favorite navigates in and a file favorite opens its parent selected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Stale_Entry_Is_Skipped'Access,
         "clicking a stale favorite does not crash and is skipped");
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
        (T, Test_Text_Input_Click_Focuses'Access, "toolbar input click focuses the field and sets the cursor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scrollbar_Drag_Begin'Access, "scrollbar thumb click begins a drag the shell owns");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Resize_Drag'Access,
         "a header separator press begins a resize (not a sort) and drag persists the new width");
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
        (T, Test_Context_Menu_Open_And_Edit'Access, "item-menu open, rename, cut, and duplicate commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Archive_Commands'Access, "item-menu compress-zip, compress-7z, and extract commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Empty_Area_Commands'Access, "empty-area menu new-folder and paste commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Trash_Lifecycle'Access, "item-menu delete, undo, and restore-from-trash lifecycle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Menu_Contents_And_Enablement'Access,
         "item menu lists the expected commands and enables the selection-driven ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Area_Menu_Contents'Access,
         "empty-area menu lists create/new-folder/paste/open-terminal/refresh and no item-only commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Header_Menu_Column_Config'Access,
         "details-header menu lists the column toggles and grouping and flips a setting");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extract_Enablement_By_Selection'Access,
         "extract enables only when the selection includes an archive");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash_Enablement_By_Context'Access,
         "restore-from-trash enables only inside the trash files directory");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Enablement_Reflects_Clipboard'Access,
         "paste enables only when the clipboard holds items");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Conflict_Action_Guards'Access,
         "stale or malformed paste-conflict actions are ignored");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Disabled_Command_Does_Not_Act'Access,
         "dispatching a disabled menu command is gated and changes no state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Rename_Then_Undo'Access,
         "sequence: rename a file via the menu, commit, then undo back to the original name");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undo_Shortcut_Ctrl_Z'Access,
         "Ctrl+Z through the key seam routes to Undo_Command and restores the original name");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Redo_Shortcut_Ctrl_Shift_Z'Access,
         "Ctrl+Shift+Z through the key seam routes to Redo_Command and re-applies the rename");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Compress_Then_Extract'Access,
         "sequence: compress a file to zip, then extract the reloaded archive");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Trash_Then_Restore'Access,
         "sequence: delete to trash, view the trash, then restore from the menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Cut_Paste_Into_Subdir'Access,
         "sequence: cut a file, paste it into a subdirectory, then undo the move");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Descending_Sort_Arrows_Follow_Display'Access,
         "Up/Down follow the displayed order under descending sort (not reversed)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Descending_Grid_Arrows_Follow_Display'Access,
         "grid Up/Down follow the displayed order under descending sort (not reversed)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_And_Group_Commands'Access,
         "column-toggle and group-by commands mutate settings and grouping inserts header rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Command_Updates_Open_Pane'Access,
         "a settings command run with the settings pane open updates the pane, so its save keeps the change");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Settings_Command_Updates_Open_Pane'Access,
         "a settings command run by its shortcut with the settings pane open updates the pane too");
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
        (T, Test_Tree_Toggle_Command_And_Click'Access,
         "the tree toggle command flips the panel and a label click navigates through the reducer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Pick_Keyboard'Access,
         "the destination-pick tree navigates by arrows, expands/collapses, and confirms on Enter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Panel_Keyboard'Access,
         "Tab reaches the folder tree, whose rows then take the arrows, Enter and Escape");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Space_Seam'Access,
         "Space opens and closes Quick Look for a single selection and types into a focused field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Record_Open_Persists_Recent'Access,
         "opening an item through the reducer records it at the front of recents and persists");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Focus_Blocks_File_Shortcuts'Access,
         "file shortcuts never fire behind a focused text field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Commands_Registry'Access,
         "recent commands register, gate on the recent view, and appear in the empty-area menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Scope_Chip_Cycles'Access,
         "clicking the filter-bar scope chip cycles the scope, re-runs the query, "
         & "and does not focus the filter input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Refused_After_Failed_Load'Access,
         "after a failed settings load changes apply but report they are not saved");
   end Register_Tests;

   --  Center of the cell laid out for visible item Index, derived from the real
   --  item layout (rule a). Returns whether the cell was found.
   procedure Item_Center
     (Model  : Files.Model.Window_Model;
      Index  : Positive;
      X      : out Natural;
      Y      : out Natural;
      Found  : out Boolean)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Files.Settings.Default_Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
   begin
      X := 0;
      Y := 0;
      Found := False;
      for Cell of Items loop
         if Cell.Visible_Index = Index then
            X := Cell.X + Cell.Width / 2;
            Y := Cell.Y + Cell.Height / 2;
            Found := True;
            return;
         end if;
      end loop;
   end Item_Center;

   --  Number of grid-item accessibility nodes currently marked Selected. With no
   --  overlay and the info pane closed these are exactly the main-view items, so
   --  this is a theme-proof proxy for the selection state (rules b and e).
   function Selected_Item_Nodes (Model : Files.Model.Window_Model) return Natural is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Files.Settings.Default_Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      Count    : Natural := 0;
   begin
      for Node of Frame.Accessibility loop
         if (Node.Role = Guikit.Draw.Role_List_Item
             or else Node.Role = Guikit.Draw.Role_Table_Row)
           and then Node.Selected
         then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Selected_Item_Nodes;

   --  Apply the input action a click at (X, Y) translates to, exactly as the
   --  shell does (rule d).
   procedure Click
     (Model     : in out Files.Model.Window_Model;
      Settings  : in out Files.Settings.Settings_Model;
      X         : Natural;
      Y         : Natural;
      Modifiers : Guikit.Input.Modifier_Set;
      Result    : out Files.Interaction.Interaction_Result)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X, Y, Window_W, Window_H,
           Activate => False, Modifiers => Modifiers, Line_Height => Line);
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Modifiers,
         Result            => Result);
   end Click;

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Entry_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Drop_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Metadata_Clicks_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The compact window of the targeted-scroll tests: small enough that both
   --  the info pane and the detail view overflow.
   Target_W : constant Natural := 600;
   Target_H : constant Natural := 180;

   --  Scroll down (negative GLFW offset) at (X, Y) through the real translator.
   procedure Scroll_Down_At
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      X        : Natural;
      Y        : Natural)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Scroll_At
          (Snapshot, X, Y, Target_W, Target_H, Y_Offset => -1, Line_Height => Line);
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
   end Scroll_Down_At;

   --  The targeted-scroll fixture: detail view, Gamma.md selected, info pane open.
   procedure Open_Targeted_Scroll_Fixture (Model : in out Files.Model.Window_Model) is
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Files_Suite.Support.Select_Name (Model, "Gamma.md");
      Files.Model.Toggle_Info_Pane (Model);
   end Open_Targeted_Scroll_Fixture;

   --  Vertical centre of the main view in the compact targeted-scroll window.
   function Targeted_Main_Y
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Natural
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
   begin
      return Layout.Main_Y + Layout.Main_Height / 2;
   end Targeted_Main_Y;

   --  Reproduce the model state Test_Scroll_Targets_Pane_Under_Cursor leaves
   --  behind: the fixture, one wheel step over the info pane and one over the
   --  main view, then the main view returned to its top.
   procedure Replay_Targeted_Scroll
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model) is
   begin
      Open_Targeted_Scroll_Fixture (Model);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
      begin
         Scroll_Down_At (Model, Settings, Info.X + Info.Width / 2, Info.Y + Info.Height / 2);
         Scroll_Down_At
           (Model, Settings, Layout.Main_X + Layout.Main_Width / 2, Layout.Main_Y + Layout.Main_Height / 2);
      end;
      Files.Model.Set_Main_View_Scroll_Lines (Model, 0);
   end Replay_Targeted_Scroll;

   procedure Test_Scroll_Targets_Pane_Under_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlays_Contain_Wheel_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Format a positive index without the leading space Integer'Image inserts.
   function Index_Image (Value : Positive) return String is
      Raw : constant String := Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Index_Image;

   --  Load a real on-disk directory into a fresh window model, exactly as the
   --  controller does when navigating, so disk-backed menu commands operate on
   --  genuine items.
   function Loaded_Model (Directory : String) return Files.Model.Window_Model is
      Load  : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory (Directory, Files.Settings.Default_Settings);
      Model : Files.Model.Window_Model;
   begin
      Files.Model.Initialize (Model, Directory, Load.Items, Files_Suite.Support.Root);
      return Model;
   end Loaded_Model;

   --  Return the first visible item index currently reported Selected, or zero.
   function First_Selected_Visible (Model : Files.Model.Window_Model) return Natural is
   begin
      for Index in 1 .. Files.Model.Visible_Count (Model) loop
         if Files.Model.Is_Selected (Model, Index) then
            return Index;
         end if;
      end loop;
      return 0;
   end First_Selected_Visible;

   --  Open the item context menu by right-clicking the cell of the first
   --  selected item, deriving the coordinate from the real item layout (rule a)
   --  and driving the real Apply_Right_Click (rule d).
   procedure Open_Item_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Visible  : constant Natural := First_Selected_Visible (Model);
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      X, Y     : Natural := 0;
      In_Main  : Boolean;
      Index    : Natural;
   begin
      Assert (Visible > 0, "a selected item exists to anchor the context menu");
      for Cell of Items loop
         if Cell.Visible_Index = Visible then
            X := Cell.X + Cell.Width / 2;
            Y := Cell.Y + Cell.Height / 2;
         end if;
      end loop;
      In_Main :=
        X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
        and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
      Index := Files.Rendering.Hit.Item_At (Items, X, Y);
      Files.Interaction.Apply_Right_Click (Model, Settings, In_Main, Index, X, Y, Result);
   end Open_Item_Context_Menu;

   --  Open the empty-area context menu by right-clicking the center of the main
   --  view, which is item-free in the directories these tests build.
   procedure Open_Empty_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      X : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
      Y : constant Natural := Layout.Main_Y + Layout.Main_Height / 2;
      Index : constant Natural := Files.Rendering.Hit.Item_At (Items, X, Y);
   begin
      Files.Interaction.Apply_Right_Click (Model, Settings, True, Index, X, Y, Result);
   end Open_Empty_Context_Menu;

   --  Resolve a command from the live context-menu layout (rule a), assert the
   --  derived coordinate hit-tests back to that row, then dispatch it through the
   --  real Apply_Context_Menu_Command (rule d). Found is false when the open menu
   --  does not offer the command.
   procedure Dispatch_Menu_Command
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Command       : Files.Commands.Command_Id;
      Result        : out Files.Interaction.Interaction_Result;
      Found         : out Boolean)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Menu     : constant Files.Rendering.Context_Menu_Layout :=
        Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
      Target_Row   : Natural := 0;
      Row_X, Row_Y : Natural;
   begin
      Found := False;
      for Row in 1 .. Menu.Row_Count loop
         if Menu.Commands (Row) = Command then
            Target_Row := Row;
         end if;
      end loop;
      --  No row for it: Found stays False, and the caller's assertion says so.
      if Target_Row = 0 then
         return;
      end if;
      Row_X := Menu.X + Menu.Width / 2;
      Row_Y :=
        Files.Rendering.Context_Menu_Row_Top (Menu, Target_Row) + Menu.Row_Height / 2;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Hit.Context_Menu_Row_At (Menu, Row_X, Row_Y),
         Target_Row,
         "the derived coordinate hit-tests back to the resolved menu row");
      Found := True;
      Files.Interaction.Apply_Context_Menu_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Settings_Path,
         Command           => Menu.Commands (Target_Row),
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
   end Dispatch_Menu_Command;

   --  Whether the currently open context menu lists Command in its real
   --  Calculate_Context_Menu_Layout rows (rule a: contents come from the live
   --  layout, never a hardcoded row index).
   function Menu_Offers
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id)
      return Boolean
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Menu     : constant Files.Rendering.Context_Menu_Layout :=
        Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
   begin
      for Row in 1 .. Menu.Row_Count loop
         if Menu.Commands (Row) = Command then
            return True;
         end if;
      end loop;
      return False;
   end Menu_Offers;

   --  Commit the active focused text (rename / create) through the real key seam
   --  the shell uses -- Enter routed via Files.Controller.Handle_Key (rule d),
   --  not a direct Commit_Rename call.
   procedure Commit_Focused_Text
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Handle_Key
          (Model, Settings, Guikit.Input.Key_Return, Guikit.Input.No_Modifiers);
      pragma Unreferenced (Outcome);
   begin
      null;
   end Commit_Focused_Text;

   --  Dispatch Command through the reducer's command branch -- the same entry the
   --  shell uses for menu-bar and shortcut-less commands (e.g. Undo).
   procedure Dispatch_Command
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Action : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Command,
         others  => <>);
   begin
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
   end Dispatch_Command;

   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Resize_Persists_On_Release (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Conflict_Action_Guards
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Descending_Sort_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Descending_Grid_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Interaction_Test_Case));
      return Result;
   end Suite;

   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Pick_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Panel_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  True when Path is present in the persisted favorites list.
   function Has_Favorite
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Boolean is
   begin
      for P of Settings.Favorite_Paths loop
         if Ada.Strings.Unbounded.To_String (P) = Path then
            return True;
         end if;
      end loop;
      return False;
   end Has_Favorite;

   --  Drive the real Select_Drive command through the reducer so the root
   --  selector opens seeded with the platform roots plus the persisted
   --  favorites (each carrying its star label token).
   procedure Open_Favorites_Selector
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      Action : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Select_Drive_Command,
         others  => <>);
      Result : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
   end Open_Favorites_Selector;

   --  Click the open selector's row whose root path equals Target_Path, deriving
   --  the coordinate from the real root-path layout (rule a). Found reports
   --  whether such a row existed.
   procedure Click_Root_Row
     (Model       : in out Files.Model.Window_Model;
      Settings    : in out Files.Settings.Settings_Model;
      Target_Path : String;
      Found       : out Boolean;
      Result      : out Files.Interaction.Interaction_Result)
   is
      X, Y : Natural := 0;
   begin
      Found := False;

      --  The selector lays out only the rows that fit, scrolling around the
      --  selected one, so a root can exist and still be off screen. That never
      --  happened on the Linux runner, whose root list is short; a Mac mounts
      --  enough volumes to push the favourites out of view. Select the target
      --  first -- which is what scrolls it in -- exactly as a user reaching for
      --  an off-screen row would, and only then lay the frame out and click it.
      for Index in 1 .. Files.Model.Root_Count (Model) loop
         if Files.Model.Root_Path (Model, Index) = Target_Path then
            Files.Model.Set_Root_Selected_Index (Model, Index);
            exit;
         end if;
      end loop;

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Selector : constant Files.Rendering.Root_Selector_Layout :=
           Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line);
         Rows     : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Selector);
      begin
         for Row of Rows loop
            if Files.Model.Root_Path (Model, Positive (Row.Root_Index)) = Target_Path then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
               Found := True;
            end if;
         end loop;

         if not Found then
            Result := (others => <>);
            return;
         end if;

         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         end;
      end;
   end Click_Root_Row;

   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Writes_Report_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Labels_Follow_Moves_And_Stay_Loadable (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Moves_Refused_When_Full (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Label_Picker_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Focus_Blocks_File_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Refused_After_Failed_Load (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

end Files_Suite.Interaction;

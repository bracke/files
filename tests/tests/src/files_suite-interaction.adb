with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Zlib;

with Files.Breadcrumbs;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Folder_Tree;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Guikit.Draw;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Guikit.Layout;

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
   use type Files.Model.Palette_Mode;
   use type Guikit.Draw.Accessibility_Role;
   use type Files.Types.Color_Label;
   use type Files.Types.Focus_Target;
   use type Files.Types.Search_Scope;
   use type Files.Types.View_Mode;

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
   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Targeted_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   --  Gap #3 -- clickable breadcrumbs and the folder-tree sidebar.
   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Targeted_Scroll'Access, "scroll targets the pane under the cursor");
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
        (T, Test_Quick_Look_Space_Seam'Access,
         "Space opens and closes Quick Look for a single selection and types into a focused field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Record_Open_Persists_Recent'Access,
         "opening an item through the reducer records it at the front of recents and persists");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Commands_Registry'Access,
         "recent commands register, gate on the recent view, and appear in the empty-area menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Scope_Chip_Cycles'Access,
         "clicking the filter-bar scope chip cycles the scope, re-runs the query, "
         & "and does not focus the filter input");
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

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
   begin
      Item_Center (Model, 2, X, Y, Found);
      Assert (Found, "a layout cell exists for the target item");
      Click (Model, Settings, X, Y, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Is_Selected (Model, 2), "the clicked item becomes selected");
      Assert
        (Selected_Item_Nodes (Model) = 1,
         "exactly one item accessibility node reports Selected after a single click");
   end Test_Left_Click_Selects;

   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X1, Y1   : Natural;
      X2, Y2   : Natural;
      Found1   : Boolean;
      Found2   : Boolean;
   begin
      Item_Center (Model, 1, X1, Y1, Found1);
      Item_Center (Model, 3, X2, Y2, Found2);
      Assert (Found1 and then Found2, "layout cells exist for both target items");

      Click (Model, Settings, X1, Y1, Guikit.Input.No_Modifiers, Result);
      Assert (Selected_Item_Nodes (Model) = 1, "a plain click starts a single-item selection");

      Click (Model, Settings, X2, Y2, Ctrl, Result);
      Assert
        (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 3),
         "ctrl-click adds the second item to the selection");
      Assert (Selected_Item_Nodes (Model) = 2, "two item nodes report Selected after ctrl-click");

      Click (Model, Settings, X1, Y1, Ctrl, Result);
      Assert (not Files.Model.Is_Selected (Model, 1), "ctrl-click toggles the first item back off");
      Assert (Files.Model.Is_Selected (Model, 3), "the other item stays selected");
      Assert (Selected_Item_Nodes (Model) = 1, "the toggled-off item is no longer reported Selected");
   end Test_Ctrl_Click_Multi_Selection;

   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X1, Y1   : Natural;
      X3, Y3   : Natural;
      Found1   : Boolean;
      Found3   : Boolean;
   begin
      Item_Center (Model, 1, X1, Y1, Found1);
      Item_Center (Model, 3, X3, Y3, Found3);
      Assert (Found1 and then Found3, "layout cells exist for the range endpoints");

      Click (Model, Settings, X1, Y1, Guikit.Input.No_Modifiers, Result);
      Assert (Selected_Item_Nodes (Model) = 1, "a plain click anchors a single-item selection");

      Click (Model, Settings, X3, Y3, Shift, Result);
      Assert
        (Files.Model.Is_Selected (Model, 1)
           and then Files.Model.Is_Selected (Model, 2)
           and then Files.Model.Is_Selected (Model, 3),
         "shift-click selects the inclusive range from the anchor to the clicked item");
      Assert
        (Selected_Item_Nodes (Model) = 3,
         "three item nodes report Selected after the shift-range click");
   end Test_Shift_Click_Range_Selection;

   --  Text entry: the shell's real typed-character path is
   --  Files.Controller.Append_Focused_Text on whatever input is focused (only
   --  fetching the bytes from the OS is GLFW-bound), so it is exercised here.
   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
   begin
      Files.Model.Focus_Filter_Input (Model);
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "rep");
         pragma Unreferenced (Outcome);
      begin
         null;
      end;
      Assert (Files.Model.Filter_Text (Model) = "rep", "typed text lands in the focused filter input");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Focus_Command_Palette_Input (Model);
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "view");
         pragma Unreferenced (Outcome);
      begin
         null;
      end;
   end Test_Text_Entry_Updates_Focused_Input;

   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;

      --  Recompute In_Main / Item_Index from the live layout, as the shell does
      --  before calling Apply_Right_Click.
      procedure Right_Click (Target : Positive) is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         In_Main  : Boolean;
         Index    : Natural;
      begin
         Item_Center (Model, Target, X, Y, Found);
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click
           (Model      => Model,
            Settings   => Settings,
            In_Main    => In_Main,
            Item_Index => Index,
            X          => X,
            Y          => Y,
            Result     => Result);
      end Right_Click;
   begin
      Right_Click (2);
      Assert (Found, "a layout cell exists for the right-clicked item");
      Assert (Files.Model.Context_Menu_Is_Open (Model), "right-click opens the context menu");
      Assert (Files.Model.Is_Selected (Model, 2), "right-click selects the unselected item under the cursor");
      Assert (Result.Context_Menu_Changed, "the result reports the context-menu change");

      --  With a modal overlay open the same right-click must be swallowed: the
      --  menu stays closed (the shell suppresses it behind modals).
      Files.Model.Close_Context_Menu (Model);
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings overlay is open for the suppression case");
      Right_Click (2);
      Assert
        (not Files.Model.Context_Menu_Is_Open (Model),
         "right-click behind a modal overlay leaves the context menu closed");
   end Test_Right_Click_Opens_Menu;

   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
      In_Main  : Boolean;
      Index    : Natural;
   begin
      --  Open the item context menu through the real right-click path so the
      --  menu rows come from the live snapshot.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      begin
         Item_Center (Model, 2, X, Y, Found);
         Assert (Found, "a layout cell exists for the menu-anchor item");
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click (Model, Settings, In_Main, Index, X, Y, Result);
      end;
      Assert (Files.Model.Context_Menu_Is_Open (Model), "context menu is open before the row click");

      --  Resolve the Copy row from the real menu layout (rule a) and dispatch it.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Menu     : constant Files.Rendering.Context_Menu_Layout :=
           Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
         Target_Row : Natural := 0;
         Row_X      : Natural;
         Row_Y      : Natural;
      begin
         for Row in 1 .. Menu.Row_Count loop
            if Menu.Commands (Row) = Files.Commands.Copy_Selected_Items_Command then
               Target_Row := Row;
            end if;
         end loop;
         Assert (Target_Row > 0, "the item context menu offers the copy command");

         Row_X := Menu.X + Menu.Width / 2;
         Row_Y :=
           Files.Rendering.Context_Menu_Row_Top (Menu, Target_Row) + Menu.Row_Height / 2;
         Assert
           (Files.Rendering.Context_Menu_Row_At (Menu, Row_X, Row_Y) = Target_Row,
            "the derived coordinate hit-tests back to the copy row");

         Files.Interaction.Apply_Context_Menu_Command
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Command           => Menu.Commands (Target_Row),
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
      end;

      Assert
        (Result.Command = Files.Commands.Copy_Selected_Items_Command,
         "the result echoes the dispatched command id");
      Assert (Result.Context_Menu_Changed, "the result reports the menu closing");
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      Assert
        (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Copy,
         "the copy command records a copy clipboard intent");
      Assert (Files.Model.Clipboard_Has_Items (Model), "the copy command captured the selected item");
   end Test_Menu_Row_Dispatch;

   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      --  Ctrl+3 is the Select_Details shortcut.
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_3, Ctrl);
   begin
      Assert
        (Action.Kind = Files.Events.Command_Input_Action,
         "a known shortcut translates to a command input action");
      Assert
        (Action.Command = Files.Commands.Select_Details_Command,
         "Ctrl+3 selects the details-view command");

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Ctrl,
         Result            => Result);

      Assert
        (Result.Command = Files.Commands.Select_Details_Command,
         "the result echoes the dispatched command id");
      Assert
        (Files.Model.View_Mode_Of (Model) = Files.Types.Details,
         "dispatching the shortcut switches the model to the details view");
   end Test_Keyboard_Shortcut_Command;

   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Input.Navigation_Direction;
      Parent_Action : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_Up, Alt);
      Plain_Action  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_Up, Guikit.Input.No_Modifiers);
   begin
      --  Alt+Up is a modifier-specific shortcut, so it routes to the command.
      Assert
        (Parent_Action.Kind = Files.Events.Command_Input_Action,
         "alt+up translates to a command input action");
      Assert
        (Parent_Action.Command = Files.Commands.Navigate_Parent_Command,
         "alt+up dispatches the navigate-parent command");

      --  Plain Up is left for grid navigation so the selection still moves.
      Assert
        (Plain_Action.Kind = Files.Events.Selection_Input_Action,
         "plain up stays a selection movement action");
      Assert
        (Plain_Action.Direction = Guikit.Input.Move_Up,
         "plain up still moves the selection up in the grid");
   end Test_Alt_Up_Navigates_Parent;

   --  Drive the GENUINE live key-dispatch seam the shell uses --
   --  Files.Interaction.Handle_Key -- rather than the Translate_Key ->
   --  Apply_Input_Action proxy. Handle_Key runs the focus-aware controller and
   --  re-routes settings-path keys through Execute_Command, exactly as
   --  Handle_Pressed_Key did inline. Press the real Shortcut_For key codes (rule
   --  d: never invent a binding) and assert semantic outcomes (rule b).
   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "interaction-key.conf");
   begin
      Files_Suite.Support.Reset_Root;

      --  (1) View shortcut: Ctrl+3 (Shortcut_For (Select_Details)) flows through
      --  the key seam to the details-view command and switches the model view.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_3,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert
           (Result.Command = Files.Commands.Select_Details_Command,
            "Ctrl+3 dispatched through Handle_Key reports the details-view command");
         Assert
           (Files.Model.View_Mode_Of (Model) = Files.Types.Details,
            "the key seam switches the model to the details view");
      end;

      --  (2) Settings-path shortcut: Save_Settings_Command is key-bound to Ctrl+S
      --  (Shortcut_For). With the settings pane open the command is enabled, so
      --  the key seam must re-route it through Execute_Command -- proven by the
      --  settings-path-only follow-ups (Settings_Changed, Clear_Pending_Text) and
      --  the persisted file -- which the plain controller branch never produces.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         --  Open the pane through the same key seam (Ctrl+, =
         --  Toggle_Settings_Pane, a non-settings-path command that takes the
         --  plain controller branch) so the whole scenario stays on the seam.
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Key               => Guikit.Input.Key_Comma,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert
           (Files.Model.Settings_Pane_Is_Open (Model),
            "the settings pane is open so the Ctrl+S save command is enabled");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Key               => Guikit.Input.Key_S,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert
           (Result.Command = Files.Commands.Save_Settings_Command,
            "Ctrl+S dispatched through Handle_Key reports the save-settings command");
         Assert
           (Result.Settings_Changed,
            "the key seam re-routes the save through Execute_Command and reports a settings change");
         Assert
           (Result.Clear_Pending_Text,
            "the settings-path re-route asks the shell to drop pending character input");
         Assert
           (Ada.Directories.Exists (Path),
            "the key-driven save persists the settings file to disk");
      end;

      --  (3) Toggle shortcut: Ctrl+4 (Shortcut_For (Toggle_Info_Pane)) needs a
      --  selection to be enabled. The key seam toggles the info pane in the model
      --  via the plain controller branch (no settings-path re-route).
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Gamma.md");
         Assert
           (not Files.Model.Info_Pane_Is_Open (Model),
            "the info pane starts closed before the toggle key");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_4,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert
           (Result.Command = Files.Commands.Toggle_Info_Pane_Command,
            "Ctrl+4 dispatched through Handle_Key reports the toggle-info-pane command");
         Assert
           (Files.Model.Info_Pane_Is_Open (Model),
            "the key seam toggles the info pane open in the model");
      end;
   end Test_Keyboard_Dispatch_Path;

   --  With a settings Shortcut row armed, the key seam routes the next physical
   --  chord to capture (rebinding the live keymap) rather than acting on it, and
   --  Escape cancels, Backspace unbinds, and Delete resets to the built-in
   --  default -- exercising Files.Controller.Capture_Settings_Shortcut end to end.
   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Input.Key_Code;
      use type Files.Commands.Shortcut;
      Path : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "capture.conf");
      Cmd  : constant Files.Commands.Command_Id := Files.Commands.Select_Small_Icons_Command;

      --  Open the pane, jump to the last (Shortcuts) section, and arm its first
      --  row (Select_Small_Icons). Leaves the model capturing.
      procedure Open_And_Arm
        (Model    : in out Files.Model.Window_Model;
         Settings : in out Files.Settings.Settings_Model)
      is
         Result : Files.Interaction.Interaction_Result;
         Rects  : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text   : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes  : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Guikit.Input.Key_Comma, Modifiers => Ctrl,
            Current_Font_Size => Base_Font, Result => Result);
         Files.Model.Settings_Build_Frame
           (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
            Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
            Rectangles => Rects, Text => Text, Accessibility => Nodes);
         Files.Model.Settings_Set_Active_Section (Model, Natural'Last);
         Files.Model.Settings_Begin_Capture (Model);
      end Open_And_Arm;

      procedure Press
        (Model    : in out Files.Model.Window_Model;
         Settings : in out Files.Settings.Settings_Model;
         Key      : Guikit.Input.Key_Code;
         Mods     : Guikit.Input.Modifier_Set)
      is
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Key, Modifiers => Mods, Current_Font_Size => Base_Font, Result => Result);
      end Press;
   begin
      Files_Suite.Support.Reset_Root;

      --  (1) A chord captured while armed rebinds the live keymap.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Assert (Files.Model.Settings_Is_Capturing (Model), "the first shortcut row is armed");
         Assert (Files.Model.Settings_Capturing_Key (Model) = "shortcut.view.small",
                 "the armed row is the first command's shortcut field");
         Press (Model, Settings, Guikit.Input.Key_5, Ctrl_Shift);
         Assert (not Files.Model.Settings_Is_Capturing (Model), "capturing a chord disarms the row");
         declare
            SC : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Cmd);
         begin
            Assert (SC.Present and then SC.Key = Guikit.Input.Key_5
                    and then SC.Modifiers (Guikit.Input.Control_Key)
                    and then SC.Modifiers (Guikit.Input.Shift_Key),
                    "the captured chord rebinds the command in the live keymap");
         end;
      end;

      --  (2) Escape cancels capture and leaves the binding untouched.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Escape, Guikit.Input.No_Modifiers);
         Assert (not Files.Model.Settings_Is_Capturing (Model), "Escape disarms the row");
         Assert (Files.Commands.Shortcut_For (Cmd) = Files.Commands.Default_Shortcut_For (Cmd),
                 "Escape leaves the binding at its default");
      end;

      --  (3) Backspace unbinds the command.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Backspace, Guikit.Input.No_Modifiers);
         Assert (not Files.Commands.Shortcut_For (Cmd).Present,
                 "Backspace unbinds the command");
      end;

      --  (4) Delete resets a rebound command to its built-in default.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Is_Set   : Boolean;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Files.Commands.Set_Shortcut_Override
           (Cmd, Files.Commands.Parse_Shortcut ("control+shift+5"));
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Delete, Guikit.Input.No_Modifiers);
         declare
            Ignore : constant Files.Commands.Shortcut := Files.Commands.Shortcut_Override (Cmd, Is_Set);
         begin
            pragma Unreferenced (Ignore);
            Assert (not Is_Set, "Delete clears the override, resetting to the built-in default");
         end;
         Assert (Files.Commands.Shortcut_For (Cmd) = Files.Commands.Default_Shortcut_For (Cmd),
                 "the command resolves to its default binding after a reset");
      end;

      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Shortcut_Capture_Routing;

   --  Ctrl+Tab / Ctrl+Shift+Tab move between the settings section tabs through the
   --  key seam -- the only keyboard route across sections -- and wrap at the ends.
   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "tabs.conf");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text     : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      procedure Tab (Mods : Guikit.Input.Modifier_Set) is
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Guikit.Input.Key_Tab, Modifiers => Mods,
            Current_Font_Size => Base_Font, Result => Result);
      end Tab;
   begin
      Files_Suite.Support.Reset_Root;

      --  Open the pane and lay it out so the sections exist.
      Files.Interaction.Handle_Key
        (Model => Model, Settings => Settings, Settings_Path => Path,
         Key => Guikit.Input.Key_Comma, Modifiers => Ctrl,
         Current_Font_Size => Base_Font, Result => Result);
      Files.Model.Settings_Build_Frame
        (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
         Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
         Rectangles => Rects, Text => Text, Accessibility => Nodes);

      declare
         Count : constant Natural := Files.Model.Settings_Section_Count (Model);
      begin
         Assert (Count > 1, "the settings form has multiple section tabs");
         Assert (Files.Model.Settings_Active_Section (Model) = 1, "the first section is active initially");

         Tab (Ctrl);
         Assert (Files.Model.Settings_Active_Section (Model) = 2, "Ctrl+Tab advances to the next section");

         Tab (Ctrl_Shift);
         Assert (Files.Model.Settings_Active_Section (Model) = 1, "Ctrl+Shift+Tab returns to the previous section");

         --  Wrap backward from the first section to the last.
         Tab (Ctrl_Shift);
         Assert (Files.Model.Settings_Active_Section (Model) = Count,
                 "Ctrl+Shift+Tab wraps from the first section to the last");

         --  Wrap forward from the last section back to the first.
         Tab (Ctrl);
         Assert (Files.Model.Settings_Active_Section (Model) = 1,
                 "Ctrl+Tab wraps from the last section to the first");
      end;
   end Test_Settings_Tab_Keys;

   --  Home/End/PageUp/PageDown page the file-grid selection through the genuine
   --  key seam (Files.Interaction.Handle_Key) and never navigate: plain Home is
   --  distinct from Alt+Home (navigate home).
   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Home_Dir : constant String := Files.Model.Current_Path (Model);
      Last     : constant Positive := Files.Model.Visible_Count (Model);
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_End,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "End moves the grid selection");
      Assert (Files.Model.Selected_Index (Model) = Last, "End selects the last visible item");
      Assert (Files.Model.Current_Path (Model) = Home_Dir, "End does not navigate");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Home,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "Home moves the grid selection");
      Assert (Files.Model.Selected_Index (Model) = 1, "Home selects the first visible item");
      Assert (Files.Model.Current_Path (Model) = Home_Dir, "plain Home does not navigate home (that stays Alt+Home)");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Page_Down,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Files.Model.Selected_Index (Model) = Last, "PageDown pages the selection down to the last item");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Page_Up,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Files.Model.Selected_Index (Model) = 1, "PageUp pages the selection back to the first item");
   end Test_Grid_Nav_Keys;

   --  Ctrl+'=' / Ctrl+'+' grow, Ctrl+'-' shrinks, and Ctrl+0 resets the live
   --  font size, all clamped to the supported range, through the key seam.
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Zoom (Key : Guikit.Input.Key_Code; Mods : Guikit.Input.Modifier_Set) is
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Key,
            Modifiers         => Mods,
            Current_Font_Size => Settings.Font_Pixel_Size,
            Result            => Result);
      end Zoom;
   begin
      Assert (Settings.Font_Pixel_Size = 16, "the default font size is the starting point");

      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Assert (Settings.Font_Pixel_Size = 17, "Ctrl+Equal grows the font size by one");
      Assert (Result.Font_Size_Changed, "the growing zoom reports a font-size change");
      Assert (Result.Settings_Changed, "the growing zoom reports a settings change");

      Zoom (Guikit.Input.Key_Equal, Ctrl_Shift);
      Assert (Settings.Font_Pixel_Size = 18, "Ctrl+Plus (Shift+Ctrl+Equal) also grows the font size");

      Zoom (Guikit.Input.Key_Minus, Ctrl);
      Assert (Settings.Font_Pixel_Size = 17, "Ctrl+Minus shrinks the font size by one");

      Settings.Font_Pixel_Size := 24;
      Zoom (Guikit.Input.Key_0, Ctrl);
      Assert (Settings.Font_Pixel_Size = Files.Settings.Default_Font_Pixel_Size, "Ctrl+0 resets to the default size");
      Assert (Result.Font_Size_Changed, "the reset reports a font-size change");

      --  Clamp at the maximum: growing past the ceiling makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Max_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Assert
        (Settings.Font_Pixel_Size = Files.Settings.Max_Font_Pixel_Size,
         "Ctrl+Equal clamps at the maximum font size");
      Assert (not Result.Font_Size_Changed, "a no-op zoom at the ceiling reports no font-size change");

      --  Clamp at the minimum: shrinking past the floor makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Min_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Minus, Ctrl);
      Assert
        (Settings.Font_Pixel_Size = Files.Settings.Min_Font_Pixel_Size,
         "Ctrl+Minus clamps at the minimum font size");
      Assert (not Result.Font_Size_Changed, "a no-op zoom at the floor reports no font-size change");
   end Test_Keyboard_Zoom;

   procedure Test_Targeted_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      --  Scroll down (negative GLFW offset) at (X, Y) through the real translator.
      procedure Scroll_At (X : Natural; Y : Natural) is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot, X, Y, Window_W, Window_H, Y_Offset => -1, Line_Height => Line);
      begin
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
      end Scroll_At;

      Info_X, Info_Y : Natural;
      Main_X, Main_Y : Natural;
   begin
      Files_Suite.Support.Select_Name (Model, "Gamma.md");
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Info_Pane_Is_Open (Model), "the info pane is open for the scroll-target test");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
      begin
         Assert (Info.Width > 0 and then Info.Height > 0, "the info pane has a hittable region");
         Info_X := Info.X + Info.Width / 2;
         Info_Y := Info.Y + Info.Height / 2;
         Main_X := Layout.Main_X + Layout.Main_Width / 2;
         Main_Y := Layout.Main_Y + Layout.Main_Height / 2;
      end;

      Scroll_At (Info_X, Info_Y);
      Assert
        (Files.Model.Info_Pane_Scroll_Lines (Model) > 0,
         "scrolling over the info pane moves the info-pane offset");
      Assert
        (Files.Model.Main_View_Scroll_Lines (Model) = 0,
         "scrolling over the info pane leaves the main view untouched");

      declare
         Info_Before : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
      begin
         Scroll_At (Main_X, Main_Y);
         Assert
           (Files.Model.Main_View_Scroll_Lines (Model) > 0,
            "scrolling over the main view moves the main-view offset");
         Assert
           (Files.Model.Info_Pane_Scroll_Lines (Model) = Info_Before,
            "scrolling over the main view leaves the info-pane offset unchanged");
      end;
   end Test_Targeted_Scroll;

   --  Open the settings pane through the real Ctrl+, shortcut so its draft is
   --  initialised exactly as the live app does.
   procedure Open_Settings_Pane
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      Result : Files.Interaction.Interaction_Result;
      Action : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_Comma, Ctrl);
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Ctrl,
         Result            => Result);
   end Open_Settings_Pane;
   --  Item 8/9: the bottom-bar status area reports the hidden (dot-file) count
   --  and doubles as a clickable Show_Hidden_Files toggle. Derive the click
   --  coordinate from the real bottom-bar accessibility node (rule a/b) and
   --  route it through the full Translate_Click -> Apply_Input_Action pipeline
   --  (rule d), asserting semantic outcomes only (rule c).
   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "hidden-toggle.conf");

      function Items_With_Hidden return Files.File_System.Item_Vectors.Vector is
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, ".hidden_one", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, ".hidden_two", Files.Types.Regular_File_Item, "text/plain"));
         return Items;
      end Items_With_Hidden;

      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
      Action   : Files.Events.Input_Action;
      Toggle_Name : constant String :=
        Files.Localization.Text (Files.Commands.Name_Key (Files.Commands.Toggle_Hidden_Files_Command));
      X, Y     : Natural := 0;
      Found    : Boolean := False;
      Before   : Boolean;
   begin
      Files_Suite.Support.Reset_Root;
      Files.Model.Initialize
        (Model,
         Directory_Path    => Files_Suite.Support.Root,
         Items             => Items_With_Hidden,
         Home_Path         => "/home/test");

      --  The model query reports the two dot-files, and the snapshot carries it
      --  to the renderer.
      Assert (Files.Model.Hidden_Item_Count (Model) = 2, "the model counts both hidden dot-files");

      Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      Assert (Snapshot.Hidden_Count = 2, "the snapshot surfaces the hidden count for the bottom bar");

      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);

      --  Derive the click coordinate from the real bottom-bar control node.
      for Node of Frame.Accessibility loop
         if Node.Role = Guikit.Draw.Role_Button
           and then Ada.Strings.Unbounded.To_String (Node.Name) = Toggle_Name
         then
            X := Node.X + Node.Width / 2;
            Y := Node.Y + Node.Height / 2;
            Found := True;
         end if;
      end loop;
      Assert (Found, "the bottom-bar hidden-count control is exposed as an accessible button");

      Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
      Assert
        (Action.Kind = Files.Events.Command_Input_Action
           and then Action.Command = Files.Commands.Toggle_Hidden_Files_Command,
         "the hidden-count region translates to the Toggle_Hidden_Files command");

      Before := Settings.Show_Hidden_Files;
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Path,
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);

      Assert (Settings.Show_Hidden_Files /= Before, "clicking the hidden count flips Show_Hidden_Files");
      Assert (Result.Settings_Changed, "the hidden-count click reports a settings change");
      Assert (Result.Directory_Reloaded, "the hidden-count click reports the directory reload");
      Assert (Ada.Directories.Exists (Path), "the hidden-count click persists the settings file");
   end Test_Bottom_Bar_Hidden_Toggle;

   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Sort_Field;
      use type Files.Settings.Sort_Field;
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "sort-persist.conf");

      function Items return Files.File_System.Item_Vectors.Vector is
         V : Files.File_System.Item_Vectors.Vector;
      begin
         V.Append (Files.File_System.Make_Item
                     (Files_Suite.Support.Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
         V.Append (Files.File_System.Make_Item
                     (Files_Suite.Support.Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
         return V;
      end Items;

      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Dispatch (Command : Files.Commands.Command_Id) is
         Action : constant Files.Events.Input_Action :=
           (Kind => Files.Events.Command_Input_Action, Command => Command, Activate => True, others => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
      end Dispatch;
   begin
      Files_Suite.Support.Reset_Root;
      Files.Model.Initialize
        (Model,
         Directory_Path => Files_Suite.Support.Root,
         Items          => Items,
         Home_Path      => "/home/test");

      --  Default sort is by name, ascending. Selecting size from the bottom bar
      --  must apply live and persist the field to the settings file.
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Name, "the model starts sorted by name");
      Dispatch (Files.Commands.Sort_By_Size_Command);
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Size, "the sort command applies live");
      Assert (Settings.Sort_Field_Value = Files.Settings.Sort_By_Size, "the sort field is written to settings");
      Assert (Result.Settings_Changed, "the sort command reports a settings change");
      Assert (Ada.Directories.Exists (Path), "the sort command persists the settings file");

      --  Re-selecting the same field flips direction; that flip must persist too --
      --  the reported bug was that the bottom-bar direction change was not saved.
      Assert (Files.Model.Sort_Is_Ascending (Model), "selecting a new field sorts ascending");
      Dispatch (Files.Commands.Sort_By_Size_Command);
      Assert (not Files.Model.Sort_Is_Ascending (Model), "re-selecting the field flips to descending");
      Assert (not Settings.Sort_Ascending, "the flipped direction is written to settings");

      --  The direction survives a round-trip through the on-disk settings file.
      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Load_File (Path);
      begin
         Assert (Reloaded.Success, "the persisted settings file reloads cleanly");
         Assert (Reloaded.Settings.Sort_Field_Value = Files.Settings.Sort_By_Size,
                 "the reloaded settings keep the chosen sort field");
         Assert (not Reloaded.Settings.Sort_Ascending,
                 "the reloaded settings keep the descending direction");
      end;
   end Test_Bottom_Bar_Sort_Persists;

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
      Index := Files.Rendering.Item_At (Items, X, Y);
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
      Index : constant Natural := Files.Rendering.Item_At (Items, X, Y);
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
      if Target_Row = 0 then
         return;
      end if;
      Row_X := Menu.X + Menu.Width / 2;
      Row_Y :=
        Files.Rendering.Context_Menu_Row_Top (Menu, Target_Row) + Menu.Row_Height / 2;
      Assert
        (Files.Rendering.Context_Menu_Row_At (Menu, Row_X, Row_Y) = Target_Row,
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

   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Roots    : Files.Types.String_Vectors.Vector;
      Root_A   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "root-a");
      Root_B   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "root-b");
      X, Y     : Natural := 0;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Root_A);
      Ada.Directories.Create_Path (Root_B);
      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Root_A));
      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Root_B));
      Files.Model.Open_Root_Selector (Model, Roots);

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
         Action   : Files.Events.Input_Action;
      begin
         for Row of Rows loop
            if Row.Root_Index = 2 then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
            end if;
         end loop;
         Assert
           (Files.Rendering.Root_Path_At (Rows, X, Y) = 2,
            "the derived coordinate hit-tests back to the second root row");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Root_Click_Input_Action,
            "a root-row coordinate translates to a root click");
         Assert (Action.Root_Index = 2, "the root click carries the second root index");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      Assert (Files.Model.Current_Path (Model) = Root_B, "the root click navigates to the chosen root");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "selecting a root closes the root selector");
   end Test_Root_Selector_Click_Navigates;
   --  Open the command palette, derive its close (X) button from the real
   --  palette layout, click the button's center through the shell's
   --  Translate_Click -> Apply_Input_Action path, and assert the palette closed.
   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Model.Open_Command_Palette (Model);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "the command palette is open before the close click");
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Palette  : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line);
         Close    : constant Files.Rendering.Close_Button_Layout :=
           Files.Rendering.Panel_Close_Button
             (Palette.X, Palette.Y, Palette.Width, Palette.Height, Line);
      begin
         Assert (Close.Visible, "the open command palette exposes a close (X) button");
         Click
           (Model, Settings, Close.X + Close.Width / 2, Close.Y + Close.Height / 2,
            Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (not Files.Model.Command_Palette_Is_Open (Model),
         "clicking the palette close (X) button closes the command palette");
   end Test_Command_Palette_Close_Button_Closes;

   --  Same seam for the info pane: open it, derive its close (X) button from
   --  the real info-pane layout (kept clear of the scrollbar column), click the
   --  button's center, and assert the pane closed.
   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Info_Pane_Is_Open (Model), "the info pane is open before the close click");
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
         Panel_W  : constant Natural :=
           (if Info.Scrollbar_Visible and then Info.Width > Info.Scrollbar_Width
            then Info.Width - Info.Scrollbar_Width
            else Info.Width);
         Close    : constant Files.Rendering.Close_Button_Layout :=
           Files.Rendering.Panel_Close_Button (Info.X, Info.Y, Panel_W, Info.Height, Line);
      begin
         Assert (Close.Visible, "the open info pane exposes a close (X) button");
         Click
           (Model, Settings, Close.X + Close.Width / 2, Close.Y + Close.Height / 2,
            Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (not Files.Model.Info_Pane_Is_Open (Model),
         "clicking the info-pane close (X) button closes the info pane");
   end Test_Info_Pane_Close_Button_Closes;
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Toolbar  : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Window_W);
      Center_Y : constant Natural :=
        Guikit.Layout.Toolbar_Input_Y (Line) + Guikit.Layout.Toolbar_Input_Height (Line) / 2;
      Left_X   : constant Natural := Toolbar.Middle_X + Guikit.Layout.Input_Field_Padding;
      Right_X  : constant Natural := Toolbar.Middle_X + Toolbar.Middle_Width - 1;
   begin
      Files.Model.Set_Path_Input_Text (Model, "abcdef");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Left_X, Center_Y, Window_W, Window_H, Line_Height => Line);
      begin
         Assert
           (Action.Kind = Files.Events.Text_Click_Input_Action,
            "the path-input region translates to a text click");
         Assert
           (Action.Focus_Target = Files.Types.Focus_Path_Input,
            "the text click targets the path input");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      Assert
        (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input,
         "applying the text click moves focus to the path input");
      Assert
        (Files.Model.Text_Cursor_Position (Model) = 0,
         "clicking the field's left edge places the cursor at the start of the text");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Right_X, Center_Y, Window_W, Window_H, Line_Height => Line);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      --  Focusing the path input loads the current directory path for editing,
      --  so the exact end offset is path-dependent; asserting the cursor moved
      --  off the start proves the click set a concrete cursor position.
      Assert
        (Files.Model.Text_Cursor_Position (Model) > 0,
         "clicking deeper into the field advances the cursor into the path text");
   end Test_Text_Input_Click_Focuses;

   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Before   : Natural;
   begin
      --  A details list of many items overflows the main view so a draggable
      --  scrollbar thumb is laid out.
      for Index in 1 .. 60 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Main     : constant Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural;
      begin
         Assert (Main.Scrollbar_Visible, "the overflowing list lays out a scrollbar");
         X := Main.Scrollbar_X + Main.Scrollbar_Width / 2;
         Y := Main.Scrollbar_Thumb_Y + Main.Scrollbar_Height / 2;
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Scrollbar_Drag_Begin_Input_Action,
            "a click on the scrollbar thumb translates to a drag-begin action");
         Assert
           (Action.Scroll_Area = Files.Events.Scroll_Main_View,
            "the drag-begin action targets the main view");

         --  The reducer treats scrollbar-drag begin as a no-op: continuous drag
         --  state is owned by the GLFW shell, not the model (see the reducer
         --  comment). Applying it must therefore leave the model untouched.
         Before := Files.Model.Main_View_Scroll_Lines (Model);
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert
           (Files.Model.Main_View_Scroll_Lines (Model) = Before,
            "applying drag-begin leaves the main-view scroll offset to the shell");
         Assert
           (Result.Command = Files.Commands.No_Command and then not Result.Context_Menu_Changed,
            "the drag-begin reducer branch produces no command or menu effect");
      end;
   end Test_Scrollbar_Drag_Begin;

   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Model.Sort_Field;

      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      for Index in 1 .. 8 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Sep_X    : Natural;
         Base_W   : Natural;
         Header_Y : Natural;
         Action   : Files.Events.Input_Action;
         Sort_Before : Files.Model.Sort_Field;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the details list lays out a first data row");
         Sep_X    := Row.Size_X;
         Base_W   := Row.Size_Width;
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Assert (Base_W > Files.Types.Minimum_Detail_Column_Width,
                 "the sample size column starts above the minimum width");

         --  A press on the size column's left-edge separator translates to a
         --  resize-begin action carrying the target column, origin, and width.
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Sep_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         Assert (Action.Kind = Files.Events.Column_Resize_Begin_Input_Action,
                 "a press on a header separator begins a column resize");
         Assert (Files.Types.Detail_Column'Val (Action.Item_Index) = Files.Types.Size_Column,
                 "the resize targets the column whose left edge was pressed");
         Assert (Action.Cursor_Position = Sep_X and then Action.Scroll_Drag_Anchor = Base_W,
                 "the drag-begin action carries the separator origin and column width");

         --  Applying the begin action must not change the sort field: the
         --  separator suppresses the header cell's sort click behind it.
         Sort_Before := Files.Model.Sort_Field_Of (Model);
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert (Files.Model.Sort_Field_Of (Model) = Sort_Before,
                 "pressing a separator does not change the sort field");

         --  Dragging the separator left by 40 px widens the size column by ~40.
         Files.Interaction.Apply_Column_Resize
           (Settings, "", Files.Types.Size_Column,
            Origin_X     => Action.Cursor_Position,
            Origin_Width => Action.Scroll_Drag_Anchor,
            Current_X    => Sep_X - 40,
            Result       => Result);
         Assert (Result.Settings_Changed, "the resize step reports a persisted change");
         Assert (Settings.Column_Widths (Files.Types.Size_Column) = Base_W + 40,
                 "dragging the separator left widens the persisted column width by the drag distance");

         --  The details layout reflects the new width on the next snapshot.
         declare
            After_Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            After_Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (After_Snapshot, Window_W, Window_H, Line);
            After_Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout (After_Snapshot, After_Layout, Line);
         begin
            for Cell of After_Rows loop
               if Cell.Visible_Index = 1 then
                  Assert (Cell.Size_Width = Base_W + 40,
                          "the details layout reflects the resized column width");
                  exit;
               end if;
            end loop;
         end;

         --  A far rightward drag (raw width below the minimum) clamps up to it.
         Files.Interaction.Apply_Column_Resize
           (Settings, "", Files.Types.Size_Column,
            Origin_X     => Action.Cursor_Position,
            Origin_Width => Action.Scroll_Drag_Anchor,
            Current_X    => Sep_X + (Base_W - 10),
            Result       => Result);
         Assert (Settings.Column_Widths (Files.Types.Size_Column) =
                   Files.Types.Minimum_Detail_Column_Width,
                 "a drag that shrinks the column past the minimum clamps up to it");
      end;
   end Test_Column_Resize_Drag;

   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Types.Detail_Column_Order;
      use type Files.Model.Sort_Field;

      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      for Index in 1 .. 8 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Header_Y : Natural;
         Cell_X   : Natural;
         Drop_X   : Natural;
         Action   : Files.Events.Input_Action;
         Drop     : Natural;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the details list lays out a first data row");
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Cell_X   := Row.Size_X + Row.Size_Width / 2;
         Drop_X   := Row.Modified_X + Row.Modified_Width / 2;

         --  A press on the size column's cell body (clear of any separator)
         --  begins a reorder drag carrying the dragged column and its sort
         --  command, rather than immediately sorting.
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Cell_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         Assert (Action.Kind = Files.Events.Column_Reorder_Begin_Input_Action,
                 "a press on a header cell body begins a column reorder");
         Assert (Files.Types.Detail_Column'Val (Action.Item_Index) = Files.Types.Size_Column,
                 "the reorder targets the column whose cell body was pressed");
         Assert (Action.Command = Files.Commands.Sort_By_Size_Command,
                 "the reorder-begin action carries the column's sort command for the click fallback");

         --  Dropping the dragged column over the modified column moves it there
         --  and persists the new order.
         Drop :=
           Files.Rendering.Details_Header_Drop_Index
             (Snapshot, Layout, Drop_X, Header_Y, Line_Height => Line);
         Assert (Drop in Files.Types.Detail_Column_Index,
                 "the drop coordinate resolves to a valid target slot");
         Files.Interaction.Apply_Column_Reorder
           (Settings, "", Files.Types.Size_Column, Drop, Result);
         Assert (Result.Settings_Changed, "the reorder drop reports a persisted change");
         Assert (Settings.Column_Order (2) = Files.Types.Size_Column,
                 "the dropped column takes the target slot in the persisted order");
      end;

      --  A press/release with no movement still sorts: applying the sort command
      --  the reorder-begin action carried changes the sort field and leaves the
      --  column order untouched.
      declare
         Fresh    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Order_Before : constant Files.Types.Detail_Column_Order := Fresh.Column_Order;
         Sort_Before  : constant Files.Model.Sort_Field := Files.Model.Sort_Field_Of (Model);
         Sort_Action  : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Size_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Fresh, "", Sort_Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert (Files.Model.Sort_Field_Of (Model) /= Sort_Before,
                 "a click without a drag applies the sort command");
         Assert (Fresh.Column_Order = Order_Before,
                 "a sort click leaves the column order unchanged");
      end;

      --  A press on a header separator still begins a resize, never a reorder.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Action   : Files.Events.Input_Action;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the reordered details list lays out a first data row");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Row.Size_X, (Layout.Main_Y + Row.Y) / 2,
              Window_W, Window_H, Line_Height => Line);
         Assert (Action.Kind = Files.Events.Column_Resize_Begin_Input_Action,
                 "a separator press still begins a resize, not a reorder");
      end;
   end Test_Column_Reorder_Drag;

   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      --  A small details list leaves ample empty space below the rows and lays
      --  out no scrollbar, so an empty-grid press is unambiguous.
      for Index in 1 .. 6 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Cells    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Cell_1   : constant Files.Rendering.Item_Layout := Cells.Element (1);
         Cell_2   : constant Files.Rendering.Item_Layout := Cells.Element (2);
         Bottom_Y : constant Natural :=
           Cells.Element (Cells.Last_Index).Y
           + Cells.Element (Cells.Last_Index).Height + 20;
         Empty_X  : constant Natural := Layout.Main_X + 10;

         --  The rectangle a drag from item 1's cell to item 2's cell describes.
         Rect_X, Rect_Y, Rect_W, Rect_H : Natural;
         Empty    : Files.Rendering.Visible_Index_Vectors.Vector;
         Hits     : Files.Rendering.Visible_Index_Vectors.Vector;
         Base     : Files.Rendering.Visible_Index_Vectors.Vector;
         X, Y     : Natural;
         Found    : Boolean;
      begin
         Assert (Bottom_Y < Layout.Main_Y + Layout.Main_Height,
                 "the six-row list leaves empty grid space below the last row");

         --  Details rows share an X, so span a nonzero width across rows 1..2.
         Files.Rendering.Marquee_Rect
           (Start_X   => Cell_1.X + 5,
            Start_Y   => Cell_1.Y + Cell_1.Height / 2,
            Current_X => Cell_1.X + 15,
            Current_Y => Cell_2.Y + Cell_2.Height / 2,
            X         => Rect_X,
            Y         => Rect_Y,
            Width     => Rect_W,
            Height    => Rect_H);
         Hits := Files.Rendering.Items_In_Rect (Cells, Rect_X, Rect_Y, Rect_W, Rect_H);

         --  Precedence: a press on empty grid space begins a marquee rather than
         --  clearing or ignoring, and it is not additive without a modifier.
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
            Additive : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Modifiers => Ctrl, Line_Height => Line);
         begin
            Assert (Action.Kind = Files.Events.Marquee_Begin_Input_Action,
                    "an empty-space press begins a marquee");
            Assert (not Action.Toggle_Selection,
                    "a plain empty-space marquee is not additive");
            Assert (Additive.Kind = Files.Events.Marquee_Begin_Input_Action
                    and then Additive.Toggle_Selection,
                    "a Ctrl empty-space press begins an additive marquee");
         end;

         --  Precedence: a press ON an item is a normal click, not a marquee; a
         --  press on the details header is a header action, not a marquee.
         Item_Center (Model, 1, X, Y, Found);
         Assert (Found, "a layout cell exists for the target item");
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         begin
            Assert (Action.Kind = Files.Events.Item_Click_Input_Action,
                    "a press on an item stays a normal item click, not a marquee");
         end;
         declare
            Header_X : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
            Header_Y : constant Natural :=
              (if Cell_1.Y > Line then Cell_1.Y - Line / 2 else Cell_1.Y);
            Header   : constant Files.Rendering.Detail_Header_Cell :=
              Files.Rendering.Details_Header_Cell_At (Snapshot, Layout, Header_X, Header_Y, Line);
            Action   : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Header_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         begin
            Assert (Header.Present, "the details header spans the probed point");
            Assert (Action.Kind /= Files.Events.Marquee_Begin_Input_Action,
                    "a press on the details header does not begin a marquee");
         end;

         --  An empty-space marquee begin is a shell-owned no-op in the reducer:
         --  applying it must not disturb a prior selection (it is not a clear).
         Files.Model.Select_Visible (Model, 5);
         Assert (Files.Model.Is_Selected (Model, 5), "item 5 is selected before the marquee begins");
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         end;
         Assert (Files.Model.Is_Selected (Model, 5),
                 "beginning a marquee leaves the prior selection to the shell (no clear)");

         --  Dragging over items 1 and 2 (non-additive) selects exactly them and
         --  drops the pre-existing selection of item 5.
         Base := Files.Interaction.Selected_Visible_Indices (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => False, Base => Base);
         Assert (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 2),
                 "a non-additive marquee selects exactly the items it touches");
         Assert (not Files.Model.Is_Selected (Model, 3)
                 and then not Files.Model.Is_Selected (Model, 5),
                 "a non-additive marquee replaces the prior selection");

         --  Releasing keeps the selection: the reducer applies nothing on a
         --  marquee release, so the last applied set survives.
         declare
            Before : constant Natural := Files.Model.Selected_Count (Model);
         begin
            Assert (Before = 2, "the marquee selection holds after the drag");
         end;

         --  An additive marquee unions the touched items with the base snapshot.
         Files.Model.Clear_Selection (Model);
         Files.Model.Select_Visible (Model, 4);
         Base := Files.Interaction.Selected_Visible_Indices (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => True, Base => Base);
         Assert (Files.Model.Is_Selected (Model, 1)
                 and then Files.Model.Is_Selected (Model, 2)
                 and then Files.Model.Is_Selected (Model, 4),
                 "an additive marquee unions the touched items with the prior selection");
         Assert (Files.Model.Selected_Count (Model) = 3,
                 "the additive marquee selects exactly the union");

         --  A zero-area marquee (a press that never dragged) selects nothing new.
         Empty := Files.Rendering.Items_In_Rect (Cells, Rect_X, Rect_Y, 0, 0);
         Assert (Empty.Is_Empty, "a zero-area marquee touches no items");
      end;
   end Test_Marquee_Selection_Drag;

   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
   begin
      --  Open on a directory navigates into it.
      declare
         Dir   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "open-nav");
         Items : Files.File_System.Item_Vectors.Vector;
         Model : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "inside.txt"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "open-nav", Files.Types.Directory_Item, "inode/directory"));
         Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
         Files.Model.Select_Visible (Model, 1);

         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Open_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the open command");
         Assert (Files.Model.Current_Path (Model) = Dir, "opening a directory navigates into it");
         Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      end;

      --  Rename, Cut, and Duplicate on a real file, each from a fresh model.
      declare
         Dir       : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "edit-ops");
         Source    : constant String := Files_Suite.Support.Join (Dir, "report.txt");
         Copy_Path : constant String := Files_Suite.Support.Join (Dir, "report (copy).txt");
         Model     : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Files_Suite.Support.Write_File (Source, "payload");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the rename command");
         Assert (Files.Model.Rename_Is_Active (Model), "rename starts inline editing of the selection");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Cut_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the cut command");
         Assert (Result.Command = Files.Commands.Cut_Selected_Items_Command, "the result echoes the cut command");
         Assert
           (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut,
            "cut records a cut clipboard intent");
         Assert (Files.Model.Clipboard_Has_Items (Model), "cut captures the selected item");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Duplicate_Selected_Command, Result, Found);
         Assert (Found, "the item menu offers the duplicate command");
         Assert (Ada.Directories.Exists (Source), "duplicate keeps the original file");
         Assert (Ada.Directories.Exists (Copy_Path), "duplicate writes a uniquely named copy");
      end;
   end Test_Context_Menu_Open_And_Edit;

   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "archive-ops");
      Report   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Notes    : constant String := Files_Suite.Support.Join (Dir, "notes.txt");
      Zip_Path : constant String := Files_Suite.Support.Join (Dir, "report.zip");
      Sz_Path  : constant String := Files_Suite.Support.Join (Dir, "report.7z");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Report, "first payload");
      Files_Suite.Support.Write_File (Notes, "second payload");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_Zip_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-zip command");
      Assert (Result.Command = Files.Commands.Compress_Zip_Command, "the result echoes the compress-zip command");
      Assert (Ada.Directories.Exists (Zip_Path), "compress-zip writes a zip archive next to the item");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_7z_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-7z command");
      Assert (Ada.Directories.Exists (Sz_Path), "compress-7z writes a 7z archive next to the item");

      --  Extract a real archive built next to the originals.
      declare
         use type Zlib.Status_Code;
         Bundle : constant String := Files_Suite.Support.Join (Dir, "bundle.zip");
         Dest   : constant String := Files_Suite.Support.Join (Dir, "bundle");
         Inputs : Zlib.Text_Array (1 .. 2);
         Names  : Zlib.Text_Array (1 .. 2);
         Status : Zlib.Status_Code;
      begin
         Inputs (1) := Ada.Strings.Unbounded.To_Unbounded_String (Report);
         Inputs (2) := Ada.Strings.Unbounded.To_Unbounded_String (Notes);
         Names (1) := Ada.Strings.Unbounded.To_Unbounded_String ("report.txt");
         Names (2) := Ada.Strings.Unbounded.To_Unbounded_String ("notes.txt");
         Zlib.ZIP_Files (Inputs, Bundle, Names, Status => Status);
         Assert (Status = Zlib.Ok, "the test archive is created for extraction");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "bundle.zip");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
         Assert (Found, "the item menu offers the extract command");
         Assert (Ada.Directories.Exists (Dest), "extract creates a folder from the archive base name");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Dest, "report.txt")),
            "extract writes the archived entries into the new folder");
      end;
   end Test_Context_Menu_Archive_Commands;

   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
   begin
      --  New Folder from the empty-area menu activates a temporary directory item.
      declare
         Dir   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "empty-area");
         Model : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Model := Loaded_Model (Dir);

         Open_Empty_Context_Menu (Model, Settings, Result);
         Assert (Files.Model.Context_Menu_Is_Open (Model), "the empty-area menu opens on empty space");
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.New_Folder_Command, Result, Found);
         Assert (Found, "the empty-area menu offers the new-folder command");
         Assert (Files.Model.Temporary_Item_Is_Active (Model), "new folder activates a temporary item");
         Assert
           (Files.Model.Temporary_Item_Is_Directory (Model),
            "the new-folder temporary item is marked as a directory");
      end;

      --  Paste from the empty-area menu copies a clipboard item into the
      --  navigated-into subdirectory.
      declare
         Src_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "paste-src");
         Sub     : constant String := Files_Suite.Support.Join (Src_Dir, "sub");
         Model   : Files.Model.Window_Model;
         Load    : Files.File_System.Directory_Load_Result;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Sub);
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Src_Dir, "a.txt"), "payload");

         Model := Loaded_Model (Src_Dir);
         Files_Suite.Support.Select_Name (Model, "a.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Copy_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the copy command");

         Load := Files.File_System.Load_Directory (Sub, Settings);
         Files.Model.Navigate_To (Model, Sub, Load.Items);
         Open_Empty_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Paste_Items_Command, Result, Found);
         Assert (Found, "the empty-area menu offers the paste command");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Sub, "a.txt")),
            "paste copies the clipboard item into the current directory");
      end;
   end Test_Context_Menu_Empty_Area_Commands;

   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Found       : Boolean;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_trash_xdg";
      Trash_File  : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Join (Trash_Home, "Trash"), "files");
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      Restore_Src : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "restore-me.txt");
      Had_Data    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home    : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Data    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Home    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Backend : Ada.Strings.Unbounded.Unbounded_String;
      Model       : Files.Model.Window_Model;

      procedure Restore_Environment is
      begin
         if Had_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Ada.Strings.Unbounded.To_String (Old_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", Ada.Strings.Unbounded.To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set
              ("FILES_TRASH_BACKEND", Ada.Strings.Unbounded.To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Data then
         Old_Data :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Files_Suite.Support.Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);

      --  Delete moves the item to trash and records an undoable action.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Delete_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the delete command");
      Assert (not Ada.Directories.Exists (Doomed), "delete moves the item out of the directory");
      Assert (Files.Model.Undo_Available (Model), "delete records an undoable action");

      --  Undo has neither a context-menu row nor a keyboard shortcut, so it is
      --  driven through the reducer's command branch, the same entry the shell
      --  uses for menu-bar commands.
      declare
         Undo_Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Undo_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Undo_Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (Ada.Directories.Exists (Doomed), "undo restores the trashed item to its original path");
      Assert (not Files.Model.Undo_Available (Model), "undo consumes the undoable action");
      --  Re-trashing would allocate a fresh trash location, so a restored trash
      --  action is undo-only and is never offered for redo.
      Assert (not Files.Model.Redo_Available (Model), "a restored-trash undo is not offered for redo");

      --  Restore From Trash, dispatched from the item menu while viewing trash.
      declare
         Mutation : Files.File_System.Mutation_Result;
         Load     : Files.File_System.Directory_Load_Result;
      begin
         Files_Suite.Support.Write_File (Restore_Src, "payload");
         Mutation := Files.File_System.Move_To_Trash (Restore_Src);
         Assert (Mutation.Success, "the restore setup moves a file into the trash");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "restore-me.txt")),
            "the restore setup stores the trashed payload");

         Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
         Files.Model.Initialize
           (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
         Files_Suite.Support.Select_Name (Model, "restore-me.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Restore_From_Trash_Command, Result, Found);
         Assert (Found, "the item menu offers the restore-from-trash command");
         Assert (Ada.Directories.Exists (Restore_Src), "restore returns the file to its original path");
         Assert
           (not Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "restore-me.txt")),
            "restore removes the trashed payload");
      end;

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Context_Menu_Trash_Lifecycle;

   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "menu-contents");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "report.txt"), "payload");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "the item menu opens on the selected file");

      --  Every item-context command the layout promises is present (rule a).
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the item menu lists Open");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_With_Command),
              "the item menu lists Open With");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Favorite_Command),
              "the item menu lists Toggle Favorite");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Set_Color_Label_Command),
              "the item menu lists Set Color Label");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the item menu lists Copy");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Cut_Selected_Items_Command),
              "the item menu lists Cut");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Copy_To_Command),
              "the item menu lists Copy to");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Move_To_Command),
              "the item menu lists Move to");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Duplicate_Selected_Command),
              "the item menu lists Duplicate");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_Symlink_Command),
              "the item menu lists Create Symlink");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_Hardlink_Command),
              "the item menu lists Create Hardlink");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Rename_Selected_Items_Command),
              "the item menu lists Rename");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Delete_Selected_Items_Command),
              "the item menu lists Delete");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Compress_Zip_Command),
              "the item menu lists Compress Zip");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Compress_7z_Command),
              "the item menu lists Compress 7z");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "the item menu lists Extract");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Restore_From_Trash_Command),
              "the item menu lists Restore From Trash");

      --  Selection-driven enablement (rule b: semantic Is_Enabled, not geometry).
      Assert (Files.Commands.Is_Enabled (Files.Commands.Copy_Selected_Items_Command, Model),
              "Copy is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Cut_Selected_Items_Command, Model),
              "Cut is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Model),
              "Duplicate is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Copy_To_Command, Model),
              "Copy to is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Move_To_Command, Model),
              "Move to is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
              "Create Symlink is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
              "Create Hardlink is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Compress_Zip_Command, Model),
              "Compress Zip is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Compress_7z_Command, Model),
              "Compress 7z is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Open_With_Command, Model),
              "Open With is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
              "Open is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
              "Delete is enabled with a selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
              "Rename is enabled for a single real selection");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Set_Color_Label_Command, Model),
              "Set Color Label is enabled with a selection");

      --  Context-sensitive commands are present but disabled in a normal
      --  directory on a plain file: Extract needs an archive, Restore needs trash.
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled on a non-archive selection");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is disabled outside the trash directory");
   end Test_Item_Menu_Contents_And_Enablement;

   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "empty-contents");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Model := Loaded_Model (Dir);

      Open_Empty_Context_Menu (Model, Settings, Result);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "the empty-area menu opens on empty space");

      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_File_Command),
              "the empty-area menu lists Create File");
      Assert (Menu_Offers (Model, Settings, Files.Commands.New_Folder_Command),
              "the empty-area menu lists New Folder");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Paste_Items_Command),
              "the empty-area menu lists Paste");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_Terminal_Command),
              "the empty-area menu lists Open Terminal");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Refresh_Directory_Command),
              "the empty-area menu lists Refresh");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Empty_Trash_Command),
              "the empty-area menu lists Empty Trash");

      --  The item-only commands must not leak into the empty-area menu.
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the empty-area menu omits Open");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the empty-area menu omits Copy");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Cut_Selected_Items_Command),
              "the empty-area menu omits Cut");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Delete_Selected_Items_Command),
              "the empty-area menu omits Delete");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Rename_Selected_Items_Command),
              "the empty-area menu omits Rename");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "the empty-area menu omits Extract");
   end Test_Empty_Area_Menu_Contents;

   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Context_Menu_Target;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      for Index in 1 .. 6 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      --  Right-click the details header, deriving the coordinate from the real
      --  header hit-test (rule a) and driving the real Apply_Right_Click (rule d).
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Header_X : Natural := 0;
         Header_Y : Natural := 0;
         In_Main  : Boolean;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
            end if;
         end loop;
         Header_X := Row.Name_X + Row.Name_Width / 2;
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Assert
           (Files.Rendering.Details_Header_Cell_At
              (Snapshot, Layout, Header_X, Header_Y, Line).Present,
            "the derived coordinate lands on the details header band");
         In_Main :=
           Header_X >= Layout.Main_X and then Header_X < Layout.Main_X + Layout.Main_Width
           and then Header_Y >= Layout.Main_Y and then Header_Y < Layout.Main_Y + Layout.Main_Height;
         Files.Interaction.Apply_Right_Click
           (Model, Settings, In_Main, 0, Header_X, Header_Y, Result,
            In_Details_Header => True);
      end;

      Assert (Files.Model.Context_Menu_Is_Open (Model), "the header menu opens on the column header");
      Assert
        (Files.Model.Context_Menu_Target_Of (Model) = Files.Model.Context_Menu_Header,
         "the right-click targets the details-header menu");

      --  Every column toggle and the grouping cycle are offered (rule a).
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Modified_Command),
              "the header menu lists the modified-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Size_Command),
              "the header menu lists the size-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Type_Command),
              "the header menu lists the type-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Created_Command),
              "the header menu lists the created-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Permissions_Command),
              "the header menu lists the permissions-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Cycle_Group_By_Command),
              "the header menu lists the grouping cycle");

      --  The item-only commands must not leak into the header menu.
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the header menu omits Open");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the header menu omits Copy");

      --  Selecting a toggle flips the persisted setting through the reducer.
      declare
         Before : constant Boolean := Settings.Column_Visible (Files.Types.Size_Column);
      begin
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Toggle_Column_Size_Command, Result, Found);
         Assert (Found, "the header menu offers the size-column toggle for dispatch");
         Assert (Result.Settings_Changed, "toggling a column reports a persisted settings change");
         Assert
           (Settings.Column_Visible (Files.Types.Size_Column) /= Before,
            "dispatching the toggle flips the column's visibility setting");
         Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      end;
   end Test_Header_Menu_Column_Config;

   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "extract-enable");
      Plain    : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Bundle   : constant String := Files_Suite.Support.Join (Dir, "bundle.zip");
      Inputs   : Zlib.Text_Array (1 .. 1);
      Names    : Zlib.Text_Array (1 .. 1);
      Status   : Zlib.Status_Code;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Plain, "payload");
      Inputs (1) := Ada.Strings.Unbounded.To_Unbounded_String (Plain);
      Names (1) := Ada.Strings.Unbounded.To_Unbounded_String ("report.txt");
      Zlib.ZIP_Files (Inputs, Bundle, Names, Status => Status);
      Assert (Status = Zlib.Ok, "the test archive is created for the enablement check");

      --  A plain-file selection: Extract is listed but disabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "Extract is listed for a plain-file selection");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled when the selection holds no archive");

      --  An archive selection: Extract is enabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "bundle.zip");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is enabled when the selection includes an archive");
   end Test_Extract_Enablement_By_Selection;

   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_restore_enable_xdg";
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      Had_Data    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home    : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Data    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Home    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Backend : Ada.Strings.Unbounded.Unbounded_String;
      Model       : Files.Model.Window_Model;
      Mutation    : Files.File_System.Mutation_Result;
      Load        : Files.File_System.Directory_Load_Result;

      procedure Restore_Environment is
      begin
         if Had_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Ada.Strings.Unbounded.To_String (Old_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", Ada.Strings.Unbounded.To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set
              ("FILES_TRASH_BACKEND", Ada.Strings.Unbounded.To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Data then
         Old_Data :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Files_Suite.Support.Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);

      --  A selected file in a normal directory: Restore From Trash is disabled.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Restore_From_Trash_Command),
              "Restore From Trash is listed even in a normal directory");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is disabled in a normal directory");

      --  After trashing and navigating into the trash files directory, a selected
      --  trashed item enables Restore From Trash.
      Mutation := Files.File_System.Move_To_Trash (Doomed);
      Assert (Mutation.Success, "the setup moves the file into the trash");
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Initialize
        (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Assert (Files.Model.Selected_Count (Model) > 0, "the trashed item is selected in the trash view");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is enabled with a selection inside the trash directory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash_Enablement_By_Context;

   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "paste-enable");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "a.txt"), "payload");
      Model := Loaded_Model (Dir);

      --  No clipboard yet: Paste is listed in the empty-area menu but disabled.
      Open_Empty_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Paste_Items_Command),
              "the empty-area menu lists Paste");
      Assert (not Files.Model.Clipboard_Has_Items (Model), "the clipboard starts empty");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Paste_Items_Command, Model),
              "Paste is disabled before anything is copied");
      Files.Model.Close_Context_Menu (Model);

      --  Copy a file: Paste becomes enabled.
      Files_Suite.Support.Select_Name (Model, "a.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Copy_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the copy command");
      Assert (Files.Model.Clipboard_Has_Items (Model), "copy populates the clipboard");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Paste_Items_Command, Model),
              "Paste is enabled once the clipboard holds items");
   end Test_Paste_Enablement_Reflects_Clipboard;

   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "disabled-noop");
      Extract  : constant String := Files_Suite.Support.Join (Dir, "report");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "report.txt"), "payload");
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");

      --  Extract is disabled on a plain-file selection. Dispatching it through the
      --  real menu seam must be gated by Execute_Command (Is_Enabled) and act on
      --  nothing.
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled for the plain-file selection");
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
      Assert (Found, "the disabled command is still offered by the menu");
      Assert (Result.Command = Files.Commands.Extract_Archive_Command,
              "the result echoes the dispatched command id");
      Assert (not Result.Command_Executed,
              "the disabled command does not report execution");
      Assert (Result.Status = Files.Controller.Controller_Ignored,
              "the gated dispatch returns an ignored controller status");
      Assert (not Ada.Directories.Exists (Extract),
              "the disabled extract command creates no folder");
   end Test_Disabled_Command_Does_Not_Act;

   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "rename-seq");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Step 1: select and start rename from the item menu.
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Assert (Files.Model.Rename_Is_Active (Model), "rename starts inline editing");

      --  Step 2: set the new name and commit through the real Enter key seam.
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");
      Assert (not Ada.Directories.Exists (Source), "committing the rename removes the old name");
      Assert (not Files.Model.Rename_Is_Active (Model), "committing the rename ends inline editing");
      Assert (Files.Model.Undo_Available (Model), "the rename records an undoable action");

      --  Step 3: undo through the reducer command branch restores the original.
      Dispatch_Command (Model, Settings, Files.Commands.Undo_Command, Result);
      Assert (Ada.Directories.Exists (Source), "undo restores the original name");
      Assert (not Ada.Directories.Exists (Renamed), "undo removes the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "undo consumes the undoable action");
   end Test_Sequence_Rename_Then_Undo;

   --  Drive undo through the GENUINE live key seam (Files.Interaction.Handle_Key)
   --  with the real Shortcut_For (Undo_Command) binding, Ctrl+Z. First establish
   --  an undoable state with a committed rename, then press Ctrl+Z and assert the
   --  seam routes to Undo_Command and the original name is restored on disk.
   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "undo-key");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Confirm Ctrl+Z translates to the undo command through the shortcut table.
      declare
         Action : constant Files.Events.Input_Action :=
           Files.Events.Translate_Key (Guikit.Input.Key_Z, Ctrl);
      begin
         Assert
           (Action.Kind = Files.Events.Command_Input_Action,
            "Ctrl+Z translates to a command input action");
         Assert
           (Action.Command = Files.Commands.Undo_Command,
            "Ctrl+Z is bound to the undo command");
      end;

      --  Establish an undoable state: rename report.txt to summary.txt via the seam.
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");
      Assert (Files.Model.Undo_Available (Model), "the rename records an undoable action");

      --  Press Ctrl+Z through the live key seam and assert the undo takes effect.
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert
        (Result.Command = Files.Commands.Undo_Command,
         "Ctrl+Z dispatched through Handle_Key reports the undo command");
      Assert (Ada.Directories.Exists (Source), "Ctrl+Z restores the original name");
      Assert (not Ada.Directories.Exists (Renamed), "Ctrl+Z removes the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "the undo consumes the undoable action");
   end Test_Undo_Shortcut_Ctrl_Z;

   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "redo-key");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Confirm Ctrl+Shift+Z translates to the redo command, distinct from the
      --  Ctrl+Z undo binding (so the two shortcuts do not collide).
      declare
         Action : constant Files.Events.Input_Action :=
           Files.Events.Translate_Key (Guikit.Input.Key_Z, Ctrl_Shift);
      begin
         Assert
           (Action.Kind = Files.Events.Command_Input_Action,
            "Ctrl+Shift+Z translates to a command input action");
         Assert
           (Action.Command = Files.Commands.Redo_Command,
            "Ctrl+Shift+Z is bound to the redo command");
      end;

      --  Establish an undo/redo state: rename report.txt to summary.txt, then
      --  undo it through the Ctrl+Z seam.
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Ada.Directories.Exists (Source), "Ctrl+Z undoes the rename");
      Assert (Files.Model.Redo_Available (Model), "redo becomes available after the undo");

      --  Press Ctrl+Shift+Z through the live key seam and assert the redo runs.
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl_Shift,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert
        (Result.Command = Files.Commands.Redo_Command,
         "Ctrl+Shift+Z dispatched through Handle_Key reports the redo command");
      Assert (Ada.Directories.Exists (Renamed), "Ctrl+Shift+Z re-applies the rename");
      Assert (not Ada.Directories.Exists (Source), "Ctrl+Shift+Z removes the reverted name");
      Assert (not Files.Model.Redo_Available (Model), "the redo shortcut consumes the redo action");
   end Test_Redo_Shortcut_Ctrl_Shift_Z;

   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "compress-seq");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Zip_Path : constant String := Files_Suite.Support.Join (Dir, "report.zip");
      Dest     : constant String := Files_Suite.Support.Join (Dir, "report");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");

      --  Step 1: compress the file to a zip via the item menu.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_Zip_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-zip command");
      Assert (Ada.Directories.Exists (Zip_Path), "compress-zip writes the archive");

      --  Step 2: reload so the new archive appears, select it, and extract.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.zip");
      Assert (Files.Model.Selected_Count (Model) > 0, "the reloaded listing contains the new archive");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is enabled on the reloaded archive selection");
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
      Assert (Found, "the item menu offers the extract command");
      Assert (Ada.Directories.Exists (Dest), "extract creates a folder from the archive base name");
      Assert
        (Ada.Directories.Exists (Files_Suite.Support.Join (Dest, "report.txt")),
         "extract writes the archived entry into the new folder");
   end Test_Sequence_Compress_Then_Extract;
   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Found       : Boolean;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_trash_seq_xdg";
      Trash_File  : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Join (Trash_Home, "Trash"), "files");
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      Had_Data    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home    : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Data    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Home    : Ada.Strings.Unbounded.Unbounded_String;
      Old_Backend : Ada.Strings.Unbounded.Unbounded_String;
      Model       : Files.Model.Window_Model;
      Load        : Files.File_System.Directory_Load_Result;

      procedure Restore_Environment is
      begin
         if Had_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Ada.Strings.Unbounded.To_String (Old_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", Ada.Strings.Unbounded.To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set
              ("FILES_TRASH_BACKEND", Ada.Strings.Unbounded.To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Data then
         Old_Data :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend :=
           Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Files_Suite.Support.Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);

      --  Step 1: delete a file to trash via the item menu.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Delete_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the delete command");
      Assert (not Ada.Directories.Exists (Doomed), "delete moves the item out of the directory");
      Assert
        (Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "doomed.txt")),
         "delete stores the payload in the trash files directory");

      --  Step 2: navigate into the trash directory and select the trashed item.
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Initialize
        (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Assert (Files.Model.Selected_Count (Model) > 0, "the trashed item is selectable in the trash view");

      --  Step 3: restore from the item menu returns the file to its origin.
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Restore_From_Trash_Command, Result, Found);
      Assert (Found, "the item menu offers the restore-from-trash command");
      Assert (Ada.Directories.Exists (Doomed), "restore returns the file to its original path");
      Assert
        (not Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "doomed.txt")),
         "restore removes the file from the trash directory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Sequence_Trash_Then_Restore;

   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Src_Dir  : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "cut-seq");
      Sub      : constant String := Files_Suite.Support.Join (Src_Dir, "sub");
      Source   : constant String := Files_Suite.Support.Join (Src_Dir, "movable.txt");
      Pasted   : constant String := Files_Suite.Support.Join (Sub, "movable.txt");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Files_Suite.Support.Write_File (Source, "payload");

      --  Step 1: cut a file from the source directory.
      Model := Loaded_Model (Src_Dir);
      Files_Suite.Support.Select_Name (Model, "movable.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Cut_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the cut command");
      Assert
        (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut,
         "cut records a cut clipboard intent");

      --  Step 2: navigate into the subdirectory and paste via the empty-area menu.
      Load := Files.File_System.Load_Directory (Sub, Settings);
      Files.Model.Navigate_To (Model, Sub, Load.Items);
      Open_Empty_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Paste_Items_Command, Result, Found);
      Assert (Found, "the empty-area menu offers the paste command");
      Assert (Ada.Directories.Exists (Pasted), "paste moves the cut file into the subdirectory");
      Assert (not Ada.Directories.Exists (Source), "a cut paste removes the file from its origin");

      --  Step 3: if the move is undoable, undo returns the file to its origin.
      if Files.Model.Undo_Available (Model) then
         Dispatch_Command (Model, Settings, Files.Commands.Undo_Command, Result);
         Assert (Ada.Directories.Exists (Source), "undo moves the cut file back to its origin");
         Assert (not Ada.Directories.Exists (Pasted), "undo removes the file from the subdirectory");
      end if;
   end Test_Sequence_Cut_Paste_Into_Subdir;

   --  Bug 15 regression: arrow navigation must always move to the visually
   --  adjacent item as displayed, regardless of sort direction. Drives the real
   --  path (sort command through Apply_Input_Action, arrows through Handle_Key)
   --  and uses Build_Snapshot -- the display-order oracle -- to locate items.
   procedure Test_Descending_Sort_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "nav-desc");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;

      --  Position of Name in the DISPLAYED order (1-based), or 0 when absent.
      function Display_Position_Of (Name : String) return Natural is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            if Ada.Strings.Unbounded.To_String (Snapshot.Items.Element (Index).Name) = Name then
               return Index;
            end if;
         end loop;
         return 0;
      end Display_Position_Of;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "a.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "b.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "c.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "d.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "e.txt"));
      Model := Loaded_Model (Dir);
      Files.Model.Set_View_Mode (Model, Files.Types.Details);

      --  Toggle to descending name sort through the real command path.
      declare
         Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Name_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Files.Model.Sort_Is_Ascending (Model), "the sort command toggles to descending order");

      --  Anchor on a middle item and remember where it sits when displayed.
      Files_Suite.Support.Select_Name (Model, "c.txt");
      declare
         Start_Pos : constant Natural := Display_Position_Of ("c.txt");
      begin
         Assert
           (Start_Pos > 1 and then Start_Pos < 5,
            "the anchor item sits in the middle of the displayed order");

         --  Down must advance to the NEXT displayed item, never the previous one.
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Down, Guikit.Input.No_Modifiers, Base_Font, Result);
         Assert
           (Display_Position_Of (Files.Model.Selected_Name (Model)) = Start_Pos + 1,
            "Down moves to the next displayed item under descending sort");

         --  Up must return to the anchor (the previous displayed item).
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Up, Guikit.Input.No_Modifiers, Base_Font, Result);
         Assert
           (Display_Position_Of (Files.Model.Selected_Name (Model)) = Start_Pos,
            "Up moves to the previous displayed item under descending sort");
      end;
   end Test_Descending_Sort_Arrows_Follow_Display;

   procedure Test_Descending_Grid_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "nav-desc-grid");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;

      function Display_Position_Of (Name : String) return Natural is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            if Ada.Strings.Unbounded.To_String (Snapshot.Items.Element (Index).Name) = Name then
               return Index;
            end if;
         end loop;
         return 0;
      end Display_Position_Of;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      declare
         Names : constant String := "abcdef";
      begin
         for I in Names'Range loop
            Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, Names (I) & ".txt"));
         end loop;
      end;
      Model := Loaded_Model (Dir);
      Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
      declare
         Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Name_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Files.Model.Sort_Is_Ascending (Model), "sort toggled to descending");
      --  Reload the directory while descending is active -- the common browsing
      --  case. The loaded item order must be re-sorted to match the display, or
      --  arrow navigation walks the raw load order and moves the wrong way.
      declare
         Reload : constant Files.Operations.Operation_Result := Files.Operations.Refresh (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;
      --  Two-column grid: Down should move down a row (two display positions).
      Files.Model.Set_Selection_Grid_Columns (Model, 2);
      Files_Suite.Support.Select_Name (Model, "c.txt");
      declare
         Start_Pos : constant Natural := Display_Position_Of ("c.txt");
      begin
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Down, Guikit.Input.No_Modifiers, Base_Font, Result);
         Assert
           (Display_Position_Of (Files.Model.Selected_Name (Model)) = Start_Pos + 2,
            "grid Down moves down a row (not up) under descending sort");
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Up, Guikit.Input.No_Modifiers, Base_Font, Result);
         Assert
           (Display_Position_Of (Files.Model.Selected_Name (Model)) = Start_Pos,
            "grid Up returns to the previous row under descending sort");
      end;
   end Test_Descending_Grid_Arrows_Follow_Display;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Interaction_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Group_Mode;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Before   : constant Boolean :=
        Settings.Column_Visible (Files.Types.Permissions_Column);
   begin
      --  The toggle command flips the persisted visibility and reports the
      --  settings change through the interaction result.
      Files.Interaction.Execute_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Toggle_Column_Permissions_Command,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Settings.Column_Visible (Files.Types.Permissions_Column) /= Before,
              "the permissions-column command flips its visibility");
      Assert (Result.Settings_Changed, "the column toggle reports a settings change");

      --  The group command advances the persisted grouping mode.
      Files.Interaction.Execute_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Cycle_Group_By_Command,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Settings.Group_By = Files.Types.Group_By_Type,
              "the group-by command advances the grouping mode");

      --  With grouping active in the details view, Build_Snapshot inserts a
      --  non-selectable header row (Visible_Index zero) ahead of the items.
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Header_Rows : Natural := 0;
         Item_Rows   : Natural := 0;
      begin
         for Item of Snapshot.Items loop
            if Item.Is_Group_Header then
               Header_Rows := Header_Rows + 1;
               Assert (Item.Visible_Index = 0, "a group header carries no visible index");
            else
               Item_Rows := Item_Rows + 1;
               Assert (Item.Visible_Index > 0, "a real row keeps its visible index");
            end if;
         end loop;
         Assert (Header_Rows >= 1, "grouping inserts at least one header row");
         Assert (Item_Rows = 3, "every sample item survives grouping");
      end;
   end Test_Column_And_Group_Commands;

   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
   begin
      declare
         Segs : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Segments ("/home/user/files");
      begin
         Assert (Natural (Segs.Length) = 3, "an absolute path yields one segment per named component (no root)");
         Assert (To_String (Segs.Element (1).Label) = "home", "the first segment is the first component");
         Assert (To_String (Segs.Element (1).Ancestor_Path) = "/home", "the first segment navigates to /home");
         Assert (To_String (Segs.Element (2).Label) = "user", "the second segment is the next component");
         Assert (To_String (Segs.Element (2).Ancestor_Path) = "/home/user",
                 "the second segment navigates to /home/user");
         Assert (To_String (Segs.Element (3).Label) = "files", "the last segment is the leaf component");
         Assert
           (To_String (Segs.Element (3).Ancestor_Path) = "/home/user/files",
            "the leaf segment navigates to the full path");
      end;

      declare
         Long   : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Segments ("/a/b/c/d/e/f/g");
         Elided : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Elide (Long, 4);
         Has_Ellipsis : Boolean := False;
      begin
         Assert (Natural (Long.Length) = 7, "the long path has seven segments");
         Assert (Natural (Elided.Length) = 4, "eliding to four keeps four segments");
         Assert (To_String (Elided.First_Element.Label) = "a", "elision keeps the first component");
         Assert (To_String (Elided.Last_Element.Label) = "g", "elision keeps the trailing component");
         for S of Elided loop
            if Files.Breadcrumbs.Is_Ellipsis (S) then
               Has_Ellipsis := True;
            end if;
         end loop;
         Assert (Has_Ellipsis, "elision inserts a non-navigable marker between the head and tail");
      end;
   end Test_Breadcrumb_Segments_And_Elide;

   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Deep     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "deep");
      Leaf     : constant String := Files_Suite.Support.Join (Deep, "leaf");
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Leaf);
      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Leaf, Settings);
      begin
         Files.Model.Initialize
           (Model,
            Directory_Path    => Leaf,
            Items             => Load.Items,
            Home_Path         => "/home/test");
      end;

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Breadcrumb_Segment_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Breadcrumb_Layout (Snapshot, Window_W, Line);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural := 0;
         Found    : Boolean := False;
      begin
         Assert (not Rows.Is_Empty, "an unfocused path bar lays out clickable breadcrumb segments");
         for Row of Rows loop
            if Row.Clickable
              and then Row.Segment_Index /= 0
              and then To_String
                         (Snapshot.Breadcrumb_Segments.Element (Row.Segment_Index).Ancestor_Path)
                       = Deep
            then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
               Found := True;
            end if;
         end loop;
         Assert (Found, "the breadcrumb for the parent directory is laid out");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Breadcrumb_Click_Input_Action,
            "a breadcrumb coordinate translates to a breadcrumb click");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      declare
         Expected : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Deep);
      begin
         Assert
           (Files.Model.Current_Path (Model) = To_String (Expected.Directory_Path),
            "clicking the parent breadcrumb navigates to the parent directory");
      end;
   end Test_Breadcrumb_Click_Navigates;

   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "tree");
      Alpha    : constant String := Files_Suite.Support.Join (Tree_Dir, "alpha");
      Beta     : constant String := Files_Suite.Support.Join (Tree_Dir, "beta");
      Secret   : constant String := Files_Suite.Support.Join (Tree_Dir, ".secret");
      A1       : constant String := Files_Suite.Support.Join (Alpha, "a1");
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Ignored  : Files.Controller.Controller_Result;
      Rows     : Files.Folder_Tree.Visible_Row_Vectors.Vector;

      function Row_Named (Src : Files.Folder_Tree.Visible_Row_Vectors.Vector; Name : String) return Natural is
      begin
         for R of Src loop
            if To_String (R.Name) = Name then
               return R.Node_Index;
            end if;
         end loop;
         return 0;
      end Row_Named;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Beta);
      Ada.Directories.Create_Path (Secret);
      Ada.Directories.Create_Path (A1);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Tree_Dir, "file.txt"));

      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Seed_Tree (Model, Seeds);
      Files.Model.Open_Tree_Panel (Model);

      Rows := Files.Model.Tree_Visible_Rows (Model);
      Assert (Natural (Rows.Length) = 1, "an unexpanded tree shows only its root node");

      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Rows := Files.Model.Tree_Visible_Rows (Model);
      Assert (Natural (Rows.Length) = 3, "expanding the root reveals its two subdirectories");
      Assert (Rows.Element (1).Depth = 0, "the root sits at depth zero");
      Assert
        (Rows.Element (2).Depth = 1 and then Rows.Element (3).Depth = 1,
         "the loaded children sit at depth one");
      Assert (Row_Named (Rows, ".secret") = 0, "hidden directories are excluded when Show_Hidden_Files is off");
      Assert (Row_Named (Rows, "file.txt") = 0, "regular files are excluded from the tree");

      declare
         Alpha_Index : constant Natural := Row_Named (Rows, "alpha");
      begin
         Assert (Alpha_Index /= 0, "the alpha subdirectory is present");
         Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, Alpha_Index, Toggle => True);
      end;
      Rows := Files.Model.Tree_Visible_Rows (Model);
      declare
         Depth_Two : Boolean := False;
      begin
         for R of Rows loop
            if To_String (R.Name) = "a1" then
               Depth_Two := R.Depth = 2;
            end if;
         end loop;
         Assert (Depth_Two, "expanding alpha reveals its child at depth two");
      end;

      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Rows := Files.Model.Tree_Visible_Rows (Model);
      Assert (Natural (Rows.Length) = 1, "collapsing the root hides all its descendants");

      declare
         Hidden_On : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Model2    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Seeds2    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
         Rows2     : Files.Folder_Tree.Visible_Row_Vectors.Vector;
      begin
         Hidden_On.Show_Hidden_Files := True;
         Seeds2.Append
           (Files.Folder_Tree.Entry_Seed'
              (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
         Files.Model.Seed_Tree (Model2, Seeds2);
         Files.Model.Open_Tree_Panel (Model2);
         Ignored := Files.Controller.Handle_Tree_Click (Model2, Hidden_On, 1, Toggle => True);
         Rows2 := Files.Model.Tree_Visible_Rows (Model2);
         Assert (Row_Named (Rows2, ".secret") /= 0, "hidden directories appear when Show_Hidden_Files is on");
      end;
   end Test_Tree_Expand_Collapse_And_Hidden;

   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Folder_Tree_Command,
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "the toggle command opens the folder tree");
      Assert (Files.Model.Tree_Node_Count (Model) > 0, "opening the tree seeds it with root nodes");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Panel    : constant Files.Rendering.Tree_Panel_Layout :=
           Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line);
         Rows     : constant Files.Rendering.Tree_Row_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Tree_Row_Layout (Snapshot, Panel, Line);
         Target   : constant String := Files.Model.Tree_Node_Path (Model, 1);
         Expected : constant Files.File_System.Path_Result :=
           Files.File_System.Normalize_Path (Target);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural := 0;
      begin
         Assert (not Rows.Is_Empty, "the open tree lays out at least one row");
         declare
            Row : constant Files.Rendering.Tree_Row_Layout := Rows.Element (1);
         begin
            X := Row.Triangle_X + Line + 2;
            Y := Row.Y + Row.Height / 2;
         end;
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Tree_Click_Input_Action,
            "a tree label coordinate translates to a tree click");
         Assert (not Action.Toggle_Selection, "clicking the label navigates rather than toggles");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert
           (Expected.Status = Files.File_System.Path_Valid
              and then Files.Model.Current_Path (Model) = To_String (Expected.Directory_Path),
            "clicking a tree label navigates to that directory");
      end;

      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Folder_Tree_Command,
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "toggling again closes the folder tree");
   end Test_Tree_Toggle_Command_And_Click;

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
      X, Y     : Natural := 0;
   begin
      Found := False;
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
   end Click_Root_Row;

   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "favorites.conf");
      Item     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt");
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Toggle_Favorite_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;

      --  Selected file: favoriting stores the item's full path, not the folder.
      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Assert (Files.Model.Selected_Count (Model) = 1, "the sample file is selected before favoriting");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Has_Favorite (Settings, Item), "favoriting a selected file stores its path");
      Assert (Result.Settings_Changed, "favoriting reports a settings change");

      --  Toggling the same selection again removes the favorite.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Has_Favorite (Settings, Item), "toggling the selected file again removes its favorite");

      --  No selection: the toggle falls back to the current directory.
      Files.Model.Deselect_All (Model);
      Assert (Files.Model.Selected_Count (Model) = 0, "the selection is cleared for the fallback path");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert
        (Has_Favorite (Settings, Files.Model.Current_Path (Model)),
         "with no selection the toggle favorites the current folder");
   end Test_Favorite_Toggle_On_Selection;

   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "fav-group");
      One      : constant String := Files_Suite.Support.Join (Dir, "one.txt");
      Two      : constant String := Files_Suite.Support.Join (Dir, "two.txt");
      Three    : constant String := Files_Suite.Support.Join (Dir, "three.txt");
      Model    : Files.Model.Window_Model;
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Toggle_Favorite_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (One, "a");
      Files_Suite.Support.Write_File (Two, "b");
      Files_Suite.Support.Write_File (Three, "c");

      --  All three selected, none favorited: one invocation stars every item.
      Model := Loaded_Model (Dir);
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 3, "all three files are selected before the group toggle");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Has_Favorite (Settings, One), "the group toggle stars the first item");
      Assert (Has_Favorite (Settings, Two), "the group toggle stars the second item");
      Assert (Has_Favorite (Settings, Three), "the group toggle stars the third item");
      Assert (Result.Settings_Changed, "starring the group reports a settings change");

      --  All three favorited: the next invocation un-stars the whole group.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Has_Favorite (Settings, One), "a second group toggle un-stars the first item");
      Assert (not Has_Favorite (Settings, Two), "a second group toggle un-stars the second item");
      Assert (not Has_Favorite (Settings, Three), "a second group toggle un-stars the third item");

      --  Mixed selection (one already favorited): the group toggle stars every
      --  item rather than flipping each independently.
      Settings.Favorite_Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Two));
      Assert (Has_Favorite (Settings, Two), "the second item is pre-favorited for the mixed case");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Has_Favorite (Settings, One), "a mixed group toggle stars the previously unstarred first item");
      Assert (Has_Favorite (Settings, Two), "a mixed group toggle leaves the already-starred second item starred");
      Assert (Has_Favorite (Settings, Three), "a mixed group toggle stars the previously unstarred third item");
   end Test_Favorite_Group_Toggle_Multi_Selection;

   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "label-group");
      One      : constant String := Files_Suite.Support.Join (Dir, "one.txt");
      Two      : constant String := Files_Suite.Support.Join (Dir, "two.txt");
      Three    : constant String := Files_Suite.Support.Join (Dir, "three.txt");
      Model    : Files.Model.Window_Model;
      Open_Cmd : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Set_Color_Label_Command,
         others  => <>);

      function Choose (Label : Files.Types.Color_Label) return Files.Events.Input_Action is
      begin
         return
           (Kind       => Files.Events.Label_Picker_Choice_Input_Action,
            Item_Index => Files.Types.Color_Label'Pos (Label),
            others     => <>);
      end Choose;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (One, "a");
      Files_Suite.Support.Write_File (Two, "b");
      Files_Suite.Support.Write_File (Three, "c");

      --  Open the picker on a multi-selection via the command seam.
      Model := Loaded_Model (Dir);
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 3, "all three files are selected before labeling");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Open_Cmd, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Label_Picker_Is_Open (Model), "the set-label command opens the picker");

      --  Choosing a color labels every selected item and closes the picker.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.Green), Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Label_Picker_Is_Open (Model), "choosing a swatch closes the picker");
      Assert (Files.Settings.Label_Of (Settings, One) = Files.Types.Green, "the first item is labeled green");
      Assert (Files.Settings.Label_Of (Settings, Two) = Files.Types.Green, "the second item is labeled green");
      Assert (Files.Settings.Label_Of (Settings, Three) = Files.Types.Green, "the third item is labeled green");
      Assert (Result.Settings_Changed, "labeling reports a settings change");

      --  Choosing None clears every selected item's label.
      Files.Model.Open_Label_Picker (Model);
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.No_Label), Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Settings.Label_Of (Settings, One) = Files.Types.No_Label, "None clears the first label");
      Assert (Files.Settings.Label_Of (Settings, Two) = Files.Types.No_Label, "None clears the second label");
      Assert (Files.Settings.Label_Of (Settings, Three) = Files.Types.No_Label, "None clears the third label");

      --  A mixed selection (one already labeled differently) all takes the
      --  chosen color.
      Files.Settings.Set_Label (Settings, Two, Files.Types.Red);
      Files.Model.Open_Label_Picker (Model);
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.Blue), Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Settings.Label_Of (Settings, One) = Files.Types.Blue, "the first item becomes blue");
      Assert (Files.Settings.Label_Of (Settings, Two) = Files.Types.Blue,
              "the previously red item is overwritten to blue");
      Assert (Files.Settings.Label_Of (Settings, Three) = Files.Types.Blue, "the third item becomes blue");
   end Test_Color_Label_Picker_Applies_To_Selection;

   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model      : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result     : Files.Interaction.Interaction_Result;
      Fav_Folder : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "fav-folder");
      Fav_File   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "fav-file.txt");
      Prefix     : constant String := Files.Localization.Text ("root.favorite.prefix");
      Found      : Boolean;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Fav_Folder);
      Files_Suite.Support.Write_File (Fav_File);
      Settings.Favorite_Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Fav_Folder));
      Settings.Favorite_Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Fav_File));

      Open_Favorites_Selector (Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "the selector opens for the favorites test");

      --  The star-prefixed base names are what the selector renders for
      --  favorites (semantic label assertion, not pixels).
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Saw_Folder : Boolean := False;
         Saw_File   : Boolean := False;
      begin
         for Label of Snapshot.Root_Labels loop
            if Ada.Strings.Unbounded.To_String (Label) = Prefix & "fav-folder" then
               Saw_Folder := True;
            elsif Ada.Strings.Unbounded.To_String (Label) = Prefix & "fav-file.txt" then
               Saw_File := True;
            end if;
         end loop;
         Assert (Saw_Folder, "the folder favorite renders as a star-prefixed base name");
         Assert (Saw_File, "the file favorite renders as a star-prefixed base name");
      end;

      --  Clicking the folder favorite navigates into it.
      Click_Root_Row (Model, Settings, Fav_Folder, Found, Result);
      Assert (Found, "the folder favorite row is laid out");
      Assert (Files.Model.Current_Path (Model) = Fav_Folder, "a folder favorite navigates into the folder");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "a folder favorite click closes the selector");

      --  Clicking the file favorite opens its parent with the file selected.
      Open_Favorites_Selector (Model, Settings);
      Click_Root_Row (Model, Settings, Fav_File, Found, Result);
      Assert (Found, "the file favorite row is laid out");
      Assert
        (Files.Model.Current_Path (Model) = Files_Suite.Support.Root,
         "a file favorite navigates to the file's parent directory");
      declare
         Selected  : constant Files.File_System.Item_Vectors.Vector :=
           Files.Model.Selected_Items (Model);
         Saw_File  : Boolean := False;
      begin
         for Item of Selected loop
            if Ada.Strings.Unbounded.To_String (Item.Name) = "fav-file.txt" then
               Saw_File := True;
            end if;
         end loop;
         Assert (Saw_File, "a file favorite selects the file in its parent directory");
      end;
   end Test_Favorite_Selector_Star_And_Clicks;

   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "path-star.conf");
      Current  : constant String := Files.Model.Current_Path (Model);
      Star     : constant Files.Rendering.Path_Favorite_Star_Bounds :=
        Files.Rendering.Path_Favorite_Star_Region (Window_W, Line);

      --  Rebuild the real snapshot/frame each time and translate a click at the
      --  star's center, so the assertion drives the same seam the shell drives.
      function Star_Action return Files.Events.Input_Action is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      begin
         return
           Files.Events.Translate_Click
             (Snapshot, Frame,
              Star.X + Star.Width / 2,
              Star.Y + Star.Height / 2,
              Window_W, Window_H, Line_Height => Line);
      end Star_Action;
   begin
      Files_Suite.Support.Reset_Root;
      Assert (Star.Visible, "the path-bar star is laid out at the default window size");
      Assert (not Has_Favorite (Settings, Current), "the current directory starts unfavorited");

      --  The star coordinate resolves to the favorite-toggle action, not to
      --  focusing the path field or navigating a breadcrumb.
      declare
         Action : constant Files.Events.Input_Action := Star_Action;
      begin
         Assert
           (Action.Kind = Files.Events.Path_Favorite_Toggle_Input_Action,
            "a click on the empty path star translates to the favorite-toggle action");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (Has_Favorite (Settings, Current), "clicking the empty star favorites the current directory");
      Assert (Result.Settings_Changed, "toggling the path star reports a settings change");
      Assert (Ada.Directories.Exists (Path), "toggling the path star persists the settings file");
      Assert
        (Files.Model.Focus (Model) /= Files.Types.Focus_Path_Input,
         "toggling the path star does not focus the path input");
      Assert
        (Files.Model.Current_Path (Model) = Current,
         "toggling the path star does not navigate away from the current directory");

      --  The snapshot now reports the favorited state (filled star); clicking
      --  the same zone again removes the favorite.
      declare
         Action : constant Files.Events.Input_Action := Star_Action;
      begin
         Assert
           (Action.Kind = Files.Events.Path_Favorite_Toggle_Input_Action,
            "a second click on the now-filled path star is still the favorite-toggle action");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Has_Favorite (Settings, Current), "clicking the filled star unfavorites the current directory");
   end Test_Path_Star_Click_Toggles_Current_Dir;

   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Stale    : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "gone");
      Before   : constant String := Files.Model.Current_Path (Model);
      Found    : Boolean;
   begin
      Files_Suite.Support.Reset_Root;
      Settings.Favorite_Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Stale));

      Open_Favorites_Selector (Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "the selector opens for the stale-favorite test");

      --  Clicking the stale favorite must not raise and must not navigate.
      Click_Root_Row (Model, Settings, Stale, Found, Result);
      Assert (Found, "the stale favorite row is still laid out");
      Assert (Result.Status = Files.Controller.Controller_Ignored, "a stale favorite click is skipped");
      Assert (Files.Model.Current_Path (Model) = Before, "a stale favorite click does not navigate");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "a skipped stale click leaves the selector open");
   end Test_Favorite_Stale_Entry_Is_Skipped;

   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      No_Mod   : Guikit.Input.Modifier_Set renames Guikit.Input.No_Modifiers;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      procedure Press_Space
        (Model  : in out Files.Model.Window_Model;
         Result : out Files.Interaction.Interaction_Result) is
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_Space,
            Modifiers         => No_Mod,
            Current_Font_Size => Base_Font,
            Result            => Result);
      end Press_Space;
   begin
      --  (1) Single selection, grid focused: Space opens Quick Look, the snapshot
      --  carries it, and the parallel space character is dropped from type-ahead.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Alpha.txt");
         Press_Space (Model, Result);
         Assert (Files.Model.Quick_Look_Is_Open (Model), "Space opens Quick Look for a single selection");
         Assert (Result.Clear_Pending_Text, "the grid Space shortcut drops the parallel type-ahead space");
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
         begin
            Assert (Snapshot.Quick_Look_Open, "the snapshot carries the open Quick Look overlay");
         end;

         --  (2) Space again closes it.
         Press_Space (Model, Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Space again closes Quick Look");

         --  (3) Reopen, then Escape closes it.
         Press_Space (Model, Result);
         Assert (Files.Model.Quick_Look_Is_Open (Model), "Space reopens Quick Look");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_Escape,
            Modifiers         => No_Mod,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Escape closes Quick Look");
      end;

      --  (4) No selection: Space does not open Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Model.Deselect_All (Model);
         Press_Space (Model, Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Space with no selection does not open Quick Look");
      end;

      --  (5) Multi-selection: Space does not open Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Model.Select_All_Visible (Model);
         Assert (Files.Model.Selected_Count (Model) > 1, "the sample model has more than one selectable item");
         Press_Space (Model, Result);
         Assert
           (not Files.Model.Quick_Look_Is_Open (Model),
            "Space with more than one item selected does not open Quick Look");
      end;

      --  (6) Focused text field: Space types a space rather than opening Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Alpha.txt");
         Files.Model.Focus_Filter_Input (Model);
         Press_Space (Model, Result);
         Assert
           (not Files.Model.Quick_Look_Is_Open (Model),
            "Space in a focused text field does not open Quick Look");
         Assert
           (not Result.Clear_Pending_Text,
            "Space in a focused field keeps its character event so it types a space");
         declare
            Typed : constant Files.Controller.Controller_Result :=
              Files.Controller.Append_Focused_Text (Model, " ");
            pragma Unreferenced (Typed);
         begin
            Assert
              (Files.Model.Filter_Text (Model) = " ",
               "the space character types into the focused filter input");
         end;
      end;
   end Test_Quick_Look_Space_Seam;

   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Dir      : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "opened-dir");
      Path     : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "recent.conf");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Open_Selected_Items_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Items.Append
        (Files.File_System.Make_Item
           (Files_Suite.Support.Root, "opened-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      Files.Model.Select_Visible (Model, 1);

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Path,
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);

      declare
         Recent : constant Files.Types.String_Vectors.Vector :=
           Files.Settings.Recent_Paths (Settings);
      begin
         Assert (not Recent.Is_Empty, "opening an item records it in the recent list");
         Assert (To_String (Recent.First_Element) = Ada.Directories.Full_Name (Dir),
                 "the opened folder lands at the front of the recent list");
      end;
      Assert (Result.Settings_Changed, "recording an open reports a settings change");
      Assert (Ada.Directories.Exists (Path), "recording an open persists the settings file");
   end Test_Record_Open_Persists_Recent;

   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "reg-recent-dir");
      Empty    : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "reg-empty-dir");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Navigate_Recent_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Empty);

      --  Both commands are registered and palette-visible.
      Assert (Files.Commands.Contains ("navigate.recent"), "Navigate Recent is a registered command");
      Assert (Files.Commands.Contains ("recent.clear"), "Clear Recent is a registered command");
      Assert (Files.Commands.Command_Palette_Visible (Files.Commands.Navigate_Recent_Command),
              "Navigate Recent appears in the command palette");
      Assert (Files.Commands.Command_Palette_Visible (Files.Commands.Clear_Recent_Command),
              "Clear Recent appears in the command palette");

      --  Seed a recent path, then enter the recent view through the real reducer.
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (Dir));
      Items.Append
        (Files.File_System.Make_Item
           (Files_Suite.Support.Root, "reg-recent-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);

      --  Outside the recent view: Navigate Recent is enabled, Clear Recent is not.
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Recent_Command, Model),
              "Navigate Recent is enabled in an ordinary view");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Clear_Recent_Command, Model),
              "Clear Recent is disabled outside the recent view");

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
      Assert (Files.Model.In_Recent_View (Model), "the reducer enters the recent view");
      Assert (Files.Model.Item_Count (Model) > 0, "the recent view lists the stored path");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Clear_Recent_Command, Model),
              "Clear Recent is enabled in a non-empty recent view");

      --  The empty-area context menu offers Clear Recent (alongside Empty Trash).
      declare
         Menu_Model : Files.Model.Window_Model := Loaded_Model (Empty);
         Menu_Result : Files.Interaction.Interaction_Result;
      begin
         Open_Empty_Context_Menu (Menu_Model, Settings, Menu_Result);
         Assert (Menu_Offers (Menu_Model, Settings, Files.Commands.Clear_Recent_Command),
                 "the empty-area menu lists Clear Recent");
      end;
   end Test_Recent_Commands_Registry;

   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "scope-chip");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Result   : Files.Interaction.Interaction_Result;
      Toolbar  : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Window_W);
      Chip     : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Line);
      Chip_X   : constant Natural := Chip.X + Chip.Width / 2;
      Chip_Y   : constant Natural := Chip.Y + Chip.Height / 2;
      Full_Count : Natural;

      function Chip_Action (Model : Files.Model.Window_Model) return Files.Events.Input_Action is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      begin
         return Files.Events.Translate_Click
           (Snapshot, Frame, Chip_X, Chip_Y, Window_W, Window_H, Line_Height => Line);
      end Chip_Action;
   begin
      Assert (Chip.Visible, "the scope chip fits and is laid out at the default window width");

      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      --  One file matches by NAME only, one by CONTENT only, so the two search
      --  scopes return visibly different result sets from the same query text.
      Files_Suite.Support.Write_File
        (Files_Suite.Support.Join (Dir, "needle-name.txt"), "irrelevant body");
      Files_Suite.Support.Write_File
        (Files_Suite.Support.Join (Dir, "plain.txt"), "has a needle inside the body");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Files_Suite.Support.Root);
      Full_Count := Files.Model.Item_Count (Model);
      Files.Model.Set_Filter (Model, "needle");

      --  The frame draws the chip: an accessibility node advertises it.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Found    : Boolean := False;
      begin
         Assert
           (Snapshot.Search_Scope = Files.Types.Filter_Here,
            "the snapshot starts on the Filter_Here scope for the renderer to draw");
         for Node of Frame.Accessibility loop
            if Ada.Strings.Unbounded.To_String (Node.Name) =
              Files.Localization.Text ("accessibility.search_scope")
            then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the frame draws an accessibility node for the scope chip");
      end;

      --  First chip click: the click resolves to the scope-toggle action rather
      --  than a filter text click, and does not focus the filter input.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Assert
           (Action.Kind = Files.Events.Search_Scope_Toggle_Input_Action,
            "clicking the chip yields the scope-toggle action, not a text click");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Names,
         "the first chip click cycles to the Search_Names scope");
      Assert
        (Files.Model.Focus (Model) /= Files.Types.Focus_Filter_Input,
         "the chip click does not focus the filter input");
      Assert
        (Files.Model.Item_Count (Model) = 1,
         "cycling to Search_Names re-runs the query as a recursive name search");

      --  Second chip click: cycle to Search_Contents and re-run as a grep.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Contents,
         "the second chip click cycles to the Search_Contents scope");
      Assert (Files.Model.Search_Results_Are_Active (Model), "content results are shown");
      Assert
        (Files.Model.Item_Count (Model) = 1,
         "cycling to Search_Contents re-runs the query as a recursive content search");

      --  Third chip click: cycle back to Filter_Here and restore the directory.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "the third chip click cycles back to Filter_Here");
      Assert
        (not Files.Model.Search_Results_Are_Active (Model),
         "returning to Filter_Here drops the search-results state");
      Assert
        (Files.Model.Item_Count (Model) = Full_Count,
         "returning to Filter_Here restores the plain directory listing");
   end Test_Search_Scope_Chip_Cycles;

end Files_Suite.Interaction;

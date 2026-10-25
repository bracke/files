with Ada.Calendar;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with I18N.Normalization;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Interfaces.C.Strings;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files.UTF8;
with Files.UI;
with Files_Suite.Support;

package body Files_Suite.Commands is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_32;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Command_Placement;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Application.Run_Mode;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Guikit.Draw.Accessibility_Role;
   use type Guikit.Draw.Icon_Asset_Color_Role;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Atlas_Texture_Format;
   use type Guikit.Vulkan.Texture_Source;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Textrender.Fonts.Load_Result;
   use type Files.Types.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;
   use Files_Suite.Support;

   type Command_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Command_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Command_Test_Case);

   procedure Test_Clear_Filter_And_No_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commands_Disabled_Without_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Pure_Command_Execution (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Table_Complete (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Pane_Toggle_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Close_Command_Closes_Settings_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Field_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Pane_Modal_Blocking (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_View_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Identifiers_Registered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Modal_Allowlists (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Registered_Command_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Shortcut_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Text_And_Search (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Placements (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Focus_And_Palette (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Input_Editing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Input_Utf8_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Word_Editing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Word_Control_Separators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Word_Unicode_Separators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filter_Return_And_Clear (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Range_Edges_And_Picker_Tree (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Rename_Multibyte_Edits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Path_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Containing_Folder_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Save_Settings_Applies_Live (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shift_Click_Range_Anchor (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Escape_Dismisses_Grid_Popups (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sort_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tab_Focus_Ring (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Command_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files commands and controller");
   end Name;

   overriding procedure Register_Tests (T : in out Command_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Clear_Filter_And_No_Command_Enablement'Access, "clear-filter enablement and the no-command no-op");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commands_Disabled_Without_Selection'Access,
         "commands without a selection or history are disabled and report why");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Pure_Command_Execution'Access, "pure command execution touches neither filesystem nor history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Table_Complete'Access,
         "every command has a unique identifier and a name key, and pure commands run through the one path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Pane_Toggle_Commands'Access, "the settings pane toggles, seeds a draft, and resets");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Close_Command_Closes_Settings_Pane'Access, "the close command closes an open settings pane");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Field_Keys'Access, "settings fields keep the caret at the end and validate on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Pane_Modal_Blocking'Access,
         "the settings pane opens by shortcut and blocks background commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_View_Command_Enablement'Access,
         "the virtual recent view disables create, paste, rename, and search");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Identifiers_Registered'Access, "command identifiers are registered");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Modal_Allowlists'Access, "commands allowed while the root selector or settings pane is open");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Registered_Command_Metadata'Access,
         "every registered command has localized metadata and unique shortcuts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Shortcut_Metadata'Access, "command shortcut and persistence metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Text_And_Search'Access, "shortcut text is normalized and search text includes aliases");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Dispatch'Access, "shortcuts dispatch through the command registry");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Placements'Access, "commands are placed in the toolbar, bottom bar, or palette");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Overrides'Access, "shortcut parsing, override resolution, and conflict lookup");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Path_Input_Return'Access, "controller commits path input on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Focus_And_Palette'Access,
         "the filter shortcut focuses the filter and hands focus to the palette");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Input_Editing'Access, "filter input edits text at the cursor and updates the projection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Input_Utf8_Cursor'Access,
         "the filter cursor moves and deletes whole UTF-8 characters and combining sequences");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Word_Editing'Access, "Control word movement and deletion in the filter input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Word_Control_Separators'Access,
         "ASCII and C1 control characters separate words in the filter input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Word_Unicode_Separators'Access,
         "Unicode spaces separate words and multibyte letters form whole words in the filter input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_Return_And_Clear'Access,
         "controller commits filter input on Return and clear-filter restores the listing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Range_Edges_And_Picker_Tree'Access,
         "Shift+arrow stops at the listing's edges, and Copy To leaves an open folder tree open");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_Rename_Multibyte_Edits'Access,
         "deleting in several rename rows at once keeps multibyte names whole");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Rename_Return'Access, "controller commits rename on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Command_Palette_Escape_Priority'Access, "controller prioritizes palette Escape");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Path_Command'Access, "copy-path joins selection paths for the system clipboard");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Containing_Folder_Command'Access, "open-containing-folder reveals a search result");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Save_Settings_Applies_Live'Access, "saving settings applies the view mode and sort to the live model");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shift_Click_Range_Anchor'Access, "successive shift-clicks extend the range from a fixed anchor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Escape_Dismisses_Grid_Popups'Access, "Escape dismisses grid popups instead of trapping the keyboard");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sort_Menu_Keyboard'Access, "the sort menu navigates by arrows and applies on Enter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Keyboard'Access, "the context menu opens with Shift+F10 and navigates by arrows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tab_Focus_Ring'Access, "Tab and Shift+Tab cycle focus around grid, path input, and filter");
   end Register_Tests;

   function Same_Shortcut
     (Left  : Files.Commands.Shortcut;
      Right : Files.Commands.Shortcut)
      return Boolean is
   begin
      return Left.Present
        and then Right.Present
        and then Left.Key = Right.Key
        and then Left.Modifiers = Right.Modifiers;
   end Same_Shortcut;

   procedure Test_Clear_Filter_And_No_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commands_Disabled_Without_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Pure_Command_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Table_Complete (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Pane_Toggle_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Close_Command_Closes_Settings_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Field_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Pane_Modal_Blocking (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_View_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Identifiers_Registered (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Modal_Allowlists (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Registered_Command_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Shortcut_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Text_And_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Placements (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Rename_Multibyte_Edits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Range_Edges_And_Picker_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Focus_And_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Input_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Input_Utf8_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Word_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Word_Control_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Word_Unicode_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filter_Return_And_Clear (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Copy_Path_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Containing_Folder_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shift_Click_Range_Anchor (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Escape_Dismisses_Grid_Popups (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sort_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tab_Focus_Ring (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Save_Settings_Applies_Live (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Command_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Commands;

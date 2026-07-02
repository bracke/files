with Ada.Calendar;
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
with Files.Features;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Files.Rendering;
with Files.Rendering.Vulkan;
with Files.Settings;
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
   use type Files.Rendering.Accessibility_Role;
   use type Files.Rendering.Icon_Asset_Color_Role;
   use type Files.Rendering.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Rendering.Vulkan.Atlas_Texture_Format;
   use type Files.Rendering.Vulkan.Texture_Source;
   use type Files.Rendering.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.Key_Code;
   use type Files.Types.Modifier_Set;
   use type Files.Types.Navigation_Direction;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;
   use Files_Suite.Support;

   type Command_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Command_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Command_Test_Case);

   procedure Test_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Registry_And_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Search (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Toggle_Shortcut (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Filter_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Command_Palette_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Palette_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Disabled_Palette_Result (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Empty_Palette_Result (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Command_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files commands and controller");
   end Name;

   overriding procedure Register_Tests (T : in out Command_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Enablement'Access, "command enablement");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Registry_And_Shortcuts'Access, "command registry and shortcuts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Palette_Search'Access, "command palette search and disabled entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Palette_Toggle_Shortcut'Access, "command palette Control+P toggles");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Path_Input_Return'Access, "controller commits path input on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Filter_Input_Return'Access, "controller commits filter input on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Rename_Return'Access, "controller commits rename on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Command_Palette_Return'Access, "controller executes palette result on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Command_Palette_Escape_Priority'Access, "controller prioritizes palette Escape");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Palette_Selection_Movement'Access, "controller moves palette selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Disabled_Palette_Result'Access, "controller ignores disabled palette result");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Empty_Palette_Result'Access, "controller ignores empty palette result");
   end Register_Tests;

   procedure Test_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Empty    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Assert (not Files.Commands.Is_Enabled (Files.Commands.No_Command, Model), "no-command is never enabled");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Create_File_Command, Model), "create is enabled initially");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Focus_Filter_Input_Command, Model),
         "filter focus is enabled initially");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear filter is disabled without filter text");
      Result := Files.Controller.Execute_Command (Files.Commands.Clear_Filter_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled clear-filter command is ignored");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled clear-filter returns operation data");
      Assert (Files.Model.Last_Error_Key (Model) = "error.filter.empty", "disabled clear-filter records error");
      Files.Model.Set_Filter (Model, "alpha");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear filter is enabled with filter text");
      Result := Files.Controller.Execute_Command (Files.Commands.Clear_Filter_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Clear_Filter_Command, "clear-filter command is reported");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "enabled clear-filter reports successful state-only operation");
      Assert (Files.Model.Filter_Text (Model) = "", "clear-filter command clears filter text");
      Model := Sample_Model;
      Files.Commands.Execute (Files.Commands.No_Command, Model);
      Assert (Files.Model.Current_Path (Model) = Root, "direct no-command execution does not change path");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons, "direct no-command execution preserves view");

      Assert (not Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "back disabled initially");
      Files.Commands.Execute (Files.Commands.Navigate_Back_Command, Model);
      Assert (Files.Model.Current_Path (Model) = Root, "direct disabled back command does not change path");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled back command is ignored");
      Assert (Result.Operation.Status = Files.Operations.Operation_Disabled, "disabled back returns operation data");
      Assert (Files.Model.Last_Error_Key (Model) = "error.history.back_unavailable", "disabled back records error");
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled back click is ignored");
      Assert (Result.Command = Files.Commands.Navigate_Back_Command, "disabled back click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled back click returns operation data");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "delete disabled with no selection");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink disabled with no selection");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link disabled with no selection");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Deselect_All_Command, Model),
         "deselect-all disabled with nothing selected");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Invert_Selection_Command, Model),
         "invert-selection enabled with visible items");
      Files.Model.Select_All_Visible (Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Deselect_All_Command, Model),
         "deselect-all enabled with a non-empty selection");
      Files.Model.Clear_Selection (Model);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Undo_Command, Model),
         "undo disabled with no recorded history");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Redo_Command, Model),
         "redo disabled with no recorded history");
      --  The info pane can always be toggled, even with nothing selected: an
      --  empty selection simply shows an empty pane.
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Toggle_Info_Pane_Command, Model),
         "info toggle enabled with no selection");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "info toggle executes with no selection");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info toggle opens the info pane with no selection");
      --  Restore the closed state so later assertions see no transient panes.
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second info toggle closes the pane again");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled delete command is ignored");
      Assert (Result.Operation.Status = Files.Operations.Operation_Disabled, "disabled delete returns operation data");
      Assert (Files.Model.Last_Error_Key (Model) = "error.selection.empty", "disabled delete records error");
      Result := Files.Controller.Execute_Command (Files.Commands.Rename_Selected_Items_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled rename command is ignored");
      Assert (Result.Operation.Status = Files.Operations.Operation_Disabled, "disabled rename returns operation data");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.disabled", "disabled rename records error");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel disabled with no transient state");
      Files.Model.Focus_Path_Input (Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while path input has focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "drive selector command is controller-routed");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "drive selector reports successful state-only operation");
      Assert (Files.Model.Last_Error_Key (Model) = "", "drive selector clears stale error state");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while root selector is open");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Model := Sample_Model;
      Files.Commands.Execute (Files.Commands.Select_Drive_Command, Model);
      Assert
        (not Files.Model.Root_Selector_Is_Open (Model),
         "pure drive selector command does not inspect filesystem roots");
      Files.Commands.Execute (Files.Commands.Create_File_Command, Model);
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "pure create command does not inspect filesystem names");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Commands.Execute (Files.Commands.Select_Details_Command, Model);
      Assert
        (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons,
         "pure command execution respects root-selector modal disablement");
      Files.Commands.Execute (Files.Commands.Close_Command_Palette_Command, Model);
      Assert
        (not Files.Model.Root_Selector_Is_Open (Model),
         "pure context cancel can close root selector");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/direct-next", Empty);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "direct back can be enabled");
      Files.Commands.Execute (Files.Commands.Navigate_Back_Command, Model);
      Assert
        (Files.Model.Current_Path (Model) = "/tmp/files_aunit/direct-next",
         "pure back command does not reload or navigate history");
      Files.Commands.Execute (Files.Commands.Navigate_Forward_Command, Model);
      Assert
        (Files.Model.Current_Path (Model) = "/tmp/files_aunit/direct-next",
         "pure forward command does not reload or navigate history");
      Model := Sample_Model;
      Files.Model.Move_Selection (Model, Files.Types.Move_Right);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "delete enabled with selection");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Toggle_Info_Pane_Command, Model),
         "info toggle enabled with selection");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink enabled with a selection in a real directory");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link enabled with a selection in a real directory");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Open_Terminal_Command, Model),
         "open-terminal enabled in a real directory");
      Files.Commands.Execute (Files.Commands.Open_Selected_Items_Command, Model);
      Assert
        (Files.Model.Current_Path (Model) = Root,
         "pure open command does not load selected items");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "rename enabled with one selected item");
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Close_Command_Palette_Command, Model),
         "context cancel enabled while rename is active");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Toggle_Settings_Pane_Command, Model),
         "settings pane command is enabled in the normal model state");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "pure settings command does not open unseeded settings pane");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model),
         "save settings is disabled without settings pane");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model),
         "reset settings is disabled without settings pane");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "controller opens settings pane with editable draft");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "settings toggle reports successful state-only operation");
      Assert
        (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input,
         "settings pane receives editable settings focus");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Files.Model.Begin_Create_File (Model, "settings-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "settings.toggle");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert
        (Files.Model.Settings_Pane_Is_Open (Model),
         "controller opens settings pane over pending create");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "settings pane opening clears pending create state");
      Assert
        (not Files.Model.Rename_Is_Active (Model),
         "settings pane opening clears pending rename state");
      Assert
        (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input,
         "settings pane opening focuses settings after clearing edit state");
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "pure settings command can close seeded settings pane");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "controller reopens settings pane with editable draft");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model), "save settings is enabled");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model), "reset settings is enabled");
      Files.Controller.Replace_Focused_Text (Model, "details");
      Assert (Files.Model.Settings_Field_Text (Model) = "details", "settings draft field is editable");
      Result := Files.Controller.Execute_Command (Files.Commands.Reset_Settings_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Reset_Settings_Command, "reset settings command is reported");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "reset settings reports success");
      Assert
        (Files.Model.Settings_Field_Text (Model) = "small_icons",
         "reset settings restores default draft view mode");
      Result := Files.Controller.Execute_Command (Files.Commands.Save_Settings_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Save_Settings_Command, "pure save settings command is reported");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "pure save settings command keeps runtime path-resolution sentinel");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 1, Option => 2);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "settings option click saves the changed setting");
      Assert
        (Result.Command = Files.Commands.Save_Settings_Command,
         "settings option click reports the save command");
      Assert (Files.Model.Settings_Field_Text (Model) = "large_icons", "settings option click updates scalar value");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 1, Option => 2);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "repeated settings option click still saves");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 3, Option => 5);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "sort field accepts the fifth (created) option");
      Assert
        (Files.Model.Settings_Field_Text (Model) = "created",
         "sort option 5 selects the created sort field");
      Files.Model.Set_Settings_Field_Index (Model, 7);
      Files.Model.Set_Settings_Field_Text (Model, "32");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 7, Option => 151);
      Assert
        (Result.Status = Files.Controller.Controller_Ignored,
         "font-size stepper at its max bound is a no-op");
      Assert (Files.Model.Settings_Field_Text (Model) = "32", "font stepper at max keeps the value");
      Files.Model.Set_Settings_Field_Text (Model, "16");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 7, Option => 151);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "font-size stepper below max increments and saves");
      Assert (Files.Model.Settings_Field_Text (Model) = "17", "font stepper increments the value");
      Files.Model.Set_Settings_Field_Index (Model, 2);
      Files.Controller.Replace_Focused_Text (Model, "true");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 2, Option => 4);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "unsupported settings option is ignored");
      Assert
        (Files.Model.Settings_Field_Text (Model) = "true",
         "unsupported settings option does not mutate boolean setting");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 99);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "unsupported settings field is ignored");
      Assert (Files.Model.Settings_Field_Index (Model) = 2, "unsupported settings field does not clamp focus");
      Assert
        (Files.Model.Settings_Field_Text (Model) = "true",
         "unsupported settings field does not mutate settings text");
      Files.Model.Set_Settings_Field_Index (Model, 6);
      Files.Controller.Replace_Focused_Text (Model, "ab");
      Files.Model.Set_Text_Cursor_Position (Model, 1);
      declare
         Utf8_Text : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Draft     : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Draft.Icon_Theme_Name := To_Unbounded_String (Utf8_Text);
         Files.Model.Set_Settings_Draft (Model, Draft);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "settings draft replacement snaps stale UTF-8 cursor to character boundary");
         Draft.Icon_Theme_Name := To_Unbounded_String ("files-basic");
         Files.Model.Set_Settings_Draft (Model, Draft);
      end;
      Files.Model.Set_Settings_Field_Index (Model, 2);
      declare
         Old_Mapping_Count : constant Natural :=
           Natural (Files.Model.Settings_Draft_Of (Model).Filetype_Keys.Length);
      begin
         Result := Files.Controller.Handle_Settings_Click (Model, Field => 8, Option => 100);
         Assert
           (Result.Status = Files.Controller.Controller_Command_Executed,
            "settings value-field add click executes");
         Assert
           (Result.Command = Files.Commands.Save_Settings_Command,
            "settings value-field add click reports the save command");
         Assert
           (Files.Model.Settings_Field_Index (Model) = 8,
            "settings value-field add click moves focus to the clicked field");
         Assert
           (Natural (Files.Model.Settings_Draft_Of (Model).Filetype_Keys.Length) = Old_Mapping_Count + 1,
            "settings value-field add click creates a mapping row");
         Result := Files.Controller.Handle_Settings_Click (Model, Field => 8, Option => 101);
         Assert
           (Result.Status = Files.Controller.Controller_Command_Executed,
            "settings value-field remove click executes");
         Assert
           (Result.Command = Files.Commands.Save_Settings_Command,
            "settings value-field remove click reports the save command");
         Assert
           (Natural (Files.Model.Settings_Draft_Of (Model).Filetype_Keys.Length) = Old_Mapping_Count,
            "settings value-field remove click drops the added mapping row");
      end;
      Files.Model.Set_Settings_Field_Index (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_S, Ctrl);
      Assert (Result.Command = Files.Commands.Save_Settings_Command, "control+s routes settings save command");
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "control+s reports settings save command execution for runtime persistence");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_N, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "scalar settings field ignores add-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
      Assert
        (Result.Status = Files.Controller.Controller_Ignored,
         "scalar settings field ignores remove-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "scalar settings field ignores entry paging");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Files.Model.Settings_Field_Index (Model) = 2, "down moves to next settings field");
      Files.Model.Set_Settings_Field_Index (Model, 12);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Files.Model.Settings_Field_Index (Model) = 13, "down reaches the final settings field (13)");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Files.Model.Settings_Field_Index (Model) = 1, "down from the final settings field wraps to first");
      Files.Model.Set_Settings_Field_Index (Model, 2);
      Files.Controller.Replace_Focused_Text (Model, "maybe");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Failed,
         "invalid settings field Return reports validation failure");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.settings.invalid_boolean",
         "invalid settings field Return reports diagnostic key");
      Files.Controller.Replace_Focused_Text (Model, "true");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "valid settings field Return reports validation success");
      Assert (Files.Model.Last_Error_Key (Model) = "", "valid settings draft field validates on Return");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "controller closes settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Comma, Ctrl);
      Assert (Result.Command = Files.Commands.Toggle_Settings_Pane_Command, "control+comma routes settings command");
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma opens settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Comma, Ctrl);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "control+comma closes open settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Comma, Ctrl);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma reopens settings pane");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "Escape closes unfocused settings pane");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "closed settings text click is ignored");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed settings text click does not focus input");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "settings.toggle");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens from palette state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "settings pane opening closes command palette");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "settings pane opening clears palette query");
      Assert (not Files.Model.Rename_Is_Active (Model), "settings pane opening clears active rename state");
      Assert
        (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input,
         "settings pane opening moves focus to settings input");
      Files.Model.Select_Visible (Model, 1);
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Save_Settings_Command),
         "settings pane allowlist includes save");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Delete_Selected_Items_Command),
         "settings pane allowlist excludes background delete");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "settings pane disables background delete command");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
         "settings pane disables background open command");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model),
         "settings pane keeps save command enabled");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Open_Command_Palette_Command, Model),
         "settings pane keeps palette command enabled");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background delete command");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.path.missing",
         "settings modal block preserves existing error");
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background item click");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input, "blocked item click keeps settings focus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background path text click");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input, "blocked text click keeps settings focus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "settings pane accepts settings text click");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after focus Escape");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "settings Escape clears settings focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane reopens after Escape close check");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert (Files.Model.Selected_Item (Model).Name = "Alpha.txt", "settings modal starts with stable selection");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background selection keys");
      Assert
        (Files.Model.Selected_Item (Model).Name = "Alpha.txt",
         "settings pane keeps background selection unchanged");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "settings pane can regain settings focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette can open over settings pane");
      Result := Files.Controller.Handle_Settings_Click (Model, Field => 1, Option => 3);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "palette blocks settings click behind overlay");
      Assert
        (Files.Model.Settings_Field_Text (Model) /= "details",
         "blocked settings click leaves settings field unchanged");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before history enablement check");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/next", Empty);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "back enabled after navigation");
   end Test_Command_Enablement;

   procedure Test_Command_Registry_And_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl          : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Alt           : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Shift         : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Ctrl_Shift    : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Small_Shortcut : Files.Commands.Shortcut;
      Drive_Shortcut : Files.Commands.Shortcut;
      Settings_Shortcut : Files.Commands.Shortcut;
      Empty_Shortcut : Files.Commands.Shortcut;
      Delete_Secondary : Files.Commands.Shortcut;
      Empty_Secondary : Files.Commands.Shortcut;

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
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Alt (Files.Types.Alt_Key) := True;
      Shift (Files.Types.Shift_Key) := True;
      Ctrl_Shift (Files.Types.Control_Key) := True;
      Ctrl_Shift (Files.Types.Shift_Key) := True;
      Assert (Files.Commands.Command_Count = 63, "all expected commands are registered");
      Assert (Files.Commands.Contains ("navigate.parent"), "navigate-parent command identifier is registered");
      Assert (Files.Commands.Contains ("favorite.toggle"), "favorite-toggle command identifier is registered");
      Assert
        (not Files.Commands.Contains ("bookmark.toggle"),
         "the renamed bookmark identifier is no longer registered");
      Assert
        (Files.Commands.Identifier (Files.Commands.Toggle_Favorite_Command) = "favorite.toggle",
         "the favorite command reports its renamed identifier");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Toggle_Favorite_Command),
         "the favorite command routes through the settings-path persistence seam");
      Assert (Files.Commands.Contains ("file.copy_to"), "copy-to command identifier is registered");
      Assert (Files.Commands.Contains ("file.move_to"), "move-to command identifier is registered");
      Assert (Files.Commands.Contains ("tree.toggle"), "toggle-folder-tree command identifier is registered");
      Assert (Files.Commands.Contains ("terminal.open"), "open-terminal command identifier is registered");
      Assert (Files.Commands.Contains ("link.symbolic"), "create-symlink command identifier is registered");
      Assert (Files.Commands.Contains ("link.hard"), "create-hard-link command identifier is registered");
      Assert (Files.Commands.Contains ("file.compress_zip"), "compress-zip command identifier is registered");
      Assert (Files.Commands.Contains ("file.compress_7z"), "compress-7z command identifier is registered");
      Assert (Files.Commands.Contains ("view.small"), "stable command identifier is registered");
      Assert (Files.Commands.Contains ("settings.toggle"), "settings command identifier is registered");
      Assert (Files.Commands.Contains ("sort.menu.toggle"), "sort menu command identifier is registered");
      Assert (Files.Commands.Contains ("sort.name"), "sort by name command identifier is registered");
      Assert (Files.Commands.Contains ("sort.size"), "sort by size command identifier is registered");
      Assert (Files.Commands.Contains ("sort.type"), "sort by type command identifier is registered");
      Assert (Files.Commands.Contains ("sort.created"), "sort by created command identifier is registered");
      Assert (Files.Commands.Contains ("sort.changed"), "sort by changed command identifier is registered");
      Assert (Files.Commands.Contains ("selection.select_all"), "select-all command identifier is registered");
      Assert (Files.Commands.Contains ("selection.invert"), "invert-selection command identifier is registered");
      Assert
        (Files.Commands.Contains ("selection.deselect_all"),
         "deselect-all command identifier is registered");
      Assert (Files.Commands.Contains ("settings.save"), "settings save command identifier is registered");
      Assert (Files.Commands.Contains ("settings.reset"), "settings reset command identifier is registered");
      Assert (Files.Commands.Contains ("drive.eject_selected"), "drive eject command identifier is registered");
      Assert
        (Files.Commands.Contains ("file.delete_permanently"),
         "permanent delete command identifier is registered");
      Assert
        (Files.Commands.Contains ("file.generate_thumbnails"),
         "thumbnail generation command identifier is registered");
      Assert
        (Files.Commands.Contains ("directory.search_recursive"),
         "recursive search command identifier is registered");
      Assert (not Files.Commands.Contains (""), "empty command identifier is not registered");
      Assert
        (Files.Commands.Placement_For (Files.Commands.No_Command) = Files.Commands.No_Placement,
         "no-command has no toolbar or palette placement");
      Assert
        (not Files.Commands.Requires_Settings_Path (Files.Commands.No_Command),
         "no-command does not require a settings path");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Select_Drive_Command),
         "drive selector is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Open_Selected_Root_Command),
         "selected-root activation is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Eject_Selected_Root_Command),
         "selected-root eject is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Open_Command_Palette_Command),
         "palette open is allowed while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Root_Selector (Files.Commands.Close_Command_Palette_Command),
         "palette close is allowed while root selector is open");
      Assert
        (not Files.Commands.Allowed_With_Root_Selector (Files.Commands.Toggle_Settings_Pane_Command),
         "settings pane is blocked while root selector is open");
      Assert
        (not Files.Commands.Allowed_With_Root_Selector (Files.Commands.Delete_Selected_Items_Command),
         "delete is blocked while root selector is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Toggle_Settings_Pane_Command),
         "settings toggle is allowed while settings pane is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Open_Command_Palette_Command),
         "palette open is allowed while settings pane is open");
      Assert
        (Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Close_Command_Palette_Command),
         "palette close is allowed while settings pane is open");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Select_Drive_Command),
         "drive selector is blocked while settings pane is open");
      Assert
        (not Files.Commands.Allowed_With_Settings_Pane (Files.Commands.Navigate_Back_Command),
         "background navigation is blocked while settings pane is open");
      Assert
        (not Files.Commands.Command_Palette_Visible (Files.Commands.No_Command),
         "no-command is hidden from the command palette");
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Identifier : constant String := Files.Commands.Identifier (Id);
            Key        : constant String := Files.Commands.Name_Key (Id);
            Description_Key : constant String := Files.Commands.Description_Key (Id);
            Text       : constant String := Files.Localization.Text (Key);
            Description : constant String := Files.Localization.Text (Description_Key);
            Primary    : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Id);
            Secondary  : constant Files.Commands.Shortcut := Files.Commands.Secondary_Shortcut_For (Id);
            Placement  : constant Files.Commands.Command_Placement := Files.Commands.Placement_For (Id);
         begin
            Assert (Identifier /= "", "registered command identifier is non-empty");
            Assert (Files.Commands.Contains (Identifier), "registered command is found by its identifier");
            Assert (Key /= "", "registered command name key is non-empty");
            Assert (Text /= Key, "command localization exists for " & Identifier);
            Assert (Description_Key /= "", "registered command description key is non-empty");
            Assert (Description /= Description_Key, "command description localization exists for " & Identifier);
            Assert (Placement /= Files.Commands.No_Placement, "registered command has placement metadata");
            Assert
              (Files.Commands.Command_Palette_Visible (Id),
               "registered command is command-palette visible");
            Assert
              (Files.Commands.Allowed_With_Settings_Pane (Id) or else not Files.Commands.Requires_Settings_Path (Id),
               "settings-path commands are allowed while settings pane is open");
            if Primary.Present then
               Assert (Primary.Key /= Files.Types.Key_Unknown, "present primary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Primary) /= "",
                  "present primary shortcut has searchable text");
               Assert
                 (Files.Commands.Find_By_Shortcut (Primary.Key, Primary.Modifiers) = Id,
                  "present primary shortcut routes back to command");
            else
               Assert (Primary.Key = Files.Types.Key_Unknown, "absent primary shortcut has unknown key");
               Assert
                 (Files.Commands.Shortcut_Text (Primary) = "",
                  "absent primary shortcut has no searchable text");
            end if;
            if Secondary.Present then
               Assert (Secondary.Key /= Files.Types.Key_Unknown, "present secondary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Secondary) /= "",
                  "present secondary shortcut has searchable text");
               Assert
                 (Files.Commands.Find_By_Shortcut (Secondary.Key, Secondary.Modifiers) = Id,
                  "present secondary shortcut routes back to command");
            else
               Assert (Secondary.Key = Files.Types.Key_Unknown, "absent secondary shortcut has unknown key");
               Assert
                 (Files.Commands.Shortcut_Text (Secondary) = "",
                  "absent secondary shortcut has no searchable text");
            end if;
            if Id /= Files.Commands.Registered_Command_Id'First then
               for Previous in Files.Commands.Registered_Command_Id'First .. Files.Commands.Command_Id'Pred (Id) loop
                  Assert
                    (Files.Commands.Identifier (Previous) /= Identifier,
                     "registered command identifier is unique");
                  declare
                     Shortcut : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Id);
                     Secondary : constant Files.Commands.Shortcut := Files.Commands.Secondary_Shortcut_For (Id);
                     Previous_Shortcut : constant Files.Commands.Shortcut :=
                       Files.Commands.Shortcut_For (Previous);
                     Previous_Secondary : constant Files.Commands.Shortcut :=
                       Files.Commands.Secondary_Shortcut_For (Previous);
                  begin
                     Assert
                       (not Same_Shortcut (Shortcut, Secondary),
                        "registered command primary and secondary shortcuts do not collide");
                     Assert
                       (not Same_Shortcut (Shortcut, Previous_Shortcut),
                        "registered command primary shortcut is unique");
                     Assert
                       (not Same_Shortcut (Shortcut, Previous_Secondary),
                        "registered command primary shortcut does not collide with previous secondary");
                     Assert
                       (not Same_Shortcut (Secondary, Previous_Shortcut),
                        "registered command secondary shortcut does not collide with previous primary");
                     Assert
                       (not Same_Shortcut (Secondary, Previous_Secondary),
                        "registered command secondary shortcut is unique");
                  end;
               end loop;
            end if;
         end;
      end loop;
      Small_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command);
      Assert (Small_Shortcut.Present, "shortcut metadata marks small-icons shortcut present");
      Assert (Small_Shortcut.Key = Files.Types.Key_1, "shortcut metadata stores small-icons key");
      Assert (Small_Shortcut.Modifiers = Ctrl, "shortcut metadata stores small-icons modifiers");
      Drive_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Select_Drive_Command);
      Assert (Drive_Shortcut.Present, "drive selector exposes shortcut metadata");
      Assert (Drive_Shortcut.Key = Files.Types.Key_D, "drive selector shortcut uses D");
      Assert (Drive_Shortcut.Modifiers = Ctrl, "drive selector shortcut uses Control");
      Settings_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Toggle_Settings_Pane_Command);
      Assert (Settings_Shortcut.Present, "settings pane exposes shortcut metadata");
      Assert (Settings_Shortcut.Key = Files.Types.Key_Comma, "settings pane shortcut uses comma");
      Assert (Settings_Shortcut.Modifiers = Ctrl, "settings pane shortcut uses Control");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Toggle_Settings_Pane_Command) =
         Files.Commands.Command_Palette_Only,
         "settings command uses command-palette placement");
      Assert
        (Files.Commands.Description_Key (Files.Commands.Toggle_Settings_Pane_Command) =
         "command.settings.toggle.description",
         "settings command description key is stable");
      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Save_Settings_Command).Key = Files.Types.Key_S,
         "settings save command uses S shortcut metadata");
      Assert
        (not Files.Commands.Shortcut_For (Files.Commands.Reset_Settings_Command).Present,
         "settings reset command is palette-only");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Save_Settings_Command),
         "settings save requires a settings path");
      Assert
        (not Files.Commands.Requires_Settings_Path (Files.Commands.Reset_Settings_Command),
         "settings reset does not require a settings path");
      Empty_Shortcut := Files.Commands.Shortcut_For (Files.Commands.No_Command);
      Assert (not Empty_Shortcut.Present, "no-command exposes absent shortcut metadata");
      Empty_Secondary := Files.Commands.Secondary_Shortcut_For (Files.Commands.No_Command);
      Assert (not Empty_Secondary.Present, "no-command exposes absent secondary shortcut metadata");
      Delete_Secondary := Files.Commands.Secondary_Shortcut_For (Files.Commands.Delete_Selected_Items_Command);
      Assert (Delete_Secondary.Present, "delete command exposes secondary shortcut metadata");
      Assert (Delete_Secondary.Key = Files.Types.Key_Backspace, "delete secondary shortcut uses Backspace");
      Assert
        (Delete_Secondary.Modifiers = Files.Types.No_Modifiers,
         "delete secondary shortcut has no modifiers");
      Assert
        (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Files.Commands.Open_Command_Palette_Command)) =
         "control+p",
         "primary shortcut text is normalized");
      Assert
        (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Files.Commands.Toggle_Settings_Pane_Command)) =
         "control+,",
         "settings shortcut text includes comma");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "delete") = 1,
         "command shortcut search text keeps canonical delete shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "del") > 0,
         "command shortcut search text includes delete shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "backspace") > 0,
         "command shortcut search text includes secondary shortcuts");
      Assert
        (Files.Commands.Shortcut_Text
           (Files.Commands.Shortcut_For (Files.Commands.Delete_Selected_Permanently_Command)) =
         "shift+delete",
         "permanent delete shortcut text is normalized");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Permanently_Command),
            "shift+delete") = 1,
         "permanent delete shortcut search text keeps canonical shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Command_Palette_Command),
            "control+p") = 1,
         "command shortcut search text keeps canonical primary shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Command_Palette_Command),
            "ctrl+p") > 0,
         "command shortcut search text includes control shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Navigate_Back_Command),
            "option+left") > 0,
         "command shortcut search text includes option shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Close_Command_Palette_Command),
            "esc") > 0,
         "command shortcut search text includes escape shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Selected_Items_Command),
            "enter") > 0,
         "command shortcut search text includes return shortcut alias");
      Assert
        (Files.Commands.Shortcut_Search_Text (Files.Commands.No_Command) = "",
         "no-command has no shortcut search text");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_1, Ctrl) = Files.Commands.Select_Small_Icons_Command,
         "control+1 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_2, Ctrl) = Files.Commands.Select_Large_Icons_Command,
         "control+2 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_3, Ctrl) = Files.Commands.Select_Details_Command,
         "control+3 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_4, Ctrl) = Files.Commands.Toggle_Info_Pane_Command,
         "control+4 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Comma, Ctrl) =
         Files.Commands.Toggle_Settings_Pane_Command,
         "control+comma dispatches settings pane command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_L, Ctrl) = Files.Commands.Focus_Path_Input_Command,
         "control+l dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Home, Alt) = Files.Commands.Navigate_Home_Command,
         "alt+home dispatches home command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Left, Alt) = Files.Commands.Navigate_Back_Command,
         "alt+left dispatches back command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Right, Alt) = Files.Commands.Navigate_Forward_Command,
         "alt+right dispatches forward command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Up, Alt) = Files.Commands.Navigate_Parent_Command,
         "alt+up dispatches parent command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Up, Files.Types.No_Modifiers) =
           Files.Commands.No_Command,
         "plain up is not a command shortcut so grid navigation keeps it");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_N, Ctrl) = Files.Commands.Create_File_Command,
         "control+n dispatches create-file command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_A, Ctrl) = Files.Commands.Select_All_Command,
         "control+a dispatches select-all command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_P, Ctrl) = Files.Commands.Open_Command_Palette_Command,
         "control+p dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_F, Ctrl) = Files.Commands.Focus_Filter_Input_Command,
         "control+f dispatches filter focus command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_D, Ctrl) = Files.Commands.Select_Drive_Command,
         "control+d dispatches drive selector command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_F, Ctrl_Shift) = Files.Commands.Clear_Filter_Command,
         "control+shift+f dispatches clear-filter command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_R, Ctrl) = Files.Commands.Refresh_Directory_Command,
         "control+r dispatches refresh command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_S, Ctrl) = Files.Commands.Save_Settings_Command,
         "control+s dispatches settings save command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Delete, Files.Types.No_Modifiers) =
           Files.Commands.Delete_Selected_Items_Command,
         "delete dispatches delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Backspace, Files.Types.No_Modifiers) =
           Files.Commands.Delete_Selected_Items_Command,
         "backspace dispatches delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Delete, Shift) =
           Files.Commands.Delete_Selected_Permanently_Command,
         "shift+delete dispatches permanent delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_F2, Files.Types.No_Modifiers) =
           Files.Commands.Rename_Selected_Items_Command,
         "F2 dispatches rename command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Escape, Files.Types.No_Modifiers) =
           Files.Commands.Close_Command_Palette_Command,
         "escape dispatches context-cancel command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Return, Files.Types.No_Modifiers) =
           Files.Commands.Open_Selected_Items_Command,
         "return dispatches open-selected command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Z, Ctrl) = Files.Commands.Undo_Command,
         "Ctrl+Z dispatches the undo command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_Z, Ctrl_Shift) = Files.Commands.Redo_Command,
         "Ctrl+Shift+Z dispatches the redo command distinct from undo");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Select_Drive_Command) = Files.Commands.Toolbar_Left,
         "drive selector is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Navigate_Home_Command) = Files.Commands.Toolbar_Left,
         "home command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Navigate_Back_Command) = Files.Commands.Toolbar_Left,
         "back command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Navigate_Forward_Command) = Files.Commands.Toolbar_Left,
         "forward command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Navigate_Parent_Command) = Files.Commands.Toolbar_Left,
         "parent command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Create_File_Command) = Files.Commands.Toolbar_Left,
         "create-file command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Delete_Selected_Items_Command) = Files.Commands.Toolbar_Left,
         "delete command is placed in left toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Focus_Path_Input_Command) = Files.Commands.Toolbar_Middle,
         "path input command is placed in middle toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Focus_Filter_Input_Command) = Files.Commands.Toolbar_Right,
         "filter input command is placed in right toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Clear_Filter_Command) = Files.Commands.Toolbar_Right,
         "clear-filter command is placed in right toolbar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Refresh_Directory_Command) =
           Files.Commands.Command_Palette_Only,
         "refresh command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Select_Small_Icons_Command) = Files.Commands.Bottom_Bar,
         "small view command is placed in bottom bar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Select_Large_Icons_Command) = Files.Commands.Bottom_Bar,
         "large view command is placed in bottom bar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Select_Details_Command) = Files.Commands.Bottom_Bar,
         "view mode command is placed in bottom bar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Toggle_Info_Pane_Command) = Files.Commands.Bottom_Bar,
         "info-pane command is placed in bottom bar");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Rename_Selected_Items_Command) =
           Files.Commands.Command_Palette_Only,
         "rename command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Open_Selected_Items_Command) =
           Files.Commands.Command_Palette_Only,
         "open-selected command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Select_All_Command) =
           Files.Commands.Command_Palette_Only,
         "select-all command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Invert_Selection_Command) =
           Files.Commands.Placement_For (Files.Commands.Select_All_Command),
         "invert-selection placement matches select-all");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Deselect_All_Command) =
           Files.Commands.Placement_For (Files.Commands.Select_All_Command),
         "deselect-all placement matches select-all");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Invert_Selection_Command),
            (True, Files.Types.Key_I, Ctrl)),
         "invert-selection uses Control+I");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Deselect_All_Command),
            (True, Files.Types.Key_A, Ctrl_Shift)),
         "deselect-all uses Control+Shift+A");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_I, Ctrl) = Files.Commands.Invert_Selection_Command,
         "Control+I resolves to invert-selection command");
      Assert
        (Files.Commands.Find_By_Shortcut (Files.Types.Key_A, Ctrl_Shift) = Files.Commands.Deselect_All_Command,
         "Control+Shift+A resolves to deselect-all command");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Delete_Selected_Permanently_Command) =
           Files.Commands.Command_Palette_Only,
         "permanent delete command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Generate_Thumbnails_Command) =
           Files.Commands.Command_Palette_Only,
         "thumbnail generation command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Search_Recursive_Command) =
           Files.Commands.Command_Palette_Only,
         "recursive search command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Close_Command_Palette_Command) =
           Files.Commands.Command_Palette_Only,
         "context-close command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Open_Selected_Root_Command) =
           Files.Commands.Command_Palette_Only,
         "open-selected-root command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Eject_Selected_Root_Command) =
           Files.Commands.Command_Palette_Only,
         "eject-selected-root command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Open_Command_Palette_Command) =
           Files.Commands.Command_Palette_Only,
         "palette toggle is not duplicated in toolbar metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Reset_Settings_Command) =
           Files.Commands.Command_Palette_Only,
         "settings reset command is palette-only metadata");
      Assert
        (Files.Commands.Placement_For (Files.Commands.Save_Settings_Command) =
           Files.Commands.Command_Palette_Only,
         "settings save command is palette-only metadata");
   end Test_Command_Registry_And_Shortcuts;

   procedure Test_Command_Palette_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model          : Files.Model.Window_Model := Sample_Model;
      Small_Results  : Files.Command_Palette.Result_Vectors.Vector;
      Rename_Results : Files.Command_Palette.Result_Vectors.Vector;
      Create_Results : Files.Command_Palette.Result_Vectors.Vector;
      Clear_Results  : Files.Command_Palette.Result_Vectors.Vector;
      Mixed_Results  : Files.Command_Palette.Result_Vectors.Vector;
      Exact_Results  : Files.Command_Palette.Result_Vectors.Vector;
      Description_Results : Files.Command_Palette.Result_Vectors.Vector;
      Shortcut_Results : Files.Command_Palette.Result_Vectors.Vector;
      All_Results    : Files.Command_Palette.Result_Vectors.Vector;
      Long_Query      : Unbounded_String;
      Long_Results    : Files.Command_Palette.Result_Vectors.Vector;
      Found_Disabled : Boolean := False;
      Found_Rename_Enabled : Boolean := False;
      Found_Create_Disabled : Boolean := False;
      Found_Clear    : Boolean := False;
      Found_Clear_Disabled : Boolean := False;
      Found_Root_Open_Disabled : Boolean := False;
      Found_Root_Open_Enabled : Boolean := False;
      Found_Root_Eject_Disabled : Boolean := False;
      Found_Root_Eject_Enabled : Boolean := False;
      Found_Root_Blocked_Path : Boolean := False;
      Found_Root_Drive_Enabled : Boolean := False;
      Found_Reset_Disabled : Boolean := False;
      Found_Reset_Enabled  : Boolean := False;
      Found_Settings_Delete_Disabled : Boolean := False;
   begin
      All_Results := Files.Command_Palette.Search ("", Model);
      Assert
        (Natural (All_Results.Length) = Files.Commands.Command_Count,
         "empty palette search returns every registered command");
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Index : constant Positive :=
              Positive (Files.Commands.Command_Id'Pos (Id) - Files.Commands.Command_Id'Pos
                (Files.Commands.Registered_Command_Id'First) + 1);
         begin
            Assert (All_Results.Element (Index).Command = Id, "empty palette search preserves registry order");
            Assert
              (To_String (All_Results.Element (Index).Identifier) = Files.Commands.Identifier (Id),
               "empty palette search exposes stable command identifiers");
            Assert
              (To_String (All_Results.Element (Index).Description) =
                 Files.Localization.Text (Files.Commands.Description_Key (Id)),
               "empty palette search exposes localized command descriptions");
         end;
      end loop;
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Identifier_Results : constant Files.Command_Palette.Result_Vectors.Vector :=
              Files.Command_Palette.Search (Files.Commands.Identifier (Id), Model);
            Label_Results      : constant Files.Command_Palette.Result_Vectors.Vector :=
              Files.Command_Palette.Search
                (Files.Localization.Text (Files.Commands.Name_Key (Id)), Model);
            Found_By_Identifier : Boolean := False;
            Found_By_Label      : Boolean := False;
         begin
            for Result_Item of Identifier_Results loop
               if Result_Item.Command = Id then
                  Found_By_Identifier := True;
               end if;
            end loop;
            for Result_Item of Label_Results loop
               if Result_Item.Command = Id then
                  Found_By_Label := True;
               end if;
            end loop;
            Assert
              (Found_By_Identifier,
               "palette search finds every command by stable identifier");
            Assert
              (Found_By_Label,
               "palette search finds every command by localized label");
         end;
      end loop;

      Small_Results := Files.Command_Palette.Search ("small", Model);
      Assert (Natural (Small_Results.Length) >= 1, "palette search matches localized command labels");
      Assert
        (Small_Results.Element (1).Command = Files.Commands.Select_Small_Icons_Command,
         "small-icons command is returned");
      Assert
        (To_String (Small_Results.Element (1).Description) =
           Files.Localization.Text ("command.view.small.description"),
         "palette result carries localized command description");
      Assert (Small_Results.Element (1).Score < Natural'Last, "palette result exposes finite match score");

      Exact_Results := Files.Command_Palette.Search ("view.details", Model);
      Assert (Natural (Exact_Results.Length) >= 1, "exact identifier palette search returns results");
      Assert
        (Exact_Results.Element (1).Command = Files.Commands.Select_Details_Command,
         "exact identifier palette search ranks exact identifier first");
      Assert
        (Exact_Results.Element (1).Score < Small_Results.Element (1).Score,
         "exact identifier palette search scores above localized label prefix search");

      Rename_Results := Files.Command_Palette.Search ("file.rename", Model);
      for Result_Item of Rename_Results loop
         if Result_Item.Command = Files.Commands.Rename_Selected_Items_Command and then not Result_Item.Enabled then
            Found_Disabled := True;
         end if;
      end loop;
      Assert (Found_Disabled, "disabled selection-dependent entries still appear");

      Files.Model.Begin_Create_File (Model, "pending.txt");
      Rename_Results := Files.Command_Palette.Search ("file.rename", Model);
      for Result_Item of Rename_Results loop
         if Result_Item.Command = Files.Commands.Rename_Selected_Items_Command and then Result_Item.Enabled then
            Found_Rename_Enabled := True;
         end if;
      end loop;
      Assert (Found_Rename_Enabled, "rename entry is enabled while temporary create rename is active");
      Create_Results := Files.Command_Palette.Search ("file.create", Model);
      for Result_Item of Create_Results loop
         if Result_Item.Command = Files.Commands.Create_File_Command and then not Result_Item.Enabled then
            Found_Create_Disabled := True;
         end if;
      end loop;
      Assert (Found_Create_Disabled, "create entry is disabled while temporary create item is active");
      Files.Model.Cancel_Create_File (Model);

      Clear_Results := Files.Command_Palette.Search ("filter.clear", Model);
      for Result_Item of Clear_Results loop
         if Result_Item.Command = Files.Commands.Clear_Filter_Command and then not Result_Item.Enabled then
            Found_Clear_Disabled := True;
         end if;
      end loop;
      Assert (Found_Clear_Disabled, "disabled clear-filter command still appears");

      Files.Model.Set_Filter (Model, "beta");
      Clear_Results := Files.Command_Palette.Search ("Clear Filter", Model);
      for Result_Item of Clear_Results loop
         if Result_Item.Command = Files.Commands.Clear_Filter_Command and then Result_Item.Enabled then
            Found_Clear := True;
         end if;
      end loop;
      Assert (Found_Clear, "palette search matches localized clear-filter label when enabled");

      for Result_Item of Files.Command_Palette.Search ("settings.reset", Model) loop
         if Result_Item.Command = Files.Commands.Reset_Settings_Command and then not Result_Item.Enabled then
            Found_Reset_Disabled := True;
         end if;
      end loop;
      Assert (Found_Reset_Disabled, "settings reset appears disabled when settings pane is closed");
      Files.Model.Begin_Settings_Edit (Model, Files.Settings.Make_Draft (Files.Settings.Default_Settings));
      for Result_Item of Files.Command_Palette.Search ("Reset Settings", Model) loop
         if Result_Item.Command = Files.Commands.Reset_Settings_Command and then Result_Item.Enabled then
            Found_Reset_Enabled := True;
         end if;
      end loop;
      Assert (Found_Reset_Enabled, "palette search matches localized reset-settings label when enabled");
      Files.Model.Select_Visible (Model, 1);
      for Result_Item of Files.Command_Palette.Search ("file.delete_selected", Model) loop
         if Result_Item.Command = Files.Commands.Delete_Selected_Items_Command and then not Result_Item.Enabled then
            Found_Settings_Delete_Disabled := True;
         end if;
      end loop;
      Assert (Found_Settings_Delete_Disabled, "settings pane disables background delete palette result");
      Files.Model.Toggle_Settings_Pane (Model);

      for Result_Item of Files.Command_Palette.Search ("drive.open_selected", Model) loop
         if Result_Item.Command = Files.Commands.Open_Selected_Root_Command and then not Result_Item.Enabled then
            Found_Root_Open_Disabled := True;
         end if;
      end loop;
      Assert (Found_Root_Open_Disabled, "root-open command appears disabled when selector is closed");
      for Result_Item of Files.Command_Palette.Search ("drive.eject_selected", Model) loop
         if Result_Item.Command = Files.Commands.Eject_Selected_Root_Command and then not Result_Item.Enabled then
            Found_Root_Eject_Disabled := True;
         end if;
      end loop;
      Assert (Found_Root_Eject_Disabled, "root-eject command appears disabled when selector is closed");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Root_Entries);
      for Result_Item of Files.Command_Palette.Search ("drive.open_selected", Model) loop
         if Result_Item.Command = Files.Commands.Open_Selected_Root_Command and then Result_Item.Enabled then
            Found_Root_Open_Enabled := True;
         end if;
      end loop;
      Assert (Found_Root_Open_Enabled, "root-open command appears enabled when selector has a root");
      declare
         Removable_Roots : Files.File_System.Root_Entry_Vectors.Vector;
      begin
         Removable_Roots.Append
           (Files.File_System.Root_Entry'
              (Path        => To_Unbounded_String ("/tmp/removable-root"),
               Label       => To_Unbounded_String ("root.mount|removable-root"),
               Kind        => Files.File_System.Root_Mount,
               Volume_Name => To_Unbounded_String ("removable-root"),
               Ready       => Files.File_System.Root_Ready,
               Removable   => True));
         Files.Model.Open_Root_Selector (Model, Removable_Roots);
      end;
      for Result_Item of Files.Command_Palette.Search ("Eject Selected Drive", Model) loop
         if Result_Item.Command = Files.Commands.Eject_Selected_Root_Command and then Result_Item.Enabled then
            Found_Root_Eject_Enabled := True;
         end if;
      end loop;
      Assert (Found_Root_Eject_Enabled, "root-eject command appears enabled for removable roots");
      for Result_Item of Files.Command_Palette.Search ("path.focus", Model) loop
         if Result_Item.Command = Files.Commands.Focus_Path_Input_Command and then not Result_Item.Enabled then
            Found_Root_Blocked_Path := True;
         end if;
      end loop;
      Assert (Found_Root_Blocked_Path, "root selector disables background palette commands");
      for Result_Item of Files.Command_Palette.Search ("drive.select", Model) loop
         if Result_Item.Command = Files.Commands.Select_Drive_Command and then Result_Item.Enabled then
            Found_Root_Drive_Enabled := True;
         end if;
      end loop;
      Assert (Found_Root_Drive_Enabled, "root selector keeps drive command enabled");
      Files.Model.Close_Root_Selector (Model);

      Mixed_Results := Files.Command_Palette.Search ("NaViGaTe.BaCk", Model);
      Assert (Natural (Mixed_Results.Length) = 1, "palette search matches identifiers case-insensitively");
      Assert
        (Mixed_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "mixed-case identifier search returns the matching command");

      Description_Results := Files.Command_Palette.Search ("previous directory", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search matches localized command descriptions");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "description search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search matches description terms independently");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "description token search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory" & ASCII.HT & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats tabs as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "tab-separated description search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory" & ASCII.LF & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats line feeds as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "line-feed-separated description search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory" & ASCII.CR & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats carriage returns as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "carriage-return-separated description search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory" & ASCII.VT & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats vertical tabs as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "vertical-tab-separated description search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("directory" & ASCII.FF & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats form feeds as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "form-feed-separated description search returns the matching command");
      Description_Results :=
        Files.Command_Palette.Search ("directory" & Character'Val (133) & "previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search treats C1 next-line controls as token separators");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "C1 next-line-separated description search returns the matching command");
      declare
         NBSP : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
         Line_Separator : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
      begin
         Description_Results := Files.Command_Palette.Search ("directory" & NBSP & "previous", Model);
         Assert
           (Natural (Description_Results.Length) = 1,
            "palette search treats UTF-8 NBSP as a token separator");
         Assert
           (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
            "UTF-8 NBSP-separated description search returns the matching command");
         Description_Results := Files.Command_Palette.Search ("directory" & Line_Separator & "previous", Model);
         Assert
           (Natural (Description_Results.Length) = 1,
            "palette search treats UTF-8 line separator as a token separator");
         Assert
           (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
            "UTF-8 line-separator description search returns the matching command");
      end;
      Description_Results := Files.Command_Palette.Search ("navigate.back previous", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search can match separate tokens across identifier and description");
      Assert
        (Description_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "cross-field token search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("control+p", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches primary command shortcuts");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Open_Command_Palette_Command,
         "primary shortcut search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("ctrl+p", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches control shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Open_Command_Palette_Command,
         "control shortcut alias search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("option+left", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches option shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "option shortcut alias search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("control+shift+f", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches common control-shift shortcut order");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Clear_Filter_Command,
         "common control-shift shortcut order returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("ctrl+shift+f", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches abbreviated control-shift shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Clear_Filter_Command,
         "abbreviated control-shift shortcut alias returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("backspace", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches secondary command shortcuts");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Delete_Selected_Items_Command,
         "secondary shortcut search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("del", Model);
      Assert
        (Natural (Shortcut_Results.Length) >= 1,
         "palette search matches delete shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Delete_Selected_Items_Command,
         "delete shortcut alias search ranks delete first");
      Shortcut_Results := Files.Command_Palette.Search ("esc", Model);
      Assert
        (Natural (Shortcut_Results.Length) >= 1,
         "palette search matches escape shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Close_Command_Palette_Command,
         "escape shortcut alias search ranks close-palette first");
      Shortcut_Results := Files.Command_Palette.Search ("enter", Model);
      Assert
        (Natural (Shortcut_Results.Length) >= 1,
         "palette search matches return shortcut aliases");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Open_Selected_Items_Command,
         "return shortcut alias search ranks open-selected first");
      Mixed_Results := Files.Command_Palette.Search ("   navigate.back   ", Model);
      Assert
        (Natural (Mixed_Results.Length) = 1,
         "palette search trims leading and trailing identifier whitespace");
      Assert
        (Mixed_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "trimmed identifier search returns the matching command");
      Shortcut_Results := Files.Command_Palette.Search ("CoNtRoL+p", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search matches primary shortcuts case-insensitively");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Open_Command_Palette_Command,
         "mixed-case primary shortcut search returns the matching command");
      Assert
        (Shortcut_Results.Element (1).Score < Natural'Last,
         "mixed-case primary shortcut search keeps a finite score");
      Shortcut_Results := Files.Command_Palette.Search ("  backspace  ", Model);
      Assert
        (Natural (Shortcut_Results.Length) = 1,
         "palette search trims shortcut query whitespace");
      Assert
        (Shortcut_Results.Element (1).Command = Files.Commands.Delete_Selected_Items_Command,
         "trimmed secondary shortcut search returns the matching command");
      Clear_Results := Files.Command_Palette.Search ("cLeAr fIlTeR", Model);
      Assert
        (Natural (Clear_Results.Length) = 1,
         "palette search matches localized labels case-insensitively");
      Assert
        (Clear_Results.Element (1).Command = Files.Commands.Clear_Filter_Command,
         "mixed-case localized label search returns the matching command");
      Description_Results := Files.Command_Palette.Search ("  navigate.back    previous  ", Model);
      Assert
        (Natural (Description_Results.Length) = 1,
         "palette search ignores repeated token separators around cross-field queries");
      Description_Results := Files.Command_Palette.Search ("navigate.back impossible-token", Model);
      Assert
        (Natural (Description_Results.Length) = 0,
         "palette search requires every query token to match");

      Mixed_Results := Files.Command_Palette.Search ("   ", Model);
      Assert
        (Natural (Mixed_Results.Length) = Files.Commands.Command_Count,
         "whitespace-only palette query is treated as empty search");
      Assert
        (Mixed_Results.Element (1).Command = Files.Commands.Registered_Command_Id'First,
         "whitespace-only palette query preserves registry order");

      for Index in 1 .. 2_000 loop
         Append (Long_Query, "previous ");
      end loop;
      Long_Results := Files.Command_Palette.Search (To_String (Long_Query), Model);
      Assert (Natural (Long_Results.Length) = 1, "long repeated palette query remains searchable");
      Assert
        (Long_Results.Element (1).Command = Files.Commands.Navigate_Back_Command,
         "long repeated palette query preserves matching command");
      Assert (Long_Results.Element (1).Score < Natural'Last, "long repeated palette query keeps score bounded");
   end Test_Command_Palette_Search;

   procedure Test_Command_Palette_Toggle_Shortcut (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Layout   : Files.Rendering.Layout_Metrics;
      Palette_Layout : Files.Rendering.Command_Palette_Layout;
      Palette_Rows   : Files.Rendering.Command_Result_Layout_Vectors.Vector;
   begin
      Ctrl (Files.Types.Control_Key) := True;

      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "Control+P routes to palette command");
      Assert (Files.Model.Last_Error_Key (Model) = "", "palette shortcut clears stale error state");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "first Control+P opens palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "open palette receives focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "second Control+P routes through registry");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "second Control+P closes palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed palette clears focus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 3);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "closed palette text click is ignored");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed palette text click does not focus input");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Files.Controller.Replace_Focused_Text (Model, "view.details");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_L, Ctrl);
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "Control+L routes while palette is open");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "path focus closes command palette");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "path focus clears palette query");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "path input receives focus after palette");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "palette blocks stale path text click");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "blocked text click leaves palette open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "blocked text click keeps palette focus");
   end Test_Command_Palette_Toggle_Shortcut;

   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "path-target");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "loaded.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.path.missing");
      Ctrl (Files.Types.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_L, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "Control+L executes focus command");
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "Control+L focuses path input");
      Assert (Files.Model.Last_Error_Key (Model) = "", "path focus clears stale error state");
      Files.Model.Begin_Create_File (Model, "path-pending.txt");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "");
      Assert (Files.Model.Text_Cursor_Position (Model) = 0, "path replacement places cursor at text end");
      Result := Files.Controller.Append_Focused_Text (Model, Root);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "path input append updates text");
      Assert (Files.Model.Path_Input_Text (Model) = Root, "path input append uses focused path field");
      Assert (Files.Model.Text_Cursor_Position (Model) = Root'Length, "path append advances cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert
        (Result.Command = Files.Commands.Open_Command_Palette_Command,
         "Control+P routes through command registry from path input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette from path input");
      Assert (Files.Model.Path_Input_Text (Model) = Root, "palette shortcut preserves edited path input text");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "Escape closes palette after path shortcut");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, Join (Root, "missing-path-target"));
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "invalid path input Return executes path command");
      Assert
        (Result.Command = Files.Commands.Focus_Path_Input_Command,
         "invalid path input Return reports path command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "invalid path input returns failure");
      Assert (To_String (Result.Operation.Path) = "", "missing path input has no operation path");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.path.missing",
         "invalid path input reports path diagnostic");
      Assert (Files.Model.Current_Path (Model) = Root, "invalid controller path input does not navigate");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "invalid path input keeps focus");
      Assert (Files.Model.Last_Error_Key (Model) = "error.path.missing", "invalid path input records error");
      Assert (not Files.Model.Path_Input_Is_Valid (Model), "invalid path input marks validation state");
      Assert
        (Files.Model.Path_Input_Error_Key (Model) = "error.path.missing",
         "invalid path input stores validation diagnostic");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid path input preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid path input preserves rename state");

      Files.Controller.Replace_Focused_Text (Model, Target);
      Assert (Files.Model.Path_Input_Is_Valid (Model), "path input edit clears stale validation state");
      Assert (Files.Model.Path_Input_Error_Key (Model) = "", "path input edit clears stale validation diagnostic");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "modified Return does not commit path input");
      Assert (Files.Model.Current_Path (Model) = Root, "modified Return in path input does not navigate");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "modified Return keeps path input focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "path input Return executes path command");
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "path input Return reports path command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "Return commits path input");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Target),
         "path input operation reports normalized target path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target), "path input navigates");
      Assert (Files.Model.Last_Error_Key (Model) = "", "path input success clears stale error state");
      Assert (Files.Model.Item_Count (Model) = 1, "path input loads destination items");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "path input commit clears focus");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "path input success clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "path input success clears rename state");

      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, Join (Target, "loaded.txt"));
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "file path input Return executes path command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Navigated,
         "file path input navigates to parent directory");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Target),
         "file path input operation reports normalized parent directory");
      Assert
        (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target),
         "file path input changes model to parent directory");
      Assert (Files.Model.Item_Count (Model) = 1, "file path input loads parent directory items");
   end Test_Controller_Path_Input_Return;

   procedure Test_Controller_Filter_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Ctrl_Shift : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Ctrl_Shift (Files.Types.Control_Key) := True;
      Ctrl_Shift (Files.Types.Shift_Key) := True;
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "filter.focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_F, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "filter focus executes command");
      Assert (Result.Command = Files.Commands.Focus_Filter_Input_Command, "filter command is routed");
      Assert (Files.Model.Last_Error_Key (Model) = "", "filter focus clears stale error state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "filter focus closes command palette");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "filter focus clears palette query");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input, "filter input receives focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "Control+P executes while filter input has focus");
      Assert
        (Result.Command = Files.Commands.Open_Command_Palette_Command,
         "Control+P routes through command registry from filter input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette from filter input");
      Assert
        (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette,
         "Control+P transfers focus from filter input to palette");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "Escape closes palette after filter shortcut");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "palette closes before filter editing resumes");
      Files.Model.Focus_Filter_Input (Model);

      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Append_Focused_Text (Model, "be");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter append updates text");
      Result := Files.Controller.Append_Focused_Text (Model, "ta");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "second filter append updates text");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter text is updated through controller");
      Assert (Files.Model.Text_Cursor_Position (Model) = 4, "filter append leaves cursor at text end");
      Assert (Files.Model.Visible_Count (Model) = 1, "filter input updates visible projection");
      Assert (Files.Model.Selected_Name (Model) = "Beta.txt", "filter reconciles selection");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter click updates text cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 2, "filter click positions cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "filter Escape clears focus before refocus");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_F, Ctrl);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input, "filter shortcut refocuses filter input");
      Assert (Files.Model.Text_Cursor_Position (Model) = 4, "filter shortcut refocus places cursor at text end");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter click can reposition after refocus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "same filter cursor click is ignored");
      Result := Files.Controller.Append_Focused_Text (Model, "X");
      Assert (Files.Model.Filter_Text (Model) = "beXta", "filter insert uses cursor position");
      Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter insert advances cursor from insertion point");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Backspace edits text");
      Assert (Result.Command = Files.Commands.No_Command, "filter Backspace does not route delete command");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Backspace removes character before cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 2, "filter Backspace moves cursor backward");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Delete edits text");
      Assert (Result.Command = Files.Commands.No_Command, "filter Delete does not route delete command");
      Assert (Files.Model.Filter_Text (Model) = "bea", "filter Delete removes character at cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter insert restores text at cursor");
      Assert (Files.Model.Selected_Name (Model) = "Beta.txt", "text delete preserves selected visible item");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Home moves text cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 0, "filter Home moves cursor to start");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Home at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Backspace at start is ignored");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Backspace at start leaves text unchanged");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_End);
      Assert (Files.Model.Text_Cursor_Position (Model) = 4, "filter End moves cursor to end");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter End at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Right at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Delete at end is ignored");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Delete at end leaves text unchanged");
      Files.Controller.Replace_Focused_Text (Model, "b");
      Assert (Files.Model.Text_Cursor_Position (Model) = 1, "short filter replacement clamps cursor to end");
      Result := Files.Controller.Append_Focused_Text (Model, "eta");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter append after clamp updates text");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter append after short replacement uses clamped cursor");
      declare
         Utf8_Text : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Combining_Text : constant String :=
           "e" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "a" & Utf8_Text & "b");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 1,
            "filter click snaps UTF-8 cursor to character boundary");
         Files.Model.Set_Text_Cursor_Position (Model, 2);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 1,
            "model cursor setter snaps UTF-8 cursor to character boundary");
         Files.Model.Set_Text_Cursor_Position (Model, 4);
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter Left moves before ASCII after UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Left moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 0, "filter Left reaches start before UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Right moves over ASCII before UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
         Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter Right moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
         Assert (Files.Model.Filter_Text (Model) = "ab", "filter Backspace removes whole UTF-8 input");
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Backspace lands before removed UTF-8 input");
         Files.Controller.Replace_Focused_Text (Model, "a" & Utf8_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
         Assert (Files.Model.Filter_Text (Model) = "ab", "filter Delete removes whole UTF-8 input");
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Delete keeps cursor before UTF-8 input");

         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "model cursor setter snaps combining mark starts to the base boundary");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Left at combining base is ignored");
         Files.Model.Set_Text_Cursor_Position (Model, Combining_Text'Length + 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = Combining_Text'Length,
            "filter Left moves before ASCII after combining text");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "filter Left moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = Combining_Text'Length,
            "filter Right moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
         Assert
           (Files.Model.Filter_Text (Model) = "b",
            "filter Backspace removes base and trailing combining marks together");
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "filter Backspace lands before removed combining sequence");
         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 0);
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
         Assert
           (Files.Model.Filter_Text (Model) = "b",
            "filter Delete removes base and trailing combining marks together");
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "filter Delete keeps cursor before removed combining sequence");
         Files.Controller.Replace_Focused_Text (Model, "e");
         Result :=
           Files.Controller.Append_Focused_Text
             (Model, Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#)));
         Assert
           (Files.Model.Filter_Text (Model) = Combining_Text,
            "filter append can add a trailing combining mark");
         Assert
           (Files.Model.Text_Cursor_Position (Model) = Combining_Text'Length,
            "filter append leaves cursor after appended trailing combining mark");
      end;
      Files.Controller.Replace_Focused_Text (Model, "alpha beta-gamma");
      Assert (Files.Model.Text_Cursor_Position (Model) = 16, "long filter replacement places cursor at end");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Left moves by word");
      Assert (Files.Model.Text_Cursor_Position (Model) = 11, "Control+Left stops before previous word");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Backspace deletes previous word");
      Assert (Files.Model.Filter_Text (Model) = "alpha gamma", "Control+Backspace removes previous word and separator");
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Backspace leaves cursor at word boundary");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Delete deletes next word");
      Assert (Files.Model.Filter_Text (Model) = "alpha ", "Control+Delete removes next word");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Delete at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Backspace at start is ignored");
      Files.Controller.Replace_Focused_Text (Model, "beta");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.LF & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats line feed as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
      Assert
        (Files.Model.Filter_Text (Model) = "beta",
         "Control+Backspace removes previous word across line feed");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.CR & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats carriage return as word separator");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.VT & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats vertical tab as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
      Assert
        (Files.Model.Filter_Text (Model) = "beta",
         "Control+Backspace removes previous word across vertical tab");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.FF & "beta");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
      Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before form feed");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
      Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across form feed");

      declare
         C1_Break : constant Character := Character'Val (133);
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
         Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats C1 NEL as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
         Assert
           (Files.Model.Filter_Text (Model) = "beta",
            "Control+Backspace removes previous word across C1 NEL");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before C1 NEL");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
         Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across C1 NEL");
      end;
      declare
         NBSP : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
         Assert (Files.Model.Text_Cursor_Position (Model) = 7, "Control+Left treats UTF-8 NBSP as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace, Ctrl);
         Assert
           (Files.Model.Filter_Text (Model) = "beta",
            "Control+Backspace removes previous word across UTF-8 NBSP");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before UTF-8 NBSP");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
         Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across UTF-8 NBSP");
      end;
      declare
         Line_Separator : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & Line_Separator & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 8,
            "Control+Left treats UTF-8 line separator as word separator");
      end;
      Files.Controller.Replace_Focused_Text (Model, "beta");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "filter Return executes focus command");
      Assert (Result.Command = Files.Commands.Focus_Filter_Input_Command, "Return commits filter input");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "filter Return reports successful state-only commit");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "filter Return clears focus");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Return preserves text");
      Assert (Files.Model.Current_Path (Model) = Root, "filter Return does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_F, Ctrl_Shift);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "clear-filter executes command");
      Assert (Result.Command = Files.Commands.Clear_Filter_Command, "clear-filter command is routed");
      Assert (Files.Model.Filter_Text (Model) = "", "clear-filter command clears text");
      Assert (Files.Model.Visible_Count (Model) = 3, "clear-filter restores visible projection");
      Assert (Files.Model.Selected_Name (Model) = "Beta.txt", "clear-filter preserves selected visible item");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Clear_Filter_Command, Model),
         "clear-filter disables after clearing");
   end Test_Controller_Filter_Input_Return;

   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_F2);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "F2 executes rename command");
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "F2 reports rename command");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "F2 focuses rename input");
      Assert
        (Files.Model.Text_Cursor_Position (Model) = 3,
         "F2 places rename cursor before the file extension");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_End);
      Assert
        (Files.Model.Text_Cursor_Position (Model) = Files.Model.Rename_Text (Model)'Length,
         "End moves the rename cursor to the end of the name");
      Result := Files.Controller.Append_Focused_Text (Model, ".bak");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename append works immediately after F2");
      Assert
        (Files.Model.Rename_Text (Model) = "old.txt.bak",
         "initial rename cursor appends text at the end");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename Left moves cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Rename_Text (Model) = "new.ttx", "rename insert uses cursor position");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename append updates text");
      Assert (Files.Model.Rename_Text (Model) = "new.tttx", "rename second insert advances cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename Backspace edits text");
      Assert (Files.Model.Rename_Text (Model) = "new.ttx", "rename Backspace removes character before cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Files.Model.Rename_Text (Model) = "new.tt", "rename Delete removes character at cursor");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "rename replacement clamps cursor to text end");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Rename_Text (Model) = "new.txt", "rename append restores commit text");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "rename Return executes rename command");
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "rename Return reports rename command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "Return commits rename");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "rename file exists after Return");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename Return clears rename mode");
   end Test_Controller_Rename_Return;

   procedure Test_Controller_Command_Palette_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      Roots    : Files.Types.String_Vectors.Vector;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette");
      Result := Files.Controller.Append_Focused_Text (Model, "view.");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "palette append updates query");
      Result := Files.Controller.Append_Focused_Text (Model, "details");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "palette second append updates query");
      Assert (Files.Model.Command_Palette_Query (Model) = "view.details", "palette append builds query");
      Assert (Files.Model.Text_Cursor_Position (Model) = 12, "palette append advances query cursor");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "palette query selects first result");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 99);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "palette Return executes selected command");
      Assert (Result.Command = Files.Commands.Select_Details_Command, "Return executes selected palette command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "stale palette index clamps before execute");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "executed stale-index palette closes");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "executed stale-index palette clears query");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "executed stale-index palette clears focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Files.Controller.Replace_Focused_Text (Model, "view.small");
      Assert (Files.Model.Text_Cursor_Position (Model) = 10, "palette replacement clamps cursor to query end");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "reopened palette query selects first result");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "palette Backspace edits query text");
      Assert (Result.Command = Files.Commands.No_Command, "palette Backspace does not route delete command");
      Assert (Files.Model.Command_Palette_Query (Model) = "view.smal", "palette Backspace removes previous character");
      Result := Files.Controller.Handle_Text_Click
        (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 5);
      Assert (Files.Model.Text_Cursor_Position (Model) = 5, "palette text click positions cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "palette Delete edits query text");
      Assert (Result.Command = Files.Commands.No_Command, "palette Delete does not route delete command");
      Assert (Files.Model.Command_Palette_Query (Model) = "view.mal", "palette Delete removes character at cursor");
      Files.Controller.Replace_Focused_Text (Model, "view.small");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "palette Control+Left edits query cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 5, "palette Control+Left moves to query word boundary");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete, Ctrl);
      Assert (Files.Model.Command_Palette_Query (Model) = "view.", "palette Control+Delete removes next query word");
      Files.Controller.Replace_Focused_Text (Model, "view.small");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "reopened palette Return executes command");
      Assert (Result.Command = Files.Commands.Select_Small_Icons_Command, "Return executes selected palette command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons, "palette command mutates model");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "executed palette closes");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "executed palette clears query");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Files.Controller.Replace_Focused_Text (Model, "view.details");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Select_Details_Command, "palette click executes result command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "palette click mutates model");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "executed palette click closes palette");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "closed palette result click is ignored");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "closed palette result click does not execute");

      Roots.Append (To_Unbounded_String (Root));
      Files.Model.Open_Root_Selector (Model, Roots);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens over selected root");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette keeps selected root available");
      Files.Controller.Replace_Focused_Text (Model, "path.focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "blocked root palette Return is ignored");
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "blocked root palette Return reports command");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "blocked root palette Return leaves palette open");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked root palette Return keeps root selector open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "blocked root palette keeps focus");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "blocked root palette click is ignored");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "blocked root palette click leaves palette open");
      Files.Controller.Replace_Focused_Text (Model, "drive.open_selected");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert
        (Result.Command = Files.Commands.Open_Selected_Root_Command,
         "palette Return executes selected-root command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "palette root activation navigates");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "palette root activation closes palette");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "palette root activation closes root selector");
   end Test_Controller_Command_Palette_Return;

   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "F2 enters rename before palette opens");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "Control+P routes from rename input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette over rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "palette takes focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "Escape first updates palette state");
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "Escape first closes palette");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "Escape closes the open palette");
      Assert (Files.Model.Rename_Is_Active (Model), "Escape does not cancel rename while palette is open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed palette clears palette focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "second Escape routes context cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "second Escape cancels pending rename");
      Assert (Files.Model.Text_Cursor_Position (Model) = 0, "second Escape clears stale rename cursor");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "second Escape leaves focus clear");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Rename_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "inactive rename text click is ignored");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "inactive rename text click does not focus input");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Escape);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "idle Escape is ignored");
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "idle Escape still reports context command");
   end Test_Controller_Command_Palette_Escape_Priority;

   procedure Test_Controller_Palette_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Layout   : Files.Rendering.Layout_Metrics;
      Palette_Layout : Files.Rendering.Command_Palette_Layout;
      Palette_Rows   : Files.Rendering.Command_Result_Layout_Vectors.Vector;
      Found_Selected_Page_Row : Boolean;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette for movement");
      Files.Controller.Replace_Focused_Text (Model, "settings.");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "palette movement starts at first result");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "palette movement starts unscrolled");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "Down updates palette selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 2, "Down moves to next palette result");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "Down keeps visible result list unscrolled");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Up);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "Up moves to previous palette result");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "Up restores first result offset");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Left);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 3, "Left wraps palette selection");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "small wrapped palette stays unscrolled");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "Right wraps palette selection");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "wrapped first palette result resets offset");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 2, "Right moves to next palette result");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Right);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 3, "Right moves to third palette result");
      Result := Files.Controller.Handle_Scroll (Model, Lines => -1);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "scroll up updates palette selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 2, "scroll up moves palette selection up");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "scroll up keeps visible result list unscrolled");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 1);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 3, "scroll down moves palette selection down");
      Assert
        (Files.Model.Command_Palette_Result_Offset (Model) = 0,
         "scroll down keeps visible result list unscrolled");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "normal wheel delta updates palette");
      Assert
        (Files.Model.Command_Palette_Selected_Index (Model) = 1,
         "normal wheel delta advances even when it matches result count");
      Result := Files.Controller.Handle_Scroll (Model, Lines => -3);
      Assert
        (Result.Status = Files.Controller.Controller_Palette_Updated,
         "negative exact-count palette scroll updates selection");
      Assert
        (Files.Model.Command_Palette_Selected_Index (Model) = 3,
         "negative exact-count palette scroll advances instead of no-op");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 1);
      Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
      Result := Files.Controller.Handle_Scroll (Model, Lines => Integer'First);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "saturated palette scroll is handled");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 3, "saturated upward scroll stays bounded");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Command_Palette,
           Lines => Integer'Last);
      Assert
        (Result.Status = Files.Controller.Controller_Palette_Updated,
         "saturated targeted palette scroll is handled");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "saturated downward scroll stays bounded");
      Files.Controller.Replace_Focused_Text (Model, "no-such-command");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 0, "empty palette query clears selection");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty palette ignores keyboard movement");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty palette ignores automatic scroll");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Command_Palette,
           Lines => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty palette ignores targeted scroll");
      Files.Controller.Replace_Focused_Text (Model, "settings.save");
      Assert
        (Natural (Files.Command_Palette.Search ("settings.save", Model).Length) = 1,
         "unique palette query has one result");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single palette result ignores Down");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single palette result ignores PageDown");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single palette result ignores Home");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single palette result ignores End");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single palette result ignores wheel movement");
      Files.Controller.Replace_Focused_Text (Model, "settings.");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Main_View,
           Lines => 5);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "palette blocks targeted main scroll");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "blocked main scroll leaves item view still");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "palette Home at first result is ignored");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "palette Home selects first result");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "palette Home resets result offset");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "palette End updates selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 3, "palette End selects last result");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "palette End keeps short result list unscrolled");
      Files.Controller.Replace_Focused_Text (Model, "");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "empty query starts at first command");
      Files.Model.Set_Command_Palette_Selected_Index (Model, Natural'Last);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert
        (Result.Status = Files.Controller.Controller_Palette_Updated,
         "Down clamps extreme stale palette selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "Down restarts extreme stale palette selection");
      Files.Model.Set_Command_Palette_Selected_Index (Model, Natural'Last);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Page_Down);
      Assert
        (Result.Status = Files.Controller.Controller_Palette_Updated,
         "PageDown clamps extreme stale palette selection");
      Assert
        (Files.Model.Command_Palette_Selected_Index (Model) = 1,
         "PageDown restarts extreme stale palette selection");
      declare
         Result_Count : constant Natural :=
           Natural (Files.Command_Palette.Search ("", Model).Length);
      begin
         Files.Model.Set_Command_Palette_Selected_Index (Model, Result_Count - 1);
         Files.Model.Set_Command_Palette_Result_Offset (Model, Result_Count - 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
         Assert (Files.Model.Command_Palette_Selected_Index (Model) = Result_Count, "stale offset move reaches end");
         Assert
           (Files.Model.Command_Palette_Result_Offset (Model) = Result_Count - 4,
            "stale palette offset clamps to last full page");
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Home);
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "palette Home restores first result");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "palette PageDown updates selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 5, "palette PageDown jumps by page");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 1, "palette PageDown scrolls selected row into view");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 360, Line_Height => 20);
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Found_Selected_Page_Row := False;
      for Row of Palette_Rows loop
         if Row.Result_Index = 5 and then Row.Selected then
            Found_Selected_Page_Row := True;
         end if;
      end loop;
      Assert (Found_Selected_Page_Row, "paged palette keeps selected result visible");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Page_Up);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "palette PageUp updates selection");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "palette PageUp jumps back by page");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "palette PageUp restores top offset");
      Files.Controller.Replace_Focused_Text (Model, "view.details");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "narrowed query reconciles selection");
      Assert (Files.Model.Command_Palette_Result_Offset (Model) = 0, "narrowed query resets result offset");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Command = Files.Commands.Select_Details_Command, "Return executes reconciled palette result");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "wrapped palette command mutates model");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "executed wrapped palette result closes palette");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "");
      Files.Model.Set_Command_Palette_Result_Offset (Model, 5);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 300, Line_Height => 20);
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (not Palette_Rows.Is_Empty, "scrolled palette layout exposes visible command rows");
      declare
         Search_Results : constant Files.Command_Palette.Result_Vectors.Vector :=
           Files.Command_Palette.Search ("", Model);
         Clicked_Index : constant Natural := Palette_Rows.Element (1).Result_Index;
         Clicked_Command : constant Files.Commands.Command_Id :=
           Search_Results.Element (Positive (Clicked_Index)).Command;
      begin
         Assert (Clicked_Index > 1, "scrolled palette click uses absolute result index");
         Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Clicked_Index);
         Assert (Result.Command = Clicked_Command, "scrolled palette click executes visible absolute result");
         Assert (not Files.Model.Command_Palette_Is_Open (Model), "scrolled palette click closes palette");
      end;
   end Test_Controller_Palette_Selection_Movement;

   procedure Test_Controller_Disabled_Palette_Result (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Files.Controller.Replace_Focused_Text (Model, "file.rename");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 99);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled palette result is ignored");
      Assert
        (Result.Command = Files.Commands.Rename_Selected_Items_Command,
         "disabled palette Return reports selected command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled palette Return reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.rename.disabled",
         "disabled palette Return reports localized error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.disabled", "disabled palette Return records error");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "disabled palette result leaves palette open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "disabled palette keeps input focus");
      Assert (Files.Model.Command_Palette_Query (Model) = "file.rename", "disabled palette preserves query text");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "disabled palette clamps stale selection");
      Assert (not Files.Model.Rename_Is_Active (Model), "disabled palette result does not execute");

      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 0);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "outside palette result click is ignored");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "outside palette click leaves palette open");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "disabled palette click is ignored");
      Assert
        (Result.Command = Files.Commands.Rename_Selected_Items_Command,
         "disabled palette click reports selected command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled palette click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.rename.disabled",
         "disabled palette click reports localized error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.disabled", "disabled palette click records error");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 1, "disabled palette click selects row");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "disabled palette click leaves palette open");

      Files.Model.Set_Command_Palette_Query (Model, "filter.clear");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Clear_Filter_Command, "disabled clear palette click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled clear palette click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.filter.empty",
         "disabled clear palette click reports empty-filter error");
      Assert (Files.Model.Last_Error_Key (Model) = "error.filter.empty", "disabled clear palette click records error");

      Files.Model.Set_Command_Palette_Query (Model, "drive.open_selected");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Open_Selected_Root_Command, "disabled root-open click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled root-open click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.root.selection.empty",
         "disabled root-open click reports empty-root error");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.root.selection.empty",
         "disabled root-open click records error");

      Files.Model.Set_Command_Palette_Query (Model, "settings.save");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Save_Settings_Command, "disabled settings save click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled settings save click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.settings.closed",
         "disabled settings save click reports closed-settings error");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.settings.closed",
         "disabled settings save click records error");

      Files.Model.Set_Command_Palette_Query (Model, "settings.reset");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Reset_Settings_Command, "disabled settings reset click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled settings reset click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.settings.closed",
         "disabled settings reset click reports closed-settings error");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.settings.closed",
         "disabled settings reset click records error");

      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens for modal palette checks");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens over settings pane for disabled check");
      Files.Controller.Replace_Focused_Text (Model, "file.delete_selected");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings-modal disabled palette Return is ignored");
      Assert
        (Result.Command = Files.Commands.Delete_Selected_Items_Command,
         "settings-modal disabled palette Return reports command");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.path.missing",
         "settings-modal disabled palette Return preserves existing error");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "settings-modal disabled Return leaves palette open");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings-modal disabled palette click is ignored");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.path.missing",
         "settings-modal disabled palette click preserves existing error");
      Files.Model.Close_Command_Palette (Model);
      Files.Model.Toggle_Settings_Pane (Model);

      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "file.create");
      Result := Files.Controller.Handle_Command_Result_Click (Model, Settings, Result_Index => 1);
      Assert (Result.Command = Files.Commands.Create_File_Command, "disabled create palette click reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "disabled create palette click reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.create.pending",
         "disabled create palette click reports pending-create error");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.create.pending",
         "disabled create palette click records error");
      Assert (Files.Model.Temporary_Item_Name (Model) = "pending.txt", "disabled create palette keeps pending item");
   end Test_Controller_Disabled_Palette_Result;

   procedure Test_Controller_Empty_Palette_Result (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
      Found_Empty_Text : Boolean := False;
      Found_Empty_Status : Boolean := False;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_P, Ctrl);
      Files.Controller.Replace_Focused_Text (Model, "no-such-command-token");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 0, "empty palette search has no selection");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty palette Down is ignored");
      Assert (Files.Model.Command_Palette_Selected_Index (Model) = 0, "empty palette movement stays unselected");

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Return ignores an empty palette result");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "empty palette Return leaves palette open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "empty palette keeps input focus");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons, "empty palette Return does not mutate view");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      for Command of Frame.Text loop
         if To_String (Command.Text) = Files.Localization.Text ("command.palette.empty")
           and then Command.Color = Files.Rendering.Muted_Text_Color
         then
            Found_Empty_Text := True;
         end if;
      end loop;
      for Node of Frame.Accessibility loop
         if Node.Role = Files.Rendering.Role_Status
           and then To_String (Node.Name) = Files.Localization.Text ("command.palette.empty")
         then
            Found_Empty_Status := True;
         end if;
      end loop;
      Assert (Found_Empty_Text, "empty palette renders localized empty state");
      Assert (Found_Empty_Status, "empty palette exposes accessible status node");
   end Test_Controller_Empty_Palette_Result;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Command_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Commands;

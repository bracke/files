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
   use type Files.Model.Sort_Field;
   use type Files.Settings.Sort_Field;
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

   procedure Test_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Registry_And_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Filter_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Copy_Path_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Containing_Folder_Command (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Shortcut_Overrides'Access, "shortcut parsing, override resolution, and conflict lookup");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Path_Input_Return'Access, "controller commits path input on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Filter_Input_Return'Access, "controller commits filter input on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Rename_Return'Access, "controller commits rename on Return");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Command_Palette_Escape_Priority'Access, "controller prioritizes palette Escape");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Copy_Path_Command'Access, "copy-path joins selection paths for the system clipboard");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Containing_Folder_Command'Access, "open-containing-folder reveals a search result");
   end Register_Tests;

   procedure Test_Command_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Empty    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
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
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
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
      Result := Files.Controller.Execute_Command (Files.Commands.Reset_Settings_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Reset_Settings_Command, "reset settings command is reported");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "reset settings reports success");
      Result := Files.Controller.Execute_Command (Files.Commands.Save_Settings_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Save_Settings_Command, "pure save settings command is reported");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "pure save settings command keeps runtime path-resolution sentinel");
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_S, Ctrl);
      Assert (Result.Command = Files.Commands.Save_Settings_Command, "control+s routes settings save command");
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "control+s reports settings save command execution for runtime persistence");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "scalar settings field ignores add-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Assert
        (Result.Status = Files.Controller.Controller_Ignored,
         "scalar settings field ignores remove-entry shortcut");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "scalar settings field ignores entry paging");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      declare
         Bad : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Bad.Show_Hidden_Files := To_Unbounded_String ("maybe");
         Files.Model.Set_Settings_Draft (Model, Bad);
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Failed,
         "invalid settings field Return reports validation failure");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.settings.invalid_boolean",
         "invalid settings field Return reports diagnostic key");
      declare
         Good : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Good.Show_Hidden_Files := To_Unbounded_String ("true");
         Files.Model.Set_Settings_Draft (Model, Good);
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "valid settings field Return reports validation success");
      Assert (Files.Model.Last_Error_Key (Model) = "", "valid settings draft field validates on Return");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "controller closes settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Assert (Result.Command = Files.Commands.Toggle_Settings_Pane_Command, "control+comma routes settings command");
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma opens settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "control+comma closes open settings pane");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Comma, Ctrl);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "control+comma reopens settings pane");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "Escape closes unfocused settings pane");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "closed settings text click is ignored");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed settings text click does not focus input");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens from palette state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "settings pane opening closes command palette");
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
      Assert (Result.Status = Files.Controller.Controller_Ignored,
              "settings clicks route through the panel, not the generic text-click path");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after focus Escape");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "settings Escape clears settings focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane reopens after Escape close check");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert (Files.Model.Selected_Item (Model).Name = "Alpha.txt", "settings modal starts with stable selection");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background selection keys");
      Assert
        (Files.Model.Selected_Item (Model).Name = "Alpha.txt",
         "settings pane keeps background selection unchanged");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Settings_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored,
              "settings text-clicks are handled by the panel, not the generic path");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette can open over settings pane");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before history enablement check");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/next", Empty);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Back_Command, Model), "back enabled after navigation");
   end Test_Command_Enablement;

   procedure Test_Command_Registry_And_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl          : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Alt           : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Shift         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
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
      Ctrl (Guikit.Input.Control_Key) := True;
      Alt (Guikit.Input.Alt_Key) := True;
      Shift (Guikit.Input.Shift_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Assert (Files.Commands.Command_Count = 72, "all expected commands are registered");
      Assert (Files.Commands.Contains ("navigate.recent"), "recent-view command identifier is registered");
      Assert (Files.Commands.Contains ("search.contents"), "content-search command identifier is registered");
      Assert (Files.Commands.Contains ("recent.clear"), "clear-recent command identifier is registered");
      Assert (Files.Commands.Contains ("label.set"), "set-color-label command identifier is registered");
      Assert (Files.Commands.Contains ("edit.copy_path"), "copy-path command identifier is registered");
      Assert
        (Files.Commands.Contains ("navigate.containing"),
         "open-containing-folder command identifier is registered");
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
               Assert (Primary.Key /= Guikit.Input.Key_Unknown, "present primary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Primary) /= "",
                  "present primary shortcut has searchable text");
               Assert
                 (Files.Commands.Find_By_Shortcut (Primary.Key, Primary.Modifiers) = Id,
                  "present primary shortcut routes back to command");
            else
               Assert (Primary.Key = Guikit.Input.Key_Unknown, "absent primary shortcut has unknown key");
               Assert
                 (Files.Commands.Shortcut_Text (Primary) = "",
                  "absent primary shortcut has no searchable text");
            end if;
            if Secondary.Present then
               Assert (Secondary.Key /= Guikit.Input.Key_Unknown, "present secondary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Secondary) /= "",
                  "present secondary shortcut has searchable text");
               Assert
                 (Files.Commands.Find_By_Shortcut (Secondary.Key, Secondary.Modifiers) = Id,
                  "present secondary shortcut routes back to command");
            else
               Assert (Secondary.Key = Guikit.Input.Key_Unknown, "absent secondary shortcut has unknown key");
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
      Assert (Small_Shortcut.Key = Guikit.Input.Key_1, "shortcut metadata stores small-icons key");
      Assert (Small_Shortcut.Modifiers = Ctrl, "shortcut metadata stores small-icons modifiers");
      Drive_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Select_Drive_Command);
      Assert (Drive_Shortcut.Present, "drive selector exposes shortcut metadata");
      Assert (Drive_Shortcut.Key = Guikit.Input.Key_D, "drive selector shortcut uses D");
      Assert (Drive_Shortcut.Modifiers = Ctrl, "drive selector shortcut uses Control");
      Settings_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Toggle_Settings_Pane_Command);
      Assert (Settings_Shortcut.Present, "settings pane exposes shortcut metadata");
      Assert (Settings_Shortcut.Key = Guikit.Input.Key_Comma, "settings pane shortcut uses comma");
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
        (Files.Commands.Shortcut_For (Files.Commands.Save_Settings_Command).Key = Guikit.Input.Key_S,
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
      Assert (Delete_Secondary.Key = Guikit.Input.Key_Backspace, "delete secondary shortcut uses Backspace");
      Assert
        (Delete_Secondary.Modifiers = Guikit.Input.No_Modifiers,
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
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_1, Ctrl) = Files.Commands.Select_Small_Icons_Command,
         "control+1 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_2, Ctrl) = Files.Commands.Select_Large_Icons_Command,
         "control+2 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_3, Ctrl) = Files.Commands.Select_Details_Command,
         "control+3 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_4, Ctrl) = Files.Commands.Toggle_Info_Pane_Command,
         "control+4 dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Comma, Ctrl) =
         Files.Commands.Toggle_Settings_Pane_Command,
         "control+comma dispatches settings pane command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_L, Ctrl) = Files.Commands.Focus_Path_Input_Command,
         "control+l dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Home, Alt) = Files.Commands.Navigate_Home_Command,
         "alt+home dispatches home command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Left, Alt) = Files.Commands.Navigate_Back_Command,
         "alt+left dispatches back command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Right, Alt) = Files.Commands.Navigate_Forward_Command,
         "alt+right dispatches forward command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Up, Alt) = Files.Commands.Navigate_Parent_Command,
         "alt+up dispatches parent command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Up, Guikit.Input.No_Modifiers) =
           Files.Commands.No_Command,
         "plain up is not a command shortcut so grid navigation keeps it");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_N, Ctrl) = Files.Commands.Create_File_Command,
         "control+n dispatches create-file command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_A, Ctrl) = Files.Commands.Select_All_Command,
         "control+a dispatches select-all command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_P, Ctrl) = Files.Commands.Open_Command_Palette_Command,
         "control+p dispatches through registry");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F, Ctrl) = Files.Commands.Focus_Filter_Input_Command,
         "control+f dispatches filter focus command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_D, Ctrl) = Files.Commands.Select_Drive_Command,
         "control+d dispatches drive selector command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F, Ctrl_Shift) = Files.Commands.Clear_Filter_Command,
         "control+shift+f dispatches clear-filter command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_R, Ctrl) = Files.Commands.Refresh_Directory_Command,
         "control+r dispatches refresh command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F5, Guikit.Input.No_Modifiers) =
           Files.Commands.Refresh_Directory_Command,
         "F5 also dispatches refresh command as a secondary accelerator");
      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Refresh_Directory_Command).Key = Guikit.Input.Key_R,
         "refresh keeps control+r as its displayed primary shortcut");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_N, Ctrl_Shift) = Files.Commands.New_Folder_Command,
         "control+shift+n dispatches new-folder command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_C, Ctrl_Shift) = Files.Commands.Copy_Path_Command,
         "control+shift+c dispatches copy-path command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl) = Files.Commands.Toggle_Favorite_Command,
         "control+b dispatches toggle-favorite command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_S, Ctrl_Shift) = Files.Commands.Search_Recursive_Command,
         "control+shift+s dispatches recursive search command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_C, Ctrl) = Files.Commands.Copy_Selected_Items_Command,
         "plain control+c still dispatches copy, distinct from copy-path");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_S, Ctrl) = Files.Commands.Save_Settings_Command,
         "control+s dispatches settings save command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Delete, Guikit.Input.No_Modifiers) =
           Files.Commands.Delete_Selected_Items_Command,
         "delete dispatches delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Backspace, Guikit.Input.No_Modifiers) =
           Files.Commands.Delete_Selected_Items_Command,
         "backspace dispatches delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Delete, Shift) =
           Files.Commands.Delete_Selected_Permanently_Command,
         "shift+delete dispatches permanent delete command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_F2, Guikit.Input.No_Modifiers) =
           Files.Commands.Rename_Selected_Items_Command,
         "F2 dispatches rename command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Escape, Guikit.Input.No_Modifiers) =
           Files.Commands.Close_Command_Palette_Command,
         "escape dispatches context-cancel command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Return, Guikit.Input.No_Modifiers) =
           Files.Commands.Open_Selected_Items_Command,
         "return dispatches open-selected command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Z, Ctrl) = Files.Commands.Undo_Command,
         "Ctrl+Z dispatches the undo command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Z, Ctrl_Shift) = Files.Commands.Redo_Command,
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
            (True, Guikit.Input.Key_I, Ctrl)),
         "invert-selection uses Control+I");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Deselect_All_Command),
            (True, Guikit.Input.Key_A, Ctrl_Shift)),
         "deselect-all uses Control+Shift+A");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_I, Ctrl) = Files.Commands.Invert_Selection_Command,
         "Control+I resolves to invert-selection command");
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_A, Ctrl_Shift) = Files.Commands.Deselect_All_Command,
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

   procedure Test_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Ctrl (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;

      --  Parsing is the inverse of the formatter.
      declare
         Parsed : constant Files.Commands.Shortcut := Files.Commands.Parse_Shortcut ("control+1");
      begin
         Assert (Parsed.Present and then Parsed.Key = Guikit.Input.Key_1, "control+1 parses to the 1 key");
         Assert (Parsed.Modifiers (Guikit.Input.Control_Key)
                 and then not Parsed.Modifiers (Guikit.Input.Shift_Key),
                 "control+1 parses only the control modifier");
      end;
      Assert (Files.Commands.Text_To_Key ("f5") = Guikit.Input.Key_F5, "text-to-key maps a function key");
      Assert (Files.Commands.Text_To_Key ("nope") = Guikit.Input.Key_Unknown,
              "unrecognised text yields Key_Unknown");

      --  Defaults still resolve, and an override rebinds a chord to a command.
      Assert (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_1, Ctrl)
              = Files.Commands.Select_Small_Icons_Command,
              "ctrl+1 defaults to small icons");
      Assert (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift)
              = Files.Commands.No_Command,
              "ctrl+shift+b is unbound by default");
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Toggle_Show_Extensions_Command,
         (Present => True, Key => Guikit.Input.Key_B, Modifiers => Ctrl_Shift));
      Assert (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift)
              = Files.Commands.Toggle_Show_Extensions_Command,
              "an override binds the chosen chord to its command");
      Assert (Files.Commands.Shortcut_For (Files.Commands.Toggle_Show_Extensions_Command).Key
              = Guikit.Input.Key_B,
              "Shortcut_For resolves to the override");

      --  Clearing reverts to the default (here, no shortcut).
      Files.Commands.Clear_Shortcut_Override (Files.Commands.Toggle_Show_Extensions_Command);
      Assert (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift)
              = Files.Commands.No_Command,
              "clearing the override unbinds the chord");
      Assert (not Files.Commands.Shortcut_For (Files.Commands.Toggle_Show_Extensions_Command).Present,
              "the command has no default shortcut after clearing");

      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Shortcut_Overrides;

   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "path-target");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "loaded.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.path.missing");
      Ctrl (Guikit.Input.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_L, Ctrl);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert
        (Result.Command = Files.Commands.Open_Command_Palette_Command,
         "Control+P routes through command registry from path input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette from path input");
      Assert (Files.Model.Path_Input_Text (Model) = Root, "palette shortcut preserves edited path input text");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "Escape closes palette after path shortcut");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, Join (Root, "missing-path-target"));
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "modified Return does not commit path input");
      Assert (Files.Model.Current_Path (Model) = Root, "modified Return in path input does not navigate");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "modified Return keeps path input focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
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
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "filter focus executes command");
      Assert (Result.Command = Files.Commands.Focus_Filter_Input_Command, "filter command is routed");
      Assert (Files.Model.Last_Error_Key (Model) = "", "filter focus clears stale error state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "filter focus closes command palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input, "filter input receives focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "filter Escape clears focus before refocus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input, "filter shortcut refocuses filter input");
      Assert (Files.Model.Text_Cursor_Position (Model) = 4, "filter shortcut refocus places cursor at text end");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter click can reposition after refocus");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "same filter cursor click is ignored");
      Result := Files.Controller.Append_Focused_Text (Model, "X");
      Assert (Files.Model.Filter_Text (Model) = "beXta", "filter insert uses cursor position");
      Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter insert advances cursor from insertion point");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Backspace edits text");
      Assert (Result.Command = Files.Commands.No_Command, "filter Backspace does not route delete command");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Backspace removes character before cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 2, "filter Backspace moves cursor backward");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Delete edits text");
      Assert (Result.Command = Files.Commands.No_Command, "filter Delete does not route delete command");
      Assert (Files.Model.Filter_Text (Model) = "bea", "filter Delete removes character at cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter insert restores text at cursor");
      Assert (Files.Model.Selected_Name (Model) = "Beta.txt", "text delete preserves selected visible item");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "filter Home moves text cursor");
      Assert (Files.Model.Text_Cursor_Position (Model) = 0, "filter Home moves cursor to start");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Home at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Backspace at start is ignored");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Backspace at start leaves text unchanged");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert (Files.Model.Text_Cursor_Position (Model) = 4, "filter End moves cursor to end");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter End at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Right at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
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
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter Left moves before ASCII after UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Left moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert (Files.Model.Text_Cursor_Position (Model) = 0, "filter Left reaches start before UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Right moves over ASCII before UTF-8");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Assert (Files.Model.Text_Cursor_Position (Model) = 3, "filter Right moves over whole UTF-8 input");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
         Assert (Files.Model.Filter_Text (Model) = "ab", "filter Backspace removes whole UTF-8 input");
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Backspace lands before removed UTF-8 input");
         Files.Controller.Replace_Focused_Text (Model, "a" & Utf8_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Assert (Files.Model.Filter_Text (Model) = "ab", "filter Delete removes whole UTF-8 input");
         Assert (Files.Model.Text_Cursor_Position (Model) = 1, "filter Delete keeps cursor before UTF-8 input");

         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 1);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "model cursor setter snaps combining mark starts to the base boundary");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert (Result.Status = Files.Controller.Controller_Ignored, "filter Left at combining base is ignored");
         Files.Model.Set_Text_Cursor_Position (Model, Combining_Text'Length + 1);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = Combining_Text'Length,
            "filter Left moves before ASCII after combining text");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "filter Left moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = Combining_Text'Length,
            "filter Right moves over base and trailing combining marks together");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
         Assert
           (Files.Model.Filter_Text (Model) = "b",
            "filter Backspace removes base and trailing combining marks together");
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 0,
            "filter Backspace lands before removed combining sequence");
         Files.Controller.Replace_Focused_Text (Model, Combining_Text & "b");
         Files.Model.Set_Text_Cursor_Position (Model, 0);
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Left moves by word");
      Assert (Files.Model.Text_Cursor_Position (Model) = 11, "Control+Left stops before previous word");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Backspace deletes previous word");
      Assert (Files.Model.Filter_Text (Model) = "alpha gamma", "Control+Backspace removes previous word and separator");
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Backspace leaves cursor at word boundary");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "Control+Delete deletes next word");
      Assert (Files.Model.Filter_Text (Model) = "alpha ", "Control+Delete removes next word");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Delete at end is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Left at start is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "Control+Backspace at start is ignored");
      Files.Controller.Replace_Focused_Text (Model, "beta");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.LF & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats line feed as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Assert
        (Files.Model.Filter_Text (Model) = "beta",
         "Control+Backspace removes previous word across line feed");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.CR & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats carriage return as word separator");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.VT & "beta");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats vertical tab as word separator");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
      Assert
        (Files.Model.Filter_Text (Model) = "beta",
         "Control+Backspace removes previous word across vertical tab");

      Files.Controller.Replace_Focused_Text (Model, "alpha" & ASCII.FF & "beta");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
      Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before form feed");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
      Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across form feed");

      declare
         C1_Break : constant Character := Character'Val (133);
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Assert (Files.Model.Text_Cursor_Position (Model) = 6, "Control+Left treats C1 NEL as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Assert
           (Files.Model.Filter_Text (Model) = "beta",
            "Control+Backspace removes previous word across C1 NEL");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & C1_Break & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before C1 NEL");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
         Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across C1 NEL");
      end;
      declare
         NBSP : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Assert (Files.Model.Text_Cursor_Position (Model) = 7, "Control+Left treats UTF-8 NBSP as word separator");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace, Ctrl);
         Assert
           (Files.Model.Filter_Text (Model) = "beta",
            "Control+Backspace removes previous word across UTF-8 NBSP");

         Files.Controller.Replace_Focused_Text (Model, "alpha" & NBSP & "beta");
         Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Filter_Input, Cursor_Position => 5);
         Assert (Files.Model.Text_Cursor_Position (Model) = 5, "filter click positions cursor before UTF-8 NBSP");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete, Ctrl);
         Assert (Files.Model.Filter_Text (Model) = "alpha", "Control+Delete removes next word across UTF-8 NBSP");
      end;
      declare
         Line_Separator : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
      begin
         Files.Controller.Replace_Focused_Text (Model, "alpha" & Line_Separator & "beta");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
         Assert
           (Files.Model.Text_Cursor_Position (Model) = 8,
            "Control+Left treats UTF-8 line separator as word separator");
      end;
      Files.Controller.Replace_Focused_Text (Model, "beta");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "filter Return executes focus command");
      Assert (Result.Command = Files.Commands.Focus_Filter_Input_Command, "Return commits filter input");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "filter Return reports successful state-only commit");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "filter Return clears focus");
      Assert (Files.Model.Filter_Text (Model) = "beta", "filter Return preserves text");
      Assert (Files.Model.Current_Path (Model) = Root, "filter Return does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl_Shift);
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
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "F2 executes rename command");
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "F2 reports rename command");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "F2 focuses rename input");
      Assert
        (Files.Model.Text_Cursor_Position (Model) = 3,
         "F2 places rename cursor before the file extension");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert
        (Files.Model.Text_Cursor_Position (Model) = Files.Model.Rename_Text (Model)'Length,
         "End moves the rename cursor to the end of the name");
      Result := Files.Controller.Append_Focused_Text (Model, ".bak");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename append works immediately after F2");
      Assert
        (Files.Model.Rename_Text (Model) = "old.txt.bak",
         "initial rename cursor appends text at the end");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename Left moves cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Rename_Text (Model) = "new.ttx", "rename insert uses cursor position");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename append updates text");
      Assert (Files.Model.Rename_Text (Model) = "new.tttx", "rename second insert advances cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Assert (Result.Status = Files.Controller.Controller_Text_Updated, "rename Backspace edits text");
      Assert (Files.Model.Rename_Text (Model) = "new.ttx", "rename Backspace removes character before cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Files.Model.Rename_Text (Model) = "new.tt", "rename Delete removes character at cursor");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Assert (Files.Model.Text_Cursor_Position (Model) = 6, "rename replacement clamps cursor to text end");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Assert (Files.Model.Rename_Text (Model) = "new.txt", "rename append restores commit text");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "rename Return executes rename command");
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "rename Return reports rename command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "Return commits rename");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "rename file exists after Return");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename Return clears rename mode");
   end Test_Controller_Rename_Return;
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "F2 enters rename before palette opens");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "Control+P routes from rename input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette over rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Command_Palette, "palette takes focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Status = Files.Controller.Controller_Palette_Updated, "Escape first updates palette state");
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "Escape first closes palette");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "Escape closes the open palette");
      Assert (Files.Model.Rename_Is_Active (Model), "Escape does not cancel rename while palette is open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "closed palette clears palette focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "second Escape routes context cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "second Escape cancels pending rename");
      Assert (Files.Model.Text_Cursor_Position (Model) = 0, "second Escape clears stale rename cursor");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "second Escape leaves focus clear");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Rename_Input, Cursor_Position => 2);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "inactive rename text click is ignored");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "inactive rename text click does not focus input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "idle Escape is ignored");
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "idle Escape still reports context command");
   end Test_Controller_Command_Palette_Escape_Priority;
   procedure Test_Copy_Path_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model      : Files.Model.Window_Model := Sample_Model;
      Empty      : Files.File_System.Item_Vectors.Vector;
      Pair       : Files.File_System.Item_Vectors.Vector;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result     : Files.Controller.Controller_Result;
      Alpha_Path : constant String := Join (Root, "Alpha.txt");
      Beta_Path  : constant String := Join (Root, "Beta.txt");
      Gamma_Path : constant String := Join (Root, "Gamma.md");
   begin
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;

      --  Pure, filesystem-free join seam.
      Assert (Files.Commands.Joined_Full_Paths (Empty) = "", "an empty selection joins to empty text");
      Pair.Append (Files.File_System.Make_Item (Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
      Pair.Append (Files.File_System.Make_Item (Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
      Assert
        (Files.Commands.Joined_Full_Paths (Pair) = Alpha_Path & ASCII.LF & Beta_Path,
         "full paths join one per line in item order");

      --  Enablement follows the selection.
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Copy_Path_Command, Model),
         "copy-path is disabled with no selection");
      Files.Model.Select_All_Visible (Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Copy_Path_Command, Model),
         "copy-path is enabled with a real selection");

      --  Executing records the system-clipboard request without touching disk.
      Assert
        (not Files.Model.System_Clipboard_Request_Pending (Model),
         "no clipboard request is pending before copy-path runs");
      Files.Commands.Execute (Files.Commands.Copy_Path_Command, Model);
      Assert
        (Files.Model.System_Clipboard_Request_Pending (Model),
         "copy-path records a pending system-clipboard request");
      Assert
        (Files.Model.System_Clipboard_Request_Text (Model) =
           Alpha_Path & ASCII.LF & Beta_Path & ASCII.LF & Gamma_Path,
         "copy-path stores the newline-joined selection paths");
      Files.Model.Clear_System_Clipboard_Request (Model);
      Assert
        (not Files.Model.System_Clipboard_Request_Pending (Model),
         "the shell clears the request once consumed");

      --  Control+Shift+C routes to the command through the controller.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_C, Ctrl_Shift);
      Assert (Result.Command = Files.Commands.Copy_Path_Command, "Control+Shift+C routes to copy-path");
   end Test_Copy_Path_Command;

   procedure Test_Open_Containing_Folder_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sub      : constant String := Join (Root, "sub");
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Write_File (Join (Sub, "found.txt"));

      --  A recursive-search-style model: the current directory is Root, but the
      --  single result item lives in Root/sub.
      Items.Append (Files.File_System.Make_Item (Sub, "found.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);

      --  Disabled without a selection, enabled with a single result selected.
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Containing_Folder_Command, Model),
         "reveal is disabled with no selection");
      Select_Name (Model, "found.txt");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Open_Containing_Folder_Command, Model),
         "reveal is enabled for a single selected result");

      Result :=
        Files.Controller.Execute_Command (Files.Commands.Open_Containing_Folder_Command, Model, Settings);
      Assert
        (Result.Command = Files.Commands.Open_Containing_Folder_Command,
         "reveal reports its command");
      Assert
        (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Sub),
         "reveal navigates to the item's containing folder");
      Assert
        (Files.Model.Selected_Count (Model) = 1
           and then To_String (Files.Model.Selected_Items (Model).First_Element.Name) = "found.txt",
         "reveal selects the item in its containing folder");
   end Test_Open_Containing_Folder_Command;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Command_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Commands;

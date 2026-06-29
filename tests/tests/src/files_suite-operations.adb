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

with Zlib;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Applications;
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

package body Files_Suite.Operations is

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

   type Operation_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Operation_Test_Case);

   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Operation_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files operations");
   end Name;

   overriding procedure Register_Tests (T : in out Operation_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Delete_Selected_Operation'Access, "delete operation moves selected item to trash");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash'Access, "restore operation returns trashed item to original path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_Directory_Loads_Items'Access, "open directory loads and navigates");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_File_Prepares_Action'Access, "open file executes configured action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Missing_Open_Action_Reports_Error'Access, "missing open action reports localized error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_File'Access, "commit create-file temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_Folder'Access, "commit create-folder temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Does_Not_Overwrite'Access, "create-file refuses existing destination");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Advanced_Filesystem_Operations'Access, "advanced filesystem operations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_File_Operation_Names'Access, "file operation invalid names");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Rename'Access, "commit rename mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Metadata_Snapshot'Access, "info pane snapshot includes metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Refresh_And_History_Loading'Access, "controller refresh and history load items");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compress_Selected_Operation'Access, "compress selected items into zip and 7z archives");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Duplicate_Selected_Operation'Access, "duplicate selected item into a uniquely named copy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extract_Selected_Operation'Access, "extract selected archive into a new folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Available_Applications'Access, "open-with discovers and parses desktop applications");
   end Register_Tests;

   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_xdg_data";
      Mac_Home     : constant String := Root & "_mac_home";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Special_Path  : constant String := Join (Root, "space % file.txt");
      Nested_Trash_Source : constant String := Join (Root, "nested-trash-source");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation      : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 0.0)) =
         "2024-02-03T00:00:00",
         "trash deletion date formats midnight");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 60.9)) =
         "2024-02-03T00:01:00",
         "trash deletion date floors fractional seconds");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 86_399.9)) =
         "2024-02-03T23:59:59",
         "trash deletion date does not round up near midnight");
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Clear ("HOME");
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Assert (not Files.File_System.Trash_Is_Available, "trash availability detects missing trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
         "trash backend reports unavailable when no trash base exists");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "unavailable trash backend reports no metadata sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Diagnostics,
         "trash capabilities expose native diagnostic policy");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "trash capabilities expose multi-item preflight policy");
      Write_File (Join (Root, "blocked-trash-parent"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Join (Root, "blocked-trash-parent"), "xdg"));
      Assert
        (not Files.File_System.Trash_Is_Available,
         "trash availability rejects a regular file in the trash parent chain");
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "missing-for-blocked-trash.txt"));
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "missing trash target still reports failed trash mutation");
      Mutation :=
        Files.File_System.Move_To_Trash_Preflight
          (Root & "/bad" & Character'Val (0) & "trash-target.txt");
      Assert (not Mutation.Success, "malformed trash target reports failed trash mutation");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "malformed trash target reports failed trash diagnostic");
      Write_File (Join (Root, "blocked-trash-target.txt"));
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "blocked-trash-target.txt"));
      Assert (not Mutation.Success, "trash preflight rejects blocked trash parent chain");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.unavailable",
         "blocked trash parent chain reports unavailable trash");
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-parent"));
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-target.txt"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Assert (Files.File_System.Trash_Is_Available, "trash availability detects XDG trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Xdg_Data_Home,
         "trash backend reports XDG data home when configured");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "XDG trash backend reports trashinfo sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Collision_Safe_Name,
         "XDG trash backend reports collision-safe naming");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "XDG trash backend reports multi-item preflight support");
      Mutation := Files.File_System.Move_To_Trash_Preflight ("/");
      Assert (not Mutation.Success, "trash preflight rejects filesystem root");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "filesystem root trash preflight reports failed trash mutation");
      declare
         Prefix_Source : constant String := Join (Root, "trash-prefix-source");
         Prefix_Base   : constant String := Prefix_Source & "-xdg";
      begin
         Write_File (Prefix_Source);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Prefix_Base);
         Mutation := Files.File_System.Move_To_Trash_Preflight (Prefix_Source);
         Assert (Mutation.Success, "trash preflight accepts sibling paths sharing a prefix");
         Assert
           (To_String (Mutation.Error_Key) = "",
            "trash prefix-sibling preflight has no diagnostic");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Directories.Delete_File (Prefix_Source);
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Windows_Recycle_Bin,
         "trash backend can represent native Windows recycle-bin intent");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Platform,
         "native Windows trash backend reports native-platform intent");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Permanent_Delete,
         "native trash capability does not opt into permanent deletion");
      declare
         Request : constant Files.File_System.Native_Trash_Request :=
           Files.File_System.Native_Trash_Request_For (Join (Root, "missing-for-native-trash.txt"));
         Native_Result : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Evaluate_Native_Trash (Request);
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
      begin
         Assert (Request.Requires_Native_Api, "native trash request records native API requirement");
         Assert (not Request.Can_Use_Current_Process, "native trash request does not claim local fallback");
         Assert (not Native_Result.Supported, "native trash result reports unsupported native adapter");
         Assert (not Native_Result.Attempted, "native trash evaluation does not attempt mutation");
         Assert (not Native_Result.Completed, "native trash evaluation does not complete mutation");
         Assert (not Native_Result.Native_Binding_Available, "Windows native trash binding is unavailable here");
         Assert
           (Native_Result.Native_Binding_Status = Files.File_System.Native_API_Not_Target,
            "Windows native trash binding reports non-target status here");
         Assert
           (To_String (Native_Result.Binding_Unit) = "Files.Platform.Windows.Trash",
            "Windows native trash result records binding unit");
         Assert (not Native_Result.Desktop_Standard, "Windows native trash is not a desktop-standard fallback");
         Assert (Native_Result.Uses_Recycle_Bin, "Windows native trash result records recycle-bin target");
         Assert
           (To_String (Native_Result.Adapter_Name) = "windows.recycle_bin",
            "Windows native trash result records adapter name");
         Assert
           (To_String (Native_Result.Native_Api_Name) = "IFileOperation",
            "Windows native trash result records native API name");
         Assert
           (To_String (Native_Result.Operation_Name) = "move_to_trash",
            "native trash result records operation name");
         Assert (Native_Result.Preserves_Metadata, "native trash result records metadata-preservation intent");
         Assert
           (not Native_Result.Requires_User_Consent,
            "native trash result records no in-app consent requirement");
         Assert
           (To_String (Native_Result.Error_Key) = "error.trash.native_unavailable",
            "native trash result reports native-unavailable diagnostic");
         Assert (not Native_Execution.Supported, "native trash execution reports unsupported adapter");
         Assert (not Native_Execution.Attempted, "native trash execution does not attempt unsupported adapter");
         Assert
           (not Native_Execution.Native_Binding_Available,
            "native trash execution reports unavailable binding");
         Assert
           (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Not_Target,
            "native trash execution preserves binding status");
         Assert
           (To_String (Native_Execution.Error_Key) = "error.trash.native_unavailable",
            "native trash execution reports native-unavailable diagnostic");
      end;
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "missing-for-native-trash.txt"));
      Assert (not Mutation.Success, "unimplemented native Windows trash fails as recoverable data");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.native_unavailable",
         "native Windows trash reports native-unavailable diagnostic");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Native,
         "trash backend can represent native macOS trash intent");
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Write_File (Join (Root, "native-execute.txt"));
      declare
         Request : constant Files.File_System.Native_Trash_Request :=
           Files.File_System.Native_Trash_Request_For (Join (Root, "native-execute.txt"));
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
      begin
         Assert (Request.Can_Use_Current_Process, "XDG trash request can execute in current process");
         Assert (Native_Execution.Supported, "XDG trash execution reports supported adapter");
         Assert (Native_Execution.Attempted, "XDG trash execution attempts mutation");
         Assert (Native_Execution.Completed, "XDG trash execution completes mutation");
         Assert (Native_Execution.Desktop_Standard, "XDG trash execution reports desktop-standard backend");
         Assert
           (not Native_Execution.Native_Binding_Available,
            "XDG trash execution does not claim OS-specific native binding");
         Assert
           (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Binding_Missing,
            "XDG trash execution reports no OS-specific native binding");
         Assert
           (To_String (Native_Execution.Binding_Unit) = "Files.File_System.Move_To_Trash",
            "XDG trash execution records binding unit");
         Assert
           (not Ada.Directories.Exists (Join (Root, "native-execute.txt")),
            "XDG trash execution moves source entry");
         Assert
           (To_String (Native_Execution.Adapter_Name) = "xdg.trash",
            "XDG trash execution records adapter name");
         Assert
           (To_String (Native_Execution.Error_Key) = "",
            "XDG trash execution has no error key");
      end;
      Write_File (Join (Root, "doomed.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Command = Files.Commands.Delete_Selected_Items_Command, "Delete routes through command registry");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "available trash moves selected item");
      Assert (To_String (Result.Operation.Path) = Join (Root, "doomed.txt"), "delete operation reports target path");
      Assert (To_String (Result.Operation.Error_Key) = "", "successful trash move has no error key");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful trash move clears model error");
      Assert (not Ada.Directories.Exists (Join (Root, "doomed.txt")), "trash move removes file from source");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")), "trash move stores file under XDG trash");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.trashinfo")),
         "trash move writes trashinfo metadata");
      Assert (Files.Model.Selected_Count (Model) = 0, "successful delete reconciles selection");
      Mutation := Files.File_System.Move_To_Trash (Join (Trash_File, "doomed.txt"));
      Assert (not Mutation.Success, "trash preflight rejects items already inside trash");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "already-trashed item reports trash failure");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")),
         "already-trashed item remains in place after rejected trash move");

      Write_File (Join (Root, "doomed.txt"), "again");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads collision target");
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second same-name delete succeeds");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt.2")), "trash collision chooses suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.2.trashinfo")),
         "trash collision writes suffixed metadata");

      Write_File (Join (Trash_Info, "sidecar-only.txt.trashinfo"));
      Write_File (Join (Root, "sidecar-only.txt"));
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "sidecar-only.txt"));
      Assert (Mutation.Success, "trash sidecar-only collision succeeds with suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "sidecar-only.txt.2")),
         "trash sidecar-only collision chooses suffix");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.2.trashinfo")),
         "trash sidecar-only collision writes suffixed metadata");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.trashinfo")),
         "trash sidecar-only collision preserves existing metadata sidecar");

      Write_File (Join (Root, "doomed2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads second delete target");
      Select_Name (Model, "doomed2.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Backspace);
      Assert
        (Result.Command = Files.Commands.Delete_Selected_Items_Command,
         "Backspace routes through same delete command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "Backspace delete uses trash operation");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed2.txt")), "Backspace moves file to trash");

      Write_File (Special_Path);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads encoded trash target");
      Select_Name (Model, "space % file.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "encoded trash target moves to trash");
      Assert
        (Project_Tools.Files.File_Contains
           (Join (Trash_Info, "space % file.txt.trashinfo"),
            "Path=" & Ada.Directories.Full_Name (Root) & "/space%20%25%20file.txt"),
         "trashinfo path percent-encodes spaces and percent signs");

      Write_File (Join (Root, "multi-a.txt"));
      Write_File (Join (Root, "multi-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads multi-delete targets");
      Files.Model.Set_Filter (Model, "multi-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "multi-selection delete succeeds");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-a.txt")), "multi-delete moves first file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-b.txt")), "multi-delete moves second file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-a.txt")), "multi-delete removes first source file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-b.txt")), "multi-delete removes second source file");

      Write_File (Join (Root, "partial-a.txt"));
      Write_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads partial-delete targets");
      Files.Model.Set_Filter (Model, "partial-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Ada.Directories.Delete_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "partial multi-delete reports failure");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.trash.failed",
         "partial multi-delete reports trash failure");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "partial-a.txt")),
         "partial multi-delete does not move earlier files before preflight failure");
      Assert
        (Ada.Directories.Exists (Join (Root, "partial-a.txt")),
         "partial multi-delete leaves earlier source files in place");
      Assert (Files.Model.Item_Count (Model) = 1, "partial multi-delete reloads stale directory model");
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.failed", "partial multi-delete keeps error state");

      Ada.Directories.Create_Path (Nested_Trash_Source);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Nested_Trash_Source, "xdg-data"));
      Mutation := Files.File_System.Move_To_Trash (Nested_Trash_Source);
      Assert (not Mutation.Success, "trash move into a source subdirectory fails");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "nested trash move reports trash failure");
      Assert (Ada.Directories.Exists (Nested_Trash_Source), "failed nested trash keeps source directory");
      Assert
        (not Ada.Directories.Exists
           (Join (Join (Join (Nested_Trash_Source, "xdg-data"), "Trash"), "info")
            & "/nested-trash-source.trashinfo"),
         "failed nested trash removes stale trashinfo metadata");

      declare
         Guard_Directory : constant String := Join (Root, "guard-preflight-z-dir");
         First_File      : constant String := Join (Root, "guard-preflight-a.txt");
         Guard_Trash     : constant String := Join (Join (Guard_Directory, "xdg-data"), "Trash");
         Guard_Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Guard_Load      : Files.File_System.Directory_Load_Result;
         Guard_Model     : Files.Model.Window_Model;
         Guard_Result    : Files.Controller.Controller_Result;
      begin
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Guard_Directory, "xdg-data"));
         Write_File (First_File);
         Ada.Directories.Create_Path (Guard_Directory);
         Guard_Load := Files.File_System.Load_Directory (Root, Guard_Settings);
         Assert (Guard_Load.Success, "guarded multi-delete setup loads");
         Files.Model.Initialize (Guard_Model, Root, Guard_Load.Items, Root);
         Files.Model.Set_Filter (Guard_Model, "guard-preflight-");
         Files.Model.Select_Visible (Guard_Model, 1);
         Files.Model.Toggle_Visible_Selection (Guard_Model, 2);

         Guard_Result := Files.Controller.Handle_Key (Guard_Model, Guard_Settings, Files.Types.Key_Delete);
         Assert
           (Guard_Result.Operation.Status = Files.Operations.Operation_Failed,
            "multi-delete preflights nested trash targets");
         Assert
           (To_String (Guard_Result.Operation.Error_Key) = "error.trash.failed",
            "multi-delete nested trash preflight reports trash failure");
         Assert
           (Ada.Directories.Exists (First_File),
            "multi-delete nested trash preflight does not move earlier selected files");
         Assert (Ada.Directories.Exists (Guard_Directory), "nested trash preflight keeps guarded directory");
         Assert
           (not Ada.Directories.Exists (Join (Join (Guard_Trash, "files"), "guard-preflight-a.txt")),
            "multi-delete nested trash preflight does not create a trash target for earlier files");
         Assert
           (Files.Model.Last_Error_Key (Guard_Model) = "error.trash.failed",
            "multi-delete nested trash preflight preserves model error");
      end;

      Project_Tools.Files.Delete_Tree (Mac_Home);
      Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Set ("HOME", Mac_Home);
      Write_File (Join (Root, "mac-trash.txt"));
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "mac-trash.txt"));
      Assert (Mutation.Success, "macOS-style home trash fallback moves files");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Home,
         "trash backend reports macOS-style home trash when present");
      Assert
        (Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "mac-trash.txt")),
         "macOS-style home trash stores the file directly under ~/.Trash");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "files")),
         "macOS-style home trash does not create a freedesktop files/ subdirectory");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "info")),
         "macOS-style home trash does not create a freedesktop info/ subdirectory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Project_Tools.Files.Delete_Tree (Mac_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Delete_Selected_Operation;

   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_restore_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Source_Path  : constant String := Join (Root, "restore-me.txt");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);

      Write_File (Source_Path, "payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "restore setup moves source file to trash");
      Assert (not Ada.Directories.Exists (Source_Path), "restore setup removes source file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")), "restore setup stores trashed payload");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore setup writes trashinfo sidecar");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "restore navigates into trash files directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "restore-me.txt");
      Assert (Files.Model.Selected_Count (Model) = 1, "restore selects the trashed item");

      Result :=
        Files.Controller.Execute_Command (Files.Commands.Restore_From_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "restore command returns success");
      Assert (Ada.Directories.Exists (Source_Path), "restore returns the file to its original path");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")),
         "restore removes the trashed payload");
      Assert
        (not Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore removes the trashinfo sidecar");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash;

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "open-dir");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Join (Root, "other-dir"));
      Write_File (Join (Dir, "child.txt"));
      Items.Append (Files.File_System.Make_Item (Root, "open-dir", Files.Types.Directory_Item, "inode/directory"));
      Items.Append (Files.File_System.Make_Item (Root, "other-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Disabled,
         "pending create selection blocks direct open preparation");
      Assert
        (To_String (Result.Error_Key) = "error.selection.empty",
         "pending create open preparation reports disabled selection");
      Assert (Files.Model.Current_Path (Model) = Root, "preparing directory open does not navigate");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.selection.empty",
         "preparing pending create open records disabled state");
      Files.Model.Set_Error (Model, "error.directory.load");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "pending create item cannot be opened directly");
      Assert (Files.Model.Current_Path (Model) = Root, "disabled pending create open keeps path");

      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert
        (To_String (Routed.Operation.Path) = Ada.Directories.Full_Name (Dir),
         "directory open returns loaded path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "directory open changes path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "directory open clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "directory open clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "directory open clears rename state");
      Assert (Files.Model.Rename_Text (Model) = "", "directory open clears stale rename text");
      Assert (Files.Model.Temporary_Item_Name (Model) = "", "directory open clears stale temporary name");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "directory open clears rename focus");
      Assert (Files.Model.Item_Count (Model) = 1, "directory open loads destination items");
      Assert (Files.Model.Visible_Item (Model, 1).Name = To_Unbounded_String ("child.txt"), "child item is loaded");

      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "multi-directory open is rejected");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.multi_directory",
         "multi-directory open reports localized diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.multi_directory",
         "multi-directory open records localized diagnostic key");
      Assert (Files.Model.Current_Path (Model) = Root, "multi-directory open does not navigate");

      Files.Model.Initialize (Model, Root, Items, Root);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Activate => True);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click routes open command");
      Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated, "double-click opens directory");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir), "double-click changes path");
   end Test_Open_Selected_Directory_Loads_Items;

   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Arguments : Files.Settings.String_Vectors.Vector;
      Shell_Arguments : Files.Settings.String_Vectors.Vector;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Model     : Files.Model.Window_Model := Sample_Model;
      Result    : Files.Operations.Operation_Result;
      Routed    : Files.Controller.Controller_Result;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Policy    : constant Files.Operations.Open_Action_Execution_Policy :=
        Files.Operations.Open_Action_Policy;
   begin
      --  Exercise the configured-action and missing-action contracts
      --  deterministically; the host opener fallback would otherwise resolve
      --  unmapped lookups in this environment.
      Settings.Use_System_Default_Opener := False;
      Assert (Policy.Uses_Argument_Vector, "open-action policy requires argument vectors");
      Assert (Policy.Shell_Requires_Explicit_Opt_In, "open-action policy requires explicit shell opt-in");
      Assert (Policy.Checks_Executable_Before_Spawn, "open-action policy checks executables before spawn");
      Assert (Policy.Tracks_Execution_Attempt, "open-action policy tracks execution attempts");
      Assert (Policy.Tracks_Exit_Status, "open-action policy tracks exit status");
      Assert (not Policy.Runs_Asynchronously, "open-action policy records synchronous execution limit");
      Assert (not Policy.Supports_Cancellation, "open-action policy records cancellation limit");
      Assert
        (Policy.Rejects_Unsafe_Placeholders,
         "open-action policy records unsafe placeholder rejection");
      Assert (Policy.Reports_Missing_Action, "open-action policy records missing-action diagnostics");
      Assert
        (Policy.Reports_Missing_Executable,
         "open-action policy records missing-executable diagnostics");
      Assert
        (Policy.Captures_Executable_Discovery,
         "open-action policy records executable discovery capture");
      Assert (Policy.Captures_Process_Result, "open-action policy records process result capture");
      Assert (Policy.Quotes_Shell_Arguments, "open-action policy records shell argument quoting");
      Assert
        (Policy.Preserves_Vector_Boundaries,
         "open-action policy records argument vector boundary preservation");
      Assert (Policy.Multi_File_Deterministic, "open-action policy records deterministic multi-file execution");
      declare
         Generic_Failure : constant Files.Operations.Operation_Result :=
           (Status              => Files.Operations.Operation_Failed,
            Error_Key           => To_Unbounded_String ("error.directory.load"),
            Path                => To_Unbounded_String (Root),
            Action              =>
              Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            Action_Executable   => Null_Unbounded_String,
            Action_Arguments    => 0,
            Action_Uses_Shell   => False,
            Execution_Attempted => False,
            Executable_Found    => False,
            Exit_Status_Known   => False,
            Exit_Status         => 0);
      begin
         Assert
           (Files.Operations.Open_Action_Lifecycle_Of (Generic_Failure).State =
            Files.Operations.Open_Action_Not_Started,
            "generic failed operations are not classified as open-action preflight failures");
      end;
      Arguments.Append (To_Unbounded_String ("--readonly"));
      Arguments.Append (To_Unbounded_String ("{path}"));
      Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action ("/bin/true", Arguments));
      Modifiers (Files.Types.Control_Key) := True;
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Set_Error (Model, "error.open_action.missing");

      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "file open action can be prepared without spawn");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "prepared action reports selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "prepared action clears stale error state");
      Assert (To_String (Result.Action.Executable) = "/bin/true", "prepared action uses configured executable");
      Assert (To_String (Result.Action_Executable) = "/bin/true", "prepared result exposes executable text");
      Assert (Result.Action_Arguments = 3, "prepared result exposes argument count");
      Assert (not Result.Execution_Attempted, "prepared action does not execute");
      Assert (not Result.Action.Use_Shell, "prepared action preserves non-shell execution");
      Assert (Natural (Result.Action.Arguments.Length) = 3, "prepared action preserves argument vector");
      Assert (To_String (Result.Action.Arguments.Element (1)) = "--readonly", "literal argument is preserved");
      Assert (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"), "path placeholder expands");
      Assert (To_String (Result.Action.Arguments.Element (3)) = "Alpha.txt", "name placeholder expands");

      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed, "file open executes an action");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "file open returns selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "executed open action clears stale error state");
      Assert (To_String (Result.Action.Executable) = "/bin/true", "executed action uses configured executable");
      Assert (To_String (Result.Action_Executable) = "/bin/true", "executed result exposes executable text");
      Assert (Result.Action_Arguments = 3, "executed result exposes argument count");
      Assert (Result.Execution_Attempted, "executed result records process attempt");
      Assert (Result.Executable_Found, "executed result records executable discovery");
      Assert (not Result.Action.Use_Shell, "executed non-shell action does not request shell execution");
      Assert (Natural (Result.Action.Arguments.Length) = 3, "executed action preserves argument vector");
      Assert (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"), "path placeholder expands");
      Assert (To_String (Result.Action.Arguments.Element (3)) = "Alpha.txt", "name placeholder expands");
      Assert (Files.Model.Current_Path (Model) = Root, "opening a non-directory does not navigate");
      declare
         Lifecycle : constant Files.Operations.Open_Action_Lifecycle :=
           Files.Operations.Open_Action_Lifecycle_Of (Result);
      begin
         Assert
           (Lifecycle.State = Files.Operations.Open_Action_Completed,
            "open-action lifecycle records completed action");
         Assert (To_String (Lifecycle.Executable) = "/bin/true", "lifecycle records executable");
         Assert (Lifecycle.Argument_Count = 3, "lifecycle records argument count");
         Assert (Lifecycle.Exit_Status_Known, "lifecycle records known exit status");
         Assert (Lifecycle.Exit_Status = 0, "lifecycle records successful process status");
      end;

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("/bin/true", Files.Settings.String_Vectors.Empty_Vector));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed, "zero-argument open action executes");
      Assert (To_String (Result.Action_Executable) = "/bin/true", "zero-argument action exposes executable");
      Assert (Result.Action_Arguments = 0, "zero-argument action exposes empty argument vector");
      Assert (Result.Execution_Attempted, "zero-argument action records process attempt");
      Assert (Result.Executable_Found, "zero-argument action records executable discovery");
      Assert (Result.Exit_Status_Known, "zero-argument action records exit status");
      Assert (Result.Exit_Status = 0, "zero-argument action records successful exit");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Set_Error (Model, "error.open_action.execution");
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "multi-file open action can be prepared");
      Assert (not Result.Execution_Attempted, "multi-file open preparation does not execute actions");
      Assert
        (To_String (Result.Path) = Join (Root, "Alpha.txt"),
         "multi-file open preparation reports first selected path");
      Assert
        (To_String (Result.Action_Executable) = "/bin/true",
         "multi-file open preparation exposes first executable");
      Assert (Files.Model.Last_Error_Key (Model) = "", "multi-file open preparation clears stale error state");
      Result := Files.Operations.Open_Selected (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Action_Executed, "multi-file open executes actions");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "multi-file open reports first selected path");
      Assert (Result.Execution_Attempted, "multi-file open records process attempts");
      Assert (Result.Executable_Found, "multi-file open records executable discovery");
      Assert (To_String (Result.Action_Executable) = "/bin/true", "multi-file open exposes first action executable");
      Assert (Result.Action_Arguments = 3, "multi-file open exposes first action argument count");
      Assert
        (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "multi-file open exposes first expanded action path");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Completed,
         "multi-file open lifecycle records completed action");
      Assert (Files.Model.Last_Error_Key (Model) = "", "multi-file open clears stale error state");
      Files.Model.Select_Visible (Model, 1);

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-preflight-marker");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         Preflight_Args.Append (To_Unbounded_String ("-c"));
         Preflight_Args.Append (To_Unbounded_String ("touch " & Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action ("/bin/sh", Preflight_Args));
         --  Keep the missing-action preflight deterministic by opting out of
         --  the host opener fallback for the unmapped second selection.
         Preflight_Settings.Use_System_Default_Opener := False;
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result :=
           Files.Operations.Prepare_Open_Selected_Action (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preparation preflights all actions");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file open preparation failure records no process attempt");
         Assert
           (To_String (Preflight_Result.Path) = Join (Root, "Gamma.md"),
            "multi-file open preparation failure reports missing-action path");
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Missing_Open_Action,
            "multi-file open preflights all actions before spawning");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
           "multi-file preflight failure does not execute earlier selected action");
      end;

      declare
         Preflight_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Preflight_Model    : Files.Model.Window_Model := Sample_Model;
         Preflight_Args     : Files.Settings.String_Vectors.Vector;
         Marker_Path        : constant String := Join (Root, "multi-open-executable-marker");
         Missing_Executable : constant String := Join (Root, "missing-open-executable");
         Preflight_Result   : Files.Operations.Operation_Result;
      begin
         if Ada.Directories.Exists (Marker_Path) then
            Ada.Directories.Delete_File (Marker_Path);
         end if;

         Preflight_Args.Append (To_Unbounded_String ("-c"));
         Preflight_Args.Append (To_Unbounded_String ("touch " & Marker_Path));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/plain",
            Files.Settings.Make_Action ("/bin/sh", Preflight_Args));
         Files.Settings.Add_Open_Action
           (Preflight_Settings,
            "text/markdown",
            Files.Settings.Make_Action (Missing_Executable, Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Preflight_Model, 1);
         Files.Model.Toggle_Visible_Selection (Preflight_Model, 3);
         Preflight_Result := Files.Operations.Open_Selected (Preflight_Model, Preflight_Settings);
         Assert
           (Preflight_Result.Status = Files.Operations.Operation_Failed,
            "multi-file open preflights missing executables before spawning");
         Assert
           (To_String (Preflight_Result.Error_Key) = "error.open_action.executable_missing",
            "multi-file executable preflight reports executable diagnostic");
         Assert
           (not Preflight_Result.Execution_Attempted,
            "multi-file executable preflight failure records no process attempt");
         Assert
           (not Ada.Directories.Exists (Marker_Path),
            "multi-file executable preflight failure does not execute earlier selected action");
      end;

      declare
         Detached_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Detached_Model    : Files.Model.Window_Model := Sample_Model;
         Detached_Result   : Files.Operations.Operation_Result;
      begin
         --  Open actions are now launched detached (fire-and-forget) through a
         --  backgrounding shell wrapper, so a launched application's own exit
         --  code is no longer observable: even /bin/false reports success
         --  because the wrapper shell itself exits zero after backgrounding.
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/plain",
            Files.Settings.Make_Action ("/bin/true", Files.Settings.String_Vectors.Empty_Vector));
         Files.Settings.Add_Open_Action
           (Detached_Settings,
            "text/markdown",
            Files.Settings.Make_Action ("/bin/false", Files.Settings.String_Vectors.Empty_Vector));
         Files.Model.Select_Visible (Detached_Model, 1);
         Files.Model.Toggle_Visible_Selection (Detached_Model, 3);
         Detached_Result := Files.Operations.Open_Selected (Detached_Model, Detached_Settings);
         Assert
           (Detached_Result.Status = Files.Operations.Operation_Action_Executed,
            "multi-file detached open succeeds without surfacing app exit codes");
         Assert
           (To_String (Detached_Result.Path) = Join (Root, "Alpha.txt"),
            "multi-file detached open reports first selected path");
         Assert
           (To_String (Detached_Result.Action_Executable) = "/bin/true",
            "multi-file detached open exposes first action executable");
         Assert
           (Detached_Result.Execution_Attempted,
            "multi-file detached open records process attempt");
         Assert
           (Detached_Result.Executable_Found,
            "multi-file detached open records executable discovery");
         Assert
           (Detached_Result.Exit_Status_Known,
            "multi-file detached open records exit status");
         Assert
           (Detached_Result.Exit_Status = 0,
            "multi-file detached open records the wrapper shell zero exit");
         Assert
           (Files.Model.Last_Error_Key (Detached_Model) = "",
            "multi-file detached open clears stale error state");
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then Ada.Environment_Variables.Value ("SHELL") else ""));

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", "/bin/custom-sh");
         Assert (Files.Operations.Shell_Executable = "/bin/custom-sh", "explicit shell uses SHELL fallback");
         Assert (Files.Operations.Shell_Command_Option = "-c", "SHELL fallback uses POSIX command option");
         Ada.Environment_Variables.Set ("COMSPEC", "C:\Windows\System32\cmd.exe");
         Assert
           (Files.Operations.Shell_Executable = "C:\Windows\System32\cmd.exe",
            "explicit shell prefers COMSPEC when present");
         Assert (Files.Operations.Shell_Command_Option = "/C", "COMSPEC shell uses Windows command option");
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      declare
         Had_Comspec : constant Boolean := Ada.Environment_Variables.Exists ("COMSPEC");
         Had_Shell   : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
         Old_Comspec : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Comspec then Ada.Environment_Variables.Value ("COMSPEC") else ""));
         Old_Shell   : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Shell then Ada.Environment_Variables.Value ("SHELL") else ""));
         Missing_Shell_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Missing_Shell_Model    : Files.Model.Window_Model := Sample_Model;
         Missing_Shell_Action   : Files.Operations.Operation_Result;

         procedure Restore_Shell_Environment is
         begin
            if Had_Comspec then
               Ada.Environment_Variables.Set ("COMSPEC", To_String (Old_Comspec));
            else
               Ada.Environment_Variables.Clear ("COMSPEC");
            end if;

            if Had_Shell then
               Ada.Environment_Variables.Set ("SHELL", To_String (Old_Shell));
            else
               Ada.Environment_Variables.Clear ("SHELL");
            end if;
         end Restore_Shell_Environment;
      begin
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", Join (Root, "missing-shell"));
         Files.Settings.Add_Open_Action
           (Missing_Shell_Settings,
            "text/plain",
            Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, Use_Shell => True));
         Files.Model.Select_Visible (Missing_Shell_Model, 1);
         Missing_Shell_Action := Files.Operations.Open_Selected (Missing_Shell_Model, Missing_Shell_Settings);
         Assert
           (Missing_Shell_Action.Status = Files.Operations.Operation_Failed,
            "explicit shell action fails preflight when shell executable is missing");
         Assert
           (not Missing_Shell_Action.Execution_Attempted,
            "missing shell executable is rejected before spawn");
         Assert
           (not Missing_Shell_Action.Executable_Found,
            "missing shell executable records failed executable lookup");
         Assert
           (To_String (Missing_Shell_Action.Error_Key) = "error.open_action.executable_missing",
            "missing shell executable reports executable diagnostic");
         Assert
           (Files.Model.Last_Error_Key (Missing_Shell_Model) = "error.open_action.executable_missing",
            "missing shell executable records model diagnostic");
         Restore_Shell_Environment;
      exception
         when others =>
            Restore_Shell_Environment;
            raise;
      end;

      Files.Model.Select_Visible (Model, 2);
      Files.Model.Focus_Filter_Input (Model);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Assert (Routed.Status = Files.Controller.Controller_Selection_Moved, "click selects item without opening");
      Assert (Routed.Command = Files.Commands.No_Command, "selection click does not execute a command");
      Assert (Files.Model.Selected_Index (Model) = 1, "click selection updates selected visible index");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "item click clears text input focus");
      Routed := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Down);
      Assert (Routed.Status = Files.Controller.Controller_Selection_Moved, "arrow key moves after item click");
      Assert (Files.Model.Selected_Index (Model) = 2, "arrow key uses main view after item click");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/typed-path");
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 0);
      Assert (Routed.Status = Files.Controller.Controller_Ignored, "outside item click is ignored");
      Assert (Files.Model.Selected_Index (Model) = 2, "outside item click preserves selection");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "outside item click preserves focus");
      Assert (Files.Model.Path_Input_Text (Model) = "/tmp/typed-path", "outside item click preserves edited text");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Select_Visible (Model, 1);

      Shell_Arguments.Append (To_Unbounded_String ("literal; exit 9"));
      Shell_Arguments.Append (To_Unbounded_String ("{name}"));
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("true", Shell_Arguments, True));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "unmodified action fallback can be prepared");
      Assert (Result.Action.Use_Shell, "prepared fallback action preserves explicit shell execution");
      Assert (Result.Action_Uses_Shell, "prepared result exposes explicit shell flag");
      Assert
        (To_String (Result.Action.Arguments.Element (1)) = "literal; exit 9",
         "explicit shell action keeps semicolon argument as one vector value");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "file open quotes explicit shell arguments before execution");
      Assert (Result.Action.Use_Shell, "explicit shell action remains explicit after execution");
      Assert (Result.Action_Uses_Shell, "executed shell result exposes explicit shell flag");
      Assert (Result.Execution_Attempted, "executed shell action records process attempt");
      Assert (Result.Exit_Status_Known, "executed shell action records exit status");
      Assert (Result.Exit_Status = 0, "quoted shell action exits successfully");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("cd", Files.Settings.String_Vectors.Empty_Vector, True));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "explicit shell action can execute shell builtins");
      Assert (Result.Action.Use_Shell, "shell builtin action preserves explicit shell execution");
      Assert (Result.Execution_Attempted, "shell builtin action records shell execution attempt");
      Assert (Result.Executable_Found, "shell builtin action records shell discovery");
      Assert (Result.Exit_Status_Known, "shell builtin action records exit status");
      Assert (Result.Exit_Status = 0, "shell builtin action exits successfully");

      declare
         Exit_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Exit_Arguments.Append (To_Unbounded_String ("7"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/plain",
            Files.Settings.Make_Action ("exit", Exit_Arguments, True));
      end;
      --  Open actions are launched detached through a backgrounding shell
      --  wrapper, so a launched command's own nonzero exit code is no longer
      --  surfaced: the wrapper shell itself exits zero after backgrounding.
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "detached explicit shell builtin launches fire-and-forget");
      Assert
        (Result.Execution_Attempted,
         "detached explicit shell builtin runs through the wrapper shell");
      Assert
        (Result.Executable_Found,
         "detached explicit shell builtin records successful shell lookup");
      Assert
        (Result.Exit_Status = 0,
         "detached explicit shell builtin records the wrapper shell zero exit");
      Assert
        (Files.Model.Last_Error_Key (Model) = "",
         "detached explicit shell builtin clears stale error state");

      Files.Settings.Add_Open_Action (Settings, "text/plain", Files.Settings.Make_Action ("/bin/false", Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Action_Executed,
         "detached open action launches without surfacing app exit codes");
      Assert (Result.Execution_Attempted, "detached process result records execution attempt");
      Assert (Result.Executable_Found, "detached process result records executable discovery");
      Assert (Result.Exit_Status_Known, "detached process result records exit status");
      Assert (Result.Exit_Status = 0, "detached process result records the wrapper shell zero exit");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State = Files.Operations.Open_Action_Completed,
         "detached process lifecycle records completed state");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).Exit_Status_Known,
         "detached process lifecycle exposes known exit status");
      Assert
        (Files.Model.Last_Error_Key (Model) = "",
         "detached open action clears localized error key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action ("/tmp/files_missing_open_action_executable", Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "missing open executable is represented");
      Assert (not Result.Execution_Attempted, "missing executable result does not attempt execution");
      Assert (not Result.Executable_Found, "missing executable result records failed lookup");
      Assert
        (Files.Operations.Open_Action_Lifecycle_Of (Result).State =
         Files.Operations.Open_Action_Preflight_Failed,
         "missing executable lifecycle records preflight failure");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.executable_missing",
         "missing open executable returns a specific diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.executable_missing",
         "missing open executable stores specific diagnostic key");

      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain",
         Files.Settings.Make_Action (Root, Arguments));
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "directory open executable is represented");
      Assert (not Result.Execution_Attempted, "directory executable result does not attempt execution");
      Assert (not Result.Executable_Found, "directory executable result records failed lookup");
      Assert
        (To_String (Result.Error_Key) = "error.open_action.executable_missing",
         "directory executable returns the missing executable diagnostic key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.open_action.executable_missing",
         "directory executable stores the missing executable diagnostic key");

      declare
         Unsafe_Arguments : Files.Settings.String_Vectors.Vector;
      begin
         Unsafe_Arguments.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-argument",
            Files.Settings.Make_Action ("/bin/true", Unsafe_Arguments));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-argument", Files.Types.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects embedded placeholders before operation preparation");
         Assert
           (To_String (Lookup.Error_Key) = "error.open_action.missing",
            "rejected embedded-placeholder action is absent from lookup");
         Assert (Files.Model.Current_Path (Model) = Root, "unsafe open action does not navigate");

         Files.Settings.Add_Open_Action
           (Settings,
            "text/unsafe-executable",
            Files.Settings.Make_Action ("{path}", Files.Types.String_Vectors.Empty_Vector));
         Lookup := Files.Settings.Lookup_Open_Action (Settings, "text/unsafe-executable", Files.Types.No_Modifiers);
         Assert
           (not Lookup.Found,
            "settings helper rejects executable placeholders before operation preparation");
         Assert
           (To_String (Lookup.Error_Key) = "error.open_action.missing",
            "rejected executable-placeholder action is absent from lookup");
      end;

      Files.Model.Set_Error (Model, "error.open_action.missing");
      Files.Settings.Add_Open_Action
        (Settings,
         "text/plain+control",
         Files.Settings.Make_Action ("/bin/true", Arguments));
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      Assert (Result.Status = Files.Operations.Operation_Success, "modifier-specific action can be prepared");
      Assert
        (To_String (Result.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "prepared modifier-specific action expands path");
      Routed := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return, Modifiers);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "Return routes file open command");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Action_Executed,
         "Return executes configured open action");
      Assert
        (To_String (Routed.Operation.Action.Arguments.Element (2)) = Join (Root, "Alpha.txt"),
         "Return open preserves modifier-specific action lookup");
      Assert (Files.Model.Last_Error_Key (Model) = "", "Return open clears stale error state");

      Files.Model.Select_Visible (Model, 2);
      Routed :=
        Files.Controller.Handle_Item_Click
          (Model, Settings, Visible_Index => 1, Activate => True, Modifiers => Modifiers);
      Assert (Routed.Command = Files.Commands.Open_Selected_Items_Command, "double-click file routes open command");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Action_Executed,
         "double-click file executes configured action");
      Assert (Files.Model.Selected_Index (Model) = 1, "double-click selects activated file");
   end Test_Open_Selected_File_Prepares_Action;

   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      --  Exercise the genuine missing-action contract deterministically by
      --  opting out of the host opener fallback that would otherwise resolve.
      Settings.Use_System_Default_Opener := False;
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Operations.Prepare_Open_Selected_Action (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Missing_Open_Action, "prepare reports missing action");
      Assert (To_String (Result.Path) = Join (Root, "Gamma.md"), "prepare missing action reports file path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.open_action.missing", "prepare missing action records error");
      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Missing_Open_Action, "missing action is reported");
      Assert (To_String (Result.Path) = Join (Root, "Gamma.md"), "missing action reports selected file path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.open_action.missing", "missing action sets error state");
      Assert (Files.Model.Current_Path (Model) = Root, "missing file action does not navigate");
   end Test_Missing_Open_Action_Reports_Error;

   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_File (Model, "created.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create commit succeeds");
      Assert (To_String (Result.Path) = Join (Root, "created.txt"), "create commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created.txt")), "create commit creates the file");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful create clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create commit clears temporary state");
      Assert (not Files.Model.Rename_Is_Active (Model), "create commit clears rename state");
      Assert (Files.Model.Item_Count (Model) = 1, "create commit reloads the directory model");
      Assert (Files.Model.Selected_Name (Model) = "created.txt", "created item is selected after reload");
   end Test_Commit_Create_File;

   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.file.create");
      Files.Model.Begin_Create_Folder (Model, "created-folder");
      Assert (Files.Model.Temporary_Item_Is_Directory (Model), "create-folder marks temporary item as directory");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create-folder commit succeeds");
      Assert (To_String (Result.Path) = Join (Root, "created-folder"), "create-folder commit returns created path");
      Assert (Ada.Directories.Exists (Join (Root, "created-folder")), "create-folder commit creates the entry");
      Assert
        (Ada.Directories.Kind (Join (Root, "created-folder")) = Ada.Directories.Directory,
         "create-folder commit creates a directory");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful create-folder clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create-folder commit clears temporary state");
      Assert (not Files.Model.Temporary_Item_Is_Directory (Model), "create-folder commit clears directory flag");
      Assert (not Files.Model.Rename_Is_Active (Model), "create-folder commit clears rename state");
      Assert (Files.Model.Item_Count (Model) = 1, "create-folder commit reloads the directory model");
      Assert (Files.Model.Selected_Name (Model) = "created-folder", "created folder is selected after reload");
   end Test_Commit_Create_Folder;

   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result        : Files.Operations.Operation_Result;
      Existing_Path : constant String := Join (Root, "existing.txt");
      Direct_Path   : constant String := Join (Root, "direct-created.txt");
      Utf8_Two_Name   : constant String := "caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt";
      Utf8_Three_Name : constant String := Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & "uro.txt";
      Utf8_Four_Name  : constant String :=
        "folder-" & Byte (16#F0#) & Byte (16#9F#) & Byte (16#93#) & Byte (16#81#) & ".txt";
      Mutation      : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Existing_Path, "original");
      Ada.Directories.Create_Path (Join (Root, "existing-dir"));
      Mutation := Files.File_System.Create_Empty_File ("");
      Assert (not Mutation.Success, "create reports empty destination failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "empty destination create reports parent diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "existing-dir"));
      Assert (not Mutation.Success, "create refuses an existing directory destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.exists",
         "existing directory create reports exists diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Existing_Path);
      Assert (not Mutation.Success, "create refuses an existing file destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.exists",
         "existing file create reports exists diagnostic");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Existing_Path), "original") > 0,
         "direct existing-file create preserves file content");
      Mutation := Files.File_System.Create_Empty_File (Join (Join (Root, "missing-parent"), "child.txt"));
      Assert (not Mutation.Success, "create reports missing parent failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "missing parent create reports parent diagnostic");
      Assert
        (not Ada.Directories.Exists (Join (Join (Root, "missing-parent"), "child.txt")),
         "missing parent create writes no child file");
      Mutation := Files.File_System.Create_Empty_File (Join (Existing_Path, "child.txt"));
      Assert (not Mutation.Success, "create reports non-directory parent failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.file.parent_missing",
         "non-directory parent create reports parent diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "bad:name.txt"));
      Assert (not Mutation.Success, "direct create rejects invalid leaf names");
      Assert
        (To_String (Mutation.Error_Key) = "error.name.invalid",
         "direct invalid-name create reports invalid-name diagnostic");
      Assert
        (not Ada.Directories.Exists (Join (Root, "bad:name.txt")),
         "direct invalid-name create writes no file");
      Mutation := Files.File_System.Create_Empty_File (Direct_Path);
      Assert (Mutation.Success, "direct create mutation succeeds");
      Assert (To_String (Mutation.Error_Key) = "", "successful direct create has no error key");
      Assert (Ada.Directories.Exists (Direct_Path), "direct create writes the requested file");
      declare
         Original_Content : constant String := Project_Tools.Files.Read_Raw_File (Existing_Path);
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Begin_Create_File (Model, "existing.txt");

         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Assert (Result.Status = Files.Operations.Operation_Failed, "create refuses an existing destination");
         Assert (To_String (Result.Error_Key) = "error.file.exists", "create reports existing file error");
         Assert (To_String (Result.Path) = Existing_Path, "failed create reports attempted destination path");
         Assert (Files.Model.Last_Error_Key (Model) = "error.file.exists", "model records existing file error");
         Assert
           (Project_Tools.Files.Read_Raw_File (Existing_Path) = Original_Content,
            "failed create leaves existing file content unchanged");
         Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed create keeps temporary item active");
         Assert (Files.Model.Rename_Is_Active (Model), "failed create keeps rename mode active");
         Assert (Files.Model.Temporary_Item_Name (Model) = "existing.txt", "failed create keeps attempted name");

         Files.Model.Set_Rename_Text (Model, "retry.txt");
         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Assert (Result.Status = Files.Operations.Operation_Success, "create retry after collision succeeds");
         Assert (Ada.Directories.Exists (Join (Root, "retry.txt")), "create retry writes renamed file");
         Assert
           (Project_Tools.Files.Read_Raw_File (Existing_Path) = Original_Content,
            "create retry preserves original existing file");
         Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create retry clears temporary state");
         Assert (Files.Model.Selected_Name (Model) = "retry.txt", "create retry selects created file");
      end;

      Files.Model.Begin_Create_File (Model, Utf8_Two_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts two-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Two_Name)), "two-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Two_Name, "two-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Three_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts three-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Three_Name)), "three-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Three_Name, "three-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Four_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "create accepts four-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Four_Name)), "four-byte UTF-8 create writes file");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Four_Name, "four-byte UTF-8 create selects file");
   end Test_Create_File_Does_Not_Overwrite;

   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sources  : Files.Types.String_Vectors.Vector;
      Search   : Files.File_System.Recursive_Search_Result;
      Before   : Files.File_System.Directory_Signature;
      Change   : Files.File_System.Directory_Change_Result;
      Plans    : Files.File_System.Drop_Import_Result;
      Mutation : Files.File_System.Mutation_Result;
      Thumbnail : Files.File_System.Thumbnail_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Source_File : constant String := Join (Root, "drop-source.txt");
      Source_Dir  : constant String := Join (Root, "drop-dir");
      Drop_Target : constant String := Join (Root, "drop-target");
      Delete_Dir  : constant String := Join (Root, "delete-tree");
      Thumbnail_Source : constant String := Join (Root, "picture.png");
      Decoded_Png_Source : constant String := Join (Root, "decoded-picture.png");
      Ppm_Thumbnail_Source : constant String := Join (Root, "picture.ppm");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
      Cache_Home : constant String := Join (Root, "cache-home");
      Had_Cache  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache  : Unbounded_String;

      procedure Restore_Cache is
      begin
         if Had_Cache then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Cache));
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;
      end Restore_Cache;
   begin
      if Had_Cache then
         Old_Cache := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "search"));
      Ada.Directories.Create_Path (Join (Join (Root, "search"), "nested"));
      Write_File (Join (Join (Root, "search"), "alpha-match.txt"), "alpha");
      Write_File (Join (Join (Join (Root, "search"), "nested"), "beta-match.txt"), "beta");
      Write_File (Join (Join (Root, "search"), "skip.txt"), "skip");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "MATCH", Settings);
      Assert (Search.Success, "recursive search succeeds");
      Assert (Natural (Search.Items.Length) = 2, "recursive search finds nested matches");
      Assert
        (To_String (Search.Items.Element (1).Name) = "alpha-match.txt",
         "recursive search preserves deterministic parent order");
      Assert
        (To_String (Search.Items.Element (2).Name) = "beta-match.txt",
         "recursive search descends into child directories");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "match", Settings, Max_Items => 1);
      Assert (Natural (Search.Items.Length) = 1, "recursive search respects result limits");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is disabled without filter text");
      Files.Model.Set_Filter (Model, "match");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is enabled with filter text");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Search_Recursive_Command,
         "recursive search routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "recursive search command succeeds");
      Assert (Files.Model.Item_Count (Model) = 2, "recursive search command loads nested result items");
      Assert
        (To_String (Files.Model.Visible_Item (Model, 2).Name) = "beta-match.txt",
         "recursive search command exposes nested matches in the model");
      Routed := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "refresh restores direct listing");
      Assert (Files.Model.Item_Count (Model) = 3, "refresh after recursive search reloads direct children");

      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Write_File (Join (Join (Root, "search"), "new-file.txt"), "new");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "polling directory watcher detects added entries");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count + 1,
         "directory watcher reports updated entry count");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Join (Root, "search")));
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "unchanged directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 4, "unchanged watcher refresh keeps loaded item count");
      Write_File (Join (Join (Root, "search"), "watched-add.txt"), "watch");
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "changed directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 5, "changed watcher refresh reloads new directory items");
      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Ada.Directories.Delete_File (Join (Join (Root, "search"), "skip.txt"));
      Write_File (Join (Join (Root, "search"), "same-count-replacement.txt"), "replacement");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "directory watcher detects same-count replacement");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count,
         "same-count replacement keeps directory entry count stable");
      Assert
        (Change.After_State.Entry_State_Checksum /= Before.Entry_State_Checksum,
         "same-count replacement changes directory entry checksum");
      Files.Model.Set_Directory_Signature (Model, Before);
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "same-count watcher refresh succeeds");
      Assert
        (Files.Model.Item_Count (Model) = 5,
         "same-count watcher refresh keeps replacement entry count");

      Ada.Directories.Create_Path (Drop_Target);
      Write_File (Source_File, "drop");
      Ada.Directories.Create_Path (Source_Dir);
      Write_File (Join (Source_Dir, "inside.txt"), "inside");
      Sources.Append (To_Unbounded_String (Source_File));
      Sources.Append (To_Unbounded_String (Source_Dir));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target);
      Assert (Plans.Success, "drop import planning accepts valid dropped paths");
      Assert (Natural (Plans.Plans.Length) = 2, "drop import plans every source path");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import copy executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "drop-source.txt")), "drop import copies files");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "drop-dir"), "inside.txt")),
         "drop import copies directories");
      Assert (Ada.Directories.Exists (Source_File), "drop copy preserves source file");

      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Source_File));
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "controller drop import succeeds");
      Assert
        (Ada.Directories.Exists (Join (Drop_Target, "drop-source 2.txt")),
         "controller drop import chooses collision-safe destination");
      Assert (Files.Model.Item_Count (Model) = 3, "controller drop import refreshes destination model");

      Ada.Directories.Create_Path (Join (Drop_Target, "nested-target"));
      Write_File (Join (Drop_Target, "drag-source.txt"), "drag");
      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Drop_Target, "drag-source.txt")));
      Routed.Operation :=
        Files.Operations.Import_Dropped_Paths_To
          (Model                 => Model,
           Settings              => Settings,
           Source_Paths          => Sources,
           Destination_Directory => Join (Drop_Target, "nested-target"),
           Mode                  => Files.File_System.Drop_Move);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "item drag import can target a specific directory");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "nested-target"), "drag-source.txt")),
         "item drag import moves the source into the target directory");
      Assert
        (not Ada.Directories.Exists (Join (Drop_Target, "drag-source.txt")),
         "item drag move removes the source from the current directory");
      Assert (Files.Model.Item_Count (Model) = 4, "item drag import refreshes the source window model");

      Sources.Clear;
      Write_File (Join (Root, "move-source.txt"), "move");
      Sources.Append (To_Unbounded_String (Join (Root, "move-source.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import move executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "move-source.txt")), "drop move creates destination");
      Assert (not Ada.Directories.Exists (Join (Root, "move-source.txt")), "drop move removes source");

      --  Moving an item into the directory it already lives in is a no-op, but
      --  copying into the same directory still makes a numbered duplicate.
      Sources.Clear;
      Write_File (Join (Root, "stay.txt"), "stay");
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory move succeeds");
      Assert (Ada.Directories.Exists (Join (Root, "stay.txt")), "same-directory move keeps the file in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory move does not create a numbered duplicate");

      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Copy);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory copy succeeds");
      Assert
        (Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory copy still creates a numbered duplicate");

      --  A directory cannot be moved or copied into itself or a descendant;
      --  the recursive copy would otherwise recurse without bound.
      Ada.Directories.Create_Path (Join (Join (Root, "tree"), "sub"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "tree")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Move);
      Assert (not Plans.Success, "moving a directory into its own subtree is rejected");
      Assert
        (To_String (Plans.Error_Key) = "error.drop.into_self",
         "into-self drop reports a deterministic diagnostic");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into its own subtree is rejected");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "tree"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into itself is rejected");

      --  Two sources sharing a simple name from different directories must get
      --  distinct destinations within one batch (no silent overwrite).
      Ada.Directories.Create_Path (Join (Root, "src-a"));
      Ada.Directories.Create_Path (Join (Root, "src-b"));
      Write_File (Join (Join (Root, "src-a"), "dup.txt"), "a");
      Write_File (Join (Join (Root, "src-b"), "dup.txt"), "b");
      Ada.Directories.Create_Path (Join (Root, "dup-dest"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-a"), "dup.txt")));
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-b"), "dup.txt")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "dup-dest"), Files.File_System.Drop_Copy);
      Assert (Plans.Success, "same-name batch drop plans successfully");
      Assert (Natural (Plans.Plans.Length) = 2, "batch drop plans both sources");
      Assert
        (To_String (Plans.Plans.Element (1).Destination_Path)
           /= To_String (Plans.Plans.Element (2).Destination_Path),
         "same-name sources get distinct destinations within a batch");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-name batch copy executes");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup.txt")),
         "first same-name file is copied");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup 2.txt")),
         "second same-name file gets a distinct name instead of overwriting");

      Ada.Directories.Create_Path (Delete_Dir);
      Write_File (Join (Delete_Dir, "doomed.txt"), "doomed");
      Ada.Directories.Create_Path (Join (Delete_Dir, "nested"));
      Write_File (Join (Join (Delete_Dir, "nested"), "child.txt"), "child");
      Mutation := Files.File_System.Delete_Permanently (Delete_Dir);
      Assert (Mutation.Success, "explicit permanent delete removes a tree");
      Assert (not Ada.Directories.Exists (Delete_Dir), "permanent delete removes the target directory");
      Mutation := Files.File_System.Delete_Permanently ("/");
      Assert (not Mutation.Success, "permanent delete refuses root paths");
      Assert
        (To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
         "permanent delete reports unsafe target diagnostic");

      Write_Binary_File (Thumbnail_Source, Minimal_Png_Header (48, 32));
      Thumbnail := Files.File_System.Generate_Thumbnail (Thumbnail_Source, Thumbnail_Cache, Size => 8);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "thumbnail generation succeeds");
      Assert (Thumbnail.Width = 8 and then Thumbnail.Height = 8, "thumbnail reports requested dimensions");
      Assert
        (Ada.Directories.Exists (To_String (Thumbnail.Thumbnail_Path)),
         "thumbnail generation writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "P3"),
         "thumbnail artifact is a plain PPM image");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "8 8"),
         "thumbnail artifact records requested image dimensions");

      Write_Binary_File
        (Decoded_Png_Source,
         Minimal_Png_RGB
           (2,
            2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));
      Thumbnail := Files.File_System.Generate_Thumbnail (Decoded_Png_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PNG thumbnail succeeds");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "255 0 0")
         and then Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "0 255 0")
         and then Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "0 0 255"),
         "decoded PNG thumbnail preserves source pixel colors");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Load := Files.File_System.Load_Directory (Root, Settings);
      declare
         Found_Auto_Thumbnail : Boolean := False;
         Extension_Settings    : Files.Settings.Settings_Model := Settings;
         Extension_Load        : Files.File_System.Directory_Load_Result;
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = "decoded-picture.png" then
               Found_Auto_Thumbnail := True;
               Assert (Item.Thumbnail_Available, "directory loading auto-generates image thumbnails");
               Assert (Item.Thumbnail_Width = 64, "auto-generated thumbnail records default width");
               Assert (Item.Thumbnail_Height = 64, "auto-generated thumbnail records default height");
               Assert
                 (Natural (Item.Thumbnail_Pixels.Length) = 64 * 64 * 4,
                  "auto-generated thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "auto-thumbnail image item is loaded");

         Files.Settings.Add_Extension_Mapping (Extension_Settings, "webp", "application/octet-stream");
         Write_File (Join (Root, "extension-only.webp"), "not a decoded image");
         Extension_Load := Files.File_System.Load_Directory (Root, Extension_Settings);
         Found_Auto_Thumbnail := False;
         for Item of Extension_Load.Items loop
            if To_String (Item.Name) = "extension-only.webp" then
               Found_Auto_Thumbnail := True;
               Assert
                 (Item.Thumbnail_Available,
                  "directory loading auto-generates thumbnails for image extensions");
               Assert
                 (Natural (Item.Thumbnail_Pixels.Length) = 64 * 64 * 4,
                  "image-extension thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "image-extension thumbnail item is loaded");
      end;
      Assert
        (Project_Tools.Files.File_Contains ("src/files-file_system.adb", "gdk_pixbuf_new_from_file_at_size")
         or else Project_Tools.Files.File_Contains ("../src/files-file_system.adb", "gdk_pixbuf_new_from_file_at_size")
         or else
           Project_Tools.Files.File_Contains
             ("../../src/files-file_system.adb", "gdk_pixbuf_new_from_file_at_size"),
         "JPEG thumbnail decoding is routed through the native image loader binding");

      Write_File
        (Ppm_Thumbnail_Source,
         "P3" & ASCII.LF
         & "# decoded thumbnail fixture" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 0 255 0" & ASCII.LF
         & "0 0 255 255 255 255" & ASCII.LF);
      Thumbnail := Files.File_System.Generate_Thumbnail (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PPM thumbnail succeeds");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "255 0 0")
         and then Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "0 255 0")
         and then Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "0 0 255"),
         "decoded PPM thumbnail preserves source pixel colors");

      Thumbnail := Files.File_System.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Assert
        (To_String (Thumbnail.Error_Key) = "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");

      Write_File (Join (Root, "command-delete.txt"), "delete");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-delete.txt");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Permanently_Command, Model),
         "permanent delete command is enabled for selected items");
      Routed :=
        Files.Controller.Execute_Command
          (Files.Commands.Delete_Selected_Permanently_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Delete_Selected_Permanently_Command,
         "permanent delete routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "permanent delete command succeeds");
      Assert
        (not Ada.Directories.Exists (Join (Root, "command-delete.txt")),
         "permanent delete command removes the selected file");

      Write_File
        (Join (Root, "command-thumbnail.ppm"),
         "P3" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-thumbnail.ppm");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Routed := Files.Controller.Execute_Command (Files.Commands.Generate_Thumbnails_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Generate_Thumbnails_Command,
         "thumbnail generation routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "thumbnail command succeeds");
      Assert
        (Ada.Directories.Exists (To_String (Routed.Operation.Path)),
         "thumbnail command writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Routed.Operation.Path), "P3"),
         "thumbnail command writes PPM thumbnail content");
      Assert
        (Files.Model.Selected_Item (Model).Thumbnail_Available,
         "thumbnail command refresh exposes generated thumbnail in the model");
      Assert
        (To_String (Files.Model.Selected_Item (Model).Thumbnail_Path) = To_String (Routed.Operation.Path),
         "thumbnail command refresh records the generated thumbnail path");
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      declare
         Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Files.Rendering.Build_Snapshot (Model, Settings),
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);
         Empty_Text : Files.Rendering.Text_Render_Result;
         Thumbnail_Batch : Files.Rendering.Vulkan.Submission_Batch;
         Found_Thumbnail_Command : Boolean := False;
         Found_Thumbnail_Icon    : Boolean := False;
         Thumbnail_Tile          : Natural := 0;
         Icon_Index              : Natural := 0;
      begin
         for Command of Thumbnail_Frame.Icons loop
            if Length (Command.Icon_Id) < 8
              or else Slice (Command.Icon_Id, 1, 8) /= "toolbar-"
            then
               Icon_Index := Icon_Index + 1;
            end if;
            if To_String (Command.Asset_Path) = To_String (Routed.Operation.Path) then
               Found_Thumbnail_Command := True;
               Thumbnail_Tile := Icon_Index - 1;
               if To_String (Command.Icon_Id) = "thumbnail" then
                  Found_Thumbnail_Icon := True;
               end if;
            end if;
         end loop;

         Assert
           (Found_Thumbnail_Command,
            "large-icons item icon command points at the generated thumbnail artifact");
         Assert
           (Found_Thumbnail_Icon,
            "large-icons item icon command uses a thumbnail-specific icon asset");
         Thumbnail_Batch := Files.Rendering.Vulkan.Build_Submission (Thumbnail_Frame, Empty_Text);
         declare
            Pixel_Offset : constant Positive := Positive (Thumbnail_Tile * 64 * 4 + 1);
         begin
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset) = 255
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 1) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 2) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 3) = 255,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels");
         end;
      end;
      for Mode in Files.Types.Small_Icons .. Files.Types.Details loop
         if Mode /= Files.Types.Large_Icons then
            Files.Model.Set_View_Mode (Model, Mode);
            declare
               Non_Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Files.Rendering.Build_Snapshot (Model, Settings),
                    Width       => 1000,
                    Height      => 800,
                    Line_Height => 20);
            begin
               for Command of Non_Thumbnail_Frame.Icons loop
                  Assert
                    (To_String (Command.Icon_Id) /= "thumbnail",
                     "non-large item icon command keeps filetype icon");
                  Assert
                    (Command.Thumbnail_Width = 0
                     and then Command.Thumbnail_Height = 0
                     and then Command.Thumbnail_Pixels.Is_Empty,
                     "non-large item icon command does not carry thumbnail pixels");
               end loop;
            end;
         end if;
      end loop;
      Restore_Cache;
   exception
      when others =>
         Restore_Cache;
         raise;
   end Test_Advanced_Filesystem_Operations;

   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Nul_Name : constant String := "bad" & Character'Val (0) & "name.txt";
      Tab_Name : constant String := "bad" & Character'Val (9) & "name.txt";
      C1_Name  : constant String := "bad" & Character'Val (133) & "name.txt";
      Encoded_C1_Name : constant String := "bad" & Byte (16#C2#) & Byte (16#85#) & "name.txt";
      Truncated_UTF8_Name : constant String := "bad" & Byte (16#E2#) & Byte (16#82#) & "name.txt";
      Overlong_UTF8_Name  : constant String := "bad" & Byte (16#C0#) & Byte (16#AF#) & "name.txt";
      NBSP_Name : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      Ideographic_Space_Name : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#3000#));
      Trailing_NBSP_Name : constant String := "trailing-nbsp" & NBSP_Name;
      Trailing_Ideographic_Name : constant String := "trailing-wide" & Ideographic_Space_Name;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Begin_Create_File (Model, "");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects empty names");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "empty create records invalid name");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, ".");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects dot names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "..");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects parent-directory names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create invalid name records error");
      Assert (not Ada.Directories.Exists (Join (Root, "bad")), "invalid create does not create directories");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid create keeps temporary item active");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid create keeps rename active");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad\name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects backslash names");
      Assert (not Ada.Directories.Exists (Join (Root, "bad\name.txt")), "invalid backslash create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad:name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects Windows-reserved names");
      Assert (not Ada.Directories.Exists (Join (Root, "bad:name.txt")), "invalid reserved create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad*name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects wildcard names");
      Assert (not Ada.Directories.Exists (Join (Root, "bad*name.txt")), "invalid wildcard create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "trailing-dot.txt.");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing-dot names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "trailing-dot.txt.")),
         "invalid trailing-dot create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "trailing-space.txt ");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "trailing-space.txt ")),
         "invalid trailing-space create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects NBSP-only names");
      Assert (not Ada.Directories.Exists (Join (Root, NBSP_Name)), "invalid NBSP-only create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing NBSP names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects trailing ideographic-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_Ideographic_Name)),
         "invalid trailing ideographic-space create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "CON.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects reserved device names");
      Assert (not Ada.Directories.Exists (Join (Root, "CON.txt")), "invalid device-name create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "CON .txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects padded device names");
      Assert (not Ada.Directories.Exists (Join (Root, "CON .txt")), "invalid padded-device create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "lPt1 .txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects mixed-case padded device names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "lPt1 .txt")),
         "invalid mixed-case padded-device create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "CONIN$");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects console device names");
      Assert (not Ada.Directories.Exists (Join (Root, "CONIN$")), "invalid console-device create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Nul_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create NUL name records error");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Tab_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects UTF-8 encoded C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects truncated UTF-8 names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects overlong UTF-8 names");

      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects empty names");

      Files.Model.Set_Rename_Text (Model, ".");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects dot names");

      Files.Model.Set_Rename_Text (Model, "..");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects parent-directory names");

      Files.Model.Set_Rename_Text (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename invalid name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "invalid rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "bad")), "invalid rename does not create directories");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid rename keeps rename active");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "invalid rename keeps selected item");

      Files.Model.Set_Rename_Text (Model, "bad\name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects backslash names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "backslash rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "bad\name.txt")), "invalid backslash rename writes no file");

      Files.Model.Set_Rename_Text (Model, "bad:name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects Windows-reserved names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "reserved-character rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "bad:name.txt")), "invalid reserved rename writes no file");

      Files.Model.Set_Rename_Text (Model, "bad*name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects wildcard names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "wildcard rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "bad*name.txt")), "invalid wildcard rename writes no file");

      Files.Model.Set_Rename_Text (Model, "renamed.");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing-dot names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing-dot rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "renamed.")), "invalid trailing-dot rename writes no file");

      Files.Model.Set_Rename_Text (Model, "renamed ");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing-space names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing-space rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "renamed ")), "invalid trailing-space rename writes no file");

      Files.Model.Set_Rename_Text (Model, Ideographic_Space_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects ideographic-space-only names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "ideographic-space-only rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing NBSP names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing NBSP rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP rename writes no file");

      Files.Model.Set_Rename_Text (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing ideographic-space names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "trailing ideographic-space rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, "NUL.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects reserved device names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "device-name rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "NUL.txt")), "invalid device-name rename writes no file");

      Files.Model.Set_Rename_Text (Model, "NUL .txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects padded device names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "padded-device rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "NUL .txt")), "invalid padded-device rename writes no file");

      Files.Model.Set_Rename_Text (Model, "cOm9 .txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects mixed-case padded device names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "mixed-case padded-device rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "cOm9 .txt")),
         "invalid mixed-case padded-device rename writes no file");

      Files.Model.Set_Rename_Text (Model, "CONOUT$.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects console device names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "console-device rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "CONOUT$.txt")), "invalid console-device rename writes no file");

      Files.Model.Set_Rename_Text (Model, Nul_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename NUL name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "NUL rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Tab_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "C1 control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects UTF-8 encoded C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "encoded C1 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects truncated UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "truncated UTF-8 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects overlong UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "overlong UTF-8 rename leaves source in place");
   end Test_Invalid_File_Operation_Names;

   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Taken    : constant String := Join (Root, "taken.txt");
      Direct_Source : constant String := Join (Root, "direct-source.txt");
      Direct_Target : constant String := Join (Root, "direct-target.txt");
      Missing_Parent_Source : constant String := Join (Root, "missing-parent-source.txt");
      Non_Directory_Source  : constant String := Join (Root, "non-directory-source.txt");
      Utf8_Target : constant String :=
        "renamed-" & Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & ".txt";
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Write_File (Taken, "destination");
      Write_File (Direct_Source, "direct");
      Write_File (Missing_Parent_Source, "missing parent");
      Write_File (Non_Directory_Source, "non-directory parent");
      Ada.Directories.Create_Path (Join (Root, "taken-dir"));
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Join (Root, "taken-dir"));
      Assert (not Mutation.Success, "rename refuses an existing directory destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing directory rename reports invalid destination");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Taken);
      Assert (not Mutation.Success, "direct rename refuses an existing file destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing file direct rename reports invalid destination");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "direct rename preserves existing destination file");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "direct failed rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Join (Root, "missing-source.txt"), Join (Root, "new-missing.txt"));
      Assert (not Mutation.Success, "rename reports missing source failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "missing source rename reports source-missing diagnostic");
      Assert (not Ada.Directories.Exists (Join (Root, "new-missing.txt")), "missing source rename writes no target");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), "");
      Assert (not Mutation.Success, "rename reports empty destination failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "empty destination rename reports invalid destination");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "empty destination rename leaves source in place");
      Mutation :=
        Files.File_System.Rename_Item
          (Root & "/bad" & Character'Val (0) & "same.txt",
           Root & "/bad" & Character'Val (0) & "same.txt");
      Assert (not Mutation.Success, "malformed same-path rename reports failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "malformed same-path rename reports source-missing diagnostic");
      Mutation :=
        Files.File_System.Rename_Item
          (Missing_Parent_Source,
           Join (Join (Root, "missing-parent"), "target.txt"));
      Assert (not Mutation.Success, "rename refuses a missing destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "missing destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Missing_Parent_Source), "missing parent rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Non_Directory_Source, Join (Taken, "target.txt"));
      Assert (not Mutation.Success, "rename refuses a non-directory destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "non-directory destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Non_Directory_Source), "non-directory parent rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Direct_Source, Join (Root, "bad:name.txt"));
      Assert (not Mutation.Success, "direct rename rejects invalid leaf names");
      Assert
        (To_String (Mutation.Error_Key) = "error.name.invalid",
         "direct invalid-name rename reports invalid-name diagnostic");
      Assert (Ada.Directories.Exists (Direct_Source), "direct invalid-name rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "bad:name.txt")),
         "direct invalid-name rename writes no target");
      Mutation := Files.File_System.Rename_Item (Direct_Source, Direct_Target);
      Assert (Mutation.Success, "direct rename mutation succeeds");
      Assert (To_String (Mutation.Error_Key) = "", "successful direct rename has no error key");
      Assert (not Ada.Directories.Exists (Direct_Source), "direct rename removes source path");
      Assert (Ada.Directories.Exists (Direct_Target), "direct rename creates destination path");
      Mutation := Files.File_System.Rename_Item (Direct_Target, Direct_Target);
      Assert (Mutation.Success, "direct same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct same-path rename keeps source path");
      Mutation :=
        Files.File_System.Rename_Item
          (Direct_Target,
           Files.File_System.Join_Path (Files.File_System.Join_Path (Root, "."), "direct-target.txt"));
      Assert (Mutation.Success, "direct normalized same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct normalized same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct normalized same-path rename keeps source path");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Error (Model, "error.rename.failed");
      Files.Model.Set_Rename_Text (Model, "old.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "same-name rename succeeds without mutation");
      Assert (To_String (Result.Path) = Join (Root, "old.txt"), "same-name rename reports existing path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "same-name rename clears stale error state");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "same-name rename leaves source in place");
      Assert (not Files.Model.Rename_Is_Active (Model), "same-name rename clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "same-name rename keeps selected source");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "taken.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename refuses an existing destination");
      Assert
        (To_String (Result.Error_Key) = "error.rename.invalid_destination",
         "existing destination rename reports invalid destination key");
      Assert (To_String (Result.Path) = Taken, "failed rename reports attempted destination path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.invalid_destination", "failed rename records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "failed rename leaves source in place");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "failed rename preserves destination");
      Assert (Files.Model.Rename_Is_Active (Model), "failed rename keeps rename mode active");
      Assert (Files.Model.Rename_Text (Model) = "taken.txt", "failed rename keeps attempted name");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "failed rename keeps selected source");

      Ada.Directories.Delete_File (Join (Root, "old.txt"));
      Files.Model.Set_Rename_Text (Model, "missing-result.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "disappeared source reports source-missing error key");
      Assert
        (To_String (Result.Path) = Join (Root, "missing-result.txt"),
         "source-missing rename reports attempted destination path");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "disappeared source records source-missing error");
      Assert (not Files.Model.Rename_Is_Active (Model), "source-missing rename clears stale rename mode");
      Assert (Files.Model.Rename_Text (Model) = "", "source-missing rename clears stale attempted name");
      Assert (Files.Model.Selected_Count (Model) = 0, "source-missing rename clears stale selection");
      Assert (Files.Model.Selected_Name (Model) = "", "source-missing rename removes stale selected item");

      Reset_Root;
      Write_File (Join (Root, "same-missing.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "same-missing.txt");
      Files.Model.Toggle_Rename (Model);
      Ada.Directories.Delete_File (Join (Root, "same-missing.txt"));
      Files.Model.Set_Rename_Text (Model, "same-missing.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed,
         "same-name rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "same-name disappeared source reports source-missing error key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "same-name disappeared source records source-missing error");
      Assert
        (not Files.Model.Rename_Is_Active (Model),
         "same-name disappeared source clears stale rename mode");

      Write_File (Join (Root, "missing-parent-source.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "missing-parent-source.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "new.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename succeeds after source is restored");
      Assert (Files.Model.Last_Error_Key (Model) = "", "restored-source rename clears stale error");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "restored-source rename creates new path");
      Assert (To_String (Result.Path) = Join (Root, "new.txt"), "rename commit returns renamed path");
      Assert (not Ada.Directories.Exists (Join (Root, "missing-parent-source.txt")), "rename removes old path");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename commit clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "new.txt", "renamed item is selected after reload");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, Utf8_Target);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename accepts UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Target)), "UTF-8 rename creates new path");
      Assert (not Ada.Directories.Exists (Join (Root, "new.txt")), "UTF-8 rename removes old path");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Target, "UTF-8 renamed item is selected after reload");
   end Test_Commit_Rename;

   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      function Detail_Value
        (Prefix_Key : String;
         Value      : String;
         Suffix_Key : String)
         return String
      is
         Prefix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
         Suffix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
      begin
         if Suffix'Length > 0
           and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
         then
            return Prefix & " " & Value & " " & Suffix;
         else
            return Prefix & " " & Value & Suffix;
         end if;
      end Detail_Value;

      function Detail_Localized_Value
        (Prefix_Key : String;
         Value_Key  : String;
         Suffix_Key : String)
         return String
      is
      begin
         return Detail_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
      end Detail_Localized_Value;

      function Detail_Lines_Encoding
        (Lines_Prefix_Key : String;
         Lines            : String;
         Lines_Suffix_Key : String;
         Encoding_Key     : String)
         return String
      is
      begin
         return
           Detail_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
           & " "
           & Detail_Localized_Value
             ("info.extra.encoding.prefix", Encoding_Key, "info.extra.encoding.suffix");
      end Detail_Lines_Encoding;

      procedure Assert_Localized_Extra
        (Name     : String;
         Filetype : String;
         Token    : String;
         Expected : String;
         Message  : String;
         Kind     : Files.Types.Item_Kind := Files.Types.Regular_File_Item)
      is
         Items : Files.File_System.Item_Vectors.Vector;
         Item  : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => Name,
              Kind        => Kind,
              Filetype    => Filetype);
      begin
         Item.Filetype_Extra := To_Unbounded_String (Token);
         Items.Append (Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) = Expected,
            Message);
      end Assert_Localized_Extra;
   begin
      Reset_Root;
      Write_File (Join (Root, "meta.txt"), "abcd");
      Write_File (Join (Root, "zmarkdown.md"), "# Title" & ASCII.LF & "body");
      Write_Binary_File (Join (Root, "zsheet.xlsx"), "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Join (Root, "zutf8.txt"), "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Join (Root, "zbinary.txt"), "bad" & Character'Val (16#C3#));
      Write_File
        (Join (Root, "zunit.adb"),
         "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Join (Root, "zdata.json"), "{""ok"":true}");
      Write_File (Join (Root, "zdoc.xml"), "<root/>");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 1, "snapshot contains selected item info");
      Assert (Snapshot.Selected_Info.Element (1).Name = To_Unbounded_String ("meta.txt"), "info name is captured");
      Assert (Snapshot.Items.Element (1).Size_Available, "item snapshot captures size availability");
      Assert
        (Snapshot.Items.Element (1).Size = Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "item snapshot captures size value");
      Assert (Snapshot.Items.Element (1).Modified_Available, "item snapshot captures modified availability");
      Assert
        (Snapshot.Items.Element (1).Modified_Time = Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "item snapshot captures modified time value");
      Assert
        (To_String (Snapshot.Items.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "item snapshot captures filesystem-backed filetype extra metadata");
      Assert (not Snapshot.Items.Element (1).Metadata_Error, "item snapshot captures metadata error state");
      Assert (Snapshot.Selected_Info.Element (1).Size_Available, "info size availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Size =
           Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "info size value is captured");
      Assert (Snapshot.Selected_Info.Element (1).Modified_Available, "info modified availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Modified_Time =
           Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "info modified time value is captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Permissions)'Length = 3,
         "info permissions are captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "info pane captures filetype-specific detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "info pane captures loaded text line metadata");
      declare
         Found_Utf8_Metadata   : Boolean := False;
         Found_Binary_Metadata : Boolean := False;
         Found_Markdown_Metadata : Boolean := False;
         Found_Xlsx_Metadata   : Boolean := False;
         Found_Ada_Metadata    : Boolean := False;
         Found_Json_Metadata   : Boolean := False;
         Found_Xml_Metadata    : Boolean := False;
      begin
         for Item of Snapshot.Items loop
            if To_String (Item.Name) = "zutf8.txt" then
               Found_Utf8_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.utf8");
            elsif To_String (Item.Name) = "zbinary.txt" then
               Found_Binary_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.binary");
            elsif To_String (Item.Name) = "zmarkdown.md" then
               Found_Markdown_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.markdown.lines.prefix",
                      "2",
                      "info.extra.markdown.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zsheet.xlsx" then
               Found_Xlsx_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.document.spreadsheet")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Value ("info.extra.office.xlsx.prefix", "1", "info.extra.office.entries.suffix");
            elsif To_String (Item.Name) = "zunit.adb" then
               Found_Ada_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.ada")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.ada.prefix",
                      "4",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdata.json" then
               Found_Json_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.json")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.json.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdoc.xml" then
               Found_Xml_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.xml")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.xml.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            end if;
         end loop;

         Assert (Found_Utf8_Metadata, "item snapshot localizes UTF-8 text metadata");
         Assert (Found_Binary_Metadata, "item snapshot localizes binary text metadata");
         Assert (Found_Markdown_Metadata, "item snapshot localizes Markdown metadata");
         Assert (Found_Xlsx_Metadata, "item snapshot localizes XLSX metadata");
         Assert (Found_Ada_Metadata, "item snapshot localizes Ada source metadata");
         Assert (Found_Json_Metadata, "item snapshot localizes JSON source metadata");
         Assert (Found_Xml_Metadata, "item snapshot localizes XML source metadata");
      end;

      Assert_Localized_Extra
        (Name     => "folder",
         Filetype => "inode/directory",
         Token    => "directory.count|7",
         Expected => Detail_Value ("info.extra.directory.count.prefix", "7", "info.extra.directory.count.suffix"),
         Message  => "item snapshot localizes directory count metadata",
         Kind     => Files.Types.Directory_Item);
      Assert_Localized_Extra
        (Name     => "program",
         Filetype => "application/x-executable",
         Token    => "executable.format|elf",
         Expected =>
           Detail_Localized_Value
             ("info.extra.executable.format.prefix",
              "info.extra.executable.format.elf",
              "info.extra.executable.format.suffix"),
         Message  => "item snapshot localizes executable format metadata",
         Kind     => Files.Types.Executable_Item);
      Assert_Localized_Extra
        (Name     => "picture.png",
         Filetype => "image/png",
         Token    => "image.dimensions|32x16",
         Expected =>
           Detail_Value ("info.extra.image.dimensions.prefix", "32x16", "info.extra.image.dimensions.suffix"),
         Message  => "item snapshot localizes image dimension metadata");
      Assert_Localized_Extra
        (Name     => "link",
         Filetype => "inode/symlink",
         Token    => "symlink.target|target.txt",
         Expected =>
           Detail_Value ("info.extra.symlink.target.prefix", "target.txt", "info.extra.symlink.target.suffix"),
         Message  => "item snapshot localizes symlink target metadata",
         Kind     => Files.Types.Symlink_Item);
      Assert_Localized_Extra
        (Name     => "paper.pdf",
         Filetype => "application/pdf",
         Token    => "document.pdf.pages|3",
         Expected =>
           Detail_Value ("info.extra.document.pdf.pages.prefix", "3", "info.extra.document.pdf.pages.suffix"),
         Message  => "item snapshot localizes PDF page metadata");
      Assert_Localized_Extra
        (Name     => "archive.tar",
         Filetype => "application/x-tar",
         Token    => "archive.format|tar",
         Expected =>
           Detail_Localized_Value
             ("info.extra.archive.format.prefix",
              "info.extra.archive.format.tar",
              "info.extra.archive.format.suffix"),
         Message  => "item snapshot localizes archive format metadata");
      Assert_Localized_Extra
        (Name     => "bundle.zip",
         Filetype => "application/zip",
         Token    => "archive.zip.entries|5",
         Expected => Detail_Value ("info.extra.archive.entries.prefix", "5", "info.extra.archive.entries.suffix"),
         Message  => "item snapshot localizes archive entry metadata");
      Assert_Localized_Extra
        (Name     => "report.docx",
         Filetype => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         Token    => "office.docx.entries|9",
         Expected => Detail_Value ("info.extra.office.docx.prefix", "9", "info.extra.office.entries.suffix"),
         Message  => "item snapshot localizes document package metadata");
      Assert_Localized_Extra
        (Name     => "track.mp3",
         Filetype => "audio/mpeg",
         Token    => "media.kind|audio",
         Expected => Files.Localization.Text ("info.extra.media.audio"),
         Message  => "item snapshot localizes audio media metadata");
      Assert_Localized_Extra
        (Name     => "clip.mp4",
         Filetype => "video/mp4",
         Token    => "media.kind|video",
         Expected => Files.Localization.Text ("info.extra.media.video"),
         Message  => "item snapshot localizes video media metadata");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 800, Line_Height => 20);
      declare
         Found_Name         : Boolean := False;
         Found_Name_Value   : Boolean := False;
         Found_Name_Bold    : Boolean := False;
         Found_Filetype     : Boolean := False;
         Found_Filetype_Value : Boolean := False;
         Found_Size         : Boolean := False;
         Found_Size_Value   : Boolean := False;
         Found_Created      : Boolean := False;
         Found_Modified     : Boolean := False;
         Found_Permissions  : Boolean := False;
         Found_Permission_First : Boolean := False;
         Found_Permission_Second : Boolean := False;
         Permission_First_Y : Natural := 0;
         Found_Metadata_Key : Boolean := False;
         Found_Kind         : Boolean := False;
         Found_Extra        : Boolean := False;
         Found_Extra_First  : Boolean := False;
         Found_Extra_Second : Boolean := False;
         Extra_First_Y      : Natural := 0;
         Found_Relative_Time : Boolean := False;
         Found_A11y_Section : Boolean := False;
         Info_X             : constant Natural := Frame.Layout.Main_Width + 10;
         Info_Y             : constant Natural := Frame.Layout.Main_Y + 10;
      begin
         for Text of Frame.Text loop
            declare
               Value : constant String := To_String (Text.Text);
            begin
               if Value = Files.Localization.Text ("info.name")
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y
               then
                  Found_Name := True;
               elsif Value = Files.Localization.Text ("info.name")
                 and then Text.X = Info_X + 1
                 and then Text.Y = Info_Y
               then
                  Found_Name_Bold := True;
               elsif Value = "meta.txt"
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y + 20
               then
                  Found_Name_Value := True;
               elsif Value = Files.Localization.Text ("info.filetype") then
                  Found_Filetype := True;
               elsif Value = Files.Localization.Text ("info.kind.text") then
                  Found_Filetype_Value := True;
               elsif Value = Files.Localization.Text ("info.size") then
                  Found_Size := True;
               elsif Ada.Strings.Fixed.Index
                 (Value, " " & Files.Localization.Text ("details.size.unit.bytes")) > 1
                 and then Value /= Files.Localization.Text ("info.size")
               then
                  Found_Size_Value := True;
               elsif Value = Files.Localization.Text ("info.created") then
                  Found_Created := True;
               elsif Value = Files.Localization.Text ("info.modified") then
                  Found_Modified := True;
               elsif Value = Files.Localization.Text ("info.permissions") then
                  Found_Permissions := True;
               elsif Value = Files.Localization.Text ("info.permissions.readable") then
                  Found_Permission_First := True;
                  Permission_First_Y := Text.Y;
               elsif Value = Files.Localization.Text ("info.permissions.writable") then
                  Found_Permission_Second :=
                    Permission_First_Y > 0 and then Text.Y = Permission_First_Y + 20;
               elsif Value = Files.Localization.Text ("info.metadata_error") then
                  Found_Metadata_Key := True;
               elsif Value = Files.Localization.Text ("info.kind") then
                  Found_Kind := True;
               elsif Value = Files.Localization.Text ("info.extra") then
                  Found_Extra := True;
               elsif Value =
                 Detail_Value ("info.extra.text.lines.prefix", "1", "info.extra.text.lines.suffix")
               then
                  Found_Extra_First := True;
                  Extra_First_Y := Text.Y;
               elsif Value =
                 Detail_Localized_Value
                   ("info.extra.encoding.prefix",
                    "info.extra.encoding.ascii",
                    "info.extra.encoding.suffix")
               then
                  Found_Extra_Second := Extra_First_Y > 0 and then Text.Y = Extra_First_Y + 20;
               elsif Value = Files.Localization.Text ("time.relative.now")
                 or else Ada.Strings.Fixed.Index
                   (Value, Files.Localization.Text ("time.relative.today") & " ") = 1
               then
                  Found_Relative_Time := True;
               end if;
            end;
         end loop;

         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_List_Item
              and then To_String (Node.Name) = "meta.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.filetype") & ": " &
                 Files.Localization.Text ("info.kind.text")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.size") & ":") > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.modified") & ":") > 0
            then
               Found_A11y_Section := True;
            end if;
         end loop;

         Assert (Found_Name, "info pane frame includes localized name row");
         Assert (Found_Name_Bold, "info pane label renders with bold offset");
         Assert (Found_Name_Value, "info pane value follows label on next row");
         Assert (Found_Filetype, "info pane frame includes localized filetype row");
         Assert (Found_Filetype_Value, "info pane filetype value is separate from label");
         Assert (Found_Size, "info pane frame includes localized size row");
         Assert (Found_Size_Value, "info pane frame includes size unit");
         Assert (Found_Created, "info pane frame includes localized missing creation row");
         Assert (Found_Modified, "info pane frame includes localized modified row");
         Assert (Found_Permissions, "info pane frame includes localized permissions row");
         Assert (Found_Permission_First, "info pane frame includes first permission row");
         Assert (Found_Permission_Second, "info pane frame includes second permission row");
         Assert (Found_Metadata_Key, "info pane frame includes localized metadata fallback row");
         Assert (Found_Kind, "info pane frame includes filetype-specific detail row");
         Assert (Found_Extra, "info pane frame includes filetype-specific extra metadata row");
         Assert (Found_Extra_First, "info pane details renders first metadata item");
         Assert (Found_Extra_Second, "info pane details renders second metadata item on separate row");
         Assert (Found_Relative_Time, "info pane humanizes recent metadata timestamps");
         Assert (Found_A11y_Section, "info pane frame exposes accessible selected-file section");
      end;

      declare
         Items          : Files.File_System.Item_Vectors.Vector;
         Broken_Item    : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "broken.txt",
              Kind        => Files.Types.Regular_File_Item,
              Filetype    => "text/plain");
         Found_Localized : Boolean := False;
         Found_A11y_Metadata : Boolean := False;
      begin
         Broken_Item.Metadata_Error := True;
         Broken_Item.Error_Key := To_Unbounded_String ("error.metadata.read");
         Items.Append (Broken_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 800, Line_Height => 20);

         for Text of Frame.Text loop
            if To_String (Text.Text) = Files.Localization.Text ("error.metadata.read")
            then
               Found_Localized := True;
            end if;
         end loop;
         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_List_Item
              and then To_String (Node.Name) = "broken.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.metadata_error") & ": "
                 & Files.Localization.Text ("error.metadata.read")) > 0
            then
               Found_A11y_Metadata := True;
            end if;
         end loop;

         Assert (Found_Localized, "info pane localizes metadata error keys");
         Assert (Found_A11y_Metadata, "info pane accessibility describes metadata error keys");
      end;

      Write_File (Join (Root, "blob.bin"), "binary");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "blob.bin");
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Files.Localization.Text ("info.extra.extension.prefix") &
         "bin" &
         Files.Localization.Text ("info.extra.extension.suffix"),
         "info pane captures extension metadata fallback");
      Files.Model.Toggle_Info_Pane (Model);

      Write_File (Join (Root, "run.sh"), "#!/bin/sh" & ASCII.LF);
      declare
         Items : Files.File_System.Item_Vectors.Vector;
         Exec_Item : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "run.sh",
              Kind        => Files.Types.Executable_Item,
              Filetype    => "application/x-executable");
      begin
         Exec_Item.Size_Available := True;
         Exec_Item.Size := Long_Long_Integer (Ada.Directories.Size (Join (Root, "run.sh")));
         Items.Append (Exec_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (Ada.Strings.Fixed.Index
              (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra),
               Files.Localization.Text ("info.extra.executable.size.prefix")) = 1,
            "info pane captures executable snapshot metadata without reading file contents");
      end;

      declare
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append
           (Files.File_System.Make_Item
              (Parent_Path => Join (Root, "missing-parent"),
               Name        => "ghost.bin",
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "application/octet-stream"));
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
            Files.Localization.Text ("info.extra.extension.prefix") &
            "bin" &
            Files.Localization.Text ("info.extra.extension.suffix"),
            "info pane snapshot uses item fields without reading a backing file");
      end;

      Write_File (Join (Root, "more.txt"), "efgh");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Filter (Model, ".txt");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 2, "info snapshot includes all selected items");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Name) = "meta.txt",
         "multi-selection info preserves first selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Name) = "more.txt",
         "multi-selection info preserves second selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes first filetype detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes second filetype detail");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      declare
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
         Info_Layout  : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);
         Row_Stride   : constant Natural := (Info_Layout.Content_Height - 20) / 2;
         First_Name_Y  : Natural := 0;
         Second_Name_Y : Natural := 0;
         Name_Label    : constant String := Files.Localization.Text ("info.name");
      begin
         for Text of Frame.Text loop
            if To_String (Text.Text) = Name_Label
              and then Text.Y = Info_Layout.Y + 10
            then
               First_Name_Y := Text.Y;
            elsif To_String (Text.Text) = Name_Label
              and then Text.Y = Info_Layout.Y + 10 + Row_Stride
            then
               Second_Name_Y := Text.Y;
            end if;
         end loop;

         Assert
           (First_Name_Y > 0 and then Second_Name_Y = First_Name_Y + Row_Stride,
            "info pane spaces selected sections by every rendered row");
      end;
   end Test_Info_Pane_Metadata_Snapshot;

   procedure Test_Controller_Refresh_And_History_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Second   : constant String := Join (Root, "second");
      Branch   : constant String := Join (Root, "branch");
      Missing_Home : constant String := Join (Root, "missing-home");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Ctrl     : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Ada.Directories.Create_Path (Second);
      Ada.Directories.Create_Path (Branch);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (Second, "two.txt"));
      Write_File (Join (Branch, "branch.txt"));
      Load := Files.File_System.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, Missing_Home);
      Files.Model.Begin_Create_File (Model, "failed-home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.home");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed home load is reported");
      Assert (To_String (Result.Operation.Path) = Missing_Home, "failed home reports attempted home path");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.path.missing",
         "failed home reports path diagnostic");
      Assert (Files.Model.Current_Path (Model) = First, "failed home preserves current path");
      Assert (Files.Model.Item_Count (Model) = 1, "failed home preserves loaded items");
      Assert (Files.Model.Last_Error_Key (Model) = "error.path.missing", "failed home records path error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed home preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed home preserves rename state");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed home preserves command palette");
      Assert (Files.Model.Command_Palette_Query (Model) = "navigate.home", "failed home preserves palette query");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Files.Model.Begin_Create_File (Model, "home-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.home");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Home_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "home load succeeds");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "home operation reports normalized home path");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "home clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "home clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "home clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "home clears command palette");
      Assert (Files.Model.Command_Palette_Query (Model) = "", "home clears palette query");
      Write_File (Join (First, "fresh.txt"));
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Scroll_Info_Pane (Model, Lines => 4);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "directory.refresh");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh operation succeeds");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "refresh operation reports current path");
      Assert (Files.Model.Item_Count (Model) = 2, "refresh loads newly created item");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "refresh clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "refresh clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "refresh clears rename focus");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "refresh clears command palette");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "refresh clears temporary selection");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "refresh resets info pane scroll");
      Files.Model.Select_Visible (Model, 1);
      Write_File (Join (First, "later.txt"));
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "directory.refresh");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second refresh operation succeeds");
      Assert (Files.Model.Item_Count (Model) = 3, "second refresh loads later item");
      Assert (Files.Model.Selected_Count (Model) = 1, "refresh preserves the selection by name");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "directory.refresh");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed refresh is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "failed refresh reports current path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "failed refresh preserves path");
      Assert (Files.Model.Item_Count (Model) = 3, "failed refresh preserves loaded items");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed refresh records load error");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "failed refresh preserves command palette");
      Assert
        (Files.Model.Command_Palette_Query (Model) = "directory.refresh",
         "failed refresh preserves palette query");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));
      Write_File (Join (First, "later.txt"));

      Load := Files.File_System.Load_Directory (Second, Settings);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Navigate_To (Model, Second, Load.Items);
      Assert (Files.Model.Root_Count (Model) = 0, "direct navigation clears stale root selector entries");
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "back operation reloads target");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "back operation reports restored path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "back restores first path");
      Assert (Files.Model.Item_Count (Model) = 3, "back loads first path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "back clears rename focus");
      Files.Model.Begin_Create_File (Model, "forward-history-pending.txt");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "forward operation reloads target");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Second),
         "forward operation reports restored path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Second), "forward restores second path");
      Assert (Files.Model.Item_Count (Model) = 1, "forward loads second path items");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "forward clears rename focus");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Begin_Create_File (Model, "failed-history-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed back reload is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (First),
         "failed back reports attempted path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Second), "failed back rolls path back");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed back records load error");
      Assert (Files.Model.Can_Go_Back (Model), "failed back preserves back history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed back preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves rename state");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second back operation succeeds");
      Project_Tools.Files.Delete_Tree (Second);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "one-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed forward preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves normal rename state");
      Assert (Files.Model.Rename_Text (Model) = "one-renamed.txt", "failed forward preserves rename text");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "failed forward restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Begin_Create_File (Model, "failed-forward-pending.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed forward reload is reported");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Second),
         "failed forward reports attempted path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (First), "failed forward rolls path back");
      Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load", "failed forward records load error");
      Assert (Files.Model.Can_Go_Forward (Model), "failed forward preserves forward history");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed forward preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "failed forward preserves rename state");
      Ada.Directories.Create_Path (Second);
      Write_File (Join (Second, "two.txt"));
      Files.Model.Cancel_Create_File (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second forward operation succeeds");
      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "two-renamed.txt");
      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "failed back preserves rename result");
      Assert (Files.Model.Rename_Is_Active (Model), "failed back preserves normal rename state");
      Assert (Files.Model.Rename_Text (Model) = "two-renamed.txt", "failed back preserves rename text");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "failed back restores rename focus");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));

      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_L, Ctrl);
      Assert (Result.Command = Files.Commands.Focus_Path_Input_Command, "Control+L focuses path for branch");
      Files.Controller.Replace_Focused_Text (Model, Branch);
      Result := Files.Controller.Handle_Key (Model, Settings, Files.Types.Key_Return);
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "path input navigates to branch");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Branch),
         "branch path input reports normalized path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Branch), "branch navigation loads path");
      Assert (not Files.Model.Can_Go_Forward (Model), "new controller navigation clears forward history");
      Assert (Files.Model.Item_Count (Model) = 1, "branch navigation carries loaded directory items");
   end Test_Controller_Refresh_And_History_Loading;

   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "compress");
      Zip_Path : constant String := Join (Dir, "report.zip");
      Sz_Path  : constant String := Join (Dir, "report.7z");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;

      function First_Bytes (Path : String; Count : Positive) return String is
         Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      begin
         if Raw'Length < Count then
            return Raw;
         end if;
         return Raw (Raw'First .. Raw'First + Count - 1);
      end First_Bytes;

      Zip_Magic : constant String :=
        "PK" & Character'Val (3) & Character'Val (4);
      Sz_Magic  : constant String :=
        Character'Val (16#37#) & Character'Val (16#7A#) & Character'Val (16#BC#)
        & Character'Val (16#AF#) & Character'Val (16#27#) & Character'Val (16#1C#);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "report.txt"), "hello compression payload");
      Write_File (Join (Dir, "notes.txt"), "second file payload");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Compress_Zip_Command, Model),
         "compress-zip command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_Zip_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "compress to zip succeeds");
      Assert (Ada.Directories.Exists (Zip_Path), "zip archive is created next to the first item");
      Assert (First_Bytes (Zip_Path, 4) = Zip_Magic, "zip archive begins with the ZIP local-header signature");

      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_7z_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "compress to 7z succeeds");
      Assert (Ada.Directories.Exists (Sz_Path), "7z archive is created next to the first item");
      Assert (First_Bytes (Sz_Path, 6) = Sz_Magic, "7z archive begins with the 7z signature");
   end Test_Compress_Selected_Operation;

   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir        : constant String := Join (Root, "duplicate");
      Source     : constant String := Join (Dir, "report.txt");
      Copy_Path  : constant String := Join (Dir, "report (copy).txt");
      Payload    : constant String := "duplicate payload contents";
      Load       : Files.File_System.Directory_Load_Result;
      Model      : Files.Model.Window_Model;
      Routed     : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Model),
         "duplicate command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Duplicate_Selected_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "duplicate succeeds");
      Assert (Ada.Directories.Exists (Source), "original item still exists after duplicating");
      Assert (Ada.Directories.Exists (Copy_Path), "duplicate is created with a distinct name");
      Assert
        (Project_Tools.Files.Read_Raw_File (Copy_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "duplicate has identical contents to the original");
   end Test_Duplicate_Selected_Operation;

   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings        : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir             : constant String := Join (Root, "extract");
      Source_Report   : constant String := Join (Dir, "report.txt");
      Source_Notes    : constant String := Join (Dir, "notes.txt");
      Archive_Path    : constant String := Join (Dir, "bundle.zip");
      Dest_Dir        : constant String := Join (Dir, "bundle");
      Out_Report      : constant String := Join (Dest_Dir, "report.txt");
      Out_Notes       : constant String := Join (Dest_Dir, "notes.txt");
      Report_Payload  : constant String := "first extraction payload";
      Notes_Payload   : constant String := "second extraction payload";
      Inputs          : Zlib.Text_Array (1 .. 2);
      Names           : Zlib.Text_Array (1 .. 2);
      Build_Status    : Zlib.Status_Code;
      Load            : Files.File_System.Directory_Load_Result;
      Model           : Files.Model.Window_Model;
      Routed          : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source_Report, Report_Payload);
      Write_File (Source_Notes, Notes_Payload);

      --  Build a real ZIP archive holding both files next to the originals.
      Inputs (1) := To_Unbounded_String (Source_Report);
      Inputs (2) := To_Unbounded_String (Source_Notes);
      Names (1) := To_Unbounded_String ("report.txt");
      Names (2) := To_Unbounded_String ("notes.txt");
      Zlib.ZIP_Files (Inputs, Archive_Path, Names, Status => Build_Status);
      Assert (Build_Status = Zlib.Ok, "test archive is created");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "bundle.zip");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
         "extract command is enabled when an archive is selected");

      Routed := Files.Controller.Execute_Command (Files.Commands.Extract_Archive_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "extract succeeds");
      Assert (Ada.Directories.Exists (Dest_Dir), "destination folder is created from the archive base name");
      Assert (Ada.Directories.Exists (Out_Report), "first archived file is extracted");
      Assert (Ada.Directories.Exists (Out_Notes), "second archived file is extracted");
      Assert
        (Project_Tools.Files.Read_Raw_File (Out_Report)
           = Project_Tools.Files.Read_Raw_File (Source_Report),
         "first extracted file matches the original contents");
      Assert
        (Project_Tools.Files.Read_Raw_File (Out_Notes)
           = Project_Tools.Files.Read_Raw_File (Source_Notes),
         "second extracted file matches the original contents");
   end Test_Extract_Selected_Operation;

   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LF         : constant Character := ASCII.LF;
      App_Base   : constant String := Join (Root, "xdg_apps");
      Apps_Dir   : constant String := Join (App_Base, "applications");
      Empty_Dirs : constant String := Join (Root, "absent_data_dir");
      Had_Home   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Dirs   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_DIRS");
      Old_Home   : Unbounded_String;
      Old_Dirs   : Unbounded_String;

      procedure Restore_Environment is
      begin
         if Had_Home then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Dirs then
            Ada.Environment_Variables.Set ("XDG_DATA_DIRS", To_String (Old_Dirs));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_DIRS");
         end if;
      end Restore_Environment;

      function Find
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Applications.Application is
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               return App;
            end if;
         end loop;
         return (Name => Null_Unbounded_String, Exec => Null_Unbounded_String);
      end Find;
   begin
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Dirs then
         Old_Dirs := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_DIRS"));
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Apps_Dir);

      Write_File
        (Join (Apps_Dir, "editor.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Text Editor" & LF & "Exec=editor %F" & LF);
      Write_File
        (Join (Apps_Dir, "viewer.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Image Viewer" & LF & "Exec=viewer --open %U" & LF
         & "Terminal=false" & LF);
      Write_File
        (Join (Apps_Dir, "nodisplay.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Hidden Display" & LF & "NoDisplay=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "hidden.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Gone" & LF & "Hidden=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "link.desktop"),
         "[Desktop Entry]" & LF & "Type=Link" & LF
         & "Name=A Link" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "noexec.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=No Command" & LF & "Exec=%F" & LF);

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", App_Base);
      Ada.Environment_Variables.Set ("XDG_DATA_DIRS", Empty_Dirs);

      declare
         Apps : constant Files.Applications.Application_Vectors.Vector :=
           Files.Applications.Available_Applications;
         Editor : constant Files.Applications.Application := Find (Apps, "Text Editor");
         Viewer : constant Files.Applications.Application := Find (Apps, "Image Viewer");
      begin
         Assert
           (Natural (Apps.Length) = 2,
            "only displayable application entries are returned");
         Assert
           (To_String (Apps.First_Element.Name) = "Image Viewer",
            "applications are sorted case-insensitively by name");
         Assert
           (To_String (Editor.Exec) = "editor",
            "Exec field codes are stripped (editor)");
         Assert
           (To_String (Viewer.Exec) = "viewer --open",
            "Exec field codes are stripped while base args are kept");

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Viewer, Targets);
            Assert
              (To_String (Action.Executable) = "viewer",
               "action executable is the first Exec token");
            Assert
              (not Action.Use_Shell,
               "open-with action is not shell-wrapped");
            Assert
              (Natural (Action.Arguments.Length) = 3,
               "arguments are remaining Exec tokens followed by each target");
            Assert
              (To_String (Action.Arguments.Element (1)) = "--open",
               "base Exec argument is preserved");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a.txt",
               "first target path is appended");
            Assert
              (To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "second target path is appended");
         end;
      end;

      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Available_Applications;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Operation_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Operations;

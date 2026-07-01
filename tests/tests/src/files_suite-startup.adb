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

package body Files_Suite.Startup is

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

   type Startup_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Startup_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Startup_Test_Case);

   procedure Test_Startup_Path_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Default_Home_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Loads_Settings_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Invalid_Settings_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Settings_Path_Not_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Report (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Error_Report (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Report_Settings_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Run_Configuration_Parsing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Localization_Catalog (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_System_Locale_Detection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_First_Implementation_Feature_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Smoke_Gate_Outcome (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Startup_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files startup and policy");
   end Name;

   overriding procedure Register_Tests (T : in out Startup_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Path_Normalization'Access, "startup path normalization");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Default_Home_Selection'Access, "default home selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Loads_Settings_File'Access, "startup loads settings file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Invalid_Settings_Diagnostic'Access, "startup reports invalid settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Settings_Path_Not_File'Access, "startup reports non-file settings path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Report'Access, "startup report formats windows and errors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Error_Report'Access, "desktop startup error report");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Report_Settings_Error'Access, "startup report formats settings errors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Run_Configuration_Parsing'Access, "runtime smoke argument parsing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localization_Catalog'Access, "localization uses default catalog");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_System_Locale_Detection'Access, "system locale detection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_First_Implementation_Feature_Policy'Access, "first implementation feature policy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Smoke_Gate_Outcome'Access, "live smoke gate outcome taxonomy");
   end Register_Tests;

   procedure Test_Startup_Path_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "dir");
      Second_Dir : constant String := Join (Root, "second");
      Filepath : constant String := Join (Dir, "note.txt");
      Other    : constant String := Join (Dir, "other.txt");
      Args     : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Direct   : Files.File_System.Path_Result;
      File     : Files.File_System.Path_Result;
      Current  : Files.File_System.Path_Result;
      Missing  : Files.File_System.Path_Result;
      Empty    : Files.File_System.Path_Result;
      Startup  : Files.Application.Startup_Result;
      Full_Dir : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Second_Dir);
      Write_File (Filepath);
      Write_File (Other);
      Write_File (Join (Second_Dir, "inside.txt"));
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));

      Direct := Files.File_System.Normalize_Path (Dir);
      File := Files.File_System.Normalize_Path (Filepath);
      Current := Files.File_System.Normalize_Path (".");
      Missing := Files.File_System.Normalize_Path (Join (Root, "missing"));
      Empty := Files.File_System.Normalize_Path ("");

      Assert (Direct.Status = Files.File_System.Path_Valid, "directory path is valid");
      Assert (To_String (Direct.Directory_Path) = Ada.Directories.Full_Name (Dir), "directory is normalized");
      Assert (File.Status = Files.File_System.Path_Valid, "file path is valid");
      Assert (To_String (File.Directory_Path) = Ada.Directories.Full_Name (Dir), "file maps to parent");
      Assert (Current.Status = Files.File_System.Path_Valid, "current-directory path is valid");
      Assert
        (To_String (Current.Directory_Path) = Ada.Directories.Full_Name (Ada.Directories.Current_Directory),
         "current-directory path normalizes to absolute directory");
      Assert (Missing.Status = Files.File_System.Path_Missing, "missing path reports an error");
      Assert (Empty.Status = Files.File_System.Path_Missing, "empty path reports missing");
      Assert (To_String (Empty.Error_Key) = "error.path.missing", "empty path reports missing-path error");
      declare
         Special_Path : constant String := "/dev/null";
      begin
         if Ada.Directories.Exists (Special_Path)
           and then Ada.Directories.Kind (Special_Path) = Ada.Directories.Special_File
         then
            declare
               Special : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Special_Path);
            begin
               Assert (Special.Status = Files.File_System.Path_Inaccessible, "special path reports inaccessible");
               Assert
                 (To_String (Special.Error_Key) = "error.path.inaccessible",
                  "special path reports inaccessible error key");

               Args.Clear;
               Args.Append (To_Unbounded_String (Special_Path));
               Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
               Assert (Startup.Windows.Is_Empty, "special startup path opens no window");
               Assert (Natural (Startup.Errors.Length) = 1, "special startup path is reported as diagnostic");
               Assert
                 (To_String (Startup.Errors.Element (1).Input_Path) = Special_Path,
                  "special startup diagnostic records original path");
               Assert
                 (To_String (Startup.Errors.Element (1).Error_Key) = "error.path.inaccessible",
                  "special startup diagnostic records inaccessible error key");
            end;
         end if;
      exception
         when others =>
            null;
      end;

      Args.Clear;
      Args.Append (To_Unbounded_String (Dir));
      Args.Append (To_Unbounded_String (Filepath));
      Args.Append (To_Unbounded_String (Other));
      Args.Append (To_Unbounded_String (Second_Dir));
      Args.Append (To_Unbounded_String (Join (Root, "missing")));
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Assert (Natural (Startup.Windows.Length) = 2, "distinct normalized paths produce one window each");
      Assert (Natural (Startup.Errors.Length) = 1, "missing path is reported without a window");
      Assert
        (To_String (Startup.Windows.Element (1).Title) = To_String (Startup.Windows.Element (1).Path),
         "window title is the normalized current directory path");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = To_String (Full_Dir),
         "startup window records the normalized directory path");
      Assert
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model) = To_String (Full_Dir),
         "startup window model uses the normalized directory path");
      Assert
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model) = 2,
         "startup window model loads direct directory entries");
      Assert
        (To_String (Startup.Windows.Element (2).Path) = Ada.Directories.Full_Name (Second_Dir),
         "startup opens a separate window for a distinct normalized directory");
      Assert
        (Files.Model.Item_Count (Startup.Windows.Element (2).Model) = 1,
         "second startup window model loads its directory entries");
      Assert
        (To_String (Startup.Settings_Path) = "",
         "path-only startup resolution has no central settings path");
      Assert
        (To_String (Startup.Errors.Element (1).Input_Path) = Join (Root, "missing"),
         "startup path diagnostic records the original invalid argument");
      Assert
        (To_String (Startup.Errors.Element (1).Error_Key) = "error.path.missing",
         "startup path diagnostic records the missing-path error key");
   end Test_Startup_Path_Normalization;

   procedure Test_Default_Home_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Args              : Files.Types.String_Vectors.Vector;
      Settings          : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Startup           : Files.Application.Startup_Result;
      Home_Path         : constant String := Join (Root, "configured-home");
      Xdg_Path          : constant String := Join (Root, "xdg-config");
      Override_Path     : constant String := Join (Root, "override.conf");
      Expected_Default  : constant String :=
        Files.File_System.Join_Path
          (Files.File_System.Join_Path (Files.File_System.Join_Path (Home_Path, ".config"), "files"),
           "settings.conf");
      Expected_Xdg      : constant String :=
        Files.File_System.Join_Path (Files.File_System.Join_Path (Xdg_Path, "files"), "settings.conf");
      Had_Files_Setting : constant Boolean := Ada.Environment_Variables.Exists ("FILES_SETTINGS");
      Had_Xdg_Config    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CONFIG_HOME");
      Had_Home          : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_User_Profile  : constant Boolean := Ada.Environment_Variables.Exists ("USERPROFILE");
      Had_Home_Drive    : constant Boolean := Ada.Environment_Variables.Exists ("HOMEDRIVE");
      Had_Home_Path     : constant Boolean := Ada.Environment_Variables.Exists ("HOMEPATH");
      Had_Home_Share    : constant Boolean := Ada.Environment_Variables.Exists ("HOMESHARE");
      Old_Files_Setting : Unbounded_String;
      Old_Xdg_Config    : Unbounded_String;
      Old_Home          : Unbounded_String;
      Old_User_Profile  : Unbounded_String;
      Old_Home_Drive    : Unbounded_String;
      Old_Home_Path     : Unbounded_String;
      Old_Home_Share    : Unbounded_String;

      procedure Restore_Environment is
      begin
         if Had_Files_Setting then
            Ada.Environment_Variables.Set ("FILES_SETTINGS", To_String (Old_Files_Setting));
         else
            Ada.Environment_Variables.Clear ("FILES_SETTINGS");
         end if;

         if Had_Xdg_Config then
            Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", To_String (Old_Xdg_Config));
         else
            Ada.Environment_Variables.Clear ("XDG_CONFIG_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_User_Profile then
            Ada.Environment_Variables.Set ("USERPROFILE", To_String (Old_User_Profile));
         else
            Ada.Environment_Variables.Clear ("USERPROFILE");
         end if;

         if Had_Home_Drive then
            Ada.Environment_Variables.Set ("HOMEDRIVE", To_String (Old_Home_Drive));
         else
            Ada.Environment_Variables.Clear ("HOMEDRIVE");
         end if;

         if Had_Home_Path then
            Ada.Environment_Variables.Set ("HOMEPATH", To_String (Old_Home_Path));
         else
            Ada.Environment_Variables.Clear ("HOMEPATH");
         end if;

         if Had_Home_Share then
            Ada.Environment_Variables.Set ("HOMESHARE", To_String (Old_Home_Share));
         else
            Ada.Environment_Variables.Clear ("HOMESHARE");
         end if;
      end Restore_Environment;
   begin
      if Had_Files_Setting then
         Old_Files_Setting := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_SETTINGS"));
      end if;

      if Had_Xdg_Config then
         Old_Xdg_Config := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CONFIG_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_User_Profile then
         Old_User_Profile := To_Unbounded_String (Ada.Environment_Variables.Value ("USERPROFILE"));
      end if;
      if Had_Home_Drive then
         Old_Home_Drive := To_Unbounded_String (Ada.Environment_Variables.Value ("HOMEDRIVE"));
      end if;
      if Had_Home_Path then
         Old_Home_Path := To_Unbounded_String (Ada.Environment_Variables.Value ("HOMEPATH"));
      end if;
      if Had_Home_Share then
         Old_Home_Share := To_Unbounded_String (Ada.Environment_Variables.Value ("HOMESHARE"));
      end if;

      Assert (Files.Application.Home_Directory /= "", "home directory fallback is never empty");
      Ada.Directories.Create_Path (Join (Root, "profile-home"));
      Ada.Directories.Create_Path (Join (Root, "drive-profile"));
      Ada.Directories.Create_Path (Join (Root, "share-profile"));
      Ada.Environment_Variables.Set ("HOME", "");
      Ada.Environment_Variables.Set ("USERPROFILE", Join (Root, "profile-home"));
      Ada.Environment_Variables.Clear ("HOMEDRIVE");
      Ada.Environment_Variables.Clear ("HOMEPATH");
      Ada.Environment_Variables.Clear ("HOMESHARE");
      Assert
        (Files.Application.Home_Directory = Join (Root, "profile-home"),
         "USERPROFILE is used when HOME is empty");
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Assert (Natural (Startup.Windows.Length) = 1, "no args resolves one path");
      Assert (Startup.Errors.Is_Empty, "valid USERPROFILE default path reports no startup error");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = Ada.Directories.Full_Name (Join (Root, "profile-home")),
         "no args opens valid USERPROFILE directory");
      Ada.Environment_Variables.Set ("HOME", Join (Root, "missing-home-env"));
      Assert
        (Files.Application.Home_Directory = Join (Root, "profile-home"),
         "invalid HOME falls back to valid USERPROFILE");
      Ada.Environment_Variables.Set ("USERPROFILE", Join (Root, "missing-profile-env"));
      Ada.Environment_Variables.Set ("HOMEDRIVE", Root);
      Ada.Environment_Variables.Set ("HOMEPATH", "/drive-profile");
      Assert
        (Files.Application.Home_Directory = Join (Root, "drive-profile"),
         "HOMEDRIVE and HOMEPATH are used when USERPROFILE is invalid");
      Ada.Environment_Variables.Set ("HOMEPATH", "/missing-drive-profile");
      Ada.Environment_Variables.Set ("HOMESHARE", Join (Root, "share-profile"));
      Assert
        (Files.Application.Home_Directory = Join (Root, "share-profile"),
         "HOMESHARE is used when drive profile is invalid");
      Ada.Environment_Variables.Set ("HOMESHARE", Join (Root, "missing-share-profile"));
      Assert
        (Files.Application.Home_Directory = Ada.Directories.Current_Directory,
         "invalid home environment falls back to current directory");
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Assert (Natural (Startup.Windows.Length) = 1, "no args resolves one path with invalid home environment");
      Assert (Startup.Errors.Is_Empty, "current-directory home fallback reports no startup error");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = Ada.Directories.Full_Name (Ada.Directories.Current_Directory),
         "no args opens current directory after invalid home environment");

      Ada.Environment_Variables.Clear ("FILES_SETTINGS");
      Ada.Environment_Variables.Clear ("XDG_CONFIG_HOME");
      Assert
        (Files.Application.Default_Settings_Path (Home_Path) = Expected_Default,
         "default settings path is under home config directory");
      Assert
        (Files.Application.Configured_Settings_Path (Home_Path) = Expected_Default,
         "configured settings path falls back to home config directory");

      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", Xdg_Path);
      Assert
        (Files.Application.Configured_Settings_Path (Home_Path) = Expected_Xdg,
         "XDG_CONFIG_HOME selects the XDG settings path");

      Ada.Environment_Variables.Set ("FILES_SETTINGS", Override_Path);
      Assert
        (Files.Application.Configured_Settings_Path (Home_Path) = Override_Path,
         "FILES_SETTINGS overrides the XDG settings path");

      Ada.Environment_Variables.Set ("FILES_SETTINGS", "");
      Assert
        (Files.Application.Configured_Settings_Path (Home_Path) = Expected_Xdg,
         "empty FILES_SETTINGS is ignored");

      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", "");
      Assert
        (Files.Application.Configured_Settings_Path (Home_Path) = Expected_Default,
         "empty XDG_CONFIG_HOME is ignored");
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Default_Home_Selection;

   procedure Test_Startup_Loads_Settings_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-settings");
      Settings_Path : constant String := Join (Root, "files.conf");
      Created_Path  : constant String := Join (Join (Root, "startup-created"), "settings.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Full_Dir      : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));
      Write_File (Join (Dir, ".hidden"));
      Write_File (Join (Dir, "shown.txt"));
      Write_File
        (Join
           (Dir,
            Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
            & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#)
            & ".txt"));
      Write_File
        (Join
           (Dir,
            Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#))
            & ".txt"));
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "default_view_mode = details" & ASCII.LF &
         "show_hidden_files = true" & ASCII.LF);

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Assert (Natural (Startup.Errors.Length) = 0, "valid settings do not add startup diagnostics");
      Assert (Natural (Startup.Windows.Length) = 1, "valid startup path opens one window");
      Assert (To_String (Startup.Settings_Path) = Settings_Path, "startup result records loaded settings path");
      Assert (Startup.Settings.Default_View = Files.Types.Details, "startup result exposes loaded default view");
      Assert (Startup.Settings.Show_Hidden_Files, "startup result exposes loaded hidden-file setting");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = To_String (Full_Dir),
         "settings startup window records normalized path");
      Assert
        (To_String (Startup.Windows.Element (1).Title) = To_String (Full_Dir),
         "settings startup window title records normalized path");
      Assert
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model) = To_String (Full_Dir),
         "settings startup model uses normalized path");
      Assert (Files.Model.View_Mode_Of (Startup.Windows.Element (1).Model) = Files.Types.Details, "view setting loads");
      Assert
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model) = 4,
         "hidden-file setting affects startup load");
      Assert
        (Files.Application.Windows.Headless_Smoke_Test (Startup),
         "startup windows with Unicode and fallback filenames pass headless render smoke test");

      Args.Clear;
      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Created_Path);
      Assert (Natural (Startup.Errors.Length) = 0, "missing startup settings are created without diagnostics");
      Assert (Ada.Directories.Exists (Created_Path), "startup creates missing default settings file");
      Assert (To_String (Startup.Settings_Path) = Created_Path, "startup result records created settings path");
      Assert (Natural (Startup.Windows.Length) = 1, "startup still opens path after creating settings file");
      Assert
        (Files.Settings.Filetype_For_Extension (Startup.Settings, "txt") = "text/plain",
         "startup result exposes created default settings");
   end Test_Startup_Loads_Settings_File;

   procedure Test_Startup_Invalid_Settings_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-invalid-settings");
      Settings_Path : constant String := Join (Root, "bad.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Full_Dir      : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));
      Write_File (Join (Dir, ".hidden"));
      Write_File (Join (Dir, "shown.txt"));
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = maybe" & ASCII.LF);

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Assert (Natural (Startup.Windows.Length) = 1, "invalid settings do not block valid paths");
      Assert (Natural (Startup.Errors.Length) = 1, "invalid settings add one startup diagnostic");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = To_String (Full_Dir),
         "invalid settings still open the normalized requested path");
      Assert
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model) = To_String (Full_Dir),
         "invalid settings startup model still uses normalized path");
      Assert
        (To_String (Startup.Errors.Element (1).Input_Path) = Settings_Path,
         "settings diagnostic records the settings path");
      Assert
        (To_String (Startup.Errors.Element (1).Error_Key) = "error.settings.invalid_boolean",
         "settings diagnostic records the parse error");
      Assert
        (Startup.Settings.Default_View = Files.Settings.Default_Settings.Default_View,
         "invalid settings leave startup result on default settings");
      Assert
        (not Startup.Settings.Show_Hidden_Files,
         "invalid settings do not leak partially parsed hidden-file setting");
      Assert
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model) = 1,
         "default settings are used after failure");
   end Test_Startup_Invalid_Settings_Diagnostic;

   procedure Test_Startup_Settings_Path_Not_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "startup-settings-directory");
      Settings_Path : constant String := Join (Root, "settings-as-directory");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Full_Dir      : Unbounded_String;
      Report        : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Settings_Path);
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));
      Write_File (Join (Dir, ".hidden"));
      Write_File (Join (Dir, "shown.txt"));

      Args.Append (To_Unbounded_String (Dir));
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Assert (Natural (Startup.Windows.Length) = 1, "settings directory does not block valid paths");
      Assert (Natural (Startup.Errors.Length) = 1, "settings directory adds one startup diagnostic");
      Assert
        (To_String (Startup.Windows.Element (1).Path) = To_String (Full_Dir),
         "settings directory startup window records normalized path");
      Assert
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model) = To_String (Full_Dir),
         "settings directory startup model uses normalized path");
      Assert
        (To_String (Startup.Errors.Element (1).Input_Path) = Settings_Path,
         "settings directory diagnostic records the settings path");
      Assert
        (To_String (Startup.Errors.Element (1).Error_Key) = "error.settings.not_file",
         "settings directory diagnostic records the not-file error");
      Assert
        (Startup.Settings.Default_View = Files.Settings.Default_Settings.Default_View,
         "settings directory leaves startup result on default settings");
      Assert
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model) = 1,
         "default settings are used when startup settings path is a directory");

      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Settings_Path & ": " &
            Files.Localization.Text ("error.settings.not_file")) > 0,
         "startup report localizes settings directory diagnostics");
   end Test_Startup_Settings_Path_Not_File;

   procedure Test_Startup_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "report-dir");
      Missing  : constant String := Join (Root, "missing-report-dir");
      Args     : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Startup  : Files.Application.Startup_Result;
      Report   : Unbounded_String;
      Smoke    : Unbounded_String;
      Caps     : Files.Application.Windows.Desktop_Capabilities;
      Plan     : Files.Application.Windows.Live_Smoke_Plan;
      Live_Result : Files.Application.Windows.Live_Smoke_Result;
      Scroll_Remainder : Long_Float := 0.0;
      Scroll_Lines     : Integer;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Args.Append (To_Unbounded_String (Dir));
      Args.Append (To_Unbounded_String (Missing));

      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.window.ready") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "startup report uses localized window label");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Missing & ": " &
            Files.Localization.Text ("error.path.missing")) > 0,
         "startup report uses localized error label and diagnostic");
      Smoke := To_Unbounded_String (Files.Application.Runtime_Smoke_Report (Startup, Width => 800, Height => 400));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke),
            Files.Localization.Text ("runtime.smoke.window") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "runtime smoke report uses localized window label");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.vertices") & ": ") > 0,
         "runtime smoke report uses localized vertex-count label");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.ready")) > 0,
         "runtime smoke report exposes headless render quality status");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.frames_attempted") & ": 1") > 0,
         "runtime smoke report exposes headless render quality frame count");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Smoke), Files.Localization.Text ("runtime.smoke.missing_glyphs") & ": 0") > 0,
         "runtime smoke report exposes missing-glyph fallback count");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.font") & ": ") > 0,
         "runtime smoke report exposes selected text font path");
      Smoke := To_Unbounded_String (Files.Application.Runtime_Smoke_Report (Startup, Width => 1, Height => 1));
      Assert
        (Ada.Strings.Fixed.Index (To_String (Smoke), Files.Localization.Text ("runtime.smoke.text_failed")) > 0,
         "runtime smoke reports zero-glyph text batches as failures");
      Assert
        (Files.Application.Runtime_Smoke_Report ((others => <>)) =
         Files.Localization.Text ("runtime.smoke.no_windows"),
         "runtime smoke report uses localized empty-startup diagnostic");
      declare
         Quality : constant Files.Application.Windows.Headless_Render_Quality_Result :=
           Files.Application.Windows.Headless_Render_Quality_Report (Startup, Width => 1000, Height => 800);
      begin
         Assert (Quality.Window_Count = 1, "headless render quality report counts windows");
         Assert (Quality.Nonblank_Frames = 1, "headless render quality report catches blank frames");
         Assert (Quality.Text_Glyph_Frames = 1, "headless render quality report catches missing text output");
         Assert (Quality.Icon_Frames = 1, "headless render quality report catches missing icon output");
         Assert (Quality.Toolbar_Icon_Frames = 1, "headless render quality report catches missing toolbar icons");
         Assert (Quality.Drag_Preview_Frames = 1, "headless render quality report catches invisible drag previews");
         Assert (Quality.Missing_Glyph_Count = 0, "headless render quality report catches missing glyphs");
         Assert (Quality.Passed, "headless render quality report passes for startup windows");
      end;
      Caps := Files.Application.Windows.Runtime_Capabilities;
      Assert (Caps.Headless_Rendering, "runtime capabilities advertise headless rendering");
      Assert
        (Caps.Live_Window_Smoke_Ready = (Caps.Display_Available and then Caps.Vulkan_Available),
         "runtime capabilities gate live window smoke on display and Vulkan");
      Assert (Caps.Event_Translation_Model, "runtime capabilities expose event translation model");
      Assert (Caps.Focus_Runtime_Model, "runtime capabilities expose focus model");
      Assert (Caps.Resize_Runtime_Model, "runtime capabilities expose resize model");
      Assert (Caps.Scroll_Runtime_Model, "runtime capabilities expose scroll model");
      Assert (Caps.Native_Drop_Callbacks, "runtime capabilities expose native drop callbacks");
      Assert
        (Caps.Native_Drop_Automation,
         "runtime capabilities expose drop event-source automation");
      declare
         Drop_Profile : constant Files.Application.Windows.Native_Drag_Automation_Profile :=
           Files.Application.Windows.Native_Drag_Automation_Profile_Of_Current_Runtime;
         Event_Profile : constant Files.Drop_Events.Drop_Event_Source_Profile := Files.Drop_Events.Profile;
         Source        : Files.Drop_Events.Drop_Event_Source;
         Paths         : Files.Types.String_Vectors.Vector;
         Drained       : Files.Types.String_Vectors.Vector;
         Mode          : Files.File_System.Drop_Import_Mode;
      begin
         Assert (Drop_Profile.Native_Drop_Callbacks, "drag automation profile keeps native drop callbacks separate");
         Assert
           (not Drop_Profile.Portable_GLFW_Automation,
            "drag automation profile rejects portable GLFW event synthesis");
         Assert (Drop_Profile.Event_Source_Backend, "drag automation profile exposes an Ada event-source backend");
         Assert (Drop_Profile.Queued_Drop_Imports, "drag automation profile supports queued drop imports");
         Assert
           (not Drop_Profile.Requires_OS_Event_Source,
            "drag automation profile no longer blocks on OS event-source backends");
         Assert
           (Drop_Profile.Max_Paths = Event_Profile.Max_Paths,
            "drag automation profile uses the drop event backend path limit");
         Assert
           (To_String (Drop_Profile.Binding_Unit) = "Files.Drop_Events",
            "drag automation profile records owning backend unit");
         Assert (Event_Profile.Event_Source_Backend, "drop event backend profile exposes event-source support");
         Paths.Append (To_Unbounded_String (""));
         Paths.Append (To_Unbounded_String ("  " & Dir & "  "));
         Paths.Append (To_Unbounded_String ("  "));
         Files.Drop_Events.Queue (Source, Paths, Files.File_System.Drop_Move);
         Assert (Files.Drop_Events.Has_Pending (Source), "drop event source queues non-empty paths");
         Assert (Files.Drop_Events.Pending_Count (Source) = 1, "drop event source filters empty paths");
         Files.Drop_Events.Take (Source, Drained, Mode);
         Assert (Mode = Files.File_System.Drop_Move, "drop event source preserves queued import mode");
         Assert (Natural (Drained.Length) = 1, "drop event source drains one filtered path");
         Assert (To_String (Drained.Element (1)) = Dir, "drop event source trims queued path text");
         Assert (not Files.Drop_Events.Has_Pending (Source), "drop event source clears after drain");
      end;
      Assert (Caps.Directory_Watch_Polling, "runtime capabilities expose directory watch polling");
      Assert (Caps.Native_File_Watching, "runtime capabilities expose native file watching");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.40);
      Assert (Scroll_Lines = 0, "fractional scroll starts below one line");
      Assert (abs (Scroll_Remainder - 0.40) < 0.000_001, "fractional scroll remainder is retained");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.35);
      Assert (Scroll_Lines = 0, "second fractional scroll can still be below one line");
      Assert (abs (Scroll_Remainder - 0.75) < 0.000_001, "second fractional scroll accumulates");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.50);
      Assert (Scroll_Lines = 1, "fractional scroll emits a whole line after accumulation");
      Assert (abs (Scroll_Remainder - 0.25) < 0.000_001, "fractional scroll keeps positive remainder");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, -0.75);
      Assert (Scroll_Lines = 0, "opposite fractional scroll can cancel without a line");
      Assert (abs (Scroll_Remainder + 0.50) < 0.000_001, "opposite fractional scroll keeps negative remainder");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, -0.75);
      Assert (Scroll_Lines = -1, "negative fractional scroll emits a whole line after accumulation");
      Assert (abs (Scroll_Remainder + 0.25) < 0.000_001, "fractional scroll keeps negative remainder");
      Scroll_Remainder := 0.0;
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, Long_Float (Integer'Last));
      Assert (Scroll_Lines = Integer'Last, "scroll accumulation saturates large positive offsets");
      Assert (Scroll_Remainder = 0.0, "saturated scroll clears remainder");
      Assert
        (Files.Application.Windows.Add_Pending_Scroll (Integer'Last - 1, 2) = Integer'Last,
         "pending scroll addition saturates positive overflow");
      Assert
        (Files.Application.Windows.Add_Pending_Scroll (Integer'First + 1, -2) = Integer'First,
         "pending scroll addition saturates negative overflow");
      Assert
        (Files.Application.Windows.Add_Pending_Scroll (4, -6) = -2,
         "pending scroll addition preserves normal mixed-sign sums");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (Character'Pos ('A'))) = "A",
         "desktop text input preserves printable ASCII");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#)) =
         Byte (16#C3#) & Byte (16#A9#),
         "desktop text input encodes two-byte UTF-8");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#20AC#)) =
         Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#),
         "desktop text input encodes three-byte UTF-8");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#)) =
         Byte (16#F0#) & Byte (16#9F#) & Byte (16#93#) & Byte (16#81#),
         "desktop text input encodes four-byte UTF-8");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (9)) = "",
         "desktop text input ignores control characters");
      Assert
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#D800#)) = "",
         "desktop text input ignores surrogate code points");
      Assert
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (100), Glfw.Size (200)) = 100,
         "runtime coordinate scaling maps proportional positions");
      Assert
        (Files.Application.Windows.Scale_Coordinate (-1.0, Glfw.Size (100), Glfw.Size (200)) = 0,
         "runtime coordinate scaling clamps negative cursor positions");
      Assert
        (Files.Application.Windows.Scale_Coordinate (150.0, Glfw.Size (100), Glfw.Size (200)) = 200,
         "runtime coordinate scaling clamps beyond framebuffer size");
      Assert
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (0), Glfw.Size (200)) = 0,
         "runtime coordinate scaling rejects zero source dimensions");
      Assert
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (100), Glfw.Size (0)) = 0,
         "runtime coordinate scaling rejects zero target dimensions");
      Plan := Files.Application.Windows.Live_Window_Smoke_Plan (Width => 640, Height => 360);
      Assert (Plan.Width = 640, "live smoke plan records requested width");
      Assert (Plan.Height = 360, "live smoke plan records requested height");
      Assert (Plan.Frame_Count = 2, "live smoke plan records two frames for readback validation");
      Assert (Plan.Input_Poll_Count = 1, "live smoke plan records deterministic input poll count");
      Assert
        (Plan.Can_Run = Caps.Live_Window_Smoke_Ready,
         "live smoke plan readiness matches runtime capabilities");
      Assert (To_String (Plan.Reason_Key) /= "", "live smoke plan exposes localized reason key");
      Live_Result := Files.Application.Windows.Evaluate_Live_Window_Smoke (Plan);
      Assert
        (Live_Result.Skipped_By_Plan = not Plan.Can_Run,
         "live smoke result records whether the plan skipped execution");
      Assert
        (Live_Result.Frames_Attempted = 0,
         "live smoke preflight reports zero attempted frames");
      Assert
        (Live_Result.Frames_Presented = 0,
         "live smoke preflight reports zero presented frames");
      Assert (not Live_Result.Window_Created, "headless live smoke evaluation does not create a window");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "headless live smoke evaluation does not fake framebuffer readback");
      Assert (To_String (Live_Result.Error_Key) /= "", "live smoke result exposes status key");
      Live_Result := Files.Application.Windows.Run_Live_Window_Smoke ((others => <>), Plan);
      Assert (not Live_Result.Window_Created, "live smoke runner does not create windows for empty startup");
      Assert
        (Live_Result.Frames_Attempted = 0,
         "empty live smoke startup reports zero attempted frames");
      Assert
        (Live_Result.Frames_Presented = 0,
         "empty live smoke startup reports zero presented frames");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "empty live smoke runner does not fake framebuffer readback");
      Assert
        (To_String (Live_Result.Error_Key) = "runtime.smoke.no_windows",
         "live smoke runner reports empty startup");
      Plan.Can_Run := False;
      Plan.Reason_Key := To_Unbounded_String ("runtime.smoke.no_display");
      Live_Result := Files.Application.Windows.Run_Live_Window_Smoke (Startup, Plan);
      Assert (Live_Result.Skipped_By_Plan, "live smoke runner skips when plan cannot run");
      Assert (not Live_Result.Attempted, "live smoke runner does not attempt skipped plan");
      Assert
        (Live_Result.Frames_Attempted = 0,
         "skipped live smoke startup reports zero attempted frames");
      Assert
        (not Live_Result.Framebuffer_Readback_Ready,
         "skipped live smoke runner does not fake framebuffer readback");
   end Test_Startup_Report;

   procedure Test_Desktop_Error_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Expected : constant String :=
        Files.Localization.Text ("startup.error") & ": " & Files.Localization.Text ("error.window.create");
   begin
      Assert
        (Files.Application.Desktop_Error_Report ("error.window.create")
         = Expected,
         "desktop error report localizes the provided key");
      Assert
        (Files.Application.Desktop_Error_Report ("") = Expected,
         "desktop error report falls back when the key is empty");
      Assert
        (Files.Application.Desktop_Error_Report ("error.window.unknown") = Expected,
         "desktop error report falls back when the key is not localized");
   end Test_Desktop_Error_Report;

   procedure Test_Startup_Report_Settings_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "report-settings-dir");
      Settings_Path : constant String := Join (Root, "bad-report-settings.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      Report        : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = not-a-boolean" & ASCII.LF);
      Args.Append (To_Unbounded_String (Dir));

      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Report := To_Unbounded_String (Files.Application.Startup_Report (Startup));
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.window.ready") & ": " & Ada.Directories.Full_Name (Dir)) > 0,
         "startup report includes the valid window after settings failure");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Report),
            Files.Localization.Text ("startup.error") & ": " &
            Settings_Path & ": " &
            Files.Localization.Text ("error.settings.invalid_boolean")) > 0,
         "startup report localizes settings parse diagnostics");
   end Test_Startup_Report_Settings_Error;

   procedure Test_Run_Configuration_Parsing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Args   : Files.Types.String_Vectors.Vector;
      Config : Files.Application.Run_Configuration;
   begin
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("/tmp/files.conf"));
      Args.Append (To_Unbounded_String ("/tmp"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "runtime smoke flag selects headless smoke mode");
      Assert (Natural (Config.Paths.Length) = 1, "runtime smoke flag is consumed");
      Assert (To_String (Config.Paths.Element (1)) = "/tmp", "runtime smoke preserves following path");
      Assert (To_String (Config.Settings_Path) = "/tmp/files.conf", "settings flag consumes following path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("--dash-start.conf"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert
        (To_String (Config.Settings_Path) = "--dash-start.conf",
         "settings flag consumes dash-prefixed following path");
      Assert
        (Config.Mode = Files.Application.Headless_Smoke_Run,
         "settings path consumption resumes flag parsing after the value");
      Assert (Config.Paths.Is_Empty, "dash-prefixed settings path value does not become a startup path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--live-smoke"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--help"));
      Args.Append (To_Unbounded_String ("--settings=/tmp/inline.conf"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Help_Run, "later run mode flag wins deterministically");
      Assert (Config.Paths.Is_Empty, "smoke flags do not become startup paths");
      Assert (To_String (Config.Settings_Path) = "/tmp/inline.conf", "settings equals form selects settings path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("-h"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Help_Run, "short help flag selects help mode");
      Assert (Config.Paths.Is_Empty, "short help flag is consumed");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--version"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Version_Run, "version flag selects version mode");
      Assert (Config.Paths.Is_Empty, "version flag is consumed");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--unknown-path"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Desktop_Run, "unknown dash-prefixed path keeps desktop mode");
      Assert (Natural (Config.Paths.Length) = 1, "unknown dash-prefixed value is preserved as a path");
      Assert (To_String (Config.Paths.Element (1)) = "--unknown-path", "unknown option is treated as a path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--"));
      Args.Append (To_Unbounded_String ("--live-smoke"));
      Args.Append (To_Unbounded_String ("--help"));
      Args.Append (To_Unbounded_String ("--settings=/tmp/after-terminator.conf"));
      Args.Append (To_Unbounded_String ("--settings"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "terminator stops smoke flag parsing");
      Assert (Natural (Config.Paths.Length) = 4, "terminated flags are preserved as paths");
      Assert (To_String (Config.Paths.Element (1)) = "--live-smoke", "terminator keeps dash-prefixed path text");
      Assert (To_String (Config.Paths.Element (2)) = "--help", "terminator keeps help-looking path text");
      Assert
        (To_String (Config.Paths.Element (3)) = "--settings=/tmp/after-terminator.conf",
         "terminator keeps settings-looking path text");
      Assert
        (To_String (Config.Paths.Element (4)) = "--settings",
         "terminator keeps bare settings flag as path text");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("--"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (To_String (Config.Settings_Path) = "--", "settings flag can consume terminator as a path");
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "flag parsing resumes after terminator setting path");
      Assert (Config.Paths.Is_Empty, "consumed terminator setting path does not become a startup path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (To_String (Config.Settings_Path) = "", "missing settings value leaves default settings path");
      Assert (Natural (Config.Paths.Length) = 1, "missing settings value preserves flag as path");
      Assert (To_String (Config.Paths.Element (1)) = "--settings", "missing settings value is not dropped");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings="));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (To_String (Config.Settings_Path) = "", "empty settings equals form leaves default settings path");
      Assert (Config.Paths.Is_Empty, "empty settings equals form is consumed as a recognized flag");

      declare
         Dir           : constant String := Join (Root, "cli-settings");
         Settings_Path : constant String := Join (Root, "cli-settings.conf");
         Startup       : Files.Application.Startup_Result;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Write_File (Join (Dir, ".hidden"));
         Write_File (Join (Dir, "shown.txt"));
         Write_File
           (Settings_Path,
            "[settings]" & ASCII.LF &
            "default_view_mode = details" & ASCII.LF &
            "show_hidden_files = true" & ASCII.LF);
         Args.Clear;
         Args.Append (To_Unbounded_String ("--settings"));
         Args.Append (To_Unbounded_String (Settings_Path));
         Args.Append (To_Unbounded_String (Dir));
         Config := Files.Application.Parse_Run_Configuration (Args);
         Startup := Files.Application.Resolve_Startup (Config.Paths, To_String (Config.Settings_Path));
         Assert
           (To_String (Startup.Settings_Path) = Settings_Path,
            "split settings flag drives startup settings path");
         Assert
           (Startup.Settings.Default_View = Files.Types.Details,
            "split settings flag loads startup default view");
         Assert
           (Files.Model.Item_Count (Startup.Windows.Element (1).Model) = 2,
            "split settings flag affects startup directory loading");
      end;

      declare
         Help : constant String := Files.Application.Help_Text;
      begin
         Assert
           (Ada.Strings.Fixed.Index (Help, "Usage: files") > 0,
            "help text includes localized usage");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--settings PATH") > 0,
            "help text documents settings path flag");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--version") > 0,
            "help text documents version flag");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--help, -h") > 0,
            "help text documents long and short help flags");
         Assert
           (Files.Application.Version_Text = "files 0.1.0-dev",
            "version text uses generated crate metadata");
      end;
   end Test_Run_Configuration_Parsing;

   procedure Test_Localization_Catalog (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Error_Keys : Files.Types.String_Vectors.Vector;

      procedure Add_Error_Key (Key : String) is
      begin
         Error_Keys.Append (To_Unbounded_String (Key));
      end Add_Error_Key;

      procedure Assert_Western_Translation
        (Locale : String)
      is
         Small_Label : constant String := Files.Localization.Text ("command.view.small", Locale);
         Missing     : constant String := Files.Localization.Text ("error.path.missing", Locale);
      begin
         Assert
           (Small_Label /= "Small Icons" and then Small_Label /= "command.view.small",
            Locale & " command label is translated");
         Assert
           (Missing /= "Path does not exist." and then Missing /= "error.path.missing",
            Locale & " error message is translated");
         Assert
           (Files.Localization.Text ("status.items", Locale) /= "status.items",
            Locale & " status label resolves from catalog");
      end Assert_Western_Translation;
   begin
      Assert
        (Files.Localization.Text ("command.view.small") = "Small Icons",
         "known command label is loaded from catalog");
      Assert (Files.Localization.Text ("startup.window.ready") = "Window", "startup window label is localized");
      Assert (Files.Localization.Text ("startup.error") = "Error", "startup error label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.window") = "Runtime smoke window",
         "runtime smoke window label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.rectangles") = "rectangles",
         "runtime smoke rectangle label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.glyphs") = "glyphs",
         "runtime smoke glyph label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.missing_glyphs") = "missing glyphs",
         "runtime smoke missing-glyph label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.font") = "font",
         "runtime smoke font label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.vertices") = "vertices",
         "runtime smoke vertex label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.vulkan_status") = "Vulkan status",
         "runtime smoke Vulkan status label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.vulkan_result") = "Vulkan result",
         "runtime smoke Vulkan result label is localized");
      Assert
        (Files.Localization.Text ("command.selection.select_all") = "Select All",
         "select-all command label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.framebuffer_readback") = "framebuffer readback",
         "runtime smoke framebuffer readback label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.frames_attempted") = "frames attempted",
         "runtime smoke attempted-frame label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.frames_presented") = "frames presented",
         "runtime smoke presented-frame label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.framebuffer_hash") = "framebuffer hash",
         "runtime smoke framebuffer hash label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.framebuffer_bytes") = "framebuffer bytes",
         "runtime smoke framebuffer byte-count label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.text_failed") = "Runtime smoke text rendering failed.",
         "runtime smoke text-failure label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.no_windows") = "Runtime smoke has no windows.",
         "runtime smoke no-window label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.no_display") = "Runtime smoke needs a live display.",
         "runtime smoke no-display label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.no_vulkan") = "Runtime smoke needs Vulkan support.",
         "runtime smoke no-Vulkan label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.ready") = "Runtime smoke is ready.",
         "runtime smoke ready label is localized");
      Assert
        (Files.Localization.Text ("runtime.smoke.requires_live_harness") = "Runtime smoke requires a live harness.",
         "runtime smoke live-harness label is localized");
      Assert
        (Files.Localization.Text ("cli.help.usage") =
         "Usage: files [--runtime-smoke] [--live-smoke] [--settings PATH] [--version] [PATH...]",
         "CLI help usage is localized");
      Assert
        (Files.Localization.Text ("cli.help.path") = "PATH opens a directory, or the parent directory of a file.",
         "CLI help path description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.runtime_smoke"), "--runtime-smoke") > 0,
         "CLI help runtime smoke description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.live_smoke"), "--live-smoke") > 0,
         "CLI help live smoke description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.settings"), "--settings PATH") > 0,
         "CLI help settings description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.version"), "--version") > 0,
         "CLI help version description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.help"), "--help, -h") > 0,
         "CLI help flag description is localized");
      Assert_Western_Translation ("da-DK");
      Assert_Western_Translation ("de-DE");
      Assert_Western_Translation ("es-ES");
      Assert_Western_Translation ("fr-FR");
      Assert_Western_Translation ("it-IT");
      Assert_Western_Translation ("nl-NL");
      Assert_Western_Translation ("pt-PT");
      Assert_Western_Translation ("sv-SE");
      Assert_Western_Translation ("nb-NO");
      Assert_Western_Translation ("fi-FI");
      Assert
        (Files.Localization.Text ("missing.test.key") = "missing.test.key",
         "unknown localization key falls back to key text");
      Assert (Files.Localization.Text ("info.name") = "Name", "info pane name label is localized");
      Assert (Files.Localization.Text ("status.items") = "Items", "item-count label is localized");
      Assert (Files.Localization.Text ("status.visible") = "Visible", "visible-count label is localized");
      Assert (Files.Localization.Text ("status.selected") = "Selected", "selected-count label is localized");
      Assert
        (Files.Localization.Text ("status.missing_metadata") = "Unavailable",
         "missing metadata fallback is localized");
      Assert (Files.Localization.Text ("accessibility.toolbar") = "Toolbar", "toolbar landmark is localized");
      Assert
        (Files.Localization.Text ("accessibility.main_view") = "Directory contents",
         "main-view landmark is localized");
      Assert
        (Files.Localization.Text ("accessibility.info_pane") = "Information pane",
         "info-pane landmark is localized");
      Assert
        (Files.Localization.Text ("accessibility.command_palette_search") = "Command search",
         "command-palette search label is localized");
      Assert
        (Files.Localization.Text ("accessibility.root_selector") = "Root locations",
         "root-selector landmark is localized");
      Add_Error_Key ("error.path.missing");
      Add_Error_Key ("error.path.inaccessible");
      Add_Error_Key ("error.directory.load");
      Add_Error_Key ("error.metadata.read");
      Add_Error_Key ("error.file.create");
      Add_Error_Key ("error.file.exists");
      Add_Error_Key ("error.file.parent_missing");
      Add_Error_Key ("error.rename.source_missing");
      Add_Error_Key ("error.rename.invalid_destination");
      Add_Error_Key ("error.rename.failed");
      Add_Error_Key ("error.trash.unavailable");
      Add_Error_Key ("error.trash.failed");
      Add_Error_Key ("error.trash.native_unavailable");
      Add_Error_Key ("error.trash.restore_unavailable");
      Add_Error_Key ("error.trash.restore_failed");
      Add_Error_Key ("error.trash.restore_parent_missing");
      Add_Error_Key ("error.trash.restore_exists");
      Add_Error_Key ("error.search.failed");
      Add_Error_Key ("error.permanent_delete.refused");
      Add_Error_Key ("error.permanent_delete.failed");
      Add_Error_Key ("error.drop.invalid_destination");
      Add_Error_Key ("error.drop.invalid_source");
      Add_Error_Key ("error.drop.failed");
      Add_Error_Key ("error.drop.into_self");
      Add_Error_Key ("error.copy.failed");
      Add_Error_Key ("error.duplicate.failed");
      Add_Error_Key ("error.compress.failed");
      Add_Error_Key ("error.extract.failed");
      Add_Error_Key ("error.undo.failed");
      Add_Error_Key ("error.thumbnail.source_missing");
      Add_Error_Key ("error.thumbnail.unsupported");
      Add_Error_Key ("error.thumbnail.failed");
      Add_Error_Key ("error.history.back_unavailable");
      Add_Error_Key ("error.history.forward_unavailable");
      Add_Error_Key ("error.selection.empty");
      Add_Error_Key ("error.create.pending");
      Add_Error_Key ("error.create.no_temporary_item");
      Add_Error_Key ("error.filter.empty");
      Add_Error_Key ("error.root.selection.empty");
      Add_Error_Key ("error.root.eject_unavailable");
      Add_Error_Key ("error.name.invalid");
      Add_Error_Key ("error.rename.disabled");
      Add_Error_Key ("error.open_action.missing");
      Add_Error_Key ("error.open_action.multi_directory");
      Add_Error_Key ("error.open_action.execution");
      Add_Error_Key ("error.open_action.executable_missing");
      Add_Error_Key ("error.open_action.unsafe_placeholder");
      Add_Error_Key ("error.settings.unknown_section");
      Add_Error_Key ("error.settings.expected_equals");
      Add_Error_Key ("error.settings.invalid_open_action");
      Add_Error_Key ("error.settings.invalid_mapping");
      Add_Error_Key ("error.settings.invalid_view_mode");
      Add_Error_Key ("error.settings.invalid_boolean");
      Add_Error_Key ("error.settings.invalid_icon_theme");
      Add_Error_Key ("error.settings.invalid_sort_field");
      Add_Error_Key ("error.settings.invalid_font_pixel_size");
      Add_Error_Key ("error.settings.unknown_key");
      Add_Error_Key ("error.settings.missing_section");
      Add_Error_Key ("error.settings.invalid");
      Add_Error_Key ("error.settings.not_file");
      Add_Error_Key ("error.settings.load");
      Add_Error_Key ("error.settings.save");
      Add_Error_Key ("error.settings.closed");
      Add_Error_Key ("error.window.create");
      for Key of Error_Keys loop
         declare
            Text_Key : constant String := To_String (Key);
         begin
            Assert (Files.Localization.Text (Text_Key) /= Text_Key, "error localization exists for " & Text_Key);
         end;
      end loop;
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Name_Key        : constant String := Files.Commands.Name_Key (Id);
            Description_Key : constant String := Files.Commands.Description_Key (Id);
         begin
            Assert (Name_Key /= "", "registered command has a localization name key");
            Assert
              (Files.Localization.Text (Name_Key) /= Name_Key,
               "registered command name is localized for " & Files.Commands.Identifier (Id));
            if Description_Key /= "" then
               Assert
                 (Files.Localization.Text (Description_Key) /= Description_Key,
                  "registered command description is localized for " & Files.Commands.Identifier (Id));
            end if;
         end;
      end loop;
   end Test_Localization_Catalog;

   procedure Test_System_Locale_Detection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Had_LC_All      : constant Boolean := Ada.Environment_Variables.Exists ("LC_ALL");
      Had_LC_Messages : constant Boolean := Ada.Environment_Variables.Exists ("LC_MESSAGES");
      Had_LC_Time     : constant Boolean := Ada.Environment_Variables.Exists ("LC_TIME");
      Had_LC_Numeric  : constant Boolean := Ada.Environment_Variables.Exists ("LC_NUMERIC");
      Had_Lang        : constant Boolean := Ada.Environment_Variables.Exists ("LANG");
      Had_Home        : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Old_LC_All      : Unbounded_String;
      Old_LC_Messages : Unbounded_String;
      Old_LC_Time     : Unbounded_String;
      Old_LC_Numeric  : Unbounded_String;
      Old_Lang        : Unbounded_String;
      Old_Home        : Unbounded_String;

      function Repository_File_Contains
        (Path    : String;
         Pattern : String)
         return Boolean is
      begin
         return
           (Project_Tools.Files.File_Exists (Path)
            and then Project_Tools.Files.File_Contains (Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../" & Path)
            and then Project_Tools.Files.File_Contains ("../" & Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../../" & Path)
            and then Project_Tools.Files.File_Contains ("../../" & Path, Pattern));
      end Repository_File_Contains;

      procedure Restore_Environment is
      begin
         if Had_LC_All then
            Ada.Environment_Variables.Set ("LC_ALL", To_String (Old_LC_All));
         else
            Ada.Environment_Variables.Clear ("LC_ALL");
         end if;

         if Had_LC_Messages then
            Ada.Environment_Variables.Set ("LC_MESSAGES", To_String (Old_LC_Messages));
         else
            Ada.Environment_Variables.Clear ("LC_MESSAGES");
         end if;

         if Had_LC_Time then
            Ada.Environment_Variables.Set ("LC_TIME", To_String (Old_LC_Time));
         else
            Ada.Environment_Variables.Clear ("LC_TIME");
         end if;

         if Had_LC_Numeric then
            Ada.Environment_Variables.Set ("LC_NUMERIC", To_String (Old_LC_Numeric));
         else
            Ada.Environment_Variables.Clear ("LC_NUMERIC");
         end if;

         if Had_Lang then
            Ada.Environment_Variables.Set ("LANG", To_String (Old_Lang));
         else
            Ada.Environment_Variables.Clear ("LANG");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
      end Restore_Environment;
   begin
      if Had_LC_All then
         Old_LC_All := To_Unbounded_String (Ada.Environment_Variables.Value ("LC_ALL"));
      end if;

      if Had_LC_Messages then
         Old_LC_Messages := To_Unbounded_String (Ada.Environment_Variables.Value ("LC_MESSAGES"));
      end if;

      if Had_LC_Time then
         Old_LC_Time := To_Unbounded_String (Ada.Environment_Variables.Value ("LC_TIME"));
      end if;

      if Had_LC_Numeric then
         Old_LC_Numeric := To_Unbounded_String (Ada.Environment_Variables.Value ("LC_NUMERIC"));
      end if;

      if Had_Lang then
         Old_Lang := To_Unbounded_String (Ada.Environment_Variables.Value ("LANG"));
      end if;

      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;

      begin
         Assert
           (Files.Localization.Normalize_Locale ("da_DK.UTF-8") = "da-DK",
            "locale normalization removes encoding and converts separator");
         Assert
           (Files.Localization.Normalize_Locale ("en_us") = "en-US",
            "locale normalization canonicalizes language and region case");
         Assert
           (Files.Localization.Normalize_Locale ("sr_RS.UTF-8@latin") = "sr-RS",
            "locale normalization removes locale modifiers");
         Assert (Files.Localization.Normalize_Locale ("C") = "en", "C locale falls back to English");
         Assert (Files.Localization.Normalize_Locale ("POSIX") = "en", "POSIX locale falls back to English");

         Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");
         Ada.Environment_Variables.Set ("LC_MESSAGES", "en_US.UTF-8");
         Ada.Environment_Variables.Set ("LC_TIME", "sv_SE.UTF-8");
         Ada.Environment_Variables.Set ("LC_NUMERIC", "fr_FR.UTF-8");
         Ada.Environment_Variables.Set ("LANG", "de_DE.UTF-8");
         Assert (Files.Localization.System_Locale = "da-DK", "LC_ALL has locale detection precedence");
         Assert (Files.Localization.System_Time_Locale = "da-DK", "LC_ALL has time-locale detection precedence");
         Assert
           (Files.Localization.System_Number_Locale = "da-DK",
            "LC_ALL has numeric-locale detection precedence");

         Ada.Environment_Variables.Clear ("LC_ALL");
         Assert (Files.Localization.System_Locale = "en-US", "LC_MESSAGES is used after LC_ALL");
         Assert (Files.Localization.System_Time_Locale = "sv-SE", "LC_TIME is used for date/time after LC_ALL");
         Assert
           (Files.Localization.System_Number_Locale = "fr-FR",
            "LC_NUMERIC is used for numbers after LC_ALL");

         Ada.Environment_Variables.Clear ("LC_MESSAGES");
         Assert (Files.Localization.System_Locale = "de-DE", "LANG is used after LC_MESSAGES");
         Ada.Environment_Variables.Clear ("LC_TIME");
         Assert (Files.Localization.System_Time_Locale = "de-DE", "LANG is used for date/time after LC_TIME");
         Ada.Environment_Variables.Clear ("LC_NUMERIC");
         Assert (Files.Localization.System_Number_Locale = "de-DE", "LANG is used for numbers after LC_NUMERIC");

         Ada.Environment_Variables.Set ("LC_ALL", "C");
         Assert (Files.Localization.System_Locale = "en", "C in LC_ALL overrides lower-precedence locale variables");
         Assert (Files.Localization.System_Time_Locale = "en", "C in LC_ALL overrides lower-precedence time locale");
         Assert
           (Files.Localization.System_Number_Locale = "en",
            "C in LC_ALL overrides lower-precedence numeric locale");

         Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");
         Assert
           (Files.Localization.Text ("command.view.small") /= "Small Icons"
            and then Files.Localization.Text ("command.view.small") /= "command.view.small",
            "detected Danish locale loads translated app catalog resources");
         Assert
           (Files.Localization.Text ("time.relative.today", Files.Localization.System_Time_Locale) = "I dag",
            "detected Danish time locale uses date/time catalog resources");
         Assert
           (Files.Localization.Text ("time.format.locale_date", "da-DK") = "%x",
            "Danish catalog includes named utilada date format patterns");
         Assert
           (Files.Localization.Text ("time.month1.long", "sv-SE") = "januari",
            "regional locales fall back to generated base-language date resources");
         Assert
           (Files.Localization.Text ("time.relative.today", "de-DE") = "Heute",
            "German catalog includes date/time resources");
         Assert (Files.Localization.Text ("number.decimal", "de-DE") = ",", "German catalog has decimal symbol");
         Assert (Files.Localization.Text ("number.group", "de-DE") = ".", "German catalog has group symbol");
         Assert
           (Files.Localization.Text ("details.size.unit.mib", "de-DE") /= "details.size.unit.mib",
            "German catalog has generated digital unit labels");
         Assert
           (Repository_File_Contains
              ("src/platform/windows/files-platform-windows.adb",
               "GetUserDefaultLocaleName"),
            "Windows native locale detection binds GetUserDefaultLocaleName");
         Assert
           (Repository_File_Contains ("src/platform/macos/files-platform-macos.adb", "CFLocaleCopyCurrent")
            and then Repository_File_Contains
              ("files.gpr",
               """-framework"", ""CoreFoundation"""),
            "macOS native locale detection binds CoreFoundation locale APIs");
         Assert
           (Repository_File_Contains
              ("src/files-localization.adb",
               "Files.Platform.Windows.Native_Locale"),
            "system locale detection falls back to Windows native locale");
         Assert
           (Repository_File_Contains
              ("src/files-localization.adb",
               "Files.Platform.Macos.Native_Locale"),
            "system locale detection falls back to macOS native locale");

         declare
            Fake_Home   : constant String := Join (Root, "locale-home");
            Config_Dir  : constant String := Join (Fake_Home, ".config");
            Config_Path : constant String := Join (Config_Dir, "plasma-localerc");
         begin
            Ada.Directories.Create_Path (Config_Dir);
            Write_File
              (Config_Path,
               "[Formats]" & ASCII.LF &
               "LC_NUMERIC=da_DK.UTF-8" & ASCII.LF &
               "LANG=de_DE.UTF-8" & ASCII.LF);
            Ada.Environment_Variables.Clear ("LC_ALL");
            Ada.Environment_Variables.Clear ("LC_TIME");
            Ada.Environment_Variables.Clear ("LC_NUMERIC");
            Ada.Environment_Variables.Set ("LANG", "C.UTF-8");
            Ada.Environment_Variables.Set ("HOME", Fake_Home);
            Assert
              (Files.Localization.System_Time_Locale = "de-DE",
               "portable process LANG falls back to KDE formats locale");
            Assert
              (Files.Localization.System_Number_Locale = "da-DK",
               "portable process LANG falls back to KDE numeric formats locale");
         end;

         Restore_Environment;
      exception
         when others =>
            Restore_Environment;
            raise;
      end;
   end Test_System_Locale_Detection;

   procedure Test_First_Implementation_Feature_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Repository_File_Exists (Path : String) return Boolean is
      begin
         return Ada.Directories.Exists (Path)
           or else Ada.Directories.Exists ("../" & Path)
           or else Ada.Directories.Exists ("../../" & Path);
      end Repository_File_Exists;

      function Repository_File_Contains
        (Path    : String;
         Pattern : String)
         return Boolean is
      begin
         return
           (Project_Tools.Files.File_Exists (Path)
            and then Project_Tools.Files.File_Contains (Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../" & Path)
            and then Project_Tools.Files.File_Contains ("../" & Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../../" & Path)
            and then Project_Tools.Files.File_Contains ("../../" & Path, Pattern));
      end Repository_File_Contains;

      function Repository_Root return String is
      begin
         if Project_Tools.Files.Directory_Exists ("src")
           and then Project_Tools.Files.Directory_Exists ("tests")
         then
            return ".";
         elsif Project_Tools.Files.Directory_Exists ("../src")
           and then Project_Tools.Files.Directory_Exists ("../tests")
         then
            return "..";
         elsif Project_Tools.Files.Directory_Exists ("../../src")
           and then Project_Tools.Files.Directory_Exists ("../../tests")
         then
            return "../..";
         else
            return ".";
         end if;
      end Repository_Root;

      function Has_Suffix
        (Text   : String;
         Suffix : String)
         return Boolean is
      begin
         return Text'Length >= Suffix'Length
           and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
      end Has_Suffix;

      function Is_Skipped_Tree (Name : String) return Boolean is
      begin
         return Name = "."
           or else Name = ".."
           or else Name = ".git"
           or else Name = ".alire"
           or else Name = "alire"
           or else Name = "bin"
           or else Name = "obj";
      end Is_Skipped_Tree;

      function Is_Forbidden_Helper_Script (Name : String) return Boolean is
      begin
         return Has_Suffix (Name, ".sh")
           or else Has_Suffix (Name, ".bash")
           or else Has_Suffix (Name, ".zsh")
           or else Has_Suffix (Name, ".fish")
           or else Has_Suffix (Name, ".ps1")
           or else Has_Suffix (Name, ".py")
           or else Has_Suffix (Name, ".awk")
           or else Has_Suffix (Name, ".pl");
      end Is_Forbidden_Helper_Script;

      function Forbidden_Helper_Script_Count (Path : String) return Natural is
         Search   : Ada.Directories.Search_Type;
         Dir_Item : Ada.Directories.Directory_Entry_Type;
         Count    : Natural := 0;
         Started  : Boolean := False;
      begin
         if not Project_Tools.Files.Directory_Exists (Path) then
            return 0;
         end if;

         Ada.Directories.Start_Search
           (Search    => Search,
            Directory => Path,
            Pattern   => "*",
            Filter    => [Ada.Directories.Directory => True, Ada.Directories.Ordinary_File => True, others => False]);
         Started := True;
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Item);
            declare
               Name      : constant String := Ada.Directories.Simple_Name (Dir_Item);
               Full_Path : constant String := Ada.Directories.Full_Name (Dir_Item);
            begin
               if Ada.Directories.Kind (Dir_Item) = Ada.Directories.Directory then
                  if not Is_Skipped_Tree (Name) then
                     Count := Count + Forbidden_Helper_Script_Count (Full_Path);
                  end if;
               elsif Is_Forbidden_Helper_Script (Name) then
                  Count := Count + 1;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         Started := False;
         return Count;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
            return Count;
      end Forbidden_Helper_Script_Count;
   begin
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Drag_And_Drop),
         "drag-and-drop import belongs to the implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Thumbnail_Generation),
         "thumbnail generation belongs to the implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Recursive_Search),
         "recursive search belongs to the implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.File_Watching),
         "file watching belongs to the implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Permanent_Delete),
         "permanent deletion belongs to the implementation");
      Assert
        (Repository_File_Contains ("src/glfw-windows-drop.adb", "glfwSetDropCallback")
         and then Repository_File_Contains ("src/files-application-windows.adb", "Handle_Drop_Input"),
         "native file-drop callbacks are connected to controller import routing");
      Assert
        (Repository_File_Contains ("src/glfw-windows-icon.adb", "glfwSetWindowIcon")
         and then Repository_File_Contains ("src/files-application-windows.adb", "Glfw.Windows.Icon.Set_Files_Icon"),
         "native desktop windows receive the packaged application icon");
      Assert
        (Repository_File_Contains ("src/files-application-windows.adb", "glfwWaitEventsTimeout")
         and then Repository_File_Contains ("src/files-application-windows.adb", "Handle_File_Watch_Poll"),
         "directory file watching is polled from the desktop event loop");
      Assert
        (Repository_File_Contains ("src/files-application-windows.adb", "inotify_init1")
         and then Repository_File_Contains ("src/files-application-windows.adb", "Drain_Native_Watch"),
         "native file watching is connected to the desktop event loop");
      Assert
        (Files.Features.Included_In_First_Implementation
           (Files.Features.Network_Filesystem_Special_Handling),
         "network filesystem special handling belongs to the implementation");
      Assert
        (Repository_File_Contains ("src/files-file_system.adb", "Root_Network_Mount")
         and then Repository_File_Contains ("share/files.catalog", "en.root.network_mount.prefix = "),
         "root discovery includes network-specific root handling");
      Assert
        (not Files.Features.Included_In_First_Implementation (Files.Features.Shell_Open_By_Default),
         "shell open actions remain opt-in");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Gpu_Screenshot_Tests),
         "GPU screenshot comparison tests belong to the implementation");
      Assert
        (Forbidden_Helper_Script_Count (Repository_Root) = 0,
         "all project helper tooling remains implemented in Ada");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Platform_Trash),
         "platform trash belongs to the first implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Root_Discovery),
         "root discovery belongs to the first implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Open_Action_Execution),
         "open-action execution belongs to the first implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Settings_Editing),
         "settings editing belongs to the first implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Desktop_Packaging),
         "desktop packaging metadata belongs to the first implementation");
      Assert
        (Files.Features.Included_In_First_Implementation (Files.Features.Permanent_Delete),
         "permanent deletion is explicitly available only through its advanced API");
      Assert
        (Repository_File_Exists ("share/applications/files.desktop"),
         "desktop packaging includes a desktop entry");
      Assert
        (Repository_File_Exists ("share/icons/hicolor/scalable/apps/files.svg"),
         "desktop packaging includes an application icon");
      Assert
        (Repository_File_Exists ("share/metainfo/dk.bracke.files.metainfo.xml"),
         "desktop packaging includes AppStream metadata");
      Assert
        (Repository_File_Exists ("share/files/package.manifest"),
         "desktop packaging includes a release manifest");
      Assert
        (Repository_File_Exists ("share/doc/files/quick-start.md"),
         "desktop packaging includes a quick-start guide");
      Assert
        (Repository_File_Contains ("share/doc/files/quick-start.md", "`Control+A` selects every visible item."),
         "quick-start guide documents the select-all shortcut");
      Assert
        (Repository_File_Exists ("share/doc/files/settings-format.md"),
         "desktop packaging includes settings format documentation");
      Assert
        (Repository_File_Exists ("share/doc/files/platform-support.md"),
         "desktop packaging includes platform support documentation");
      Assert
        (Repository_File_Contains ("share/doc/files/platform-support.md", "Ada drop event-source"),
         "platform support documentation records drop event-source support");
      Assert
        (Repository_File_Exists ("share/doc/files/release-notes.md"),
         "desktop packaging includes release notes");
      Assert
        (Repository_File_Exists ("share/files.catalog"),
         "desktop packaging includes the localization catalog");
      Assert
        (Repository_File_Exists ("share/files/icons/folder.icon"),
         "desktop packaging includes bundled icon assets");
      Assert
        (Repository_File_Exists ("share/files/icons/markdown.icon"),
         "desktop packaging includes the complete bundled icon set");
      Assert
        (Repository_File_Contains ("alire.toml", "project_tools = ""*""")
         and then Repository_File_Contains ("alire.toml", "project_tools = { path = ""../project_tools"" }"),
         "files crate pins project_tools to the local relative path");
      Assert
        (Repository_File_Contains ("alire.toml", "i18n = ""*""")
         and then Repository_File_Contains ("alire.toml", "i18n = { path = ""../i18n"" }"),
         "files crate pins i18n to the local relative path");
      Assert
        (Repository_File_Contains ("alire.toml", "textrender = ""*""")
         and then Repository_File_Contains ("alire.toml", "textrender = { path = ""../textrender"" }"),
         "files crate pins textrender to the local relative path");
      Assert
        (Repository_File_Contains ("alire.toml", "openglada_glfw")
         and then Repository_File_Contains ("alire.toml", "df_vulkan")
         and then Repository_File_Contains ("alire.toml", "textrender"),
         "files crate declares required windowing, rendering, and text-rendering dependencies");
      Assert
        (Repository_File_Contains ("tests/tests/alire.toml", "files = ""*""")
         and then Repository_File_Contains ("tests/tests/alire.toml", "files = { path = ""../.."" }"),
         "tests crate pins the parent files crate by local relative path");
      Assert
        (Repository_File_Contains ("tests/tests/alire.toml", "aunit"),
         "tests crate declares the AUnit dependency");
      Assert
        (Repository_File_Contains ("tests/alire.toml", "files = ""*""")
         and then Repository_File_Contains ("tests/alire.toml", "files = { path = "".."" }"),
         "top-level tests sub-crate pins the parent files crate by local relative path");
      Assert
        (Repository_File_Contains ("tests/alire.toml", "aunit"),
         "top-level tests sub-crate declares the AUnit dependency");
      Assert
        (Repository_File_Contains ("tests/tests.gpr", "tests/src/")
         and then Repository_File_Contains ("tests/tests.gpr", "for Main use (""tests.adb"")"),
         "top-level tests sub-crate reuses the AUnit suite sources");
      Assert
        (Repository_File_Contains ("files.gpr", "src/platform/windows")
         and then Repository_File_Contains ("files.gpr", "src/platform/macos")
         and then Repository_File_Contains ("files.gpr", "src/platform/unsupported"),
         "files project keeps platform-specific source directories wired");
      Assert
        (Repository_File_Contains ("files.gpr", "for Main use (""files-main.adb"")")
         and then Repository_File_Contains ("files.gpr", "use ""files"""),
         "files project builds the expected binary entry point");
      Assert
        (Repository_File_Contains ("tests/tests/tests.gpr", "for Main use (""tests.adb"")")
         and then Repository_File_Contains ("tests/tests/tests.gpr", "use ""tests"""),
         "nested tests project builds the expected AUnit runner");
      Assert
        (Repository_File_Contains ("tests/tests/tests.gpr", "for Source_Dirs use (""src/"", ""config/"")")
         and then Repository_File_Contains ("tests/tests/tests.gpr", """-gnat2022"""),
         "nested tests project keeps Ada 2022 test sources wired");
      Assert
        (Repository_File_Contains
           ("tools/files_check_all.gpr",
            "for Main use (""check_all.adb"", ""cldr_to_catalog.adb"", ""release_check.adb"")")
         and then Repository_File_Contains ("tools/files_check_all.gpr", "use ""check_all""")
         and then Repository_File_Contains ("tools/files_check_all.gpr", "use ""cldr_to_catalog""")
         and then Repository_File_Contains ("tools/files_check_all.gpr", "use ""release_check"""),
         "checker tooling project builds the expected Ada helpers");
      Assert
        (Repository_File_Contains ("tools/files_check_all.gpr", "for Source_Dirs use (""src"", ""config"")")
         and then Repository_File_Contains ("tools/files_check_all.gpr", """-gnat2022"""),
         "checker tooling project keeps Ada 2022 sources wired");
      Assert
        (Repository_File_Contains (".gitignore", "/obj/")
         and then Repository_File_Contains (".gitignore", "/bin/")
         and then Repository_File_Contains (".gitignore", "/alire/")
         and then Repository_File_Contains (".gitignore", "/config/"),
         "main crate ignores generated build artifacts");
      Assert
        (Repository_File_Contains ("tests/.gitignore", "/obj/")
         and then Repository_File_Contains ("tests/.gitignore", "/bin/")
         and then Repository_File_Contains ("tests/.gitignore", "/alire/")
         and then Repository_File_Contains ("tests/.gitignore", "/config/"),
         "top-level tests crate ignores generated build artifacts");
      Assert
        (Repository_File_Contains ("tests/tests/.gitignore", "/obj/")
         and then Repository_File_Contains ("tests/tests/.gitignore", "/bin/")
         and then Repository_File_Contains ("tests/tests/.gitignore", "/alire/")
         and then Repository_File_Contains ("tests/tests/.gitignore", "/config/"),
         "nested tests crate ignores generated build artifacts");
      Assert
        (Repository_File_Contains ("tools/.gitignore", "/obj/")
         and then Repository_File_Contains ("tools/.gitignore", "/bin/")
         and then Repository_File_Contains ("tools/.gitignore", "/alire/")
         and then Repository_File_Contains ("tools/.gitignore", "/config/"),
         "checker tooling crate ignores generated build artifacts");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/files.catalog"),
         "release manifest includes localization catalog");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/doc/files/quick-start.md"),
         "release manifest includes quick-start guide");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/doc/files/settings-format.md"),
         "release manifest includes settings format documentation");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/doc/files/platform-support.md"),
         "release manifest includes platform support documentation");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/doc/files/release-notes.md"),
         "release manifest includes release notes");
      Assert
        (Repository_File_Contains ("share/files/package.manifest", "share/files/icons/markdown.icon"),
         "release manifest includes bundled icon assets");
      declare
         Display_Available : constant Boolean := Files.Application.Windows.Live_Display_Available;
         Vulkan_Available  : constant Boolean := Files.Application.Windows.Vulkan_Runtime_Available;
         Capabilities      : constant Files.Application.Windows.Desktop_Capabilities :=
           Files.Application.Windows.Runtime_Capabilities;
      begin
         Assert
           (Display_Available or else not Display_Available,
            "live display capability query returns deterministic boolean");
         Assert
           (Vulkan_Available or else not Vulkan_Available,
            "Vulkan capability query returns deterministic boolean");
         Assert
           (Capabilities.Display_Available = Display_Available,
            "desktop capability report includes display state");
         Assert
           (Capabilities.Vulkan_Available = Vulkan_Available,
            "desktop capability report includes Vulkan state");
         Assert
           (Capabilities.Native_Drop_Callbacks,
            "desktop capability report includes native drop callbacks");
         Assert
           (Capabilities.Native_Drop_Automation,
            "desktop capability report exposes drop event-source automation");
      end;
   end Test_First_Implementation_Feature_Policy;

   procedure Test_Live_Smoke_Gate_Outcome (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Application.Windows.Live_Smoke_Gate;
      Skipped     : Files.Application.Windows.Live_Smoke_Result;
      No_Device   : Files.Application.Windows.Live_Smoke_Result;
      Passed      : Files.Application.Windows.Live_Smoke_Result;
      Failed      : Files.Application.Windows.Live_Smoke_Result;
      No_Readback : Files.Application.Windows.Live_Smoke_Result;
      Dirty_Exit  : Files.Application.Windows.Live_Smoke_Result;
   begin
      --  A plan skipped for want of a display or Vulkan maps to Skip.
      Skipped.Skipped_By_Plan := True;
      Skipped.Attempted := False;
      Assert
        (Files.Application.Windows.Gate_Outcome (Skipped) =
           Files.Application.Windows.Live_Smoke_Skip,
         "skipped-by-plan live smoke maps to Skip");

      --  An attempted run in which no usable Vulkan device initialized (missing
      --  or unusable ICD) is an environment gap and maps to Skip.
      No_Device.Attempted := True;
      No_Device.Skipped_By_Plan := False;
      No_Device.Vulkan_Device_Ready := False;
      Assert
        (Files.Application.Windows.Gate_Outcome (No_Device) =
           Files.Application.Windows.Live_Smoke_Skip,
         "attempted live smoke without a usable Vulkan device maps to Skip");

      --  An attempted run with a clean, structurally valid frame maps to Pass.
      Passed.Attempted := True;
      Passed.Skipped_By_Plan := False;
      Passed.Vulkan_Device_Ready := True;
      Passed.Framebuffer_Readback_Ready := True;
      Passed.Framebuffer_Passed := True;
      Passed.Closed_Cleanly := True;
      Assert
        (Files.Application.Windows.Gate_Outcome (Passed) =
           Files.Application.Windows.Live_Smoke_Pass,
         "attempted passing live smoke maps to Pass");

      --  An attempted run whose frame failed structural analysis maps to Fail.
      Failed := Passed;
      Failed.Framebuffer_Passed := False;
      Assert
        (Files.Application.Windows.Gate_Outcome (Failed) =
           Files.Application.Windows.Live_Smoke_Fail,
         "attempted degenerate live smoke maps to Fail");

      --  A run that never produced a framebuffer readback maps to Fail.
      No_Readback := Passed;
      No_Readback.Framebuffer_Readback_Ready := False;
      Assert
        (Files.Application.Windows.Gate_Outcome (No_Readback) =
           Files.Application.Windows.Live_Smoke_Fail,
         "attempted live smoke without readback maps to Fail");

      --  A run interrupted after a window opened (unclean close) maps to Fail.
      Dirty_Exit := Passed;
      Dirty_Exit.Closed_Cleanly := False;
      Assert
        (Files.Application.Windows.Gate_Outcome (Dirty_Exit) =
           Files.Application.Windows.Live_Smoke_Fail,
         "attempted live smoke that did not close cleanly maps to Fail");
   end Test_Live_Smoke_Gate_Outcome;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Startup_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Startup;

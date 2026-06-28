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

package body Files_Suite.Settings is

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

   type Settings_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Settings_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Settings_Test_Case);

   procedure Test_Settings_Parsing_And_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Load_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Invalid_Boolean (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Settings_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files settings");
   end Name;

   overriding procedure Register_Tests (T : in out Settings_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Parsing_And_Open_Actions'Access, "settings parsing and open actions");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Load_File'Access, "settings load file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Invalid_Boolean'Access, "settings invalid boolean");
   end Register_Tests;

   procedure Test_Settings_Parsing_And_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Text      : constant String :=
        ASCII.HT & "[ Settings ]" & ASCII.CR & ASCII.LF &
        ASCII.HT & "Default_View_Mode" & ASCII.HT & "=" & ASCII.HT & "DETAILS" & ASCII.CR & ASCII.LF &
        "Show_Hidden_Files = TRUE" & ASCII.CR & ASCII.LF &
        "Sort_Field = size" & ASCII.CR & ASCII.LF &
        "Sort_Ascending = FALSE" & ASCII.CR & ASCII.LF &
        "High_Contrast_Theme = TRUE" & ASCII.CR & ASCII.LF &
        "Icon_Theme = files-high-contrast" & ASCII.CR & ASCII.LF &
        "use_system_default_opener = false" & ASCII.CR & ASCII.LF &
        "# comment lines are ignored" & ASCII.LF &
        "[filetypes]" & ASCII.LF &
        "ada = text/x-ada" & ASCII.LF &
        "log = ""text/x-log""" & ASCII.LF &
        "quote = ""text/""""quoted""" & ASCII.LF &
        "eq = ""text/with=equals""" & ASCII.LF &
        "[icons]" & ASCII.LF &
        "text/x-ada = text" & ASCII.LF &
        "text/x-log = ""log-icon""" & ASCII.LF &
        "text/x-quote = ""quote""""icon""" & ASCII.LF &
        "text/x-equals = ""icon=equals""" & ASCII.LF &
        "[open-actions]" & ASCII.LF &
        "text/x-ada = editor {path}" & ASCII.LF &
        "text/x-ada+control = editor --readonly {path}" & ASCII.LF &
        "text/full = inspect {parent} {name} {stem} {extension}" & ASCII.LF &
        "text/equals = runner --flag=value ""arg=two words""" & ASCII.LF &
        "text/quoted = ""quoted editor"" ""--project file"" ""{path}""" & ASCII.LF &
        "text/quote-char = ""quote""""runner"" ""arg """" inner""" & ASCII.LF &
        "text/empty-arg = runner """" after-empty" & ASCII.LF &
        "text/shell = shell:""shell runner"" ""{name}""" & ASCII.LF &
        "text/shell-upper = SHELL:upper-runner ""{path}""" & ASCII.LF &
        "text/unknown-placeholder = inspect ""{unknown}""" & ASCII.LF &
        "text/mixed+alt+control = mixed {path}" & ASCII.LF &
        "text/spaced + CONTROL + alt = spaced {path}" & ASCII.LF &
        "text/duplicate+CONTROL+alt+control = duplicate {path}" & ASCII.LF &
        "application/ld+json = json-viewer {path}" & ASCII.LF &
        "application/ld+json+control = json-editor {path}" & ASCII.LF;
      Parsed    : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
      Manual    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Args      : Files.Types.String_Vectors.Vector;
      C1_Break  : constant Character := Character'Val (133);
      Line_Separator : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
   begin
      --  Exercise the genuine missing-action lookups deterministically; the
      --  host opener fallback would otherwise resolve unmapped lookups.
      Manual.Use_System_Default_Opener := False;
      Assert (Parsed.Success, "settings text parses");
      Assert (Parsed.Settings.Default_View = Files.Types.Details, "default view mode parses");
      Assert (Parsed.Settings.Show_Hidden_Files, "setting keys parse case-insensitively");
      Assert (Parsed.Settings.Sort_Field_Value = Files.Settings.Sort_By_Size, "sort field setting parses");
      Assert (not Parsed.Settings.Sort_Ascending, "sort direction setting parses");
      Assert (Parsed.Settings.High_Contrast_Theme, "high-contrast theme setting parses");
      Assert
        (To_String (Parsed.Settings.Icon_Theme_Name) = "files-high-contrast",
         "icon theme setting parses");
      declare
         Duplicate_Settings : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF &
              "default_view_mode = small" & ASCII.LF &
              "default_view_mode = details" & ASCII.LF &
              "show_hidden_files = false" & ASCII.LF &
              "show_hidden_files = true" & ASCII.LF &
              "sort_field = name" & ASCII.LF &
              "sort_field = modified" & ASCII.LF);
      begin
         Assert (Duplicate_Settings.Success, "duplicate scalar settings parse deterministically");
         Assert
           (Duplicate_Settings.Settings.Default_View = Files.Types.Details,
            "duplicate default view setting uses the last value");
         Assert
           (Duplicate_Settings.Settings.Show_Hidden_Files,
            "duplicate hidden-file setting uses the last value");
         Assert
           (Duplicate_Settings.Settings.Sort_Field_Value = Files.Settings.Sort_By_Modified,
            "duplicate sort field setting uses the last value");
      end;
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, ".ada") = "text/x-ada",
         "extension mapping parses");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, " ADA ") = "text/x-ada",
         "extension lookup normalizes whitespace and case");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "log") = "text/x-log",
         "quoted filetype mapping value parses");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "quote") = "text/""quoted",
         "quote-containing filetype mapping value parses");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "eq") = "text/with=equals",
         "equals-containing filetype mapping value parses");
      Assert (Files.Settings.Normalize_Extension (".") = "", "single-dot extension normalizes to empty");
      Assert
        (Files.Settings.Normalize_Extension (". TXT ") = "txt",
         "extension normalization trims after a leading dot");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, ".") = "",
         "empty normalized extension has no filetype mapping");
      Assert
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "unknown") = "",
         "unknown extension has no filetype mapping");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "pdf") = "application/pdf",
         "default settings map PDF files");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "adb") = "text/x-ada",
         "default settings map Ada body files");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "json") = "application/json",
         "default settings map JSON files");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "xml") = "application/xml",
         "default settings map XML files");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "zip") = "application/zip",
         "default settings map ZIP archives");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "tar.gz") = "application/gzip-tar",
         "default settings map compressed tar archives");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "docx") =
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "default settings map Word documents");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "xlsx") =
         "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         "default settings map spreadsheet documents");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "mp3") = "audio/mpeg",
         "default settings map MP3 audio");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "mp4") = "video/mp4",
         "default settings map MP4 video");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "inode/directory") = "folder",
         "default settings map directory icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "inode/symlink") = "link",
         "default settings map symlink icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-executable") = "executable",
         "default settings map executable icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/plain") = "text",
         "default settings map text icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/x-ada") = "ada",
         "default settings map Ada icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "image/png") = "image",
         "default settings map PNG icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-tar") = "unknown",
         "default settings map tar icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "audio/mpeg") = "unknown",
         "default settings map audio icons");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-ada") = "text",
         "icon mapping parses");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, " text/x-ada ") = "text",
         "icon lookup normalizes whitespace");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-log") = "log-icon",
         "quoted icon mapping value parses");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-quote") = "quote""icon",
         "quoted icon mapping unescapes doubled quotes");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-equals") = "icon=equals",
         "equals-containing icon mapping value parses");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "application/x-missing") = "",
         "unknown filetype has no icon mapping");
      Assert
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "   ") = "",
         "blank filetype has no icon mapping");

      Modifiers (Files.Types.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "modifier-specific open action is found");
      Assert (To_String (Lookup.Token) = "text/x-ada+control", "modifier token is normalized");
      Assert (To_String (Lookup.Action.Executable) = "editor", "action executable parses");
      Assert (Natural (Lookup.Action.Arguments.Length) = 2, "action arguments parse");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "open action lookup normalizes filetype whitespace");
      Assert
        (To_String (Lookup.Token) = "text/x-ada+control",
         "whitespace-normalized lookup preserves modifier token");

      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "/tmp/example/main.ada",
         "path placeholder expands as one argument");

      Modifiers := Files.Types.No_Modifiers;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix open action is found");
      Assert
        (To_String (Lookup.Token) = "application/ld+json",
         "structured-suffix filetype token keeps plus suffix");
      Assert
        (To_String (Lookup.Action.Executable) = "json-viewer",
         "structured-suffix open action executable parses");
      Modifiers (Files.Types.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix modifier-specific open action is found");
      Assert
        (To_String (Lookup.Token) = "application/ld+json+control",
         "structured-suffix modifier token appends after filetype suffix");
      Assert
        (To_String (Lookup.Action.Executable) = "json-editor",
         "structured-suffix modifier-specific executable parses");

      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/full", Files.Types.No_Modifiers);
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/archive.tar.gz");
      Assert (Lookup.Found, "full placeholder action is found");
      Assert (To_String (Expanded.Arguments.Element (1)) = "/tmp/example", "parent placeholder expands");
      Assert (To_String (Expanded.Arguments.Element (2)) = "archive.tar.gz", "name placeholder expands");
      Assert (To_String (Expanded.Arguments.Element (3)) = "archive.tar", "stem placeholder expands");
      Assert (To_String (Expanded.Arguments.Element (4)) = "gz", "extension placeholder expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/.profile");
      Assert (To_String (Expanded.Arguments.Element (2)) = ".profile", "dotfile name placeholder expands");
      Assert (To_String (Expanded.Arguments.Element (3)) = ".profile", "dotfile stem keeps leading-dot name");
      Assert (To_String (Expanded.Arguments.Element (4)) = "", "dotfile extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/name.");
      Assert (To_String (Expanded.Arguments.Element (2)) = "name.", "trailing-dot name placeholder expands");
      Assert (To_String (Expanded.Arguments.Element (3)) = "name.", "trailing-dot stem keeps final separator");
      Assert (To_String (Expanded.Arguments.Element (4)) = "", "trailing-dot extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "");
      Assert (To_String (Expanded.Arguments.Element (1)) = "", "empty path parent expands to empty");
      Assert (To_String (Expanded.Arguments.Element (2)) = "", "empty path name expands to empty");
      Assert (To_String (Expanded.Arguments.Element (3)) = "", "empty path stem expands to empty");
      Assert (To_String (Expanded.Arguments.Element (4)) = "", "empty path extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "relative.txt");
      Assert (To_String (Expanded.Arguments.Element (1)) = ".", "relative path parent expands to current directory");
      Assert (To_String (Expanded.Arguments.Element (2)) = "relative.txt", "relative path name expands");
      Assert (To_String (Expanded.Arguments.Element (3)) = "relative", "relative path stem expands");
      Assert (To_String (Expanded.Arguments.Element (4)) = "txt", "relative path extension expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\main.adb");
      Assert (To_String (Expanded.Arguments.Element (1)) = "C:\tmp\dir.with.dots", "Windows path parent expands");
      Assert (To_String (Expanded.Arguments.Element (2)) = "main.adb", "Windows path name expands");
      Assert (To_String (Expanded.Arguments.Element (3)) = "main", "Windows path stem expands");
      Assert (To_String (Expanded.Arguments.Element (4)) = "adb", "Windows path extension expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\main.adb");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "C:\",
         "Windows drive-root path parent keeps root separator");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "main.adb",
         "Windows drive-root path name expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\file");
      Assert
        (To_String (Expanded.Arguments.Element (4)) = "",
         "Windows placeholder extension ignores dotted directory names");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\folder\main.adb");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "\\server\share\folder",
         "UNC placeholder parent expands without losing the share root");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "main.adb",
         "UNC placeholder name expands from the leaf");
      Assert
        (To_String (Expanded.Arguments.Element (3)) = "main",
         "UNC placeholder stem expands from the leaf");
      Assert
        (To_String (Expanded.Arguments.Element (4)) = "adb",
         "UNC placeholder extension expands from the leaf");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "\\server\share\",
         "UNC share-root parent preserves the share root");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "",
         "UNC share-root name expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/trailing/");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "/tmp/example",
         "trailing separator parent expands from trimmed path");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "trailing",
         "trailing separator name expands from trimmed path");
      Assert
        (To_String (Expanded.Arguments.Element (3)) = "trailing",
         "trailing separator stem expands from trimmed path");
      Assert
        (To_String (Expanded.Arguments.Element (4)) = "",
         "trailing separator extension expands to empty");

      declare
         Embedded_Args   : Files.Types.String_Vectors.Vector;
         Embedded_Action : Files.Settings.Open_Action;
      begin
         Embedded_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Embedded_Args.Append (To_Unbounded_String ("{stem}.suffix"));
         Embedded_Action := Files.Settings.Make_Action ("inspect", Embedded_Args);
         Expanded := Files.Settings.Expand_Placeholders (Embedded_Action, "/tmp/example/main.ada");
         Assert
           (To_String (Expanded.Arguments.Element (1)) = "prefix-{path}",
            "embedded path placeholder remains literal");
         Assert
           (To_String (Expanded.Arguments.Element (2)) = "{stem}.suffix",
            "embedded stem placeholder remains literal");
         Assert
           (Files.Settings.Has_Embedded_Placeholder (Embedded_Action),
            "embedded placeholders are visible to safety checks");
         Assert
           (Files.Settings.Has_Unsafe_Placeholder_Usage (Embedded_Action),
            "embedded placeholders make open actions unsafe");
         Embedded_Action := Files.Settings.Make_Action ("{path}", Files.Types.String_Vectors.Empty_Vector);
         Assert
           (Files.Settings.Has_Unsafe_Placeholder_Usage (Embedded_Action),
            "executable placeholders make open actions unsafe");
      end;
      Assert (Files.Settings.Has_Embedded_Placeholder ("prefix-{path}"), "embedded placeholder is unsafe");
      Assert (not Files.Settings.Has_Embedded_Placeholder ("{path}"), "whole-argument placeholder is safe");
      Assert
        (not Files.Settings.Has_Embedded_Placeholder ("{unknown}"),
         "unknown placeholder token is not treated as a known placeholder");
      Assert
        (not Files.Settings.Has_Embedded_Placeholder ("prefix-{unknown}"),
         "embedded unknown placeholder remains a literal argument");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/unknown-placeholder",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "unknown placeholder open action parses");
      Assert
        (not Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action),
         "unknown placeholder open action is not unsafe");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "{unknown}",
         "unknown placeholder remains literal after expansion");

      Modifiers := Files.Types.No_Modifiers;
      Modifiers (Files.Types.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "missing modifier action falls back to unmodified filetype");
      Assert (To_String (Lookup.Token) = "text/x-ada", "fallback token is unmodified filetype");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "fallback open action lookup trims filetype");
      Assert (To_String (Lookup.Token) = "text/x-ada", "trimmed fallback token is unmodified filetype");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quoted",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "quoted open action is found");
      Assert (To_String (Lookup.Action.Executable) = "quoted editor", "quoted executable parses");
      Assert (Natural (Lookup.Action.Arguments.Length) = 2, "quoted arguments parse as separate values");
      Assert
        (To_String (Lookup.Action.Arguments.Element (1)) = "--project file",
         "quoted argument preserves spaces");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "/tmp/example/main.ada",
         "quoted placeholder expands as one argument");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada/");
      Assert
        (To_String (Expanded.Arguments.Element (2)) = "/tmp/example/main.ada/",
         "path placeholder preserves trailing separator verbatim");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quote-char",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "quote-containing open action is found");
      Assert
        (To_String (Lookup.Action.Executable) = "quote""runner",
         "quoted executable preserves doubled quote");
      Assert
        (To_String (Lookup.Action.Arguments.Element (1)) = "arg "" inner",
         "quoted argument preserves doubled quote");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/equals",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "equals-containing open action is found");
      Assert
        (To_String (Lookup.Action.Arguments.Element (1)) = "--flag=value",
         "equals-containing action argument parses");
      Assert
        (To_String (Lookup.Action.Arguments.Element (2)) = "arg=two words",
         "quoted equals-containing action argument parses");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/empty-arg",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "empty quoted argument open action is found");
      Assert (Natural (Lookup.Action.Arguments.Length) = 2, "empty quoted argument does not end parsing");
      Assert (To_String (Lookup.Action.Arguments.Element (1)) = "", "empty quoted argument is preserved");
      Assert
        (To_String (Lookup.Action.Arguments.Element (2)) = "after-empty",
         "argument after empty quoted argument is preserved");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "explicit shell open action is found");
      Assert (Lookup.Action.Use_Shell, "explicit shell prefix is preserved");
      Assert (To_String (Lookup.Action.Executable) = "shell runner", "shell executable can be quoted");
      Assert
        (To_String (Lookup.Action.Arguments.Element (1)) = "{name}",
         "shell action arguments are still parsed as a vector");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/shell.txt");
      Assert (Expanded.Use_Shell, "placeholder expansion preserves explicit shell flag");
      Assert (To_String (Expanded.Executable) = "shell runner", "placeholder expansion preserves executable");
      Assert (To_String (Expanded.Arguments.Element (1)) = "shell.txt", "shell action placeholder expands");
      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell-upper",
         Files.Types.No_Modifiers);
      Assert (Lookup.Found, "uppercase shell open action is found");
      Assert (Lookup.Action.Use_Shell, "uppercase shell prefix is normalized");
      Assert (To_String (Lookup.Action.Executable) = "upper-runner", "uppercase shell executable parses");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Files.Types.No_Modifiers);
      Assert (Lookup.Found, "unmodified non-shell open action is found");
      Assert (not Lookup.Action.Use_Shell, "shell execution is opt-in through explicit prefix");
      declare
         Serialized : constant String := Files.Settings.To_Text (Parsed.Settings);
         Reloaded   : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Serialized);
      begin
         Assert (Reloaded.Success, "serialized settings text parses");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quoted", Files.Types.No_Modifiers);
         Assert (Lookup.Found, "serialized quoted action reloads");
         Assert
           (To_String (Lookup.Action.Executable) = "quoted editor",
            "serialized quoted action preserves executable spaces");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "--project file",
            "serialized quoted action preserves spaced argument");
         Assert
           (To_String (Lookup.Action.Arguments.Element (2)) = "{path}",
            "serialized quoted action preserves placeholder argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/equals", Files.Types.No_Modifiers);
         Assert (Lookup.Found, "serialized equals-containing action reloads");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "--flag=value",
            "serialized open action preserves equals argument");
         Assert
           (To_String (Lookup.Action.Arguments.Element (2)) = "arg=two words",
            "serialized open action preserves quoted equals argument");
         Lookup :=
           Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quote-char", Files.Types.No_Modifiers);
         Assert (Lookup.Found, "serialized quote-containing action reloads");
         Assert
           (To_String (Lookup.Action.Executable) = "quote""runner",
            "serialized open action preserves executable quote");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "arg "" inner",
            "serialized open action preserves argument quote");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/empty-arg", Files.Types.No_Modifiers);
         Assert (Lookup.Found, "serialized empty-argument action reloads");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "",
            "serialized open action preserves empty argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/shell", Files.Types.No_Modifiers);
         Assert (Lookup.Found, "serialized shell action reloads");
         Assert (Lookup.Action.Use_Shell, "serialized shell action preserves shell opt-in");
         Assert
           (To_String (Lookup.Action.Executable) = "shell runner",
            "serialized shell action preserves quoted executable");
         Assert
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "quote") = "text/""quoted",
            "serialized filetype mapping preserves quote");
         Assert
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "eq") = "text/with=equals",
            "serialized filetype mapping preserves equals");
         Assert
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-quote") = "quote""icon",
            "serialized icon mapping preserves quote");
         Assert
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-equals") = "icon=equals",
            "serialized icon mapping preserves equals");
      end;
      declare
         Odd_Settings : Files.Settings.Settings_Model := Parsed.Settings;
         Odd_Text     : Unbounded_String;
         Expected     : constant String :=
           "icon_theme = " & '"' & "files " & '"' & '"' & "basic" & '"';
      begin
         Odd_Settings.Icon_Theme_Name := To_Unbounded_String ("files ""basic");
         Odd_Text := To_Unbounded_String (Files.Settings.To_Text (Odd_Settings));
         Assert
           (Ada.Strings.Fixed.Index (To_String (Odd_Text), Expected) > 0,
            "serialized icon theme quotes embedded quote");
      end;

      Modifiers := Files.Types.No_Modifiers;
      Modifiers (Files.Types.Control_Key) := True;
      Modifiers (Files.Types.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/mixed", Modifiers);
      Assert (Lookup.Found, "settings modifier token is normalized on insertion");
      Assert
        (To_String (Lookup.Token) = "text/mixed+control+alt",
         "lookup token uses normalized modifier order");
      Assert (To_String (Lookup.Action.Executable) = "mixed", "normalized settings action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/spaced", Modifiers);
      Assert (Lookup.Found, "settings modifier token trims spaces around separators");
      Assert
        (To_String (Lookup.Token) = "text/spaced+control+alt",
         "spaced modifier token is normalized on lookup");
      Assert (To_String (Lookup.Action.Executable) = "spaced", "spaced modifier action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/duplicate", Modifiers);
      Assert (Lookup.Found, "duplicate settings modifiers are normalized on insertion");
      Assert
        (To_String (Lookup.Token) = "text/duplicate+control+alt",
         "duplicate modifier token is deduplicated and ordered");
      Assert (To_String (Lookup.Action.Executable) = "duplicate", "deduplicated settings action is returned");

      declare
         Normalized_Draft_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Normalized_Draft          : Files.Settings.Settings_Draft;
         Normalized_Load           : Files.Settings.Settings_Parse_Result;
         Normalized_Args           : Files.Types.String_Vectors.Vector;
      begin
         Normalized_Args.Append (To_Unbounded_String ("{path}"));
         Files.Settings.Add_Open_Action
           (Normalized_Draft_Settings,
            "text/plain+control+alt",
            Files.Settings.Make_Action ("existing", Normalized_Args));
         Normalized_Draft := Files.Settings.Make_Draft (Normalized_Draft_Settings);
         Normalized_Draft.Filetype_Extension := To_Unbounded_String (" .TXT ");
         Normalized_Draft.Filetype_Value := To_Unbounded_String ("text/x-overridden");
         Normalized_Draft.Icon_Filetype := To_Unbounded_String (" text/plain ");
         Normalized_Draft.Icon_Value := To_Unbounded_String ("text-updated");
         Normalized_Draft.Open_Action_Token := To_Unbounded_String (" text/plain + ALT + control ");
         Normalized_Draft.Open_Action_Command := To_Unbounded_String ("editor {path}");
         Normalized_Load := Files.Settings.Apply_Draft (Normalized_Draft_Settings, Normalized_Draft);
         Assert (Normalized_Load.Success, "normalized draft mapping replacement applies");
         Assert
           (Files.Settings.Filetype_For_Extension (Normalized_Load.Settings, "txt") = "text/x-overridden",
            "normalized draft extension replaces existing row");
         Assert
           (Files.Settings.Icon_For_Filetype (Normalized_Load.Settings, "text/plain") = "text-updated",
            "trimmed draft icon key replaces existing row");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Normalized_Load.Settings,
              "text/plain",
              [Files.Types.Control_Key | Files.Types.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "normalized draft action lookup succeeds");
         Assert
           (To_String (Lookup.Action.Executable) = "editor",
            "normalized draft action replaces existing row");
         Assert
           (Natural (Normalized_Load.Settings.Extension_Filetypes.Length) =
            Natural (Normalized_Draft_Settings.Extension_Filetypes.Length),
            "normalized draft extension replacement does not add a duplicate row");
         Assert
           (Natural (Normalized_Load.Settings.Icon_Mappings.Length) =
            Natural (Normalized_Draft_Settings.Icon_Mappings.Length),
            "normalized draft icon replacement does not add a duplicate row");
         Assert
           (Natural (Normalized_Load.Settings.Open_Actions.Length) =
            Natural (Normalized_Draft_Settings.Open_Actions.Length),
            "normalized draft action replacement does not add a duplicate row");

         Normalized_Draft.Open_Action_Token := To_Unbounded_String (" application/ld+json + control ");
         Normalized_Draft.Open_Action_Command := To_Unbounded_String ("json-editor {path}");
         Assert
           (Files.Settings.Field_Diagnostic (12, "application/ld+json+control") = "",
            "settings field accepts structured-suffix modifier tokens");
         Assert
           (Files.Settings.Validate_Draft (Normalized_Draft).Success,
            "draft validates structured-suffix modifier action");
         Normalized_Load := Files.Settings.Apply_Draft (Normalized_Draft_Settings, Normalized_Draft);
         Assert (Normalized_Load.Success, "draft applies structured-suffix modifier action");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Normalized_Load.Settings,
              "application/ld+json",
              [Files.Types.Control_Key => True, others => False]);
         Assert (Lookup.Found, "draft structured-suffix modifier action lookup succeeds");
         Assert
           (To_String (Lookup.Token) = "application/ld+json+control",
            "draft structured-suffix modifier action token is normalized");
         Assert
           (To_String (Lookup.Action.Executable) = "json-editor",
            "draft structured-suffix modifier action executable parses");
      end;

      Modifiers := Files.Types.No_Modifiers;
      Modifiers (Files.Types.Meta_Key) := True;
      Modifiers (Files.Types.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing open action is represented as lookup data");
      Assert
        (To_String (Lookup.Token) = "text/missing+shift+meta",
         "missing open action records normalized attempted token");
      Assert
        (To_String (Lookup.Error_Key) = "error.open_action.missing",
         "missing open action reports deterministic diagnostic key");
      Modifiers (Files.Types.Control_Key) := True;
      Modifiers (Files.Types.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing full-modifier open action is represented as lookup data");
      Assert
        (To_String (Lookup.Token) = "text/missing+shift+control+alt+meta",
         "missing open action records full normalized modifier order");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "   ", Modifiers);
      Assert (not Lookup.Found, "empty filetype open action lookup is missing");
      Assert (To_String (Lookup.Token) = "", "empty filetype lookup reports no modifier-only token");
      Assert
        (To_String (Lookup.Error_Key) = "error.open_action.missing",
         "empty filetype lookup reports deterministic diagnostic key");

      Files.Settings.Add_Extension_Mapping (Manual, ".TXT", "text/first");
      Files.Settings.Add_Extension_Mapping (Manual, " txt ", " text/second ");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "TXT") = "text/second",
         "direct extension mapping trims values and replaces existing entries");
      Files.Settings.Add_Extension_Mapping (Manual, ".", "text/blank");
      Files.Settings.Add_Extension_Mapping (Manual, "blank", "   ");
      Files.Settings.Add_Extension_Mapping (Manual, "bad=extension", "text/bad");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & ASCII.LF & "extension", "text/bad-key");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & ASCII.VT & "extension", "text/bad-vtab-key");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & C1_Break & "extension", "text/bad-c1-key");
      Files.Settings.Add_Extension_Mapping
        (Manual,
         "bad" & Line_Separator & "extension",
         "text/bad-unicode-key");
      Files.Settings.Add_Extension_Mapping (Manual, "linebreak", "text/plain" & ASCII.LF & "bad");
      Files.Settings.Add_Extension_Mapping (Manual, "formfeed", "text/plain" & ASCII.FF & "bad");
      Files.Settings.Add_Extension_Mapping (Manual, "c1break", "text/plain" & C1_Break & "bad");
      Files.Settings.Add_Extension_Mapping
        (Manual,
         "unicodebreak",
         "text/plain" & Line_Separator & "bad");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, ".") = "",
         "direct extension mapping ignores empty normalized extension");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "blank") = "",
         "direct extension mapping ignores empty filetype value");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "bad=extension") = "",
         "direct extension mapping ignores unrepresentable extension keys");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.LF & "extension") = "",
         "direct extension mapping ignores line-break extension keys");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.VT & "extension") = "",
         "direct extension mapping ignores vertical-tab extension keys");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & C1_Break & "extension") = "",
         "direct extension mapping ignores C1 line-break extension keys");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & Line_Separator & "extension") = "",
         "direct extension mapping ignores Unicode line-separator extension keys");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "linebreak") = "",
         "direct extension mapping ignores unrepresentable values");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "formfeed") = "",
         "direct extension mapping ignores form-feed values");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "c1break") = "",
         "direct extension mapping ignores C1 line-break values");
      Assert
        (Files.Settings.Filetype_For_Extension (Manual, "unicodebreak") = "",
         "direct extension mapping ignores Unicode line-separator values");
      Files.Settings.Add_Icon_Mapping (Manual, " text/second ", " first-icon ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/second", " second-icon ");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/second") = "second-icon",
         "direct icon mapping trims values and replaces existing entries");
      Files.Settings.Add_Icon_Mapping (Manual, "   ", "blank-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/blank-icon", "   ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad=icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & ASCII.LF & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & ASCII.VT & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & C1_Break & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping
        (Manual,
         "text/bad" & Line_Separator & "icon",
         "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/linebreak-icon", "icon" & ASCII.LF & "bad");
      Files.Settings.Add_Icon_Mapping (Manual, "text/formfeed-icon", "icon" & ASCII.FF & "bad");
      Files.Settings.Add_Icon_Mapping (Manual, "text/c1break-icon", "icon" & C1_Break & "bad");
      Files.Settings.Add_Icon_Mapping
        (Manual,
         "text/unicodebreak-icon",
         "icon" & Line_Separator & "bad");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "") = "",
         "direct icon mapping ignores empty filetype key");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/blank-icon") = "",
         "direct icon mapping ignores empty icon value");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad=icon") = "",
         "direct icon mapping ignores unrepresentable filetype keys");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.LF & "icon") = "",
         "direct icon mapping ignores line-break filetype keys");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.VT & "icon") = "",
         "direct icon mapping ignores vertical-tab filetype keys");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & C1_Break & "icon") = "",
         "direct icon mapping ignores C1 line-break filetype keys");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & Line_Separator & "icon") = "",
         "direct icon mapping ignores Unicode line-separator filetype keys");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/linebreak-icon") = "",
         "direct icon mapping ignores unrepresentable values");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/formfeed-icon") = "",
         "direct icon mapping ignores form-feed values");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/c1break-icon") = "",
         "direct icon mapping ignores C1 line-break values");
      Assert
        (Files.Settings.Icon_For_Filetype (Manual, "text/unicodebreak-icon") = "",
         "direct icon mapping ignores Unicode line-separator values");

      Args.Append (To_Unbounded_String ("{path}"));
      Files.Settings.Add_Open_Action
        (Manual,
         "text/manual+META+shift+alt+control+shift",
         Files.Settings.Make_Action ("first", Args));
      Files.Settings.Add_Open_Action
        (Manual,
         " text/manual+control+alt+meta+shift ",
         Files.Settings.Make_Action ("second", Args));
      Files.Settings.Add_Open_Action
        (Manual,
         " text/spaced-manual + META + shift ",
         Files.Settings.Make_Action (" spaced-manual ", Args));
      Modifiers := Files.Types.No_Modifiers;
      Modifiers (Files.Types.Meta_Key) := True;
      Modifiers (Files.Types.Shift_Key) := True;
      Modifiers (Files.Types.Alt_Key) := True;
      Modifiers (Files.Types.Control_Key) := True;
      Assert
        (Files.Settings.Modifier_Token (Modifiers) = "+shift+control+alt+meta",
         "modifier tokens are emitted in stable lookup order");
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion normalizes modifiers");
      Assert
        (To_String (Lookup.Token) = "text/manual+shift+control+alt+meta",
         "direct open-action lookup reports normalized modifier token");
      Assert
        (To_String (Lookup.Action.Executable) = "second",
         "direct open-action insertion replaces normalized duplicate token");
      Modifiers := Files.Types.No_Modifiers;
      Modifiers (Files.Types.Meta_Key) := True;
      Modifiers (Files.Types.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/spaced-manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion trims filetype before modifiers");
      Assert
        (To_String (Lookup.Token) = "text/spaced-manual+shift+meta",
         "direct spaced open-action token is normalized");
      Assert
        (To_String (Lookup.Action.Executable) = "spaced-manual",
         "direct open-action insertion trims executable whitespace");
      Assert
        (To_String (Lookup.Action.Arguments.Element (1)) = "{path}",
         "direct open-action insertion preserves argument values");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores dangling modifier separator");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+control+",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/bad-direct",
         [Files.Types.Control_Key => True, others => False]);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores trailing modifier separator after a modifier");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+control++alt",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/bad-direct",
         [Files.Types.Control_Key => True, Files.Types.Alt_Key => True, others => False]);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores empty modifier segments");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+custom",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unknown modifiers");
      Files.Settings.Add_Open_Action
        (Manual,
         "image/svg+xml",
         Files.Settings.Make_Action ("svg-viewer", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "image/svg+xml", Files.Types.No_Modifiers);
      Assert (Lookup.Found, "direct open-action insertion accepts structured filetype suffixes");
      Assert
        (To_String (Lookup.Token) = "image/svg+xml",
         "direct structured filetype suffix lookup keeps plus suffix");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad=direct",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad=direct", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unrepresentable filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         """text/quoted-direct""",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, """text/quoted-direct""", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores quoted filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         "[text/bracketed-direct]",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "[text/bracketed-direct]", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores bracketed filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         "+control",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "", Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores modifier-only token");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/empty-executable",
         Files.Settings.Make_Action ("   ", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/empty-executable", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores empty executable");
      declare
         Unsafe_Args : Files.Types.String_Vectors.Vector;
      begin
         Unsafe_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/unsafe-argument",
            Files.Settings.Make_Action ("unsafe", Unsafe_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-argument", Files.Types.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores embedded placeholders");
      end;
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unsafe-executable",
         Files.Settings.Make_Action ("{path}", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-executable", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable placeholders");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/linebreak-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.LF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-executable", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/formfeed-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.FF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/formfeed-executable", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable form feeds");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/c1break-executable",
         Files.Settings.Make_Action ("viewer" & C1_Break & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-executable", Files.Types.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable C1 line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Files.Settings.Make_Action ("viewer" & Line_Separator & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Files.Types.No_Modifiers);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores executable Unicode line separators");
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & ASCII.LF & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/linebreak-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-argument", Files.Types.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument line breaks");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & ASCII.VT & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/vtab-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/vtab-argument", Files.Types.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument vertical tabs");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & C1_Break & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/c1break-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-argument", Files.Types.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument C1 line breaks");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & Line_Separator & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/unicodebreak-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action
           (Manual,
            "text/unicodebreak-argument",
            Files.Types.No_Modifiers);
         Assert
           (not Lookup.Found,
            "direct open-action insertion ignores argument Unicode line separators");
      end;
      Assert (Files.Settings.Field_Diagnostic (1, "details") = "", "settings field validates view mode");
      Assert
        (Files.Settings.Field_Diagnostic (1, "bad") = "error.settings.invalid_view_mode",
         "settings field reports invalid view mode");
      Assert
        (Files.Settings.Field_Diagnostic (1, "details" & ASCII.LF & "large") =
         "error.settings.invalid_view_mode",
         "view-mode field rejects line breaks");
      Assert (Files.Settings.Field_Diagnostic (2, "true") = "", "settings field validates boolean");
      Assert
        (Files.Settings.Field_Diagnostic (2, "maybe") = "error.settings.invalid_boolean",
         "settings field reports invalid boolean");
      Assert
        (Files.Settings.Field_Diagnostic (2, "true" & ASCII.LF & "false") =
         "error.settings.invalid_boolean",
         "boolean field rejects line breaks");
      Assert (Files.Settings.Field_Diagnostic (5, "false") = "", "settings field validates high-contrast boolean");
      Assert (Files.Settings.Field_Diagnostic (6, "files-basic") = "", "settings field validates icon theme");
      Assert
        (Files.Settings.Field_Diagnostic (6, "unknown-theme") = "error.settings.invalid_icon_theme",
         "settings field reports invalid icon theme");
      Assert (Files.Settings.Field_Diagnostic (3, "modified") = "", "settings field validates sort field");
      Assert
        (Files.Settings.Field_Diagnostic (3, "date") = "error.settings.invalid_sort_field",
         "settings field reports invalid sort field");
      Assert
        (Files.Settings.Field_Diagnostic (8, "text/""quoted") = "",
         "filetype value field accepts raw quote-containing values");
      Assert
        (Files.Settings.Field_Diagnostic (7, "bad=extension") = "error.settings.invalid_mapping",
         "filetype extension field rejects unrepresentable keys");
      Assert
        (Files.Settings.Field_Diagnostic (8, "text/plain" & ASCII.LF & "bad") =
         "error.settings.invalid_mapping",
         "mapping value field rejects line breaks");
      Assert
        (Files.Settings.Field_Diagnostic (8, "text/plain" & C1_Break & "bad") =
         "error.settings.invalid_mapping",
         "mapping value field rejects C1 line breaks");
      Assert
        (Files.Settings.Field_Diagnostic (8, "text/plain" & Line_Separator & "bad") =
         "error.settings.invalid_mapping",
         "mapping value field rejects Unicode line separators");
      Assert
        (Files.Settings.Field_Diagnostic (10, "quote""icon") = "",
         "icon value field accepts raw quote-containing values");
      Assert
        (Files.Settings.Field_Diagnostic (9, "text/bad=icon") = "error.settings.invalid_mapping",
         "icon filetype field rejects unrepresentable keys");
      declare
         Quote_Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Manual);
         Applied     : Files.Settings.Settings_Parse_Result;
      begin
         Quote_Draft.Filetype_Extension := To_Unbounded_String ("quote");
         Quote_Draft.Filetype_Value := To_Unbounded_String ("text/""quoted");
         Quote_Draft.Icon_Filetype := To_Unbounded_String ("text/""quoted");
         Quote_Draft.Icon_Value := To_Unbounded_String ("quote""icon");
         Assert (Files.Settings.Validate_Draft (Quote_Draft).Success, "quote-containing draft validates");
         Applied := Files.Settings.Apply_Draft (Manual, Quote_Draft);
         Assert (Applied.Success, "quote-containing draft applies");
         Assert
           (Files.Settings.Filetype_For_Extension (Applied.Settings, "quote") = "text/""quoted",
            "quote-containing draft preserves filetype mapping");
         Assert
           (Files.Settings.Icon_For_Filetype (Applied.Settings, "text/""quoted") = "quote""icon",
            "quote-containing draft preserves icon mapping");
      end;
      declare
         Broken_Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Load  : Files.Settings.Settings_Parse_Result;
      begin
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are rejected");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid",
            "mismatched draft mapping vectors report deterministic diagnostic");
         Broken_Load := Files.Settings.Apply_Draft (Manual, Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are not applied");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Extension := To_Unbounded_String ("bad=extension");
         Broken_Draft.Filetype_Value := To_Unbounded_String ("text/bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable filetype key");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "current unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("bad=extension"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype keys");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Filetype := To_Unbounded_String ("text/bad=icon");
         Broken_Draft.Icon_Value := To_Unbounded_String ("bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable icon key");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "current unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/bad=icon"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon keys");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("text/plain+hyper");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unknown open-action modifier");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "current unknown open-action modifier reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("+control");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current modifier-only open-action token");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "current modifier-only open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/bad=action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action keys");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "unrepresentable draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("""text/quoted-action""");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects quoted open-action keys");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "quoted draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("[text/bracketed-action]"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects bracketed open-action keys");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "bracketed draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("+control"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects stored modifier-only open-action tokens");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "stored modifier-only draft open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("linebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype values");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "unrepresentable draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/linebreak-value"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("icon" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon values");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "unrepresentable draft icon value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("unicodebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator filetype values");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_mapping",
            "Unicode line-separator draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/linebreak-action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action commands");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "unrepresentable draft open-action command reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/unicodebreak-action"));
         Broken_Draft.Open_Action_Commands.Append
           (To_Unbounded_String ("viewer {path}" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator open-action commands");
         Assert
           (To_String (Broken_Load.Error_Key) = "error.settings.invalid_open_action",
            "Unicode line-separator draft open-action command reports open-action diagnostic");
      end;
      Assert (Files.Settings.Field_Diagnostic (11, "text/plain+control") = "", "action token field validates");
      Assert
        (Files.Settings.Field_Diagnostic (11, "+control") = "error.settings.invalid_open_action",
         "action token field reports invalid action token");
      Assert
        (Files.Settings.Field_Diagnostic (11, "text/bad=action") = "error.settings.invalid_open_action",
         "action token field rejects unrepresentable filetype keys");
      Assert
        (Files.Settings.Field_Diagnostic (11, """text/quoted-action""") = "error.settings.invalid_open_action",
         "action token field rejects quoted filetype keys");
      Assert
        (Files.Settings.Field_Diagnostic (11, "[text/bracketed-action]") = "error.settings.invalid_open_action",
         "action token field rejects bracketed filetype keys");
      Assert
        (Files.Settings.Field_Diagnostic (11, "text/plain+control+") = "error.settings.invalid_open_action",
         "action token field reports trailing modifier separator");
      Assert
        (Files.Settings.Field_Diagnostic (11, "text/plain" & ASCII.LF & "text/html") =
         "error.settings.invalid_open_action",
         "action token field rejects line breaks");
      Assert (Files.Settings.Field_Diagnostic (12, "viewer {path}") = "", "action command field validates");
      Assert
        (Files.Settings.Field_Diagnostic (12, """quoted editor"" ""--project file"" ""{path}""") = "",
         "action command field validates quoted tokens");
      Assert
        (Files.Settings.Field_Diagnostic (12, """quote""""runner"" ""arg """" inner""") = "",
         "action command field validates doubled quotes");
      Assert
        (Files.Settings.Field_Diagnostic (12, "runner """" after-empty") = "",
         "action command field validates empty quoted argument");
      Assert
        (Files.Settings.Field_Diagnostic (12, "viewer prefix-{path}") = "error.settings.invalid_open_action",
         "action command field reports embedded placeholder");
      Assert
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & ASCII.LF & "other") =
         "error.settings.invalid_open_action",
         "action command field rejects line breaks");
      Assert
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & C1_Break & "other") =
         "error.settings.invalid_open_action",
         "action command field rejects C1 line breaks");
      Assert
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & Line_Separator & "other") =
         "error.settings.invalid_open_action",
         "action command field rejects Unicode line separators");
      Assert
        (Files.Settings.Field_Diagnostic (12, """unterminated") = "error.settings.invalid_open_action",
         "action command field reports unterminated quote");
      Assert
        (Files.Settings.Field_Diagnostic (12, """editor""junk {path}") = "error.settings.invalid_open_action",
         "action command field reports quoted token trailing junk");
      Assert
        (Files.Settings.Field_Diagnostic (0, "details") = "error.settings.invalid",
         "unknown settings field reports a deterministic diagnostic");
      Assert
        (Files.Settings.Field_Diagnostic (13, "details") = "error.settings.invalid",
         "out-of-range settings field reports a deterministic diagnostic");
      declare
         Broken : Files.Settings.Settings_Parse_Result;
      begin
         Broken := Files.Settings.Parse ("[unknown]" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown sections");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.unknown_section",
            "unknown section reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries without equals");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.expected_equals",
            "missing equals reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("default_view_mode = details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries before any section");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.missing_section",
            "missing section reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & ". = text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty normalized extensions");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_mapping",
            "empty extension mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = ""text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unterminated quoted mappings");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_mapping",
            "unterminated mapping quote reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[icons]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty icon mappings");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_mapping",
            "empty icon mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain = viewer prefix-{path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects embedded open-action placeholders");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "embedded placeholder reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/plain+control+ = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects trailing open-action modifier separator");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "trailing modifier separator reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode = compact" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown view mode values");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_view_mode",
            "unknown view mode reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "icon_theme = neon" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown icon themes");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_icon_theme",
            "unknown icon theme reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "show_hidden_files = maybe" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid boolean values");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_boolean",
            "invalid boolean reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = text/plain" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break mapping values");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_mapping",
            "C1 line-break mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[filetypes]" & ASCII.LF & "txt = text/plain" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator mapping values");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_mapping",
            "Unicode line-separator mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/c1 = viewer {path}" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break open actions");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "C1 line-break open action reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF &
              "text/unicode = viewer {path}" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator open actions");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "Unicode line-separator open action reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = bogus" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid sort fields");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_sort_field",
            "invalid sort field reports deterministic diagnostic");
         declare
            Created_Parsed : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = created" & ASCII.LF);
            Modified_Parsed : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = modified" & ASCII.LF);
         begin
            Assert (Created_Parsed.Success, "settings parser accepts the created sort field");
            Assert
              (Created_Parsed.Settings.Sort_Field_Value = Files.Settings.Sort_By_Created,
               "created sort field round-trips distinctly from modified");
            Assert
              (Modified_Parsed.Settings.Sort_Field_Value = Files.Settings.Sort_By_Modified,
               "modified sort field still round-trips to modified");
         end;
         declare
            With_Bookmarks : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Round          : Files.Settings.Settings_Parse_Result;
            Found_Eq       : Boolean := False;
            Found_Hash     : Boolean := False;
         begin
            With_Bookmarks.Bookmark_Paths.Append (To_Unbounded_String ("/data/a=b"));
            With_Bookmarks.Bookmark_Paths.Append (To_Unbounded_String ("#hashdir"));
            Round := Files.Settings.Parse (Files.Settings.To_Text (With_Bookmarks));
            Assert (Round.Success, "settings with tricky bookmark paths round-trips");
            for P of Round.Settings.Bookmark_Paths loop
               if To_String (P) = "/data/a=b" then
                  Found_Eq := True;
               elsif To_String (P) = "#hashdir" then
                  Found_Hash := True;
               end if;
            end loop;
            Assert (Found_Eq, "a bookmark path containing '=' survives the round-trip");
            Assert (Found_Hash, "a bookmark path starting with '#' survives the round-trip");
         end;
         declare
            --  The file is authoritative for mappings: a built-in mapping
            --  omitted from the file does not reappear from the defaults, while
            --  a fresh install still gets the defaults (seeded into the file by
            --  Ensure_Default_File).
            Authoritative : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse
                ("[filetypes]" & ASCII.LF & "custom = application/x-custom" & ASCII.LF);
         begin
            Assert (Authoritative.Success, "settings with an explicit filetypes section parses");
            Assert
              (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "custom")
                 = "application/x-custom",
               "an explicit filetype mapping loads from the file");
            Assert
              (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "txt") = "",
               "a built-in mapping omitted from the file does not reappear");
            Assert
              (Files.Settings.Filetype_For_Extension (Files.Settings.Default_Settings, "txt") /= "",
               "built-in defaults still provide mappings for a fresh install");
         end;
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "unexpected = value" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown setting keys");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.unknown_key",
            "unknown setting key reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain+hyper = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown open-action modifiers");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "unknown open-action modifier reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty open-action commands");
         Assert
           (To_String (Broken.Error_Key) = "error.settings.invalid_open_action",
            "empty open-action command reports deterministic diagnostic");
      end;
   end Test_Settings_Parsing_And_Open_Actions;

   procedure Test_Settings_Load_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings_Path : constant String := Join (Root, "files.conf");
      Long_Path     : constant String := Join (Root, "long.conf");
      Long_Type     : constant String :=
        "application/x-" &
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" &
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" &
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" &
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" &
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" &
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" &
        "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg" &
        "hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh" &
        "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii" &
        "jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj" &
        "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk" &
        "llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllll";
      Missing       : Files.Settings.Settings_Parse_Result;
      Empty_Load    : Files.Settings.Settings_Parse_Result;
      Not_File      : Files.Settings.Settings_Parse_Result;
      Loaded        : Files.Settings.Settings_Parse_Result;
      Long_Loaded   : Files.Settings.Settings_Parse_Result;
      Ensured_Path  : constant String := Join (Join (Root, "created-config"), "settings.conf");
      Ensured       : Files.Settings.Settings_Write_Result;
      Saved_Path    : constant String := Join (Join (Root, "saved-config"), "settings.conf");
      Blocked_Parent : constant String := Join (Root, "blocked-parent");
      Blocked_Path   : constant String := Join (Blocked_Parent, "settings.conf");
      Saved         : Files.Settings.Settings_Write_Result;
      Default_Text  : constant String := Files.Settings.Default_Settings_Text;
      Default_Parse : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Default_Text);
   begin
      Reset_Root;
      Assert (Default_Parse.Success, "default settings text parses");
      Assert
        (Files.Settings.Filetype_For_Extension (Default_Parse.Settings, "txt") = "text/plain",
         "default settings text includes filetype mappings");
      Assert
        (not Default_Parse.Settings.High_Contrast_Theme,
         "default settings text keeps high-contrast theme disabled");
      Assert
        (To_String (Default_Parse.Settings.Icon_Theme_Name) = "files-basic",
         "default settings text keeps basic icon theme selected");
      Missing := Files.Settings.Load_File (Join (Root, "missing.conf"));
      Assert (Missing.Success, "missing settings file falls back to defaults");
      Assert
        (Files.Settings.Filetype_For_Extension (Missing.Settings, "txt") = "text/plain",
         "default settings are returned for a missing file");
      Empty_Load := Files.Settings.Load_File ("");
      Assert (not Empty_Load.Success, "empty settings file path is rejected");
      Assert
        (To_String (Empty_Load.Error_Key) = "error.settings.load",
         "empty settings file path reports load diagnostic");
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      Not_File := Files.Settings.Load_File (Join (Root, "settings-dir"));
      Assert (not Not_File.Success, "directory settings path is rejected");
      Assert
        (To_String (Not_File.Error_Key) = "error.settings.not_file",
         "directory settings path reports not-file diagnostic");

      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = true" & ASCII.LF &
         "sort_field = modified" & ASCII.LF &
         "sort_ascending = false" & ASCII.LF &
         "high_contrast_theme = true" & ASCII.LF &
         "[filetypes]" & ASCII.LF &
         "foo = application/x-foo" & ASCII.LF);
      Loaded := Files.Settings.Load_File (Settings_Path);
      Assert (Loaded.Success, "settings file parses from disk");
      Assert (Loaded.Settings.Show_Hidden_Files, "show-hidden setting loads from disk");
      Assert (Loaded.Settings.Sort_Field_Value = Files.Settings.Sort_By_Modified, "sort field loads from disk");
      Assert (not Loaded.Settings.Sort_Ascending, "sort direction loads from disk");
      Assert (Loaded.Settings.High_Contrast_Theme, "theme preference loads from disk");
      Assert
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "foo") = "application/x-foo",
         "filetype mapping loads from disk");

      Write_File
        (Long_Path,
         "[filetypes]" & ASCII.LF &
         "long = " & Long_Type & ASCII.LF);
      Long_Loaded := Files.Settings.Load_File (Long_Path);
      Assert (Long_Loaded.Success, "settings loader preserves long logical lines");
      Assert
        (Files.Settings.Filetype_For_Extension (Long_Loaded.Settings, "long") = Long_Type,
         "long filetype mapping is not split while loading");

      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings creates missing file");
      Assert (Ada.Directories.Exists (Ensured_Path), "ensure default settings creates parent directories");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Assert (Loaded.Success, "ensured default settings file loads");
      Assert
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "txt") = "text/plain",
         "ensured settings file contains default mappings");
      Saved := Files.Settings.Save_Text (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
      Assert (Saved.Success, "settings text can be saved to a new path");
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert (Loaded.Success, "saved settings file loads");
      Assert (Loaded.Settings.Default_View = Files.Types.Large_Icons, "saved settings text is persisted");
      Write_File (Blocked_Parent, "not a directory");
      Saved := Files.Settings.Save_Text (Blocked_Path, "[settings]" & ASCII.LF);
      Assert (not Saved.Success, "settings save rejects a file used as parent directory");
      Assert
        (To_String (Saved.Path) = Blocked_Path,
         "settings save parent failure reports requested settings path");
      Assert
        (To_String (Saved.Error_Key) = "error.settings.not_file",
         "settings save parent failure reports not-file diagnostic");
      declare
         Reset_Draft : constant Files.Settings.Settings_Draft := Files.Settings.Reset_Draft_To_Defaults;
      begin
         Assert
           (To_String (Reset_Draft.Default_View_Mode) = "small_icons",
            "reset settings draft restores default view mode");
      end;
      declare
         Draft_Path : constant String := Join (Join (Root, "draft-config"), "settings.conf");
         Draft      : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Loaded.Settings);
         Draft_Load : Files.Settings.Settings_Parse_Result;
         Draft_Model : Files.Model.Window_Model := Sample_Model;
         Draft_Settings : Files.Settings.Settings_Model := Loaded.Settings;
         Controller_Result : Files.Controller.Controller_Result;
         Lookup : Files.Settings.Action_Lookup_Result;
         Ctrl : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      begin
         Ctrl (Files.Types.Control_Key) := True;
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Assert
           (Controller_Result.Operation.Status = Files.Operations.Operation_Disabled,
            "closed settings pane cannot save settings");
         Assert
           (To_String (Controller_Result.Operation.Error_Key) = "error.settings.closed",
            "closed settings save reports a localized disabled error");
         Assert
           (To_String (Controller_Result.Operation.Path) = Draft_Path,
            "closed settings save reports settings path");
         Files.Model.Begin_Settings_Edit (Draft_Model, Files.Settings.Make_Draft (Draft_Settings));
         Draft.Default_View_Mode := To_Unbounded_String ("details");
         Draft.Show_Hidden_Files := To_Unbounded_String ("true");
         Draft.Sort_Field_Value := To_Unbounded_String ("size");
         Draft.Sort_Ascending := To_Unbounded_String ("false");
         Draft.High_Contrast_Theme := To_Unbounded_String ("true");
         Draft.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
         Draft.Filetype_Extension := To_Unbounded_String ("log");
         Draft.Filetype_Value := To_Unbounded_String ("text/x-log");
         Draft.Icon_Filetype := To_Unbounded_String ("text/x-log");
         Draft.Icon_Value := To_Unbounded_String ("text");
         Draft.Open_Action_Token := To_Unbounded_String ("application/ld+json+alt");
         Draft.Open_Action_Command := To_Unbounded_String ("json-editor {path}");
         Assert (Files.Settings.Validate_Draft (Draft).Success, "settings draft validates editable values");
         Draft_Load := Files.Settings.Apply_Draft (Loaded.Settings, Draft);
         Assert (Draft_Load.Success, "settings draft applies to a settings model");
         Assert (Draft_Load.Settings.Default_View = Files.Types.Details, "draft applies default view");
         Assert (Draft_Load.Settings.Show_Hidden_Files, "draft applies hidden-file flag");
         Assert (Draft_Load.Settings.Sort_Field_Value = Files.Settings.Sort_By_Size, "draft applies sort field");
         Assert (Draft_Load.Settings.High_Contrast_Theme, "draft applies high-contrast theme flag");
         Assert
           (To_String (Draft_Load.Settings.Icon_Theme_Name) = "files-high-contrast",
            "draft applies icon theme selection");
         Assert
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log") = "text/x-log",
            "draft applies filetype mapping");
         Assert
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log") = "text",
            "draft applies icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Files.Types.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "draft applies modifier-specific open action");
         Assert (To_String (Lookup.Action.Executable) = "json-editor", "draft action executable is parsed");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (Saved.Success, "settings draft saves to disk");
         Draft_Load := Files.Settings.Load_File (Draft_Path);
         Assert (Draft_Load.Success, "saved draft settings load");
         Assert (Draft_Load.Settings.Default_View = Files.Types.Details, "saved draft persists default view");
         Assert
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log") = "text/x-log",
            "saved draft persists filetype mapping");
         Assert
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log") = "text",
            "saved draft persists icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Files.Types.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "saved draft persists open action");
         Assert
           (To_String (Lookup.Action.Executable) = "json-editor",
            "saved draft persists structured-suffix open action executable");
         Draft.Default_View_Mode := To_Unbounded_String ("bad-view");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (not Saved.Success, "invalid settings draft is not saved");
         Assert
           (To_String (Saved.Error_Key) = "error.settings.invalid_view_mode",
            "invalid draft save reports validation diagnostic");
         declare
            Empty_Settings : Files.Settings.Settings_Model := Loaded.Settings;
            Empty_Model    : Files.Model.Window_Model := Sample_Model;
            Empty_Load     : Files.Settings.Settings_Parse_Result;
            Repair_Draft   : Files.Settings.Settings_Draft;
         begin
            Empty_Settings.Extension_Filetypes.Clear;
            Empty_Settings.Icon_Mappings.Clear;
            Empty_Settings.Open_Actions.Clear;
            --  Keep missing open-action lookups deterministic by opting out of
            --  the host opener fallback that would otherwise resolve.
            Empty_Settings.Use_System_Default_Opener := False;
            Files.Model.Begin_Settings_Edit (Empty_Model, Files.Settings.Make_Draft (Empty_Settings));

            Files.Model.Set_Settings_Field_Index (Empty_Model, 8);
            Files.Model.Set_Settings_Field_Text (Empty_Model, "ghost");
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "empty filetype list ignores mapping text without selected row");

            Files.Model.Set_Settings_Field_Index (Empty_Model, 11);
            Files.Model.Set_Settings_Field_Text (Empty_Model, "text/x-ghost");
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "empty icon list ignores mapping text without selected row");

            Files.Model.Set_Settings_Field_Index (Empty_Model, 13);
            Files.Model.Set_Settings_Field_Text (Empty_Model, "text/x-ghost");
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "empty open-action list ignores mapping text without selected row");

            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert (Empty_Load.Success, "empty mapping draft remains valid after ignored edits");
            Assert
              (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "ghost") = "",
               "ignored empty-list filetype edit is not saved");
            Assert
              (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-ghost") = "",
               "ignored empty-list icon edit is not saved");
            Lookup :=
              Files.Settings.Lookup_Open_Action
                (Empty_Load.Settings,
                 "text/x-ghost",
                 Files.Types.No_Modifiers);
            Assert (not Lookup.Found, "ignored empty-list open-action edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
            Repair_Draft.Filetype_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Files.Model.Set_Settings_Field_Index (Empty_Model, 8);
            Files.Model.Remove_Settings_Entry (Empty_Model);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "misaligned filetype draft removal clears orphan key");
            Assert (Empty_Load.Success, "repaired misaligned filetype draft validates");
            Assert
              (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "orphan-ext") = "",
               "repaired misaligned filetype edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Icon_Values.Append (To_Unbounded_String ("orphan-icon"));
            Repair_Draft.Icon_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Files.Model.Set_Settings_Field_Index (Empty_Model, 11);
            Files.Model.Remove_Settings_Entry (Empty_Model);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "misaligned icon draft removal clears orphan value");
            Assert (Empty_Load.Success, "repaired misaligned icon draft validates");
            Assert
              (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-orphan") = "",
               "repaired misaligned icon edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/x-orphan"));
            Repair_Draft.Open_Action_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Files.Model.Set_Settings_Field_Index (Empty_Model, 13);
            Files.Model.Remove_Settings_Entry (Empty_Model);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "",
               "misaligned open-action draft removal clears orphan key");
            Assert (Empty_Load.Success, "repaired misaligned open-action draft validates");
            Lookup :=
              Files.Settings.Lookup_Open_Action
                (Empty_Load.Settings,
                 "text/x-orphan",
                 Files.Types.No_Modifiers);
            Assert (not Lookup.Found, "repaired misaligned open-action edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
            Repair_Draft.Filetype_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Assert
              (Natural (Files.Model.Settings_Draft_Of (Empty_Model).Filetype_Keys.Length) = 0,
               "begin settings edit drops orphan filetype rows");

            Files.Settings.Add_Extension_Mapping (Empty_Settings, "ada", "text/x-ada");
            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
            Repair_Draft.Filetype_Index := Natural (Repair_Draft.Filetype_Keys.Length);
            Repair_Draft.Filetype_Extension := To_Unbounded_String ("stale-ext");
            Repair_Draft.Filetype_Value := To_Unbounded_String ("text/x-stale");
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Files.Model.Set_Settings_Field_Index (Empty_Model, 8);
            Assert
              (Files.Model.Settings_Field_Text (Empty_Model) = "ada",
               "begin settings edit syncs stale filetype selection");
         end;
         --  Parse no longer injects the built-in mappings (the file is now
         --  authoritative), so seed this draft-editing test's mapping set from
         --  the defaults directly, keeping the same populated set it relies on.
         declare
            Defaults : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         begin
            Draft_Settings.Extension_Filetypes := Defaults.Extension_Filetypes;
            Draft_Settings.Icon_Mappings := Defaults.Icon_Mappings;
            Draft_Settings.Open_Actions := Defaults.Open_Actions;
         end;
         Files.Model.Toggle_Settings_Pane (Draft_Model);
         Controller_Result :=
           Files.Controller.Execute_Command
             (Files.Commands.Toggle_Settings_Pane_Command, Draft_Model, Draft_Settings);
         Assert
           (Files.Model.Focus (Draft_Model) = Files.Types.Focus_Settings_Input,
            "controller settings command opens editable settings focus");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Files.Types.Key_Right);
         Assert
           (Files.Model.Settings_Field_Text (Draft_Model) = "details",
            "settings scalar row cycles with cursor keys");
         Files.Controller.Replace_Focused_Text (Draft_Model, "details");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Files.Types.Key_Down);
         Files.Controller.Replace_Focused_Text (Draft_Model, "true");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 5);
         Files.Controller.Replace_Focused_Text (Draft_Model, "true");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 6);
         Files.Controller.Replace_Focused_Text (Draft_Model, "files-high-contrast");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 8);
         declare
            First_Extension : constant String := Files.Model.Settings_Field_Text (Draft_Model);
         begin
            Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Files.Types.Key_Page_Down);
            Assert
              (Controller_Result.Status = Files.Controller.Controller_Text_Updated,
               "settings mapping entry movement reports update");
            Assert
              (Files.Model.Settings_Field_Text (Draft_Model) /= First_Extension,
               "settings mapping rows cycle through existing entries");
         end;
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Files.Types.Key_N, Ctrl);
         Assert (Files.Model.Settings_Field_Text (Draft_Model) = "", "settings add creates a blank mapping entry");
         Files.Controller.Replace_Focused_Text (Draft_Model, "tmpdel");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 9);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-delete-me");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 9);
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Files.Types.Key_Delete, Ctrl);
         Assert
           (Files.Model.Settings_Field_Text (Draft_Model) /= "tmpdel",
            "settings remove deletes the selected mapping entry");
         Controller_Result := Files.Controller.Handle_Settings_Click (Draft_Model, Field => 8, Option => 100);
         Assert
           (Controller_Result.Status = Files.Controller.Controller_Command_Executed,
            "settings add button executes and saves");
         Files.Controller.Replace_Focused_Text (Draft_Model, "buttondel");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 10);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-button-delete");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 8);
         Controller_Result := Files.Controller.Handle_Settings_Click (Draft_Model, Field => 8, Option => 101);
         Assert
           (Controller_Result.Status = Files.Controller.Controller_Command_Executed,
            "settings remove button executes and saves");
         Assert
           (Files.Model.Settings_Field_Text (Draft_Model) /= "buttondel",
            "settings remove button deletes the selected mapping entry");
         Controller_Result := Files.Controller.Handle_Settings_Click (Draft_Model, Field => 9, Option => 101);
         Assert
           (Controller_Result.Status = Files.Controller.Controller_Ignored,
            "settings value-field remove button is ignored");
         Files.Controller.Replace_Focused_Text (Draft_Model, "cfg");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 9);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 10);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 11);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 12);
         Controller_Result := Files.Controller.Handle_Settings_Click (Draft_Model, Field => 12, Option => 100);
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/markdown");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 13);
         Files.Controller.Replace_Focused_Text (Draft_Model, "reader {path}");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 1);
         Files.Controller.Replace_Focused_Text (Draft_Model, "bad-view");
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Assert
           (Controller_Result.Operation.Status = Files.Operations.Operation_Failed,
            "controller rejects invalid settings draft");
         Assert
           (To_String (Controller_Result.Operation.Error_Key) = "error.settings.invalid_view_mode",
            "controller invalid settings save reports validation error");
         Assert
           (To_String (Controller_Result.Operation.Path) = Draft_Path,
            "controller invalid settings save reports settings path");
         Files.Controller.Replace_Focused_Text (Draft_Model, "details");
         Files.Model.Set_Settings_Field_Index (Draft_Model, 12);
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Join (Root, "settings-dir"));
         Assert
           (Controller_Result.Operation.Status = Files.Operations.Operation_Failed,
            "controller settings save rejects directory path");
         Assert
           (To_String (Controller_Result.Operation.Error_Key) = "error.settings.not_file",
            "controller settings save directory failure reports not-file diagnostic");
         Assert
           (Draft_Settings.Default_View = Loaded.Settings.Default_View,
            "controller settings save failure preserves live settings");
         Assert
           (Files.Model.Settings_Field_Text (Draft_Model) = "text/markdown",
            "controller settings save failure preserves editable draft");
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Assert
           (Controller_Result.Operation.Status = Files.Operations.Operation_Success,
            "controller saves edited settings draft");
         Assert (Draft_Settings.Default_View = Files.Types.Details, "controller save updates live settings");
         Assert (Draft_Settings.High_Contrast_Theme, "controller save updates live high-contrast setting");
         Assert
           (To_String (Draft_Settings.Icon_Theme_Name) = "files-high-contrast",
            "controller save updates live icon theme");
         Assert
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "cfg") = "text/x-config",
            "controller save updates live filetype mappings");
         Assert
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "txt") = "text/plain",
            "controller save preserves other filetype mappings");
         Assert
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "tmpdel") = "",
            "controller save omits removed filetype mappings");
         Assert
           (Files.Settings.Icon_For_Filetype (Draft_Settings, "text/x-config") = "text",
            "controller save updates live icon mappings");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Settings,
              "text/markdown",
              Files.Types.No_Modifiers);
         Assert (Lookup.Found, "controller save updates live open-action settings");
         Draft_Load := Files.Settings.Load_File (Draft_Path);
         Assert (Draft_Load.Success, "controller-saved settings file reloads");
         Assert (Draft_Load.Settings.Show_Hidden_Files, "controller save persists edited hidden-file flag");
         declare
            Missing_Current_Path : constant String := Join (Root, "settings-save-missing-current");
            Missing_Model        : Files.Model.Window_Model;
            Missing_Settings     : Files.Settings.Settings_Model := Draft_Settings;
            Missing_Items        : Files.File_System.Item_Vectors.Vector;
            Missing_Result       : Files.Controller.Controller_Result;
         begin
            Ada.Directories.Create_Path (Missing_Current_Path);
            Files.Model.Initialize
              (Missing_Model,
               Directory_Path    => Missing_Current_Path,
               Items             => Missing_Items,
               Home_Path         => "/home/test",
               Default_View_Mode => Files.Types.Small_Icons);
            Missing_Result :=
              Files.Controller.Execute_Command
                (Files.Commands.Toggle_Settings_Pane_Command, Missing_Model, Missing_Settings);
            Assert
              (Missing_Result.Status = Files.Controller.Controller_Command_Executed,
               "missing-current save fixture executes settings command");
            Assert
              (Files.Model.Settings_Pane_Is_Open (Missing_Model),
               "missing-current save fixture opens settings pane");
            Ada.Directories.Delete_Directory (Missing_Current_Path);
            Missing_Result := Files.Controller.Save_Settings (Missing_Model, Missing_Settings, Draft_Path);
            Assert
              (Missing_Result.Operation.Status = Files.Operations.Operation_Failed,
               "controller settings save reports post-save refresh failure");
            Assert
              (To_String (Missing_Result.Operation.Error_Key) /= "",
               "controller settings save keeps refresh failure diagnostic");
            Assert
              (Files.Model.Last_Error_Key (Missing_Model) = To_String (Missing_Result.Operation.Error_Key),
               "controller settings save leaves refresh failure visible");
         end;
      end;
      Write_File (Ensured_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings accepts existing regular file");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Assert (Loaded.Settings.Default_View = Files.Types.Details, "ensure default settings does not overwrite");
      Ensured := Files.Settings.Ensure_Default_File (Join (Root, "settings-dir"));
      Assert (not Ensured.Success, "ensure default settings rejects directory path");
      Assert
        (To_String (Ensured.Error_Key) = "error.settings.not_file",
         "ensure default settings reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File (Blocked_Path);
      Assert (not Ensured.Success, "ensure default settings rejects a file used as parent directory");
      Assert
        (To_String (Ensured.Path) = Blocked_Path,
         "ensure default settings parent failure reports requested settings path");
      Assert
        (To_String (Ensured.Error_Key) = "error.settings.not_file",
         "ensure default settings parent failure reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File ("");
      Assert (not Ensured.Success, "ensure default settings rejects empty settings path");
      Assert
        (To_String (Ensured.Error_Key) = "error.settings.save",
         "ensure default settings empty path reports save diagnostic");
   end Test_Settings_Load_File;

   procedure Test_Settings_Invalid_Boolean (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bad_Path : constant String := Join (Root, "bad.conf");
      Bad      : Files.Settings.Settings_Parse_Result;
      Bad_Open : Files.Settings.Settings_Parse_Result;
      Bad_Tail : Files.Settings.Settings_Parse_Result;

      procedure Assert_Parse_Error
        (Text      : String;
         Error_Key : String;
         Message   : String)
      is
         Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
      begin
         Assert (not Parsed.Success, Message);
         Assert
           (To_String (Parsed.Error_Key) = Error_Key,
            Message & " diagnostic key");
      end Assert_Parse_Error;
   begin
      Reset_Root;
      Write_File
        (Bad_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = maybe" & ASCII.LF);
      Bad := Files.Settings.Load_File (Bad_Path);
      Assert (not Bad.Success, "invalid boolean setting is rejected");
      Assert
        (To_String (Bad.Error_Key) = "error.settings.invalid_boolean",
         "invalid boolean reports a deterministic diagnostic key");

      Bad_Open :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""unterminated" & ASCII.LF);
      Assert (not Bad_Open.Success, "unterminated quoted open action is rejected");
      Assert
        (To_String (Bad_Open.Error_Key) = "error.settings.invalid_open_action",
         "unterminated quoted open action reports deterministic diagnostic key");

      Bad_Tail :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""editor""junk {path}" & ASCII.LF);
      Assert (not Bad_Tail.Success, "quoted open action rejects trailing junk");
      Assert
        (To_String (Bad_Tail.Error_Key) = "error.settings.invalid_open_action",
         "quoted open action trailing junk reports deterministic diagnostic key");

      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = edit""or {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unquoted open-action executable quote is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor ar""g" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unquoted open-action argument quote is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain =" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open action executable is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         " = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open action key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         """text/quoted-action"" = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "quoted open-action filetype key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "[text/bracketed-action] = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "bracketed open-action filetype key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "+control = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "modifier-only open action key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+custom = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unknown open-action modifier is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+ = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "dangling open-action modifier separator is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+control+ = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "trailing open-action modifier separator is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain++control = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open-action modifier segment is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor prefix-{path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "embedded open-action placeholders are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action executable placeholders are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = edit" & ASCII.VT & "or {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action executable vertical tabs are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor arg" & ASCII.FF & "value" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action argument form feeds are rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         " = text/plain" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty filetype extension mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt =" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty filetype value mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt = ""unterminated" & ASCII.LF,
         "error.settings.invalid_mapping",
         "unterminated quoted filetype mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt = ""text/plain""junk" & ASCII.LF,
         "error.settings.invalid_mapping",
         "quoted filetype mapping with trailing junk is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain =" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty icon mapping value is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         " = text" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty icon mapping key is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain = ""unterminated" & ASCII.LF,
         "error.settings.invalid_mapping",
         "unterminated quoted icon mapping is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain = ""text""junk" & ASCII.LF,
         "error.settings.invalid_mapping",
         "quoted icon mapping with trailing junk is rejected");
      Assert_Parse_Error
        ("[unknown]" & ASCII.LF,
         "error.settings.unknown_section",
         "unknown settings section is rejected");
      Assert_Parse_Error
        ("[]" & ASCII.LF,
         "error.settings.unknown_section",
         "empty settings section name is rejected");
      Assert_Parse_Error
        ("[settings" & ASCII.LF,
         "error.settings.expected_equals",
         "unterminated settings section header is rejected");
      Assert_Parse_Error
        ("orphan = value" & ASCII.LF,
         "error.settings.missing_section",
         "settings entry before section is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "default_view_mode details" & ASCII.LF,
         "error.settings.expected_equals",
         "settings entry without equals is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "default_view_mode = tiled" & ASCII.LF,
         "error.settings.invalid_view_mode",
         "invalid view mode is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "unknown_key = true" & ASCII.LF,
         "error.settings.unknown_key",
         "unknown settings key is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_directories_first = false" & ASCII.LF,
         "error.settings.unknown_key",
         "removed sort-directories setting is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_field = random" & ASCII.LF,
         "error.settings.invalid_sort_field",
         "invalid sort field is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_ascending = maybe" & ASCII.LF,
         "error.settings.invalid_boolean",
         "invalid sort direction boolean is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "icon_theme = neon" & ASCII.LF,
         "error.settings.invalid_icon_theme",
         "invalid icon theme is rejected");
   end Test_Settings_Invalid_Boolean;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Settings_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Settings;

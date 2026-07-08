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
with Files.Settings_Form;
with Guikit.Settings_Panel;
with Guikit.Input;
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
   use type Files.Settings.Theme_Choice;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
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
   procedure Test_Detail_Columns_And_Grouping (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Order_Reorder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class);
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Columns_And_Grouping'Access, "detail column customization and grouping round-trip");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Column_Order_Reorder'Access, "detail column order move helper, round-trip, and validation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Color_Labels'Access, "color label set/clear, round-trip, and invalid-color skip");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Items'Access, "recent items note/dedup/cap/clear and round-trip");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Form_Mapping_Navigation'Access,
         "settings-form maps a draft to typed fields and pages/edits mapping entries");
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
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
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
      Assert
        (Parsed.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high_contrast_theme key maps to the high-contrast theme");
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

      Modifiers (Guikit.Input.Control_Key) := True;
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

      Modifiers := Guikit.Input.No_Modifiers;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix open action is found");
      Assert
        (To_String (Lookup.Token) = "application/ld+json",
         "structured-suffix filetype token keeps plus suffix");
      Assert
        (To_String (Lookup.Action.Executable) = "json-viewer",
         "structured-suffix open action executable parses");
      Modifiers (Guikit.Input.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix modifier-specific open action is found");
      Assert
        (To_String (Lookup.Token) = "application/ld+json+control",
         "structured-suffix modifier token appends after filetype suffix");
      Assert
        (To_String (Lookup.Action.Executable) = "json-editor",
         "structured-suffix modifier-specific executable parses");

      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/full", Guikit.Input.No_Modifiers);
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
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "unknown placeholder open action parses");
      Assert
        (not Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action),
         "unknown placeholder open action is not unsafe");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Assert
        (To_String (Expanded.Arguments.Element (1)) = "{unknown}",
         "unknown placeholder remains literal after expansion");

      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "missing modifier action falls back to unmodified filetype");
      Assert (To_String (Lookup.Token) = "text/x-ada", "fallback token is unmodified filetype");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "fallback open action lookup trims filetype");
      Assert (To_String (Lookup.Token) = "text/x-ada", "trimmed fallback token is unmodified filetype");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quoted",
         Guikit.Input.No_Modifiers);
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
         Guikit.Input.No_Modifiers);
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
         Guikit.Input.No_Modifiers);
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
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "empty quoted argument open action is found");
      Assert (Natural (Lookup.Action.Arguments.Length) = 2, "empty quoted argument does not end parsing");
      Assert (To_String (Lookup.Action.Arguments.Element (1)) = "", "empty quoted argument is preserved");
      Assert
        (To_String (Lookup.Action.Arguments.Element (2)) = "after-empty",
         "argument after empty quoted argument is preserved");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell",
         Guikit.Input.No_Modifiers);
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
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "uppercase shell open action is found");
      Assert (Lookup.Action.Use_Shell, "uppercase shell prefix is normalized");
      Assert (To_String (Lookup.Action.Executable) = "upper-runner", "uppercase shell executable parses");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "unmodified non-shell open action is found");
      Assert (not Lookup.Action.Use_Shell, "shell execution is opt-in through explicit prefix");
      declare
         Serialized : constant String := Files.Settings.To_Text (Parsed.Settings);
         Reloaded   : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Serialized);
      begin
         Assert (Reloaded.Success, "serialized settings text parses");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quoted", Guikit.Input.No_Modifiers);
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
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/equals", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized equals-containing action reloads");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "--flag=value",
            "serialized open action preserves equals argument");
         Assert
           (To_String (Lookup.Action.Arguments.Element (2)) = "arg=two words",
            "serialized open action preserves quoted equals argument");
         Lookup :=
           Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quote-char", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized quote-containing action reloads");
         Assert
           (To_String (Lookup.Action.Executable) = "quote""runner",
            "serialized open action preserves executable quote");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "arg "" inner",
            "serialized open action preserves argument quote");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Reloaded.Settings, "text/empty-arg", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized empty-argument action reloads");
         Assert
           (To_String (Lookup.Action.Arguments.Element (1)) = "",
            "serialized open action preserves empty argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/shell", Guikit.Input.No_Modifiers);
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

      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
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
              [Guikit.Input.Control_Key | Guikit.Input.Alt_Key => True, others => False]);
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
              [Guikit.Input.Control_Key => True, others => False]);
         Assert (Lookup.Found, "draft structured-suffix modifier action lookup succeeds");
         Assert
           (To_String (Lookup.Token) = "application/ld+json+control",
            "draft structured-suffix modifier action token is normalized");
         Assert
           (To_String (Lookup.Action.Executable) = "json-editor",
            "draft structured-suffix modifier action executable parses");
      end;

      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing open action is represented as lookup data");
      Assert
        (To_String (Lookup.Token) = "text/missing+shift+meta",
         "missing open action records normalized attempted token");
      Assert
        (To_String (Lookup.Error_Key) = "error.open_action.missing",
         "missing open action reports deterministic diagnostic key");
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
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
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Modifiers (Guikit.Input.Control_Key) := True;
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
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
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
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores dangling modifier separator");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+control+",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/bad-direct",
         [Guikit.Input.Control_Key => True, others => False]);
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
         [Guikit.Input.Control_Key => True, Guikit.Input.Alt_Key => True, others => False]);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores empty modifier segments");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+custom",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unknown modifiers");
      Files.Settings.Add_Open_Action
        (Manual,
         "image/svg+xml",
         Files.Settings.Make_Action ("svg-viewer", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "image/svg+xml", Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "direct open-action insertion accepts structured filetype suffixes");
      Assert
        (To_String (Lookup.Token) = "image/svg+xml",
         "direct structured filetype suffix lookup keeps plus suffix");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad=direct",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad=direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unrepresentable filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         """text/quoted-direct""",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, """text/quoted-direct""", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores quoted filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         "[text/bracketed-direct]",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "[text/bracketed-direct]", Guikit.Input.No_Modifiers);
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
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/empty-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores empty executable");
      declare
         Unsafe_Args : Files.Types.String_Vectors.Vector;
      begin
         Unsafe_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/unsafe-argument",
            Files.Settings.Make_Action ("unsafe", Unsafe_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-argument", Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores embedded placeholders");
      end;
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unsafe-executable",
         Files.Settings.Make_Action ("{path}", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable placeholders");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/linebreak-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.LF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/formfeed-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.FF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/formfeed-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable form feeds");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/c1break-executable",
         Files.Settings.Make_Action ("viewer" & C1_Break & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable C1 line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Files.Settings.Make_Action ("viewer" & Line_Separator & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Guikit.Input.No_Modifiers);
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
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-argument", Guikit.Input.No_Modifiers);
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
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/vtab-argument", Guikit.Input.No_Modifiers);
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
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-argument", Guikit.Input.No_Modifiers);
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
            Guikit.Input.No_Modifiers);
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
      Assert (Files.Settings.Field_Diagnostic (5, "light") = "", "settings field validates theme value");
      Assert
        (Files.Settings.Field_Diagnostic (5, "sepia") = "error.settings.invalid_theme",
         "settings field reports invalid theme");
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
            With_Favorites : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Round          : Files.Settings.Settings_Parse_Result;
            Found_Eq       : Boolean := False;
            Found_Hash     : Boolean := False;
            Found_File     : Boolean := False;
         begin
            With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("/data/a=b"));
            With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("#hashdir"));
            --  Favorites may reference files as well as folders; the path is
            --  stored verbatim and must survive the round-trip either way.
            With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("/data/report.txt"));
            Round := Files.Settings.Parse (Files.Settings.To_Text (With_Favorites));
            Assert (Round.Success, "settings with tricky favorite paths round-trips");
            for P of Round.Settings.Favorite_Paths loop
               if To_String (P) = "/data/a=b" then
                  Found_Eq := True;
               elsif To_String (P) = "#hashdir" then
                  Found_Hash := True;
               elsif To_String (P) = "/data/report.txt" then
                  Found_File := True;
               end if;
            end loop;
            Assert (Found_Eq, "a favorite path containing '=' survives the round-trip");
            Assert (Found_Hash, "a favorite path starting with '#' survives the round-trip");
            Assert (Found_File, "a favorite path pointing at a file survives the round-trip");
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
        (Default_Parse.Settings.Theme = Files.Settings.Theme_Dark,
         "default settings text keeps the dark theme selected");
      Assert
        (To_String (Default_Parse.Settings.Icon_Theme_Name) = "files-basic",
         "default settings text keeps basic icon theme selected");
      declare
         --  The theme preference is absent from this text, so it must default to
         --  dark; a round-trip through To_Text must preserve every enum value.
         Absent_Parse : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "show_hidden_files = true" & ASCII.LF);
         Light_On     : Files.Settings.Settings_Model;
         High_On      : Files.Settings.Settings_Model;
         Round_Trip   : Files.Settings.Settings_Parse_Result;
      begin
         Assert (Absent_Parse.Success, "settings without a theme key parse");
         Assert
           (Absent_Parse.Settings.Theme = Files.Settings.Theme_Dark,
            "absent theme setting defaults to dark");
         Light_On := Files.Settings.Default_Settings;
         Light_On.Theme := Files.Settings.Theme_Light;
         Round_Trip := Files.Settings.Parse (Files.Settings.To_Text (Light_On));
         Assert (Round_Trip.Success, "serialized light-theme settings parse");
         Assert
           (Round_Trip.Settings.Theme = Files.Settings.Theme_Light,
            "the light theme round-trips through To_Text and Parse");
         High_On := Files.Settings.Default_Settings;
         High_On.Theme := Files.Settings.Theme_High_Contrast;
         Round_Trip := Files.Settings.Parse (Files.Settings.To_Text (High_On));
         Assert (Round_Trip.Success, "serialized high-contrast settings parse");
         Assert
           (Round_Trip.Settings.Theme = Files.Settings.Theme_High_Contrast,
            "the high-contrast theme round-trips through To_Text and Parse");
      end;
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
         "light_theme = true" & ASCII.LF &
         "[filetypes]" & ASCII.LF &
         "foo = application/x-foo" & ASCII.LF);
      --  Both legacy booleans set: high contrast wins over light (old precedence).
      Loaded := Files.Settings.Load_File (Settings_Path);
      Assert (Loaded.Success, "settings file parses from disk");
      Assert (Loaded.Settings.Show_Hidden_Files, "show-hidden setting loads from disk");
      Assert (Loaded.Settings.Sort_Field_Value = Files.Settings.Sort_By_Modified, "sort field loads from disk");
      Assert (not Loaded.Settings.Sort_Ascending, "sort direction loads from disk");
      Assert
        (Loaded.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high-contrast key wins over light and loads from disk");
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
         Ctrl : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Ctrl (Guikit.Input.Control_Key) := True;
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
         Draft.Theme := To_Unbounded_String ("high_contrast");
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
         Assert
           (Draft_Load.Settings.Theme = Files.Settings.Theme_High_Contrast,
            "draft applies the high-contrast theme");
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
              [Guikit.Input.Alt_Key => True, others => False]);
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
              [Guikit.Input.Alt_Key => True, others => False]);
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
                 Guikit.Input.No_Modifiers);
            Assert (not Lookup.Found, "ignored empty-list open-action edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
            Repair_Draft.Filetype_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert (Empty_Load.Success, "repaired misaligned filetype draft validates");
            Assert
              (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "orphan-ext") = "",
               "repaired misaligned filetype edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Icon_Values.Append (To_Unbounded_String ("orphan-icon"));
            Repair_Draft.Icon_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert (Empty_Load.Success, "repaired misaligned icon draft validates");
            Assert
              (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-orphan") = "",
               "repaired misaligned icon edit is not saved");

            Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
            Repair_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/x-orphan"));
            Repair_Draft.Open_Action_Index := 1;
            Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
            Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
            Assert (Empty_Load.Success, "repaired misaligned open-action draft validates");
            Lookup :=
              Files.Settings.Lookup_Open_Action
                (Empty_Load.Settings,
                 "text/x-orphan",
                 Guikit.Input.No_Modifiers);
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
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Right);
         Files.Controller.Replace_Focused_Text (Draft_Model, "details");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Down);
         Files.Controller.Replace_Focused_Text (Draft_Model, "true");
         Files.Controller.Replace_Focused_Text (Draft_Model, "high_contrast");
         Files.Controller.Replace_Focused_Text (Draft_Model, "files-high-contrast");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_N, Ctrl);
         Files.Controller.Replace_Focused_Text (Draft_Model, "tmpdel");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-delete-me");
         Controller_Result :=
           Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Delete, Ctrl);
         Files.Controller.Replace_Focused_Text (Draft_Model, "cfg");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/markdown");
         Files.Controller.Replace_Focused_Text (Draft_Model, "reader {path}");
         declare
            Bad : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Draft_Model);
         begin
            Bad.Default_View_Mode := To_Unbounded_String ("bad-view");
            Files.Model.Set_Settings_Draft (Draft_Model, Bad);
         end;
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
         declare
            Good : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Draft_Model);
         begin
            Good.Default_View_Mode := To_Unbounded_String ("details");
            Good.Theme := To_Unbounded_String ("high_contrast");
            Good.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
            Good.Show_Hidden_Files := To_Unbounded_String ("true");
            Good.Filetype_Keys.Clear;
            Good.Filetype_Values.Clear;
            Good.Filetype_Keys.Append (To_Unbounded_String ("cfg"));
            Good.Filetype_Values.Append (To_Unbounded_String ("text/x-config"));
            Good.Filetype_Keys.Append (To_Unbounded_String ("txt"));
            Good.Filetype_Values.Append (To_Unbounded_String ("text/plain"));
            Good.Icon_Keys.Clear;
            Good.Icon_Values.Clear;
            Good.Icon_Keys.Append (To_Unbounded_String ("text/x-config"));
            Good.Icon_Values.Append (To_Unbounded_String ("text"));
            Good.Open_Action_Keys.Clear;
            Good.Open_Action_Commands.Clear;
            Good.Open_Action_Keys.Append (To_Unbounded_String ("text/markdown"));
            Good.Open_Action_Commands.Append (To_Unbounded_String ("reader {path}"));
            Files.Model.Set_Settings_Draft (Draft_Model, Good);
         end;
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
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Assert
           (Controller_Result.Operation.Status = Files.Operations.Operation_Success,
            "controller saves edited settings draft");
         Assert (Draft_Settings.Default_View = Files.Types.Details, "controller save updates live settings");
         Assert
           (Draft_Settings.Theme = Files.Settings.Theme_High_Contrast,
            "controller save updates the live theme setting");
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
              Guikit.Input.No_Modifiers);
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

   procedure Test_Detail_Columns_And_Grouping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Group_Mode;
      Base : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  Defaults: name/modified/size/type visible, created/permissions hidden.
      Assert (Base.Column_Visible (Files.Types.Name_Column), "name column shown by default");
      Assert (Base.Column_Visible (Files.Types.Size_Column), "size column shown by default");
      Assert (not Base.Column_Visible (Files.Types.Permissions_Column),
              "permissions column hidden by default");
      Assert (Base.Group_By = Files.Types.No_Grouping, "grouping is off by default");

      --  Toggle helpers: name is never toggleable, others flip.
      declare
         Toggled : constant Files.Settings.Settings_Model :=
           Files.Settings.Toggle_Column (Base, Files.Types.Permissions_Column);
         Name_Fixed : constant Files.Settings.Settings_Model :=
           Files.Settings.Toggle_Column (Base, Files.Types.Name_Column);
      begin
         Assert (Toggled.Column_Visible (Files.Types.Permissions_Column),
                 "toggling permissions makes it visible");
         Assert (Name_Fixed.Column_Visible (Files.Types.Name_Column),
                 "toggling the name column leaves it visible");
      end;

      --  Width clamp: below the minimum is raised, zero clears the override.
      declare
         Narrow : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Base, Files.Types.Size_Column, 5);
         Wide   : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Base, Files.Types.Size_Column, 200);
         Reset  : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Wide, Files.Types.Size_Column, 0);
      begin
         Assert (Narrow.Column_Widths (Files.Types.Size_Column)
                   = Files.Types.Minimum_Detail_Column_Width,
                 "sub-minimum width is clamped up to the minimum");
         Assert (Wide.Column_Widths (Files.Types.Size_Column) = 200,
                 "an explicit width is retained");
         Assert (Reset.Column_Widths (Files.Types.Size_Column) = 0,
                 "a zero width clears the customization");
      end;

      --  Group cycle wraps back to No_Grouping after the last band.
      declare
         G1 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (Base);
         G2 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G1);
         G3 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G2);
         G4 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G3);
         G5 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G4);
      begin
         Assert (G1.Group_By = Files.Types.Group_By_Type, "first cycle selects type grouping");
         Assert (G2.Group_By = Files.Types.Group_By_Modified, "second cycle selects date grouping");
         Assert (G3.Group_By = Files.Types.Group_By_Size, "third cycle selects size grouping");
         Assert (G4.Group_By = Files.Types.Group_By_Label, "fourth cycle selects label grouping");
         Assert (G5.Group_By = Files.Types.No_Grouping, "grouping cycles back to none");
      end;

      --  Full round-trip through the settings text format.
      declare
         Source : Files.Settings.Settings_Model := Base;
      begin
         Source := Files.Settings.Toggle_Column (Source, Files.Types.Size_Column);
         Source := Files.Settings.Toggle_Column (Source, Files.Types.Created_Column);
         Source := Files.Settings.With_Column_Width (Source, Files.Types.Modified_Column, 175);
         Source := Files.Settings.Cycle_Group_By (Source);
         Source := Files.Settings.Cycle_Group_By (Source);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "customized column settings text parses");
            Assert (not Reloaded.Settings.Column_Visible (Files.Types.Size_Column),
                    "hidden size column round-trips");
            Assert (Reloaded.Settings.Column_Visible (Files.Types.Created_Column),
                    "enabled created column round-trips");
            Assert (Reloaded.Settings.Column_Widths (Files.Types.Modified_Column) = 175,
                    "custom modified width round-trips");
            Assert (Reloaded.Settings.Group_By = Files.Types.Group_By_Modified,
                    "grouping mode round-trips");
         end;
      end;

      --  An invalid grouping mode is diagnosed.
      declare
         Bad : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "group_by = weekly" & ASCII.LF);
      begin
         Assert (not Bad.Success, "an unknown grouping mode fails to parse");
         Assert (To_String (Bad.Error_Key) = "error.settings.invalid_group",
                 "the grouping diagnostic key is reported");
      end;
   end Test_Detail_Columns_And_Grouping;

   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      use type Files.Types.Group_Mode;
      File_Path   : constant String := "/home/user/report.txt";
      Folder_Path : constant String := "/home/user/projects";
      Base        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  A fresh model carries no labels.
      Assert (Files.Settings.Label_Of (Base, File_Path) = Files.Types.No_Label,
              "an unlabeled path reports No_Label");

      --  Set and replace a label on a file path.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Red);
      Assert (Files.Settings.Label_Of (Base, File_Path) = Files.Types.Red,
              "a set label is reported back");
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Blue);
      Assert (Files.Settings.Label_Of (Base, File_Path) = Files.Types.Blue,
              "re-labeling replaces the previous color");

      --  Label a folder path too.
      Files.Settings.Set_Label (Base, Folder_Path, Files.Types.Green);
      Assert (Files.Settings.Label_Of (Base, Folder_Path) = Files.Types.Green,
              "a folder path can carry a label");

      --  No_Label clears the entry.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.No_Label);
      Assert (Files.Settings.Label_Of (Base, File_Path) = Files.Types.No_Label,
              "No_Label clears a stored label");
      Assert (Files.Settings.Label_Of (Base, Folder_Path) = Files.Types.Green,
              "clearing one path leaves the other labeled");

      --  Full round-trip through the settings text format for file and folder.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Settings.Set_Label (Source, File_Path, Files.Types.Purple);
         Files.Settings.Set_Label (Source, Folder_Path, Files.Types.Gray);
         Source.Group_By := Files.Types.Group_By_Label;
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "labeled settings text parses");
            Assert (Files.Settings.Label_Of (Reloaded.Settings, File_Path) = Files.Types.Purple,
                    "a file path's label round-trips");
            Assert (Files.Settings.Label_Of (Reloaded.Settings, Folder_Path) = Files.Types.Gray,
                    "a folder path's label round-trips");
            Assert (Reloaded.Settings.Group_By = Files.Types.Group_By_Label,
                    "label grouping mode round-trips");
         end;
      end;

      --  An unknown color in the file is skipped rather than failing the load.
      declare
         Text : constant String :=
           "[labels]" & ASCII.LF
           & "label = ""fuchsia|/home/user/bad.txt""" & ASCII.LF
           & "label = ""yellow|/home/user/good.txt""" & ASCII.LF;
         Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Text);
      begin
         Assert (Parsed.Success, "an unknown color does not fail the load");
         Assert (Files.Settings.Label_Of (Parsed.Settings, "/home/user/bad.txt") = Files.Types.No_Label,
                 "an entry with an unknown color is skipped");
         Assert (Files.Settings.Label_Of (Parsed.Settings, "/home/user/good.txt") = Files.Types.Yellow,
                 "a valid entry alongside an invalid one still loads");
      end;
   end Test_Color_Labels;

   procedure Test_Recent_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      File_Path   : constant String := "/home/user/report.txt";
      Folder_Path : constant String := "/home/user/projects";
      Base        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      function Nth (Settings : Files.Settings.Settings_Model; Index : Positive) return String is
         Paths : constant Files.Types.String_Vectors.Vector :=
           Files.Settings.Recent_Paths (Settings);
      begin
         if Index <= Natural (Paths.Length) then
            return To_String (Paths.Element (Index));
         end if;
         return "";
      end Nth;

      function Count (Settings : Files.Settings.Settings_Model) return Natural is
      begin
         return Natural (Files.Settings.Recent_Paths (Settings).Length);
      end Count;
   begin
      --  A fresh model has no recents; the empty path is ignored.
      Assert (Count (Base) = 0, "a fresh model has no recent items");
      Files.Settings.Note_Recent (Base, "");
      Assert (Count (Base) = 0, "the empty path is not recorded");

      --  Note records most-recent-first (a file and a folder both round in).
      Files.Settings.Note_Recent (Base, File_Path);
      Files.Settings.Note_Recent (Base, Folder_Path);
      Assert (Count (Base) = 2, "two distinct items are recorded");
      Assert (Nth (Base, 1) = Folder_Path, "the most recent item is at the front");
      Assert (Nth (Base, 2) = File_Path, "the earlier item follows");

      --  Re-noting an existing path moves it to the front and dedups.
      Files.Settings.Note_Recent (Base, File_Path);
      Assert (Count (Base) = 2, "re-noting an existing path does not grow the list");
      Assert (Nth (Base, 1) = File_Path, "a re-noted path moves to the front");
      Assert (Nth (Base, 2) = Folder_Path, "the previously-front path drops back");

      --  Clearing empties the list.
      Files.Settings.Clear_Recent (Base);
      Assert (Count (Base) = 0, "Clear_Recent empties the recent list");

      --  The list is capped at Max_Recent_Items, dropping the oldest entries.
      declare
         Capped : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         for I in 1 .. Files.Settings.Max_Recent_Items + 10 loop
            Files.Settings.Note_Recent
              (Capped, "/tmp/item" & Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Both));
         end loop;
         Assert (Count (Capped) = Files.Settings.Max_Recent_Items,
                 "the recent list is capped at Max_Recent_Items");
         Assert (Nth (Capped, 1) = "/tmp/item" &
                   Ada.Strings.Fixed.Trim
                     (Integer'Image (Files.Settings.Max_Recent_Items + 10), Ada.Strings.Both),
                 "the newest item is retained at the front");
         Assert (Nth (Capped, Files.Settings.Max_Recent_Items) = "/tmp/item11",
                 "the oldest surviving item sits at the cap boundary");
      end;

      --  Full round-trip through the settings text format preserves order, cap,
      --  and both file and folder paths.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Settings.Note_Recent (Source, File_Path);
         Files.Settings.Note_Recent (Source, Folder_Path);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "recent settings text parses");
            Assert (Count (Reloaded.Settings) = 2, "both recent paths round-trip");
            Assert (Nth (Reloaded.Settings, 1) = Folder_Path,
                    "recent order is preserved most-recent-first");
            Assert (Nth (Reloaded.Settings, 2) = File_Path,
                    "the earlier recent path round-trips in order");
         end;
      end;

      --  A hand-edited file above the cap loads only the first Max_Recent_Items.
      declare
         Body_Text : Unbounded_String := To_Unbounded_String ("[recent]" & ASCII.LF);
      begin
         for I in 1 .. Files.Settings.Max_Recent_Items + 5 loop
            Append
              (Body_Text,
               "recent = ""/tmp/over" &
               Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Both) & """" & ASCII.LF);
         end loop;
         declare
            Parsed : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (To_String (Body_Text));
         begin
            Assert (Parsed.Success, "an over-cap recent section still loads");
            Assert (Count (Parsed.Settings) = Files.Settings.Max_Recent_Items,
                    "loading enforces the recent cap");
         end;
      end;
   end Test_Recent_Items;

   --  Files.Settings_Form maps the draft to typed panel fields and applies the
   --  panel's emitted changes: paging (Prev/Next) moves the selected mapping
   --  entry without saving, Add/Remove edit the list and save, and the key
   --  field's label carries the "i/n" entry counter.
   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

      function Button (Value : String) return SP.Change is
        ((Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("settings.filetype.buttons"),
          Value => To_Unbounded_String (Value)));

      function Ext return String is
        (To_String (Files.Model.Settings_Draft_Of (Model).Filetype_Extension));

      function Count return Natural is
        (Natural (Files.Model.Settings_Draft_Of (Model).Filetype_Keys.Length));

      function Ext_Label return String is
         Fields : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
      begin
         for F of Fields loop
            if To_String (F.Key) = "settings.filetype_extension" then
               return To_String (F.Label);
            end if;
         end loop;
         return "";
      end Ext_Label;
   begin
      Draft.Filetype_Keys.Clear;
      Draft.Filetype_Values.Clear;
      Draft.Filetype_Keys.Append (To_Unbounded_String ("txt"));
      Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain"));
      Draft.Filetype_Keys.Append (To_Unbounded_String ("md"));
      Draft.Filetype_Values.Append (To_Unbounded_String ("text/markdown"));
      Draft.Filetype_Index := 1;
      Files.Model.Begin_Settings_Edit (Model, Draft);

      Assert (Ext = "txt", "the first mapping entry is selected");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(1/2)") > 0, "the key field label shows the entry counter");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Assert (not Saved, "paging to the next entry does not save");
      Assert (Ext = "md", "Next selects the second entry");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(2/2)") > 0, "the counter follows the selection");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Assert (Ext = "txt", "Next wraps to the first entry");
      Saved := Files.Settings_Form.Apply (Model, Button ("prev"));
      Assert (Ext = "md", "Prev wraps back to the last entry");

      Saved := Files.Settings_Form.Apply (Model, Button ("add"));
      Assert (Saved, "adding an entry saves");
      Assert (Count = 3, "Add appends a mapping entry");

      Saved := Files.Settings_Form.Apply (Model, Button ("remove"));
      Assert (Saved, "removing an entry saves");
      Assert (Count = 2, "Remove drops the mapping entry");
   end Test_Settings_Form_Mapping_Navigation;

   procedure Test_Column_Order_Reorder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Types.Detail_Column_Order;
      Default : constant Files.Types.Detail_Column_Order :=
        Files.Types.Default_Detail_Column_Order;

      function Is_Permutation (Order : Files.Types.Detail_Column_Order) return Boolean is
         Seen : array (Files.Types.Detail_Column) of Boolean := [others => False];
      begin
         for Slot in Order'Range loop
            if Seen (Order (Slot)) then
               return False;
            end if;
            Seen (Order (Slot)) := True;
         end loop;
         for Column in Files.Types.Detail_Column loop
            if not Seen (Column) then
               return False;
            end if;
         end loop;
         return True;
      end Is_Permutation;
   begin
      --  Move a column to a new slot: size (slot 3) before modified (slot 2).
      declare
         Moved : constant Files.Types.Detail_Column_Order :=
           Files.Types.Move_Column (Default, Files.Types.Size_Column, 2);
      begin
         Assert (Moved (2) = Files.Types.Size_Column, "the moved column lands in the target slot");
         Assert (Moved (3) = Files.Types.Modified_Column, "the displaced column shifts right by one");
         Assert (Moved (1) = Files.Types.Name_Column, "the name column stays pinned to the first slot");
         Assert (Is_Permutation (Moved), "a move preserves a valid permutation");
      end;

      --  Moving to the slot a column already occupies is a no-op.
      Assert
        (Files.Types.Move_Column (Default, Files.Types.Size_Column, 3) = Default,
         "moving a column to its current slot is a no-op");

      --  The mandatory name column never moves, and no move may displace it.
      Assert
        (Files.Types.Move_Column (Default, Files.Types.Name_Column, 4) = Default,
         "moving the name column is rejected");
      declare
         Clamped : constant Files.Types.Detail_Column_Order :=
           Files.Types.Move_Column (Default, Files.Types.Permissions_Column, 1);
      begin
         Assert (Clamped (1) = Files.Types.Name_Column, "a move into the first slot is clamped after name");
         Assert (Clamped (2) = Files.Types.Permissions_Column, "the clamped move lands in the second slot");
         Assert (Is_Permutation (Clamped), "a clamped move preserves a valid permutation");
      end;

      --  With_Column_Order threads Move_Column through the settings model.
      declare
         Base    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Updated : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Order (Base, Files.Types.Permissions_Column, 2);
      begin
         Assert (Updated.Column_Order (2) = Files.Types.Permissions_Column,
                 "With_Column_Order moves the column in the settings model");
      end;

      --  Full round-trip of a reordered permutation through the text format.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Source := Files.Settings.With_Column_Order (Source, Files.Types.Size_Column, 2);
         Source := Files.Settings.With_Column_Order (Source, Files.Types.Permissions_Column, 3);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "reordered column-order text parses");
            Assert (Reloaded.Settings.Column_Order = Source.Column_Order,
                    "the customized column order round-trips");
         end;
      end;

      --  A partial order (missing columns) is rejected and falls back to default.
      declare
         Partial : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF & "detail_column_order = name,size" & ASCII.LF);
      begin
         Assert (not Partial.Success, "a partial column order fails to parse");
         Assert (To_String (Partial.Error_Key) = "error.settings.invalid_column_order",
                 "the partial-order diagnostic key is reported");
         Assert (Partial.Settings.Column_Order = Default,
                 "a rejected column order falls back to the default order");
      end;

      --  A duplicated column is likewise rejected.
      declare
         Dup : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF
              & "detail_column_order = name,size,size,modified,created,permissions"
              & ASCII.LF);
      begin
         Assert (not Dup.Success, "a duplicated column order fails to parse");
         Assert (To_String (Dup.Error_Key) = "error.settings.invalid_column_order",
                 "the duplicate-order diagnostic key is reported");
      end;

      --  A full valid permutation (using the "type" alias) parses successfully.
      declare
         Aliased_Order : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF
              & "detail_column_order = name,type,size,modified,created,permissions"
              & ASCII.LF);
      begin
         Assert (Aliased_Order.Success, "a full permutation with the type alias parses");
         Assert (Aliased_Order.Settings.Column_Order (2) = Files.Types.Filetype_Column,
                 "the type alias resolves to the filetype column in the parsed order");
      end;
   end Test_Column_Order_Reorder;
end Files_Suite.Settings;

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
with Ada.Unchecked_Deallocation;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Hostkit.Host;
with Hostkit.Fs;
with Hostkit.Metadata;

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
   use type Hostkit.Host.Kind;
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

   procedure Test_Settings_Text_Scalar_Values (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_And_Icon_Mappings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Modifier_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Placeholder_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Embedded_Placeholders (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Fallback_And_Quoting (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Actions_Serialize_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Token_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Direct_Mapping_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Direct_Open_Action_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Direct_Open_Action_Rejects_Unsafe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Draft_Mapping_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Parser_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sort_Favorites_And_Mapping_Authority (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Default_Open_Action_Suits_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Default_Settings_Text_And_Themes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Load_File_Inputs (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Ensure_And_Save_Text (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Draft_Apply_And_Save (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Draft_Ignores_Orphan_Rows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Controller_Settings_Save (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ensure_Default_File_Existing_And_Invalid (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Invalid_Boolean (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Columns_And_Grouping (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Column_Order_Reorder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Overrides_Persist (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Editing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Numeric_Values (T : in out AUnit.Test_Cases.Test_Case'Class);
   overriding function Name (T : Settings_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files settings");
   end Name;

   overriding procedure Register_Tests (T : in out Settings_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Text_Scalar_Values'Access,
         "settings text parses scalar values case-insensitively; a duplicated key keeps its last value");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_And_Icon_Mappings'Access,
         "filetype and icon mappings parse, unescape, normalize lookups, and have built-in defaults");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Modifier_Lookup'Access,
         "open action lookup honours modifier tokens and structured-suffix filetypes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Placeholder_Expansion'Access,
         "open action placeholders expand for POSIX, Windows, UNC, relative, and edge-case paths");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Embedded_Placeholders'Access,
         "embedded and unknown placeholders stay literal, and embedded ones mark an action unsafe");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Fallback_And_Quoting'Access,
         "open action lookup falls back to the unmodified filetype; quoting, equals, empty and shell arguments parse");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Actions_Serialize_Round_Trip'Access,
         "serialized settings reload open actions and mappings, and quote an embedded icon-theme quote");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Token_Normalization'Access,
         "open action modifier tokens normalize; drafts replace normalized rows; missing lookups report diagnostics");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Direct_Mapping_Insertion'Access,
         "direct extension and icon mapping insertion trims, replaces, and ignores unrepresentable keys and values");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Direct_Open_Action_Insertion'Access,
         "direct open-action insertion normalizes modifier tokens and ignores malformed filetype tokens");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Direct_Open_Action_Rejects_Unsafe'Access,
         "direct open-action insertion ignores placeholders and control characters in executables and arguments");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Field_Diagnostics'Access,
         "settings field diagnostics validate scalar, theme, sort, and mapping fields");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Draft_Mapping_Validation'Access,
         "settings drafts keep quoted mapping values and reject malformed mapping and open-action rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Field_Diagnostics'Access,
         "open action field diagnostics validate tokens, commands, field range, and argument count");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Parser_Diagnostics'Access,
         "settings parser caps persistent entries and rejects malformed input with deterministic diagnostics");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sort_Favorites_And_Mapping_Authority'Access,
         "created sort field and tricky favorites round-trip; the file is authoritative for mappings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Default_Open_Action_Suits_The_Host'Access,
         "the seeded default open action names a program this host has");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Default_Settings_Text_And_Themes'Access,
         "default settings text parses, an absent theme defaults to dark, and every theme round-trips");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Load_File_Inputs'Access,
         "settings load file reads disk, follows a link to a regular file, and rejects bad paths and oversized input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Ensure_And_Save_Text'Access,
         "ensure default file creates it; save text is atomic, owner-only, link-safe, and rejects bad input");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Draft_Apply_And_Save'Access,
         "settings drafts reset, apply, save, and reject invalid values; a closed settings pane cannot save");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Draft_Ignores_Orphan_Rows'Access, "empty and misaligned mapping drafts save no orphan rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Controller_Settings_Save'Access,
         "the controller validates and saves an edited settings draft into live settings and reports refresh failure");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ensure_Default_File_Existing_And_Invalid'Access,
         "ensure default file keeps an existing file and rejects directory, blocked-parent, and empty paths");
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
        (T, Test_Shortcut_Overrides_Persist'Access,
         "shortcut overrides round-trip through settings text, including an explicit unbind");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Editing'Access,
         "the settings form emits a shortcut row per command; Apply rebinds, rejects conflicts, and unbinds");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Form_Mapping_Navigation'Access,
         "settings-form maps a draft to typed fields and pages/edits mapping entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Numeric_Values'Access,
         "numeric settings accept plain decimals only; window sizes and column widths are clamped");
   end Register_Tests;

   --  A settings text exercising every section the parsing and open-action
   --  tests read: quoting, escaped quotes, modifier tokens, and placeholders.
   function Open_Action_Settings_Text return String is
   begin
      return
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
   end Open_Action_Settings_Text;

   --  Line breaks beyond ASCII that settings keys and values must reject.
   C1_Break : constant Character := Character'Val (133);

   function Line_Separator return String is
     (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#)));

   --  The model the direct open-action insertion test starts from: the
   --  defaults with the host opener fallback disabled, plus the extension
   --  and icon rows the direct mapping test inserts (its rejected
   --  insertions leave no row, as that test asserts).
   function Settings_With_Direct_Mappings return Files.Settings.Settings_Model is
      Manual : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Manual.Use_System_Default_Opener := False;
      Files.Settings.Add_Extension_Mapping (Manual, ".TXT", "text/first");
      Files.Settings.Add_Extension_Mapping (Manual, " txt ", " text/second ");
      Files.Settings.Add_Icon_Mapping (Manual, " text/second ", " first-icon ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/second", " second-icon ");
      return Manual;
   end Settings_With_Direct_Mappings;

   --  Settings_With_Direct_Mappings plus the open actions the direct
   --  open-action insertion test inserts successfully.
   function Settings_With_Direct_Insertions return Files.Settings.Settings_Model is
      Manual : Files.Settings.Settings_Model := Settings_With_Direct_Mappings;
      Args   : Files.Types.String_Vectors.Vector;
   begin
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
      Files.Settings.Add_Open_Action
        (Manual,
         "image/svg+xml",
         Files.Settings.Make_Action ("svg-viewer", Args));
      return Manual;
   end Settings_With_Direct_Insertions;

   procedure Test_Settings_Text_Scalar_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
   begin
      Assert (Parsed.Success, "settings text parses");
      Files_Suite.Support.Assert_Equal (Parsed.Settings.Default_View, Files.Types.Details, "default view mode parses");
      Assert (Parsed.Settings.Show_Hidden_Files, "setting keys parse case-insensitively");
      Files_Suite.Support.Assert_Equal
        (Parsed.Settings.Sort_Field_Value,
         Files.Settings.Sort_By_Size,
         "sort field setting parses");
      Assert (not Parsed.Settings.Sort_Ascending, "sort direction setting parses");
      Assert
        (Parsed.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high_contrast_theme key maps to the high-contrast theme");
      Files_Suite.Support.Assert_Equal
        (To_String (Parsed.Settings.Icon_Theme_Name),
         "files-high-contrast",
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
         Files_Suite.Support.Assert_Equal
           (Duplicate_Settings.Settings.Default_View,
            Files.Types.Details,
            "duplicate default view setting uses the last value");
         Assert
           (Duplicate_Settings.Settings.Show_Hidden_Files,
            "duplicate hidden-file setting uses the last value");
         Files_Suite.Support.Assert_Equal
           (Duplicate_Settings.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Modified,
            "duplicate sort field setting uses the last value");
      end;
   end Test_Settings_Text_Scalar_Values;

   procedure Test_Filetype_And_Icon_Mappings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Manual : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, ".ada"),
         "text/x-ada",
         "extension mapping parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, " ADA "),
         "text/x-ada",
         "extension lookup normalizes whitespace and case");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "log"),
         "text/x-log",
         "quoted filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "quote"),
         "text/""quoted",
         "quote-containing filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "eq"),
         "text/with=equals",
         "equals-containing filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Normalize_Extension ("."),
         "",
         "single-dot extension normalizes to empty");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Normalize_Extension (". TXT "),
         "txt",
         "extension normalization trims after a leading dot");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "."),
         "",
         "empty normalized extension has no filetype mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "unknown"),
         "",
         "unknown extension has no filetype mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "pdf"),
         "application/pdf",
         "default settings map PDF files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "adb"),
         "text/x-ada",
         "default settings map Ada body files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "json"),
         "application/json",
         "default settings map JSON files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "xml"),
         "application/xml",
         "default settings map XML files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "zip"),
         "application/zip",
         "default settings map ZIP archives");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "tar.gz"),
         "application/gzip-tar",
         "default settings map compressed tar archives");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "docx"),
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "default settings map Word documents");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "xlsx"),
         "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         "default settings map spreadsheet documents");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "mp3"),
         "audio/mpeg",
         "default settings map MP3 audio");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "mp4"),
         "video/mp4",
         "default settings map MP4 video");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "inode/directory"),
         "folder",
         "default settings map directory icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "inode/symlink"),
         "link",
         "default settings map symlink icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-executable"),
         "executable",
         "default settings map executable icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/plain"),
         "text",
         "default settings map text icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/x-ada"),
         "ada",
         "default settings map Ada icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "image/png"),
         "image",
         "default settings map PNG icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-tar"),
         "unknown",
         "default settings map tar icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "audio/mpeg"),
         "unknown",
         "default settings map audio icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-ada"),
         "text",
         "icon mapping parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, " text/x-ada "),
         "text",
         "icon lookup normalizes whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-log"),
         "log-icon",
         "quoted icon mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-quote"),
         "quote""icon",
         "quoted icon mapping unescapes doubled quotes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-equals"),
         "icon=equals",
         "equals-containing icon mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "application/x-missing"),
         "",
         "unknown filetype has no icon mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "   "),
         "",
         "blank filetype has no icon mapping");
   end Test_Filetype_And_Icon_Mappings;

   procedure Test_Open_Action_Modifier_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Modifiers (Guikit.Input.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "modifier-specific open action is found");
      Files_Suite.Support.Assert_Equal (To_String (Lookup.Token), "text/x-ada+control", "modifier token is normalized");
      Files_Suite.Support.Assert_Equal (To_String (Lookup.Action.Executable), "editor", "action executable parses");
      Files_Suite.Support.Assert_Equal (Natural (Lookup.Action.Arguments.Length), 2, "action arguments parse");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "open action lookup normalizes filetype whitespace");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada+control",
         "whitespace-normalized lookup preserves modifier token");

      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada",
         "path placeholder expands as one argument");

      Modifiers := Guikit.Input.No_Modifiers;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "application/ld+json",
         "structured-suffix filetype token keeps plus suffix");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "json-viewer",
         "structured-suffix open action executable parses");
      Modifiers (Guikit.Input.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix modifier-specific open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "application/ld+json+control",
         "structured-suffix modifier token appends after filetype suffix");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "json-editor",
         "structured-suffix modifier-specific executable parses");
   end Test_Open_Action_Modifier_Lookup;

   procedure Test_Open_Action_Placeholder_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/full", Guikit.Input.No_Modifiers);
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/archive.tar.gz");
      Assert (Lookup.Found, "full placeholder action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "/tmp/example",
         "parent placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "archive.tar.gz",
         "name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "archive.tar",
         "stem placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "gz",
         "extension placeholder expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/.profile");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         ".profile",
         "dotfile name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         ".profile",
         "dotfile stem keeps leading-dot name");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "dotfile extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/name.");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "name.",
         "trailing-dot name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "name.",
         "trailing-dot stem keeps final separator");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "trailing-dot extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "",
         "empty path parent expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "",
         "empty path name expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "",
         "empty path stem expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "empty path extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "relative.txt");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         ".",
         "relative path parent expands to current directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "relative.txt",
         "relative path name expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "relative",
         "relative path stem expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "txt",
         "relative path extension expands");
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Expanded := Files.Settings.Expand_Placeholders
           (Lookup.Action, "/tmp/example/a\b.txt");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (1)),
            "/tmp/example",
            "a POSIX backslash filename keeps its real parent");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (2)), "a\b.txt",
            "a POSIX backslash remains part of name and stem placeholders (name)");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (3)), "a\b",
            "a POSIX backslash remains part of name and stem placeholders (stem)");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (4)), "txt",
            "a POSIX backslash remains part of name and stem placeholders (extension)");
      end if;
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "C:\tmp\dir.with.dots",
         "Windows path parent expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "Windows path name expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "main",
         "Windows path stem expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "adb",
         "Windows path extension expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "C:\",
         "Windows drive-root path parent keeps root separator");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "Windows drive-root path name expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\file");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "Windows placeholder extension ignores dotted directory names");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\folder\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "\\server\share\folder",
         "UNC placeholder parent expands without losing the share root");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "UNC placeholder name expands from the leaf");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "main",
         "UNC placeholder stem expands from the leaf");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "adb",
         "UNC placeholder extension expands from the leaf");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "\\server\share\",
         "UNC share-root parent preserves the share root");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "",
         "UNC share-root name expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/trailing/");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "/tmp/example",
         "trailing separator parent expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "trailing",
         "trailing separator name expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "trailing",
         "trailing separator stem expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "trailing separator extension expands to empty");
   end Test_Open_Action_Placeholder_Expansion;

   procedure Test_Embedded_Placeholders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      declare
         Embedded_Args   : Files.Types.String_Vectors.Vector;
         Embedded_Action : Files.Settings.Open_Action;
      begin
         Embedded_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Embedded_Args.Append (To_Unbounded_String ("{stem}.suffix"));
         Embedded_Action := Files.Settings.Make_Action ("inspect", Embedded_Args);
         Expanded := Files.Settings.Expand_Placeholders (Embedded_Action, "/tmp/example/main.ada");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (1)),
            "prefix-{path}",
            "embedded path placeholder remains literal");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (2)),
            "{stem}.suffix",
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
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "{unknown}",
         "unknown placeholder remains literal after expansion");
   end Test_Embedded_Placeholders;

   procedure Test_Open_Action_Fallback_And_Quoting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "missing modifier action falls back to unmodified filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada",
         "fallback token is unmodified filetype");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "fallback open action lookup trims filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada",
         "trimmed fallback token is unmodified filetype");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quoted",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "quoted open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "quoted editor",
         "quoted executable parses");
      Files_Suite.Support.Assert_Equal
        (Natural (Lookup.Action.Arguments.Length),
         2,
         "quoted arguments parse as separate values");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "--project file",
         "quoted argument preserves spaces");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada",
         "quoted placeholder expands as one argument");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada/");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada/",
         "path placeholder preserves trailing separator verbatim");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quote-char",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "quote-containing open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "quote""runner",
         "quoted executable preserves doubled quote");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "arg "" inner",
         "quoted argument preserves doubled quote");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/equals",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "equals-containing open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "--flag=value",
         "equals-containing action argument parses");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (2)),
         "arg=two words",
         "quoted equals-containing action argument parses");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/empty-arg",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "empty quoted argument open action is found");
      Files_Suite.Support.Assert_Equal
        (Natural (Lookup.Action.Arguments.Length),
         2,
         "empty quoted argument does not end parsing");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "",
         "empty quoted argument is preserved");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (2)),
         "after-empty",
         "argument after empty quoted argument is preserved");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "explicit shell open action is found");
      Assert (Lookup.Action.Use_Shell, "explicit shell prefix is preserved");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "shell runner",
         "shell executable can be quoted");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "{name}",
         "shell action arguments are still parsed as a vector");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/shell.txt");
      Assert (Expanded.Use_Shell, "placeholder expansion preserves explicit shell flag");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Executable),
         "shell runner",
         "placeholder expansion preserves executable");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "shell.txt",
         "shell action placeholder expands");
      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell-upper",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "uppercase shell open action is found");
      Assert (Lookup.Action.Use_Shell, "uppercase shell prefix is normalized");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "upper-runner",
         "uppercase shell executable parses");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "unmodified non-shell open action is found");
      Assert (not Lookup.Action.Use_Shell, "shell execution is opt-in through explicit prefix");
   end Test_Open_Action_Fallback_And_Quoting;

   procedure Test_Open_Actions_Serialize_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup : Files.Settings.Action_Lookup_Result;
   begin
      declare
         Serialized : constant String := Files.Settings.To_Text (Parsed.Settings);
         Reloaded   : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Serialized);
      begin
         Assert (Reloaded.Success, "serialized settings text parses");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quoted", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized quoted action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "quoted editor",
            "serialized quoted action preserves executable spaces");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "--project file",
            "serialized quoted action preserves spaced argument");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (2)),
            "{path}",
            "serialized quoted action preserves placeholder argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/equals", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized equals-containing action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "--flag=value",
            "serialized open action preserves equals argument");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (2)),
            "arg=two words",
            "serialized open action preserves quoted equals argument");
         Lookup :=
           Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quote-char", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized quote-containing action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "quote""runner",
            "serialized open action preserves executable quote");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "arg "" inner",
            "serialized open action preserves argument quote");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Reloaded.Settings, "text/empty-arg", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized empty-argument action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "",
            "serialized open action preserves empty argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/shell", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized shell action reloads");
         Assert (Lookup.Action.Use_Shell, "serialized shell action preserves shell opt-in");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "shell runner",
            "serialized shell action preserves quoted executable");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "quote"),
            "text/""quoted",
            "serialized filetype mapping preserves quote");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "eq"),
            "text/with=equals",
            "serialized filetype mapping preserves equals");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-quote"),
            "quote""icon",
            "serialized icon mapping preserves quote");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-equals"),
            "icon=equals",
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
   end Test_Open_Actions_Serialize_Round_Trip;

   procedure Test_Open_Action_Token_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
   begin
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/mixed", Modifiers);
      Assert (Lookup.Found, "settings modifier token is normalized on insertion");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/mixed+control+alt",
         "lookup token uses normalized modifier order");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "mixed",
         "normalized settings action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/spaced", Modifiers);
      Assert (Lookup.Found, "settings modifier token trims spaces around separators");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/spaced+control+alt",
         "spaced modifier token is normalized on lookup");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "spaced",
         "spaced modifier action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/duplicate", Modifiers);
      Assert (Lookup.Found, "duplicate settings modifiers are normalized on insertion");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/duplicate+control+alt",
         "duplicate modifier token is deduplicated and ordered");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "duplicate",
         "deduplicated settings action is returned");

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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Normalized_Load.Settings, "txt"),
            "text/x-overridden",
            "normalized draft extension replaces existing row");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Normalized_Load.Settings, "text/plain"),
            "text-updated",
            "trimmed draft icon key replaces existing row");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Normalized_Load.Settings,
              "text/plain",
              [Guikit.Input.Control_Key | Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "normalized draft action lookup succeeds");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "editor",
            "normalized draft action replaces existing row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Extension_Filetypes.Length),
            Natural (Normalized_Draft_Settings.Extension_Filetypes.Length),
            "normalized draft extension replacement does not add a duplicate row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Icon_Mappings.Length),
            Natural (Normalized_Draft_Settings.Icon_Mappings.Length),
            "normalized draft icon replacement does not add a duplicate row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Open_Actions.Length),
            Natural (Normalized_Draft_Settings.Open_Actions.Length),
            "normalized draft action replacement does not add a duplicate row");

         Normalized_Draft.Open_Action_Token := To_Unbounded_String (" application/ld+json + control ");
         Normalized_Draft.Open_Action_Command := To_Unbounded_String ("json-editor {path}");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Field_Diagnostic (12, "application/ld+json+control"),
            "",
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
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Token),
            "application/ld+json+control",
            "draft structured-suffix modifier action token is normalized");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "draft structured-suffix modifier action executable parses");
      end;

      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing open action is represented as lookup data");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/missing+shift+meta",
         "missing open action records normalized attempted token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Error_Key),
         "error.open_action.missing",
         "missing open action reports deterministic diagnostic key");
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing full-modifier open action is represented as lookup data");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/missing+shift+control+alt+meta",
         "missing open action records full normalized modifier order");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "   ", Modifiers);
      Assert (not Lookup.Found, "empty filetype open action lookup is missing");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "",
         "empty filetype lookup reports no modifier-only token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Error_Key),
         "error.open_action.missing",
         "empty filetype lookup reports deterministic diagnostic key");
   end Test_Open_Action_Token_Normalization;

   procedure Test_Direct_Mapping_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  Exercise the genuine missing-action lookups deterministically; the
      --  host opener fallback would otherwise resolve unmapped lookups.
      Manual.Use_System_Default_Opener := False;
      Files.Settings.Add_Extension_Mapping (Manual, ".TXT", "text/first");
      Files.Settings.Add_Extension_Mapping (Manual, " txt ", " text/second ");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "TXT"),
         "text/second",
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
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "."),
         "",
         "direct extension mapping ignores empty normalized extension");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "blank"),
         "",
         "direct extension mapping ignores empty filetype value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad=extension"),
         "",
         "direct extension mapping ignores unrepresentable extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.LF & "extension"),
         "",
         "direct extension mapping ignores line-break extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.VT & "extension"),
         "",
         "direct extension mapping ignores vertical-tab extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & C1_Break & "extension"),
         "",
         "direct extension mapping ignores C1 line-break extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & Line_Separator & "extension"),
         "",
         "direct extension mapping ignores Unicode line-separator extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "linebreak"),
         "",
         "direct extension mapping ignores unrepresentable values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "formfeed"),
         "",
         "direct extension mapping ignores form-feed values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "c1break"),
         "",
         "direct extension mapping ignores C1 line-break values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "unicodebreak"),
         "",
         "direct extension mapping ignores Unicode line-separator values");
      Files.Settings.Add_Icon_Mapping (Manual, " text/second ", " first-icon ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/second", " second-icon ");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/second"),
         "second-icon",
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
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, ""),
         "",
         "direct icon mapping ignores empty filetype key");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/blank-icon"),
         "",
         "direct icon mapping ignores empty icon value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad=icon"),
         "",
         "direct icon mapping ignores unrepresentable filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.LF & "icon"),
         "",
         "direct icon mapping ignores line-break filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.VT & "icon"),
         "",
         "direct icon mapping ignores vertical-tab filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & C1_Break & "icon"),
         "",
         "direct icon mapping ignores C1 line-break filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & Line_Separator & "icon"),
         "",
         "direct icon mapping ignores Unicode line-separator filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/linebreak-icon"),
         "",
         "direct icon mapping ignores unrepresentable values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/formfeed-icon"),
         "",
         "direct icon mapping ignores form-feed values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/c1break-icon"),
         "",
         "direct icon mapping ignores C1 line-break values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/unicodebreak-icon"),
         "",
         "direct icon mapping ignores Unicode line-separator values");
   end Test_Direct_Mapping_Insertion;

   procedure Test_Direct_Open_Action_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual    : Files.Settings.Settings_Model := Settings_With_Direct_Mappings;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Args      : Files.Types.String_Vectors.Vector;
   begin
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
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Modifier_Token (Modifiers),
         "+shift+control+alt+meta",
         "modifier tokens are emitted in stable lookup order");
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion normalizes modifiers");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/manual+shift+control+alt+meta",
         "direct open-action lookup reports normalized modifier token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "second",
         "direct open-action insertion replaces normalized duplicate token");
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/spaced-manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion trims filetype before modifiers");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/spaced-manual+shift+meta",
         "direct spaced open-action token is normalized");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "spaced-manual",
         "direct open-action insertion trims executable whitespace");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "{path}",
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
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "image/svg+xml",
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
   end Test_Direct_Open_Action_Insertion;

   procedure Test_Direct_Open_Action_Rejects_Unsafe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : Files.Settings.Settings_Model := Settings_With_Direct_Insertions;
      Lookup : Files.Settings.Action_Lookup_Result;
      Args   : Files.Types.String_Vectors.Vector;
   begin
      Args.Append (To_Unbounded_String ("{path}"));
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
         "text/nul-executable",
         Files.Settings.Make_Action
           ("viewer" & Character'Val (0) & "ignored", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual, "text/nul-executable", Guikit.Input.No_Modifiers);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores NUL-containing executables");
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
         Broken_Args.Append
           (To_Unbounded_String ("arg" & Character'Val (0) & "ignored"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/nul-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action
           (Manual, "text/nul-argument", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "direct open-action insertion ignores NUL-containing arguments");
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
   end Test_Direct_Open_Action_Rejects_Unsafe;

   procedure Test_Settings_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "details"),
         "",
         "settings field validates view mode");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "bad"),
         "error.settings.invalid_view_mode",
         "settings field reports invalid view mode");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "details" & ASCII.LF & "large"),
         "error.settings.invalid_view_mode",
         "view-mode field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "true"),
         "",
         "settings field validates boolean");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "maybe"),
         "error.settings.invalid_boolean",
         "settings field reports invalid boolean");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "true" & ASCII.LF & "false"),
         "error.settings.invalid_boolean",
         "boolean field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (5, "light"),
         "",
         "settings field validates theme value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (5, "sepia"),
         "error.settings.invalid_theme",
         "settings field reports invalid theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (6, "files-basic"),
         "",
         "settings field validates icon theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (6, "unknown-theme"),
         "error.settings.invalid_icon_theme",
         "settings field reports invalid icon theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (3, "modified"),
         "",
         "settings field validates sort field");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (3, "date"),
         "error.settings.invalid_sort_field",
         "settings field reports invalid sort field");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/""quoted"),
         "",
         "filetype value field accepts raw quote-containing values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (7, "bad=extension"),
         "error.settings.invalid_mapping",
         "filetype extension field rejects unrepresentable keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & ASCII.LF & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & C1_Break & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects C1 line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & Line_Separator & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects Unicode line separators");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (10, "quote""icon"),
         "",
         "icon value field accepts raw quote-containing values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (9, "text/bad=icon"),
         "error.settings.invalid_mapping",
         "icon filetype field rejects unrepresentable keys");
   end Test_Settings_Field_Diagnostics;

   procedure Test_Draft_Mapping_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : constant Files.Settings.Settings_Model := Settings_With_Direct_Insertions;
   begin
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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Applied.Settings, "quote"),
            "text/""quoted",
            "quote-containing draft preserves filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Applied.Settings, "text/""quoted"),
            "quote""icon",
            "quote-containing draft preserves icon mapping");
      end;
      declare
         Broken_Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Load  : Files.Settings.Settings_Parse_Result;
      begin
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are rejected");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid",
            "mismatched draft mapping vectors report deterministic diagnostic");
         Broken_Load := Files.Settings.Apply_Draft (Manual, Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are not applied");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Extension := To_Unbounded_String ("bad=extension");
         Broken_Draft.Filetype_Value := To_Unbounded_String ("text/bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable filetype key");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "current unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("bad=extension"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Filetype := To_Unbounded_String ("text/bad=icon");
         Broken_Draft.Icon_Value := To_Unbounded_String ("bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable icon key");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "current unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/bad=icon"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("text/plain+hyper");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unknown open-action modifier");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "current unknown open-action modifier reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("+control");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current modifier-only open-action token");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "current modifier-only open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/bad=action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "unrepresentable draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("""text/quoted-action""");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects quoted open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "quoted draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("[text/bracketed-action]"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects bracketed open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "bracketed draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("+control"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects stored modifier-only open-action tokens");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "stored modifier-only draft open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("linebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/linebreak-value"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("icon" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft icon value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("unicodebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator filetype values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "Unicode line-separator draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/linebreak-action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "unrepresentable draft open-action command reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append
           (To_Unbounded_String ("text/nul-action"));
         Broken_Draft.Open_Action_Commands.Append
           (To_Unbounded_String
              ("viewer {path}" & Character'Val (0) & "ignored"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert
           (not Broken_Load.Success,
            "draft rejects NUL-containing open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "NUL-containing draft action reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/unicodebreak-action"));
         Broken_Draft.Open_Action_Commands.Append
           (To_Unbounded_String ("viewer {path}" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "Unicode line-separator draft open-action command reports open-action diagnostic");
      end;
   end Test_Draft_Mapping_Validation;

   procedure Test_Open_Action_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain+control"),
         "",
         "action token field validates");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "+control"),
         "error.settings.invalid_open_action",
         "action token field reports invalid action token");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/bad=action"),
         "error.settings.invalid_open_action",
         "action token field rejects unrepresentable filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, """text/quoted-action"""),
         "error.settings.invalid_open_action",
         "action token field rejects quoted filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "[text/bracketed-action]"),
         "error.settings.invalid_open_action",
         "action token field rejects bracketed filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain+control+"),
         "error.settings.invalid_open_action",
         "action token field reports trailing modifier separator");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain" & ASCII.LF & "text/html"),
         "error.settings.invalid_open_action",
         "action token field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}"),
         "",
         "action command field validates");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """quoted editor"" ""--project file"" ""{path}"""),
         "",
         "action command field validates quoted tokens");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """quote""""runner"" ""arg """" inner"""),
         "",
         "action command field validates doubled quotes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "runner """" after-empty"),
         "",
         "action command field validates empty quoted argument");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer prefix-{path}"),
         "error.settings.invalid_open_action",
         "action command field reports embedded placeholder");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & ASCII.LF & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & Character'Val (0) & "ignored"),
         "error.settings.invalid_open_action",
         "action command field rejects embedded NUL bytes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & C1_Break & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects C1 line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & Line_Separator & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects Unicode line separators");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """unterminated"),
         "error.settings.invalid_open_action",
         "action command field reports unterminated quote");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """editor""junk {path}"),
         "error.settings.invalid_open_action",
         "action command field reports quoted token trailing junk");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (0, "details"),
         "error.settings.invalid",
         "unknown settings field reports a deterministic diagnostic");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (13, "details"),
         "error.settings.invalid",
         "out-of-range settings field reports a deterministic diagnostic");
      declare
         Command : Unbounded_String := To_Unbounded_String ("viewer");
      begin
         for Index in 1 .. 257 loop
            Append (Command, " argument" & Natural'Image (Index));
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Field_Diagnostic (12, To_String (Command)),
            "error.settings.invalid_open_action",
            "open actions with an excessive argument vector are rejected");
      end;
   end Test_Open_Action_Field_Diagnostics;

   procedure Test_Settings_Parser_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Text   : Unbounded_String := To_Unbounded_String ("[bookmarks]" & ASCII.LF);
         Parsed : Files.Settings.Settings_Parse_Result;
      begin
         for Index in 1 .. 4_097 loop
            Append (Text, "bookmark = /tmp/item" & Natural'Image (Index) & ASCII.LF);
         end loop;
         Parsed := Files.Settings.Parse (To_String (Text));
         Assert
           (not Parsed.Success
            and then To_String (Parsed.Error_Key) = "error.settings.invalid",
            "settings parsing caps the number of persistent entries");
      end;
      declare
         Broken : Files.Settings.Settings_Parse_Result;
      begin
         Broken := Files.Settings.Parse ("[unknown]" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown sections");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.unknown_section",
            "unknown section reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries without equals");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.expected_equals",
            "missing equals reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("default_view_mode = details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries before any section");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.missing_section",
            "missing section reports deterministic diagnostic");
         Broken := Files.Settings.Parse
           ("[settings]" & ASCII.LF
            & "show_hidden_files = true" & Character'Val (0) & "ignored"
            & ASCII.LF);
         Assert
           (not Broken.Success
            and then To_String (Broken.Error_Key) = "error.settings.invalid",
            "settings parser rejects embedded NUL bytes before interpreting fields");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & ". = text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty normalized extensions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "empty extension mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = ""text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unterminated quoted mappings");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "unterminated mapping quote reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[icons]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty icon mappings");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "empty icon mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain = viewer prefix-{path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects embedded open-action placeholders");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "embedded placeholder reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/plain+control+ = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects trailing open-action modifier separator");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "trailing modifier separator reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode = compact" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown view mode values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_view_mode",
            "unknown view mode reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "icon_theme = neon" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown icon themes");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_icon_theme",
            "unknown icon theme reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "show_hidden_files = maybe" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid boolean values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_boolean",
            "invalid boolean reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = text/plain" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break mapping values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "C1 line-break mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[filetypes]" & ASCII.LF & "txt = text/plain" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator mapping values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "Unicode line-separator mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/c1 = viewer {path}" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break open actions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "C1 line-break open action reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF &
              "text/unicode = viewer {path}" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator open actions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "Unicode line-separator open action reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = bogus" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid sort fields");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_sort_field",
            "invalid sort field reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "unexpected = value" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown setting keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.unknown_key",
            "unknown setting key reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain+hyper = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown open-action modifiers");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "unknown open-action modifier reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "empty open-action command reports deterministic diagnostic");
      end;
   end Test_Settings_Parser_Diagnostics;

   procedure Test_Sort_Favorites_And_Mapping_Authority (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Created_Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = created" & ASCII.LF);
         Modified_Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = modified" & ASCII.LF);
      begin
         Assert (Created_Parsed.Success, "settings parser accepts the created sort field");
         Files_Suite.Support.Assert_Equal
           (Created_Parsed.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Created,
            "created sort field round-trips distinctly from modified");
         Files_Suite.Support.Assert_Equal
           (Modified_Parsed.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Modified,
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
         Favorites : Files.Settings.Settings_Model :=
           Files.Settings.Default_Settings;
      begin
         Files.Settings.Toggle_Favorite_Path (Favorites, "/tmp/safe");
         Files.Settings.Toggle_Favorite_Path
           (Favorites, "/tmp/bad" & Character'Val (0) & "ignored");
         Files_Suite.Support.Assert_Equal
           (Natural (Favorites.Favorite_Paths.Length),
            1,
            "a NUL-containing path cannot be persisted as a favorite");
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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "custom"),
            "application/x-custom",
            "an explicit filetype mapping loads from the file");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "txt"),
            "",
            "a built-in mapping omitted from the file does not reappear");
         Assert
           (Files.Settings.Filetype_For_Extension (Files.Settings.Default_Settings, "txt") /= "",
            "built-in defaults still provide mappings for a fresh install");
      end;
   end Test_Sort_Favorites_And_Mapping_Authority;

   --  A fresh install's one seeded open action has to name a program the host
   --  running it actually has. It named xdg-open on every host, and since a
   --  configured action wins over the system default, that entry did not just
   --  fail on Windows and macOS -- it shadowed the working `start` and `open`
   --  fallbacks, so text files did not open at all. Runs on each CI host, so
   --  each branch is checked where it applies.
   procedure Test_Default_Open_Action_Suits_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Defaults : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Lookup   : constant Files.Settings.Action_Lookup_Result :=
        Files.Settings.Lookup_Open_Action (Defaults, "text/plain", Guikit.Input.No_Modifiers);
      Expected : constant String :=
        (case Hostkit.Host.Current is
            when Hostkit.Host.Windows => "cmd",
            when Hostkit.Host.MacOS   => "open",
            when others               => "xdg-open");
      Found_Executable : constant String := To_String (Lookup.Action.Executable);
   begin
      Assert (Lookup.Found, "a fresh install seeds an open action for text/plain");
      Assert
        (not Lookup.System_Fallback,
         "the seeded text/plain action is a configured action, not the system fallback");
      Files_Suite.Support.Assert_Equal
        (Found_Executable,
         Expected,
         "the seeded text/plain opener names a program this host has: expected "
         & Expected & ", found " & Found_Executable);
      Assert
        (Natural (Lookup.Action.Arguments.Length) > 0
           and then To_String (Lookup.Action.Arguments.Last_Element) = "{path}",
         "the seeded text/plain opener is handed the file to open");
   end Test_Default_Open_Action_Suits_The_Host;

   --  The settings the draft tests start from: what Load_File returns for a
   --  saved settings file holding only a details default view, in a fresh Root.
   function Load_Saved_Details_Settings return Files.Settings.Settings_Parse_Result is
      Path : constant String := Join (Root, "files.conf");
   begin
      Reset_Root;
      Write_File (Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      return Files.Settings.Load_File (Path);
   end Load_Saved_Details_Settings;

   procedure Test_Default_Settings_Text_And_Themes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Default_Text  : constant String := Files.Settings.Default_Settings_Text;
      Default_Parse : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Default_Text);
   begin
      Assert (Default_Parse.Success, "default settings text parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Default_Parse.Settings, "txt"),
         "text/plain",
         "default settings text includes filetype mappings");
      Assert
        (Default_Parse.Settings.Theme = Files.Settings.Theme_Dark,
         "default settings text keeps the dark theme selected");
      Files_Suite.Support.Assert_Equal
        (To_String (Default_Parse.Settings.Icon_Theme_Name),
         "files-basic",
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
   end Test_Default_Settings_Text_And_Themes;

   procedure Test_Settings_Load_File_Inputs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings_Path : constant String := Join (Root, "files.conf");
      Long_Path     : constant String := Join (Root, "long.conf");
      Oversized_Path : constant String := Join (Root, "oversized.conf");
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
      Oversized_Loaded : Files.Settings.Settings_Parse_Result;
   begin
      Reset_Root;
      Missing := Files.Settings.Load_File (Join (Root, "missing.conf"));
      Assert (Missing.Success, "missing settings file falls back to defaults");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Missing.Settings, "txt"),
         "text/plain",
         "default settings are returned for a missing file");
      Empty_Load := Files.Settings.Load_File ("");
      Assert (not Empty_Load.Success, "empty settings file path is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Empty_Load.Error_Key),
         "error.settings.load",
         "empty settings file path reports load diagnostic");
      Loaded := Files.Settings.Load_File
        (Settings_Path & Character'Val (0) & "ignored");
      Assert
        (not Loaded.Success
         and then To_String (Loaded.Error_Key) = "error.settings.load",
         "settings loading rejects NUL-containing paths without truncating them");
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      Not_File := Files.Settings.Load_File (Join (Root, "settings-dir"));
      Assert (not Not_File.Success, "directory settings path is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Not_File.Error_Key),
         "error.settings.not_file",
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
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Sort_Field_Value,
         Files.Settings.Sort_By_Modified,
         "sort field loads from disk");
      Assert (not Loaded.Settings.Sort_Ascending, "sort direction loads from disk");
      Assert
        (Loaded.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high-contrast key wins over light and loads from disk");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "foo"),
         "application/x-foo",
         "filetype mapping loads from disk");
      declare
         Link_Path : constant String := Join (Root, "linked-settings.conf");
      begin
         if Files_Suite.Support.Create_Symlink (Settings_Path, Link_Path) then
            Loaded := Files.Settings.Load_File (Link_Path);
            Assert
              (Loaded.Success and then Loaded.Settings.Show_Hidden_Files,
               "settings loading follows a link only to its verified regular-file target");
         end if;
      end;
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Loaded := Files.Settings.Load_File ("/dev/null");
         Assert
           (not Loaded.Success
            and then To_String (Loaded.Error_Key) = "error.settings.not_file",
            "settings loading rejects a special file without reading it");
      end if;

      Write_File
        (Long_Path,
         "[filetypes]" & ASCII.LF &
         "long = " & Long_Type & ASCII.LF);
      Long_Loaded := Files.Settings.Load_File (Long_Path);
      Assert (Long_Loaded.Success, "settings loader preserves long logical lines");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Long_Loaded.Settings, "long"),
         Long_Type,
         "long filetype mapping is not split while loading");

      Write_Filler_File
        (Oversized_Path,
         'x',
         1 * 1024 * 1024 + 1);
      Oversized_Loaded := Files.Settings.Load_File (Oversized_Path);
      Assert
        (not Oversized_Loaded.Success
         and then To_String (Oversized_Loaded.Error_Key) = "error.settings.load",
         "oversized settings input is rejected at the bounded file reader");
   end Test_Settings_Load_File_Inputs;

   procedure Test_Settings_Ensure_And_Save_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded        : Files.Settings.Settings_Parse_Result;
      Ensured_Path  : constant String := Join (Join (Root, "created-config"), "settings.conf");
      Ensured       : Files.Settings.Settings_Write_Result;
      Saved_Path    : constant String := Join (Join (Root, "saved-config"), "settings.conf");
      Blocked_Parent : constant String := Join (Root, "blocked-parent");
      Blocked_Path   : constant String := Join (Blocked_Parent, "settings.conf");
      Saved         : Files.Settings.Settings_Write_Result;
   begin
      Reset_Root;
      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings creates missing file");
      Assert (Ada.Directories.Exists (Ensured_Path), "ensure default settings creates parent directories");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Assert (Loaded.Success, "ensured default settings file loads");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "txt"),
         "text/plain",
         "ensured settings file contains default mappings");
      Saved := Files.Settings.Save_Text (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
      Assert (Saved.Success, "settings text can be saved to a new path");
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         declare
            Linked : constant String := Saved_Path & ".link";
            Result : Files.Settings.Settings_Write_Result;
         begin
            Assert (Hostkit.Fs.Create_Link (Saved_Path, Linked), "prepare a symlinked settings file");
            Result := Files.Settings.Save_Text
              (Linked, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Linked),
                    "saving through a symlinked settings file keeps the link");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Load_File (Saved_Path).Settings.Default_View,
               Files.Types.Details,
               "the save lands in the link's target");
            Saved := Files.Settings.Save_Text
              (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
            Assert (Hostkit.Fs.Delete_Link (Linked), "remove the test link");
         end;
      end if;
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         declare
            Available : Boolean := False;
         begin
            Assert
              (Files.File_System.Permission_Bits_Of (Saved_Path, Available)
                 mod 8#1000# = 8#600# and then Available,
               "saved settings containing private paths are owner-only");
         end;
      end if;
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert (Loaded.Success, "saved settings file loads");
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Large_Icons,
         "saved settings text is persisted");
      --  Saving over an existing file goes through the atomic temp+rename path:
      --  the new content replaces the old and no temporary file is left behind.
      Saved :=
        Files.Settings.Save_Text
          (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      Assert (Saved.Success, "settings text can be saved over an existing file");
      Assert
        (not Ada.Directories.Exists (Saved_Path & ".tmp"),
         "a successful settings save leaves no temporary file behind");
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert (Loaded.Success, "resaved settings file loads");
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Details,
         "resaved settings text replaces the previous content");
      Saved := Files.Settings.Save_Text
        (Saved_Path,
         "[settings]" & ASCII.LF
         & "default_view_mode = large" & Character'Val (0) & "ignored"
         & ASCII.LF);
      Assert
        (not Saved.Success,
         "settings saving rejects embedded NUL bytes");
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert
        (Loaded.Success
         and then Loaded.Settings.Default_View = Files.Types.Details,
         "a rejected NUL-containing save preserves the existing settings file");
      declare
         --  On the heap: a megabyte on the stack overflowed Windows' 1 MiB
         --  main stack once the code below this test grew.
         type Text_Access is access String;
         procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);
         Oversized_Text : Text_Access := new String'[1 .. 1 * 1024 * 1024 + 1 => 'x'];
      begin
         Saved := Files.Settings.Save_Text (Saved_Path, Oversized_Text.all);
         Free (Oversized_Text);
         Assert
           (not Saved.Success,
            "settings saving rejects text that its bounded loader cannot read");
         Loaded := Files.Settings.Load_File (Saved_Path);
         Assert
           (Loaded.Success
            and then Loaded.Settings.Default_View = Files.Types.Details,
            "a rejected oversized save preserves the existing settings file");
      end;
      declare
         Temp_Path : constant String := Saved_Path & ".tmp";
         Victim : constant String := Join (Root, "settings-temp-victim");
      begin
         Write_File (Victim, "must stay intact");
         if Files_Suite.Support.Create_Symlink (Victim, Temp_Path) then
            Saved := Files.Settings.Save_Text
              (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
            Assert (Saved.Success, "settings save skips an occupied temp pathname");
            Assert (Hostkit.Fs.Is_Link (Temp_Path),
                    "settings save preserves a colliding temp symlink");
            Assert (File_Has_Bytes (Victim, "must stay intact"),
                    "settings save never follows and truncates a temp symlink target");
            Assert (not Ada.Directories.Exists (Saved_Path & ".tmp-2")
                      and then not Hostkit.Fs.Is_Link (Saved_Path & ".tmp-2"),
                    "settings save removes its alternate temporary file");
         end if;
      end;
      Write_File (Blocked_Parent, "not a directory");
      Saved := Files.Settings.Save_Text (Blocked_Path, "[settings]" & ASCII.LF);
      Assert (not Saved.Success, "settings save rejects a file used as parent directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Saved.Path),
         Blocked_Path,
         "settings save parent failure reports requested settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Saved.Error_Key),
         "error.settings.not_file",
         "settings save parent failure reports not-file diagnostic");
   end Test_Settings_Ensure_And_Save_Text;

   procedure Test_Settings_Draft_Apply_And_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
      Saved  : Files.Settings.Settings_Write_Result;
   begin
      declare
         Reset_Draft : constant Files.Settings.Settings_Draft := Files.Settings.Reset_Draft_To_Defaults;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Reset_Draft.Default_View_Mode),
            "small_icons",
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
      begin
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Disabled,
            "closed settings pane cannot save settings");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.closed",
            "closed settings save reports a localized disabled error");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Path),
            Draft_Path,
            "closed settings save reports settings path");
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
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Default_View,
            Files.Types.Details,
            "draft applies default view");
         Assert (Draft_Load.Settings.Show_Hidden_Files, "draft applies hidden-file flag");
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Size,
            "draft applies sort field");
         Assert
           (Draft_Load.Settings.Theme = Files.Settings.Theme_High_Contrast,
            "draft applies the high-contrast theme");
         Files_Suite.Support.Assert_Equal
           (To_String (Draft_Load.Settings.Icon_Theme_Name),
            "files-high-contrast",
            "draft applies icon theme selection");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log"),
            "text/x-log",
            "draft applies filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log"),
            "text",
            "draft applies icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "draft applies modifier-specific open action");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "draft action executable is parsed");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (Saved.Success, "settings draft saves to disk");
         Draft_Load := Files.Settings.Load_File (Draft_Path);
         Assert (Draft_Load.Success, "saved draft settings load");
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Default_View,
            Files.Types.Details,
            "saved draft persists default view");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log"),
            "text/x-log",
            "saved draft persists filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log"),
            "text",
            "saved draft persists icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "saved draft persists open action");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "saved draft persists structured-suffix open action executable");
         Draft.Default_View_Mode := To_Unbounded_String ("bad-view");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (not Saved.Success, "invalid settings draft is not saved");
         Files_Suite.Support.Assert_Equal
           (To_String (Saved.Error_Key),
            "error.settings.invalid_view_mode",
            "invalid draft save reports validation diagnostic");
      end;
   end Test_Settings_Draft_Apply_And_Save;

   procedure Test_Settings_Draft_Ignores_Orphan_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
      Lookup : Files.Settings.Action_Lookup_Result;
   begin
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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "ghost"),
            "",
            "ignored empty-list filetype edit is not saved");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-ghost"),
            "",
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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "orphan-ext"),
            "",
            "repaired misaligned filetype edit is not saved");

         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Icon_Values.Append (To_Unbounded_String ("orphan-icon"));
         Repair_Draft.Icon_Index := 1;
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
         Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
         Assert (Empty_Load.Success, "repaired misaligned icon draft validates");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-orphan"),
            "",
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
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Model.Settings_Draft_Of (Empty_Model).Filetype_Keys.Length),
            0,
            "begin settings edit drops orphan filetype rows");

         Files.Settings.Add_Extension_Mapping (Empty_Settings, "ada", "text/x-ada");
         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
         Repair_Draft.Filetype_Index := Natural (Repair_Draft.Filetype_Keys.Length);
         Repair_Draft.Filetype_Extension := To_Unbounded_String ("stale-ext");
         Repair_Draft.Filetype_Value := To_Unbounded_String ("text/x-stale");
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
      end;
   end Test_Settings_Draft_Ignores_Orphan_Rows;

   procedure Test_Controller_Settings_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
   begin
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      declare
         Draft_Path : constant String := Join (Join (Root, "draft-config"), "settings.conf");
         Draft_Load : Files.Settings.Settings_Parse_Result;
         Draft_Model : Files.Model.Window_Model := Sample_Model;
         Draft_Settings : Files.Settings.Settings_Model := Loaded.Settings;
         Controller_Result : Files.Controller.Controller_Result;
         Lookup : Files.Settings.Action_Lookup_Result;
         Ctrl : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Ctrl (Guikit.Input.Control_Key) := True;
         --  The earlier draft save left a settings file at Draft_Path; saves
         --  replace it atomically, so only its presence matters here.
         Ada.Directories.Create_Path (Join (Root, "draft-config"));
         Write_File (Draft_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files.Model.Begin_Settings_Edit (Draft_Model, Files.Settings.Make_Draft (Draft_Settings));
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
         Files_Suite.Support.Assert_Equal
           (Files.Model.Focus (Draft_Model),
            Files.Types.Focus_Settings_Input,
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
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Failed,
            "controller rejects invalid settings draft");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.invalid_view_mode",
            "controller invalid settings save reports validation error");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Path),
            Draft_Path,
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
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Failed,
            "controller settings save rejects directory path");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.not_file",
            "controller settings save directory failure reports not-file diagnostic");
         Files_Suite.Support.Assert_Equal
           (Draft_Settings.Default_View,
            Loaded.Settings.Default_View,
            "controller settings save failure preserves live settings");
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Success,
            "controller saves edited settings draft");
         Files_Suite.Support.Assert_Equal
           (Draft_Settings.Default_View,
            Files.Types.Details,
            "controller save updates live settings");
         Assert
           (Draft_Settings.Theme = Files.Settings.Theme_High_Contrast,
            "controller save updates the live theme setting");
         Files_Suite.Support.Assert_Equal
           (To_String (Draft_Settings.Icon_Theme_Name),
            "files-high-contrast",
            "controller save updates live icon theme");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "cfg"),
            "text/x-config",
            "controller save updates live filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "txt"),
            "text/plain",
            "controller save preserves other filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "tmpdel"),
            "",
            "controller save omits removed filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Settings, "text/x-config"),
            "text",
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
            Files_Suite.Support.Assert_Equal
              (Missing_Result.Status,
               Files.Controller.Controller_Command_Executed,
               "missing-current save fixture executes settings command");
            Assert
              (Files.Model.Settings_Pane_Is_Open (Missing_Model),
               "missing-current save fixture opens settings pane");
            Ada.Directories.Delete_Directory (Missing_Current_Path);
            Missing_Result := Files.Controller.Save_Settings (Missing_Model, Missing_Settings, Draft_Path);
            Files_Suite.Support.Assert_Equal
              (Missing_Result.Operation.Status,
               Files.Operations.Operation_Failed,
               "controller settings save reports post-save refresh failure");
            Assert
              (To_String (Missing_Result.Operation.Error_Key) /= "",
               "controller settings save keeps refresh failure diagnostic");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Missing_Model),
               To_String (Missing_Result.Operation.Error_Key),
               "controller settings save leaves refresh failure visible");
         end;
      end;
   end Test_Controller_Settings_Save;

   procedure Test_Ensure_Default_File_Existing_And_Invalid (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded         : Files.Settings.Settings_Parse_Result;
      Ensured_Path   : constant String := Join (Join (Root, "created-config"), "settings.conf");
      Ensured        : Files.Settings.Settings_Write_Result;
      Blocked_Parent : constant String := Join (Root, "blocked-parent");
      Blocked_Path   : constant String := Join (Blocked_Parent, "settings.conf");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      Ada.Directories.Create_Path (Join (Root, "created-config"));
      Write_File (Blocked_Parent, "not a directory");
      Write_File (Ensured_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings accepts existing regular file");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Details,
         "ensure default settings does not overwrite");
      Ensured := Files.Settings.Ensure_Default_File (Join (Root, "settings-dir"));
      Assert (not Ensured.Success, "ensure default settings rejects directory path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.not_file",
         "ensure default settings reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File (Blocked_Path);
      Assert (not Ensured.Success, "ensure default settings rejects a file used as parent directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Path),
         Blocked_Path,
         "ensure default settings parent failure reports requested settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.not_file",
         "ensure default settings parent failure reports not-file diagnostic");
      Ensured := Files.Settings.Ensure_Default_File ("");
      Assert (not Ensured.Success, "ensure default settings rejects empty settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Ensured.Error_Key),
         "error.settings.save",
         "ensure default settings empty path reports save diagnostic");
   end Test_Ensure_Default_File_Existing_And_Invalid;

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
         Files_Suite.Support.Assert_Equal (To_String (Parsed.Error_Key), Error_Key, Message & " diagnostic key");
      end Assert_Parse_Error;
   begin
      Reset_Root;
      Write_File
        (Bad_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = maybe" & ASCII.LF);
      Bad := Files.Settings.Load_File (Bad_Path);
      Assert (not Bad.Success, "invalid boolean setting is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad.Error_Key),
         "error.settings.invalid_boolean",
         "invalid boolean reports a deterministic diagnostic key");

      Bad_Open :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""unterminated" & ASCII.LF);
      Assert (not Bad_Open.Success, "unterminated quoted open action is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad_Open.Error_Key),
         "error.settings.invalid_open_action",
         "unterminated quoted open action reports deterministic diagnostic key");

      Bad_Tail :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""editor""junk {path}" & ASCII.LF);
      Assert (not Bad_Tail.Success, "quoted open action rejects trailing junk");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad_Tail.Error_Key),
         "error.settings.invalid_open_action",
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
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Settings_Test_Case));
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
      Files_Suite.Support.Assert_Equal (Base.Group_By, Files.Types.No_Grouping, "grouping is off by default");

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
         Files_Suite.Support.Assert_Equal
           (Narrow.Column_Widths (Files.Types.Size_Column),
            Files.Types.Minimum_Detail_Column_Width,
            "sub-minimum width is clamped up to the minimum");
         Files_Suite.Support.Assert_Equal
           (Wide.Column_Widths (Files.Types.Size_Column),
            200,
            "an explicit width is retained");
         Files_Suite.Support.Assert_Equal
           (Reset.Column_Widths (Files.Types.Size_Column),
            0,
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
         Files_Suite.Support.Assert_Equal (G1.Group_By, Files.Types.Group_By_Type, "first cycle selects type grouping");
         Files_Suite.Support.Assert_Equal
           (G2.Group_By,
            Files.Types.Group_By_Modified,
            "second cycle selects date grouping");
         Files_Suite.Support.Assert_Equal (G3.Group_By, Files.Types.Group_By_Size, "third cycle selects size grouping");
         Files_Suite.Support.Assert_Equal
           (G4.Group_By,
            Files.Types.Group_By_Label,
            "fourth cycle selects label grouping");
         Files_Suite.Support.Assert_Equal (G5.Group_By, Files.Types.No_Grouping, "grouping cycles back to none");
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
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Column_Widths (Files.Types.Modified_Column),
               175,
               "custom modified width round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Group_By,
               Files.Types.Group_By_Modified,
               "grouping mode round-trips");
         end;
      end;

      --  An invalid grouping mode is diagnosed.
      declare
         Bad : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "group_by = weekly" & ASCII.LF);
      begin
         Assert (not Bad.Success, "an unknown grouping mode fails to parse");
         Files_Suite.Support.Assert_Equal
           (To_String (Bad.Error_Key),
            "error.settings.invalid_group",
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
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.No_Label,
         "an unlabeled path reports No_Label");

      --  Set and replace a label on a file path.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Red);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.Red,
         "a set label is reported back");
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Blue);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.Blue,
         "re-labeling replaces the previous color");

      --  Label a folder path too.
      Files.Settings.Set_Label (Base, Folder_Path, Files.Types.Green);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, Folder_Path),
         Files.Types.Green,
         "a folder path can carry a label");
      Files.Settings.Set_Label
        (Base, File_Path & Character'Val (0) & "ignored", Files.Types.Red);
      Files_Suite.Support.Assert_Equal
        (Natural (Base.Labels.Length),
         2,
         "a NUL-containing path cannot create a persisted color label");

      --  No_Label clears the entry.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.No_Label);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.No_Label,
         "No_Label clears a stored label");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, Folder_Path),
         Files.Types.Green,
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
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Label_Of (Reloaded.Settings, File_Path),
               Files.Types.Purple,
               "a file path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Label_Of (Reloaded.Settings, Folder_Path),
               Files.Types.Gray,
               "a folder path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Group_By,
               Files.Types.Group_By_Label,
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
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Parsed.Settings, "/home/user/bad.txt"),
            Files.Types.No_Label,
            "an entry with an unknown color is skipped");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Parsed.Settings, "/home/user/good.txt"),
            Files.Types.Yellow,
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
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "a fresh model has no recent items");
      Files.Settings.Note_Recent (Base, "");
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "the empty path is not recorded");
      Files.Settings.Note_Recent
        (Base, File_Path & Character'Val (0) & "ignored");
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "a NUL-containing path is not recorded as a recent item");
      Files.Settings.Note_Recent (Base, File_Path & ASCII.LF & "b");
      Files.Settings.Note_Recent (Base, File_Path & ASCII.CR);
      Files_Suite.Support.Assert_Equal
        (Count (Base),
         0,
         "a path with a line break is not recorded, since it cannot round-trip the line-based file");

      --  Note records most-recent-first (a file and a folder both round in).
      Files.Settings.Note_Recent (Base, File_Path);
      Files.Settings.Note_Recent (Base, Folder_Path);
      Files_Suite.Support.Assert_Equal (Count (Base), 2, "two distinct items are recorded");
      Files_Suite.Support.Assert_Equal (Nth (Base, 1), Folder_Path, "the most recent item is at the front");
      Files_Suite.Support.Assert_Equal (Nth (Base, 2), File_Path, "the earlier item follows");

      --  Re-noting an existing path moves it to the front and dedups.
      Files.Settings.Note_Recent (Base, File_Path);
      Files_Suite.Support.Assert_Equal (Count (Base), 2, "re-noting an existing path does not grow the list");
      Files_Suite.Support.Assert_Equal (Nth (Base, 1), File_Path, "a re-noted path moves to the front");
      Files_Suite.Support.Assert_Equal (Nth (Base, 2), Folder_Path, "the previously-front path drops back");

      --  Clearing empties the list.
      Files.Settings.Clear_Recent (Base);
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "Clear_Recent empties the recent list");

      --  The list is capped at Max_Recent_Items, dropping the oldest entries.
      declare
         Capped : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         for I in 1 .. Files.Settings.Max_Recent_Items + 10 loop
            Files.Settings.Note_Recent
              (Capped, "/tmp/item" & Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Both));
         end loop;
         Files_Suite.Support.Assert_Equal
           (Count (Capped),
            Files.Settings.Max_Recent_Items,
            "the recent list is capped at Max_Recent_Items");
         Assert (Nth (Capped, 1) = "/tmp/item" &
                   Ada.Strings.Fixed.Trim
                     (Integer'Image (Files.Settings.Max_Recent_Items + 10), Ada.Strings.Both),
                 "the newest item is retained at the front");
         Files_Suite.Support.Assert_Equal
           (Nth (Capped, Files.Settings.Max_Recent_Items),
            "/tmp/item11",
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
            Files_Suite.Support.Assert_Equal (Count (Reloaded.Settings), 2, "both recent paths round-trip");
            Files_Suite.Support.Assert_Equal
              (Nth (Reloaded.Settings, 1),
               Folder_Path,
               "recent order is preserved most-recent-first");
            Files_Suite.Support.Assert_Equal
              (Nth (Reloaded.Settings, 2),
               File_Path,
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
            Files_Suite.Support.Assert_Equal
              (Count (Parsed.Settings),
               Files.Settings.Max_Recent_Items,
               "loading enforces the recent cap");
         end;
      end;
   end Test_Recent_Items;

   --  Persisted shortcut overrides survive a settings text round-trip, including
   --  a rebind, a rebind carrying modifiers, and an explicit unbind (empty
   --  combo). A malformed hand-edited entry is skipped without failing the load.
   procedure Test_Shortcut_Overrides_Persist (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Combo_For (Settings : Files.Settings.Settings_Model; Command : String) return String is
      begin
         for Entry_Value of Settings.Shortcut_Overrides loop
            if To_String (Entry_Value.Command) = Command then
               return To_String (Entry_Value.Combo);
            end if;
         end loop;
         return "<absent>";
      end Combo_For;

      Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Assert (Source.Shortcut_Overrides.Is_Empty, "a fresh model has no shortcut overrides");

      Source.Shortcut_Overrides.Append
        (Files.Settings.Shortcut_Override'
           (Command => To_Unbounded_String ("view.small"),
            Combo   => To_Unbounded_String ("control+shift+1")));
      --  An explicit unbind is stored with an empty combo.
      Source.Shortcut_Overrides.Append
        (Files.Settings.Shortcut_Override'
           (Command => To_Unbounded_String ("navigate.home"),
            Combo   => To_Unbounded_String ("")));

      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Files.Settings.To_Text (Source));
      begin
         Assert (Reloaded.Success, "shortcut settings text parses");
         Files_Suite.Support.Assert_Equal
           (Natural (Reloaded.Settings.Shortcut_Overrides.Length),
            2,
            "both shortcut overrides round-trip");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Reloaded.Settings, "view.small"),
            "control+shift+1",
            "a modifier-bearing rebind round-trips");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Reloaded.Settings, "navigate.home"),
            "",
            "an explicit unbind round-trips as an empty combo");
      end;

      --  A hand-edited entry without the '|' separator is skipped, not fatal.
      declare
         Text : constant String :=
           "[shortcuts]" & ASCII.LF &
           "shortcut = ""view.small|control+shift+1""" & ASCII.LF &
           "shortcut = ""malformed-no-separator""" & ASCII.LF;
         Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Text);
      begin
         Assert (Parsed.Success, "a malformed shortcut line does not fail the load");
         Files_Suite.Support.Assert_Equal
           (Natural (Parsed.Settings.Shortcut_Overrides.Length),
            1,
            "only the well-formed shortcut entry is kept");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Parsed.Settings, "view.small"),
            "control+shift+1",
            "the well-formed entry survives alongside the skipped one");
      end;
   end Test_Shortcut_Overrides_Persist;

   --  Files.Settings_Form maps the draft to typed panel fields and applies the
   --  panel's emitted changes: paging (Prev/Next) moves the selected mapping
   --  entry without saving, Add/Remove edit the list and save, and the key
   --  field's label carries the "i/n" entry counter.
   --  The Shortcuts tab: the form emits one press-to-capture row per command
   --  carrying its current binding, and Apply routes a captured chord to the live
   --  Files.Commands keymap -- rebinding, rejecting a clash with another command,
   --  unbinding on an empty chord, and clearing the override when set to default.
   procedure Test_Shortcut_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;
      use type SP.Field_Kind;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : constant Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

      --  The capture flow always feeds Apply the canonical Shortcut_Text form
      --  (modifiers normalised to shift+control+alt+meta), so the test uses it too.
      New_Chord : constant String :=
        Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut ("control+shift+5"));

      function Change (Key, Value : String) return SP.Change is
        ((Kind => SP.Value_Changed, Key => To_Unbounded_String (Key), Value => To_Unbounded_String (Value)));

      function Row_Value (Key : String) return String is
         Fields : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
      begin
         for F of Fields loop
            if To_String (F.Key) = Key then
               return (if F.Kind = SP.Shortcut then To_String (F.Value) else "<not-a-shortcut>");
            end if;
         end loop;
         return "<absent>";
      end Row_Value;

      Small_Text : constant String :=
        Files.Commands.Shortcut_Text
          (Files.Commands.Default_Shortcut_For (Files.Commands.Select_Small_Icons_Command));
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Model.Begin_Settings_Edit (Model, Draft);

      --  The form emits a row per command, keyed by "shortcut.<identifier>",
      --  showing the command's current shortcut.
      Files_Suite.Support.Assert_Equal
        (Row_Value ("shortcut.view.small"),
         Small_Text,
         "the shortcut row shows the command's current binding");

      --  Rebind Small Icons to a fresh chord (a key added by the expansion).
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", New_Chord));
      Assert (Saved, "rebinding a shortcut saves");
      declare
         SC : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command);
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (SC.Present, "the live keymap reflects the rebind (present)");
         Files_Suite.Support.Assert_Equal (SC.Key, Guikit.Input.Key_5, "the live keymap reflects the rebind (key)");
         Assert (SC.Modifiers (Guikit.Input.Control_Key), "the live keymap reflects the rebind (Control)");
         Assert (SC.Modifiers (Guikit.Input.Shift_Key), "the live keymap reflects the rebind (Shift)");
         Assert (Is_Set, "the rebind is recorded as an override");
         Files_Suite.Support.Assert_Equal
           (Row_Value ("shortcut.view.small"),
            New_Chord,
            "the row now shows the new chord");
      end;

      --  Binding the same chord to a different command is rejected as a conflict.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.large", New_Chord));
      Assert (not Saved, "a conflicting rebind does not save");
      Assert (Files.Commands.Find_By_Shortcut
                (Guikit.Input.Key_5,
                 [Guikit.Input.Control_Key => True, Guikit.Input.Shift_Key => True, others => False])
              = Files.Commands.Select_Small_Icons_Command,
              "the chord still resolves to its original command after a rejected clash");

      --  An empty chord unbinds the command.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", ""));
      Assert (Saved, "unbinding saves");
      Assert (not Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command).Present,
              "the command has no shortcut after an empty-chord unbind");

      --  Setting a command back to its built-in default clears the override.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", Small_Text));
      Assert (Saved, "restoring the default saves");
      declare
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (not Is_Set, "binding a command to its default clears the override");
      end;

      --  The pane's Reset button is a full reset: it clears shortcut overrides
      --  too, not just the draft values.
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Select_Small_Icons_Command, Files.Commands.Parse_Shortcut ("control+shift+5"));
      Saved := Files.Settings_Form.Apply
        (Model,
         (Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.actions"),
          Value => To_Unbounded_String ("reset")));
      Assert (Saved, "the reset button saves");
      declare
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (not Is_Set, "Reset clears shortcut overrides, returning the keymap to defaults");
      end;

      --  A command with a built-in secondary shortcut surfaces it (read-only) in
      --  its row help, so an "already used" rejection is explicable.
      declare
         Fields   : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
         Sec_Cmd  : constant Files.Commands.Command_Id := Files.Commands.Refresh_Directory_Command;
         Sec_Key  : constant String := "shortcut." & Files.Commands.Identifier (Sec_Cmd);
         Sec_Text : constant String :=
           Files.Commands.Shortcut_Display_Text (Files.Commands.Secondary_Shortcut_For (Sec_Cmd));
         Found    : Boolean := False;
      begin
         Assert (Sec_Text /= "", "the sample command has a secondary shortcut");
         for F of Fields loop
            if To_String (F.Key) = Sec_Key then
               Found := True;
               Assert (Ada.Strings.Fixed.Index (To_String (F.Help), Sec_Text) > 0,
                       "the row help surfaces the built-in secondary shortcut");
            end if;
         end loop;
         Assert (Found, "the command with a secondary has a shortcut row");
      end;

      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Shortcut_Editing;

   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

      function Button (Value : String) return SP.Change is
        ((Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.filetype.buttons"),
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

      Files_Suite.Support.Assert_Equal

        (Ext,

         "txt",

         "the first mapping entry is selected");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(1/2)") > 0, "the key field label shows the entry counter");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Assert (not Saved, "paging to the next entry does not save");
      Files_Suite.Support.Assert_Equal (Ext, "md", "Next selects the second entry");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(2/2)") > 0, "the counter follows the selection");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Files_Suite.Support.Assert_Equal (Ext, "txt", "Next wraps to the first entry");
      Saved := Files.Settings_Form.Apply (Model, Button ("prev"));
      Files_Suite.Support.Assert_Equal (Ext, "md", "Prev wraps back to the last entry");

      Saved := Files.Settings_Form.Apply (Model, Button ("add"));
      Assert (Saved, "adding an entry saves");
      Files_Suite.Support.Assert_Equal (Count, 3, "Add appends a mapping entry");
      Assert
        (Files.Settings.Apply_Draft
           (Files.Settings.Default_Settings, Files.Model.Settings_Draft_Of (Model)).Success,
         "a freshly added, still blank row does not block saving other settings");

      Saved := Files.Settings_Form.Apply (Model, Button ("remove"));
      Assert (Saved, "removing an entry saves");
      Files_Suite.Support.Assert_Equal (Count, 2, "Remove drops the mapping entry");
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
         Files_Suite.Support.Assert_Equal
           (Moved (2),
            Files.Types.Size_Column,
            "the moved column lands in the target slot");
         Files_Suite.Support.Assert_Equal
           (Moved (3),
            Files.Types.Modified_Column,
            "the displaced column shifts right by one");
         Files_Suite.Support.Assert_Equal
           (Moved (1),
            Files.Types.Name_Column,
            "the name column stays pinned to the first slot");
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
         Files_Suite.Support.Assert_Equal
           (Clamped (1),
            Files.Types.Name_Column,
            "a move into the first slot is clamped after name");
         Files_Suite.Support.Assert_Equal
           (Clamped (2),
            Files.Types.Permissions_Column,
            "the clamped move lands in the second slot");
         Assert (Is_Permutation (Clamped), "a clamped move preserves a valid permutation");
      end;

      --  With_Column_Order threads Move_Column through the settings model.
      declare
         Base    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Updated : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Order (Base, Files.Types.Permissions_Column, 2);
      begin
         Files_Suite.Support.Assert_Equal
           (Updated.Column_Order (2),
            Files.Types.Permissions_Column,
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
         Files_Suite.Support.Assert_Equal
           (To_String (Partial.Error_Key),
            "error.settings.invalid_column_order",
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
         Files_Suite.Support.Assert_Equal
           (To_String (Dup.Error_Key),
            "error.settings.invalid_column_order",
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
         Files_Suite.Support.Assert_Equal
           (Aliased_Order.Settings.Column_Order (2),
            Files.Types.Filetype_Column,
            "the type alias resolves to the filetype column in the parsed order");
      end;
   end Test_Column_Order_Reorder;

   --  Numeric settings are plain decimal digits: Ada literal syntax that
   --  Natural'Value would accept is rejected, window sizes are clamped into
   --  Min_Window_Dimension .. Max_Window_Dimension, and column widths get the
   --  same minimum clamp as an interactive resize.
   procedure Test_Settings_Numeric_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Parse_Setting (Line : String) return Files.Settings.Settings_Parse_Result is
        (Files.Settings.Parse ("[settings]" & ASCII.LF & Line & ASCII.LF));

      function Width_Of (Value : String) return Natural is
        (Parse_Setting ("window_width = " & Value).Settings.Window_Width);

      function Size_Column_Width_Of (Value : String) return Natural is
        (Parse_Setting ("detail_column_width_size = " & Value).Settings.Column_Widths (Files.Types.Size_Column));

      Font_Literals : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("16#10#"), To_Unbounded_String ("1_6"), To_Unbounded_String ("16E0"),
         To_Unbounded_String ("99999999999999999999")];

      Normal : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Parse
          ("[settings]" & ASCII.LF
           & "window_width = 1280" & ASCII.LF
           & "window_height = 800" & ASCII.LF
           & "font_pixel_size = 18" & ASCII.LF
           & "detail_column_width_modified = 175" & ASCII.LF);
   begin
      Assert (Normal.Success, "plain decimal numeric settings parse");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Window_Width, 1280, "a normal window width is unchanged");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Window_Height, 800, "a normal window height is unchanged");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Font_Pixel_Size, 18, "a normal font pixel size is unchanged");
      Files_Suite.Support.Assert_Equal
        (Normal.Settings.Column_Widths (Files.Types.Modified_Column), 175, "a normal column width is unchanged");

      Files_Suite.Support.Assert_Equal (Width_Of ("16#400#"), 0, "a based window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("1_024"), 0, "an underscored window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("1E3"), 0, "an exponent window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("+800"), 0, "a signed window width is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("0"), 0, "a zero window width keeps the platform default");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("1000000"), Files.Settings.Max_Window_Dimension, "a huge window width is clamped to the maximum");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("10"), Files.Settings.Min_Window_Dimension, "a tiny window width is clamped to the minimum");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("99999999999999999999"), 0, "a window width beyond Natural'Last is rejected, not raised");
      Files_Suite.Support.Assert_Equal
        (Parse_Setting ("window_height = 1000000").Settings.Window_Height,
         Files.Settings.Max_Window_Dimension,
         "a huge window height is clamped to the maximum");

      Files_Suite.Support.Assert_Equal
        (Size_Column_Width_Of ("5"),
         Files.Types.Minimum_Detail_Column_Width,
         "a column width below the minimum is clamped up to it");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("200"), 200, "a column width above the minimum is kept");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("16#C8#"), 0, "a based column width literal is rejected");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("2_00"), 0, "an underscored column width is rejected");

      for Literal of Font_Literals loop
         declare
            Parsed : constant Files.Settings.Settings_Parse_Result :=
              Parse_Setting ("font_pixel_size = " & To_String (Literal));
         begin
            Assert (not Parsed.Success, "font pixel size literal " & To_String (Literal) & " is rejected");
            Files_Suite.Support.Assert_Equal
              (To_String (Parsed.Error_Key),
               "error.settings.invalid_font_pixel_size",
               "font pixel size literal " & To_String (Literal) & " reports the font size diagnostic");
         end;
      end loop;
   end Test_Settings_Numeric_Values;
end Files_Suite.Settings;

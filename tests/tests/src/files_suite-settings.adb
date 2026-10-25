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
   procedure Test_Scalar_Settings_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scalar_Settings_Round_Trip'Access,
         "every scalar setting round-trips through the settings text and, if the pane edits it, the draft");
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

   procedure Test_Settings_Text_Scalar_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filetype_And_Icon_Mappings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Modifier_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Placeholder_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Embedded_Placeholders (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Fallback_And_Quoting (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Actions_Serialize_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Token_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Direct_Mapping_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Direct_Open_Action_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Direct_Open_Action_Rejects_Unsafe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Draft_Mapping_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Parser_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sort_Favorites_And_Mapping_Authority (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Default_Open_Action_Suits_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The settings the draft tests start from: what Load_File returns for a
   --  saved settings file holding only a details default view, in a fresh Root.
   function Load_Saved_Details_Settings return Files.Settings.Settings_Parse_Result is
      Path : constant String := Join (Root, "files.conf");
   begin
      Reset_Root;
      Write_File (Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      return Files.Settings.Load_File (Path);
   end Load_Saved_Details_Settings;

   procedure Test_Default_Settings_Text_And_Themes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Load_File_Inputs (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Ensure_And_Save_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Draft_Apply_And_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Draft_Ignores_Orphan_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Controller_Settings_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ensure_Default_File_Existing_And_Invalid (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Invalid_Boolean (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Settings_Test_Case));
      return Result;
   end Suite;

   procedure Test_Detail_Columns_And_Grouping (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Overrides_Persist (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shortcut_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Column_Order_Reorder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Settings_Numeric_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scalar_Settings_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
end Files_Suite.Settings;

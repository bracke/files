with Files.Preference_Types;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;

with Guikit.Input;
with Files.File_Types;
with Files.Icon_Themes;
with Files.Types;

--  The settings model and its file: loading, validation, saving, and the
--  settings pane's draft. Open actions and their placeholders live in
--  Files.Settings.Open_Actions, favorites, recents and labels in
--  Files.Settings.Path_References.
package Files.Settings is
   subtype UString is Files.Types.UString;
   package String_Vectors renames Files.Types.String_Vectors;

   --  One persisted path-to-color-label association. Label is never No_Label for
   --  a stored entry: clearing a label removes the entry entirely.
   type Path_Label is record
      Path  : UString;
      Label : Files.Preference_Types.Color_Label := Files.Preference_Types.No_Label;
   end record;

   package Path_Label_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Path_Label);

   --  One persisted keyboard-shortcut override. Command is a stable command
   --  identifier (as produced by Files.Commands.Identifier). Combo is the
   --  shortcut text (as produced by Files.Commands.Shortcut_Text), or an empty
   --  string to record an explicit unbind that suppresses the built-in default.
   type Shortcut_Override is record
      Command : UString;
      Combo   : UString;
   end record;

   package Shortcut_Override_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Shortcut_Override);

   --  Maximum number of recently-opened paths retained. The recent list is a
   --  most-recent-first, deduplicated, capped ring: opening a new item drops the
   --  oldest entry once this bound is reached.
   Max_Recent_Items : constant := 50;

   --  The extension and icon maps' type, from the classification the
   --  filesystem layer takes (Files.File_Types).
   package String_Maps renames Files.File_Types.String_Maps;

   type Open_Action is record
      Executable : UString;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False;
      --  Where a detached launch starts the program (a desktop entry's
      --  Path=); "" for this process's own directory. Never saved.
      Working_Directory : UString;
   end record;

   package Action_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Open_Action,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Selectable color theme. Theme_Dark is the default. The chosen value maps
   --  directly onto the renderer's palette (Guikit.Draw.Theme_Kind).
   type Theme_Choice is (Theme_Dark, Theme_Light, Theme_High_Contrast);

   --  What the settings keep about paths; see Files.Settings.Path_References.
   type Path_Store is private;

   type Settings_Model is record
      Extension_Filetypes    : String_Maps.Map;
      Icon_Mappings          : String_Maps.Map;
      Open_Actions           : Action_Maps.Map;
      Default_View           : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons;
      Show_Hidden_Files      : Boolean := False;
      Show_File_Extensions   : Boolean := True;
      Show_Used_Space        : Boolean := False;
      --  When True the free-space status field shows a graphical used/free bar,
      --  taking precedence over Show_Used_Space (free -> used -> bar cycle).
      Show_Space_Bar         : Boolean := False;
      Sort_Field_Value       : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Sort_Ascending         : Boolean := True;
      --  Selected color theme applied to the rendering palette.
      Theme                  : Theme_Choice := Theme_Dark;
      Icon_Theme             : Files.Icon_Themes.Icon_Theme := Files.Icon_Themes.Basic;
      Font_Pixel_Size        : Positive := 16;
      --  Global UI state remembered across launches. Window_Width / Height
      --  default to 0 meaning "use platform default". Info_Pane_Open mirrors
      --  the runtime toggle so it persists between sessions.
      Window_Width           : Natural := 0;
      Window_Height          : Natural := 0;
      Info_Pane_Open         : Boolean := False;
      --  Favorites, recently opened paths and color labels: reached only
      --  through Files.Settings.Path_References, which keeps their rules
      --  (validity, no repeats, the recent cap).
      Paths                  : Path_Store;
      --  When True (the default) and no per-filetype open action matches, fall
      --  back to the host system's default opener (xdg-open on Linux, open on
      --  macOS, cmd /c start on Windows). Set to False to force explicit
      --  per-type configuration.
      Use_System_Default_Opener : Boolean := True;
      --  Detail-view column customization. Column_Visible toggles individual
      --  columns (the name column is always shown), Column_Widths overrides the
      --  proportional default width per column (zero keeps the default; a
      --  width is in reference units, pixels at
      --  Guikit.Layout.Reference_Line_Height, scaled with the line height when
      --  drawn), and Group_By selects the optional non-selectable grouping bands.
      Column_Visible         : Files.Preference_Types.Detail_Column_Visibility :=
        Files.Preference_Types.Default_Detail_Column_Visibility;
      Column_Widths          : Files.Preference_Types.Detail_Column_Widths :=
        Files.Preference_Types.Default_Detail_Column_Widths;
      --  Persisted left-to-right order of the detail columns (a permutation with
      --  the mandatory name column pinned first). Every layout path iterates the
      --  visible columns in this order.
      Column_Order           : Files.Preference_Types.Detail_Column_Order :=
        Files.Preference_Types.Default_Detail_Column_Order;
      Group_By               : Files.Preference_Types.Group_Mode := Files.Preference_Types.No_Grouping;
      --  Persisted keyboard-shortcut overrides, one entry per rebound or
      --  explicitly-unbound command. Empty by default so an untouched keymap
      --  leaves every built-in shortcut in force. Serialized as the
      --  [shortcuts] section and applied to Files.Commands at startup.
      Shortcut_Overrides     : Shortcut_Override_Vectors.Vector;
      --  Session state, never written to the file: True when the settings
      --  file exists but could not be loaded, so the session runs on defaults
      --  and must not overwrite it. Changes then apply in memory and every
      --  save reports error.settings.not_persisted. An empty settings path,
      --  by contrast, asks for no persistence at all (tests, smoke runs).
      Persistence_Refused    : Boolean := False;
   end record;

   --  Whether two settings say the same thing, leaving out session state
   --  (Persistence_Refused) that never travels in a file or a job request:
   --  what a job's settings must equal for its result to apply.
   --
   --  @param Left First settings.
   --  @param Right Second settings.
   --  @return True when every persisted setting is equal.
   function Same_Content (Left, Right : Settings_Model) return Boolean is
     (if Left.Persistence_Refused = Right.Persistence_Refused
      then Left = Right
      else (Left with delta Persistence_Refused => Right.Persistence_Refused) = Right);

   --  The listing policy (hidden entries, sort field and direction) the
   --  settings ask a directory load for.
   --
   --  @param Settings Settings model to read.
   --  @return The listing options Settings selects.
   function Listing_Options_Of
     (Settings : Settings_Model)
      return Files.Types.Listing_Options;

   --  Whether two settings list a folder the same way: the listing options,
   --  and the filetype and icon maps every listed item is classified by; for
   --  the recent view also the recent paths it lists. A job's listing stays
   --  valid across any other change (a zoom, a column width, a label, a
   --  recent path when the view is a folder).
   --
   --  @param Left First settings.
   --  @param Right Second settings.
   --  @param Recent_View Whether the listing is the recent view.
   --  @return True when a listing made under Left matches one under Right.
   function Same_Listing
     (Left, Right : Settings_Model;
      Recent_View : Boolean)
      return Boolean;

   type Settings_Parse_Result is record
      Success   : Boolean := True;
      Settings  : Settings_Model;
      Error_Key : UString;
   end record;

   type Settings_Write_Result is record
      Success   : Boolean := True;
      Durable   : Boolean := True;
      Path      : UString;
      Error_Key : UString;
   end record;

   --  The scalar (single key = value) settings of the [settings] section, in
   --  the order To_Text writes them. Each literal has one row in the descriptor
   --  table in the package body (its file key, the error key for a rejected
   --  value, whether the value is quoted, whether the settings pane edits it,
   --  and whether it is written only when it differs from the default) and one
   --  arm in each of the Scalar_Text and Set_Scalar case statements. Parse,
   --  To_Text, Make_Draft, Apply_Draft and the draft validation text all
   --  iterate this type, so adding a scalar setting means adding a literal, a
   --  table row and the two arms -- the compiler insists on the arms.
   type Scalar_Setting is
     (Default_View_Mode_Setting,
      Show_Hidden_Files_Setting,
      Show_File_Extensions_Setting,
      Show_Used_Space_Setting,
      Show_Space_Bar_Setting,
      Sort_Field_Setting,
      Sort_Ascending_Setting,
      Theme_Setting,
      Icon_Theme_Setting,
      Font_Pixel_Size_Setting,
      Info_Pane_Open_Setting,
      Use_System_Default_Opener_Setting,
      Group_By_Setting,
      Detail_Column_Order_Setting,
      Detail_Column_Modified_Setting,
      Detail_Column_Width_Modified_Setting,
      Detail_Column_Size_Setting,
      Detail_Column_Width_Size_Setting,
      Detail_Column_Filetype_Setting,
      Detail_Column_Width_Filetype_Setting,
      Detail_Column_Created_Setting,
      Detail_Column_Width_Created_Setting,
      Detail_Column_Permissions_Setting,
      Detail_Column_Width_Permissions_Setting,
      Window_Width_Setting,
      Window_Height_Setting);

   --  Editable text for each scalar setting, as the settings file spells it
   --  (the icon theme unquoted). Only the slots for which Is_Pane_Setting holds
   --  are used: Make_Draft leaves the others empty and Apply_Draft keeps the
   --  base model's values for them.
   type Scalar_Texts is array (Scalar_Setting) of UString;

   --  The settings pane's editable copy of the settings: the pane-edited
   --  scalar settings as text, plus the three mapping editors (each a key and
   --  value vector, the selected row index, and that row's pending key/value
   --  edit). Valid and Error_Key carry the last validation outcome.
   type Settings_Draft is record
      --  The pane-edited scalar settings, indexed by setting.
      Scalars                : Scalar_Texts;
      Filetype_Extension     : UString;
      Filetype_Value         : UString;
      Filetype_Keys          : String_Vectors.Vector;
      Filetype_Values        : String_Vectors.Vector;
      Filetype_Index         : Natural := 0;
      Icon_Filetype          : UString;
      Icon_Value             : UString;
      Icon_Keys              : String_Vectors.Vector;
      Icon_Values            : String_Vectors.Vector;
      Icon_Index             : Natural := 0;
      Open_Action_Token      : UString;
      Open_Action_Command    : UString;
      Open_Action_Keys       : String_Vectors.Vector;
      Open_Action_Commands   : String_Vectors.Vector;
      Open_Action_Index      : Natural := 0;
      --  The shortcuts as the pane has them: the settings' [shortcuts]
      --  section, edited here and put in force only once a save of the
      --  draft is accepted.
      Shortcut_Overrides     : Shortcut_Override_Vectors.Vector;
      Error_Key              : UString;
      Valid                  : Boolean := True;
   end record;

   --  Font pixel-size bounds and default shared by every font-size adjustment
   --  path (keyboard zoom, Ctrl + scroll zoom, and the settings-pane stepper).
   Min_Font_Pixel_Size     : constant Positive := 10;
   Max_Font_Pixel_Size     : constant Positive := 32;
   Default_Font_Pixel_Size : constant Positive := 16;

   --  Bounds a persisted window_width / window_height is clamped into on load,
   --  so a hand-edited settings file cannot ask the platform for a degenerate
   --  or absurdly large surface. Zero stays "use the platform default".
   Min_Window_Dimension : constant Positive := 200;
   Max_Window_Dimension : constant Positive := 16_384;

   --  The settings file's token for each choice: the persisted format, and the
   --  one place it is spelled. Set_Scalar reads a value back through these and
   --  the settings pane offers them as its choices.
   --
   --  @param Mode View mode to name.
   --  @return Its settings-file token.
   function View_Mode_Name (Mode : Files.Preference_Types.View_Mode) return String;

   --  @param Field Sort field to name.
   --  @return Its settings-file token.
   function Sort_Field_Name (Field : Files.Types.Sort_Field) return String;

   --  @param Value Theme to name.
   --  @return Its settings-file token.
   function Theme_Name (Value : Theme_Choice) return String;

   --  @param Value Grouping mode to name.
   --  @return Its settings-file token.
   function Group_Mode_Name (Value : Files.Preference_Types.Group_Mode) return String;

   --  Clamp a requested font pixel size into the supported range.
   --
   --  @param Size Requested pixel size (may be out of range or non-positive).
   --  @return Size clamped to Min_Font_Pixel_Size .. Max_Font_Pixel_Size.
   function Clamp_Font_Pixel_Size (Size : Integer) return Positive;

   --  Return the built-in settings model used when no settings file exists.
   --
   --  @return Default settings model.
   function Default_Settings return Settings_Model;

   --  Return Settings with the visibility of a detail column toggled. The name
   --  column is always visible, so a request to toggle it returns Settings
   --  unchanged.
   --
   --  @param Settings Settings model to update.
   --  @param Column Detail column to toggle.
   --  @return Updated settings model.
   function Toggle_Column
     (Settings : Settings_Model;
      Column   : Files.Preference_Types.Detail_Column)
      return Settings_Model;

   --  Return Settings with a detail column's persisted width set to Width,
   --  clamped up to the minimum column width. A width of zero clears the
   --  customization so the layout falls back to its proportional default.
   --
   --  @param Settings Settings model to update.
   --  @param Column Detail column to resize.
   --  @param Width Requested width in reference units (pixels at
   --  Guikit.Layout.Reference_Line_Height), or zero to reset to the default.
   --  @return Updated settings model.
   function With_Column_Width
     (Settings : Settings_Model;
      Column   : Files.Preference_Types.Detail_Column;
      Width    : Natural)
      return Settings_Model;

   --  Return Settings with Column moved so it occupies slot To_Index in the
   --  detail column order. Delegates to Files.Preference_Types.Move_Column, so the name
   --  column stays pinned to the first slot and a no-op move returns Settings
   --  unchanged. Per-column widths and visibility are unaffected: they follow
   --  their column, not its position.
   --
   --  @param Settings Settings model to update.
   --  @param Column Detail column to move.
   --  @param To_Index Target one-based slot for Column.
   --  @return Updated settings model.
   function With_Column_Order
     (Settings : Settings_Model;
      Column   : Files.Preference_Types.Detail_Column;
      To_Index : Files.Preference_Types.Detail_Column_Index)
      return Settings_Model;

   --  Return Settings with Group_By advanced to the next grouping mode, cycling
   --  back to No_Grouping after the final band.
   --
   --  @param Settings Settings model to update.
   --  @return Updated settings model.
   function Cycle_Group_By
     (Settings : Settings_Model)
      return Settings_Model;

   --  Parse settings text into a settings model.
   --
   --  @param Text Settings file content.
   --  @return Parsed settings or a deterministic diagnostic key.
   function Parse
     (Text : String)
      return Settings_Parse_Result;

   --  Serialize a settings model to settings-file text.
   --
   --  @param Settings Settings model to serialize.
   --  @return Settings file content.
   function To_Text
     (Settings : Settings_Model)
      return String;

   --  The classification Settings maps items by: the two maps the
   --  filesystem layer's listings and searches take instead of the settings.
   --
   --  @param Settings Settings holding the extension and icon maps.
   --  @return A copy of those two maps.
   function Classification_Of (Settings : Settings_Model) return Files.File_Types.Classification is
     ((Extension_Filetypes => Settings.Extension_Filetypes, Icon_Mappings => Settings.Icon_Mappings));

private

   --  Whether Settings, once written, would load again: Parse bounds the file
   --  (size and entry count) against hostile input, so an edit that grows it
   --  past those bounds -- thousands of labels -- must be refused, not saved.
   --
   --  @param Settings Settings model to check.
   --  @return True when To_Text (Settings) parses successfully.
   function Loadable (Settings : Settings_Model) return Boolean;

   type Path_Store is record
      --  Favorite item and folder paths, in the order they were starred.
      Favorites : String_Vectors.Vector;
      --  Recently-opened item and folder paths, most-recent-first, capped at
      --  Max_Recent_Items; persisted as the [recent] section.
      Recent    : String_Vectors.Vector;
      --  Per-path color labels (tags). Each entry maps a full item or folder
      --  path to one of the seven swatch colors; No_Label is never stored.
      Labels    : Path_Label_Vectors.Vector;
      --  Which write the favorites and labels are the result of (Restamp):
      --  two stores with the same stamp hold the same favorites and labels,
      --  so the per-frame check that a snapshot still shows them is a number
      --  comparison. Zero is the empty store no write has touched. Not part
      --  of what the settings say ("=" below leaves it out).
      Stamp     : Natural := 0;
   end record;

   --  The favorites, recent paths and labels; not the stamp.
   --
   --  @param Left First store.
   --  @param Right Second store.
   --  @return True when both hold the same paths and labels.
   function "=" (Left, Right : Path_Store) return Boolean is
     (String_Vectors."=" (Left.Favorites, Right.Favorites)
      and then String_Vectors."=" (Left.Recent, Right.Recent)
      and then Path_Label_Vectors."=" (Left.Labels, Right.Labels));

   --  Give Store a stamp no other write in this process has had: every
   --  change to its favorites or labels ends with this (Path_References,
   --  Storage's merge).
   --
   --  @param Store Store just written.
   procedure Restamp (Store : in out Path_Store);

   --  Whether Path can be stored: not empty, and without a NUL or a line
   --  break, which the line-oriented settings file cannot round-trip.
   --
   --  @param Path Path to test.
   --  @return True when Path can be persisted.
   function Persistent_Path_Is_Valid (Path : String) return Boolean;

   --  Return the settings-file key of a scalar setting.
   --
   --  @param Setting Scalar setting to name.
   --  @return The key written before " = " in the [settings] section.
   function Scalar_Key (Setting : Scalar_Setting) return String;

   --  Whether the settings pane edits Setting, so that it has a draft slot.
   --
   --  @param Setting Scalar setting to test.
   --  @return True when Make_Draft fills and Apply_Draft applies Setting.
   function Is_Pane_Setting (Setting : Scalar_Setting) return Boolean;

   --  Return the value of one scalar setting as settings-file text, before any
   --  quoting (the icon theme is returned bare).
   --
   --  @param Settings Settings model to read.
   --  @param Setting Scalar setting to read.
   --  @return The canonical value text, which Set_Scalar accepts.
   function Scalar_Text
     (Settings : Settings_Model;
      Setting  : Scalar_Setting)
      return String;

   --  Parse Text as the value of one scalar setting and store it in Settings,
   --  applying that setting's validation and clamping exactly as Parse does.
   --  A rejected value leaves the setting unchanged (a rejected column order
   --  resets it to the default order).
   --
   --  @param Settings Settings model updated in place.
   --  @param Setting Scalar setting to set.
   --  @param Text Unquoted value text.
   --  @param Error_Key Empty when Text was accepted, otherwise the diagnostic key.
   procedure Set_Scalar
     (Settings  : in out Settings_Model;
      Setting   : Scalar_Setting;
      Text      : String;
      Error_Key : out UString);

   --  Add or replace an extension-to-filetype mapping.
   --
   --  @param Settings Settings model to update.
   --  @param Extension File extension with or without a leading dot.
   --  @param Filetype Filetype identifier.
   procedure Add_Extension_Mapping
     (Settings  : in out Settings_Model;
      Extension : String;
      Filetype  : String);

   --  Add or replace a filetype icon mapping.
   --
   --  @param Settings Settings model to update.
   --  @param Filetype Filetype identifier.
   --  @param Icon Icon identifier.
   procedure Add_Icon_Mapping
     (Settings : in out Settings_Model;
      Filetype : String;
      Icon     : String);

   --  Add or replace an open action token.
   --
   --  @param Settings Settings model to update.
   --  @param Token Filetype token, optionally including normalized modifiers.
   --  @param Action Open action to associate with Token.
   procedure Add_Open_Action
     (Settings : in out Settings_Model;
      Token    : String;
      Action   : Open_Action);

   --  Normalize active modifiers into the token order required by open-action lookup.
   --
   --  @param Modifiers Active modifier set.
   --  @return Normalized token suffix without a leading filetype.
   function Modifier_Token
     (Modifiers : Guikit.Input.Modifier_Set)
      return String;

   --  Return the default settings file content for first-run creation.
   --
   --  @return Default settings file text.
   function Default_Settings_Text return String;

   --  The most bytes a settings text may hold; Parse and the file reads
   --  (Files.Settings.Storage) both refuse more.
   Max_Settings_Text_Bytes : constant Natural := 1 * 1024 * 1024;

   --  @param Text Text to scan.
   --  @return True when Text holds a NUL character.
   function Contains_Nul (Text : String) return Boolean;

   --  @param Text Text to scan.
   --  @return True when Text holds a line feed or carriage return.
   function Contains_Line_Break (Text : String) return Boolean;

   --  Whether the mapping row at Index has neither key nor value.
   --
   --  @param Keys Row keys.
   --  @param Values Row values, aligned with Keys.
   --  @param Index Row to test.
   --  @return True when both the key and the value are blank.
   function Blank_Row
     (Keys   : String_Vectors.Vector;
      Values : String_Vectors.Vector;
      Index  : Positive)
      return Boolean;

   --  @param Text Mapping key text.
   --  @return True when Text can be written as a mapping key.
   function Mapping_Key_Is_Valid (Text : String) return Boolean;

   --  @param Text Mapping value text.
   --  @return True when Text, trimmed, can be written as a mapping value.
   function Mapping_Value_Is_Valid (Text : String) return Boolean;

   --  @param Token Open-action token, possibly with modifier suffixes.
   --  @return Index where the modifier suffixes start, or 0 when there are none.
   function Modifier_Suffix_Start (Token : String) return Natural;

   --  @param Token Open-action token as typed.
   --  @return The token in its canonical form.
   function Normalize_Action_Token (Token : String) return String;

   --  @param Token Open-action token.
   --  @return True when every modifier suffix of Token is known.
   function Action_Token_Modifiers_Are_Known (Token : String) return Boolean;

   --  @param Text Open-action key text.
   --  @return True when Text names a filetype or extension an action can bind.
   function Open_Action_Base_Key_Is_Valid (Text : String) return Boolean;

   --  @param Text Open-action command as written in the settings file.
   --  @return The parsed action.
   function Parse_Action (Text : String) return Open_Action;

   --  @param Setting Scalar setting to write.
   --  @param Value Its unquoted value text.
   --  @return The settings-file line for Setting.
   function Scalar_Line (Setting : Scalar_Setting; Value : String) return String;

   --  @param Action Open action to write.
   --  @return Its settings-file command text, which Parse_Action reads back.
   function Action_Text (Action : Open_Action) return String;

   --  @param Value Text to quote.
   --  @return Value quoted as a settings-file token.
   function Action_Token_Text (Value : String) return String;

   --  Sort Keys in ascending byte order.
   --  @param Keys Keys to sort in place.
   procedure Sort (Keys : in out String_Vectors.Vector);

   --  Whether the settings pane shows a scalar setting, and whether a draft
   --  must write it.
   type Pane_Slot is (Not_In_Pane, Pane_Required, Pane_Optional);

   --  @param Setting Scalar setting.
   --  @return Its place in the settings pane.
   function Pane_Slot_Of (Setting : Scalar_Setting) return Pane_Slot;

end Files.Settings;

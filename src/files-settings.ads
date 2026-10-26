with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;

with Guikit.Input;
with Files.Types;

--  Settings loading, validation, and filetype-to-action mapping.
package Files.Settings is
   subtype UString is Files.Types.UString;
   package String_Vectors renames Files.Types.String_Vectors;

   --  One persisted path-to-color-label association. Label is never No_Label for
   --  a stored entry: clearing a label removes the entry entirely.
   type Path_Label is record
      Path  : UString;
      Label : Files.Types.Color_Label := Files.Types.No_Label;
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

   package String_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Open_Action is record
      Executable : UString;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False;
   end record;

   package Action_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Open_Action,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Selectable color theme. Theme_Dark is the default. The chosen value maps
   --  directly onto the renderer's palette (Guikit.Draw.Theme_Kind).
   type Theme_Choice is (Theme_Dark, Theme_Light, Theme_High_Contrast);

   type Settings_Model is record
      Extension_Filetypes    : String_Maps.Map;
      Icon_Mappings          : String_Maps.Map;
      Open_Actions           : Action_Maps.Map;
      Default_View           : Files.Types.View_Mode := Files.Types.Small_Icons;
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
      Icon_Theme_Name        : UString;
      Font_Pixel_Size        : Positive := 16;
      --  Global UI state remembered across launches. Window_Width / Height
      --  default to 0 meaning "use platform default". Info_Pane_Open mirrors
      --  the runtime toggle so it persists between sessions.
      Window_Width           : Natural := 0;
      Window_Height          : Natural := 0;
      Info_Pane_Open         : Boolean := False;
      Favorite_Paths         : String_Vectors.Vector;
      --  Recently-opened item and folder paths, most-recent-first, capped at
      --  Max_Recent_Items. Maintained through Note_Recent / Clear_Recent and read
      --  back through the Recent_Paths accessor; persisted as the [recent]
      --  section. Kept as a distinct value field so the accessor can expose a
      --  read-only view without colliding with the function name.
      Recent_Paths_Value     : String_Vectors.Vector;
      --  Per-path color labels (tags). Each entry maps a full item or folder
      --  path to one of the seven swatch colors; No_Label is never stored.
      Labels                 : Path_Label_Vectors.Vector;
      --  When True (the default) and no per-filetype open action matches, fall
      --  back to the host system's default opener (xdg-open on Linux, open on
      --  macOS, cmd /c start on Windows). Set to False to force explicit
      --  per-type configuration.
      Use_System_Default_Opener : Boolean := True;
      --  Detail-view column customization. Column_Visible toggles individual
      --  columns (the name column is always shown), Column_Widths overrides the
      --  proportional default width per column (zero keeps the default), and
      --  Group_By selects the optional non-selectable grouping bands.
      Column_Visible         : Files.Types.Detail_Column_Visibility :=
        Files.Types.Default_Detail_Column_Visibility;
      Column_Widths          : Files.Types.Detail_Column_Widths :=
        Files.Types.Default_Detail_Column_Widths;
      --  Persisted left-to-right order of the detail columns (a permutation with
      --  the mandatory name column pinned first). Every layout path iterates the
      --  visible columns in this order.
      Column_Order           : Files.Types.Detail_Column_Order :=
        Files.Types.Default_Detail_Column_Order;
      Group_By               : Files.Types.Group_Mode := Files.Types.No_Grouping;
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
     ((Left with delta Persistence_Refused => False) = (Right with delta Persistence_Refused => False));

   --  The exact subset of the settings that Build_Snapshot reads. The render
   --  layer caches this and reuses the cached view snapshot while it still
   --  matches, so the snapshot rebuilds automatically on a theme, column,
   --  visibility, favorite or label change without any explicit invalidation.
   --  Keep this in step with the Settings.* reads in build_snapshot.adb.
   type Snapshot_Settings_Key is record
      Show_File_Extensions : Boolean := False;
      Show_Used_Space      : Boolean := False;
      Show_Space_Bar       : Boolean := False;
      Theme                : Theme_Choice := Theme_Dark;
      Icon_Theme_Name      : UString;
      Column_Visible       : Files.Types.Detail_Column_Visibility :=
        Files.Types.Default_Detail_Column_Visibility;
      Column_Widths        : Files.Types.Detail_Column_Widths :=
        Files.Types.Default_Detail_Column_Widths;
      Column_Order         : Files.Types.Detail_Column_Order :=
        Files.Types.Default_Detail_Column_Order;
      Group_By             : Files.Types.Group_Mode := Files.Types.No_Grouping;
      Favorite_Paths       : String_Vectors.Vector;
      Labels               : Path_Label_Vectors.Vector;
   end record;

   --  The listing policy (hidden entries, sort field and direction) the
   --  settings ask a directory load for.
   --
   --  @param Settings Settings model to read.
   --  @return The listing options Settings selects.
   function Listing_Options_Of
     (Settings : Settings_Model)
      return Files.Types.Listing_Options;

   --  Capture the snapshot-relevant settings for caching.
   --
   --  @param Settings Settings model to read.
   --  @return The snapshot-input key for Settings.
   function Snapshot_Settings_Key_Of
     (Settings : Settings_Model)
      return Snapshot_Settings_Key;

   --  Whether Settings still yields the snapshot-input key Key, i.e. nothing the
   --  view snapshot depends on has changed. Compares in place without building a
   --  new key, so it is cheap enough for the per-frame render reuse check.
   --
   --  @param Settings Settings model to test.
   --  @param Key Previously captured snapshot-input key.
   --  @return True when Settings's snapshot inputs equal Key.
   function Same_Snapshot_Settings
     (Settings : Settings_Model;
      Key      : Snapshot_Settings_Key)
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

   type Action_Lookup_Result is record
      Found            : Boolean := False;
      Action           : Open_Action;
      Token            : UString;
      Error_Key        : UString;
      System_Fallback  : Boolean := False;
   end record;

   --  The scalar (single key = value) settings of the [settings] section, in
   --  the order To_Text writes them. Each literal has one row in the descriptor
   --  table in the package body (its file key, the error key for a rejected
   --  value, whether the value is quoted, whether the settings pane edits it,
   --  and whether it is written only when it differs from the default) and one
   --  arm in each of the Scalar_Text and Set_Scalar case statements. Parse,
   --  To_Text, Make_Draft, Apply_Draft, the draft validation text and
   --  Field_Diagnostic all iterate this type, so adding a scalar setting means
   --  adding a literal, a table row and the two arms -- the compiler insists on
   --  the arms.
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
      Error_Key              : UString;
      Valid                  : Boolean := True;
   end record;

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
      Column   : Files.Types.Detail_Column)
      return Settings_Model;

   --  Return Settings with a detail column's persisted width set to Width,
   --  clamped up to the minimum column width. A width of zero clears the
   --  customization so the layout falls back to its proportional default.
   --
   --  @param Settings Settings model to update.
   --  @param Column Detail column to resize.
   --  @param Width Requested pixel width, or zero to reset to the default.
   --  @return Updated settings model.
   function With_Column_Width
     (Settings : Settings_Model;
      Column   : Files.Types.Detail_Column;
      Width    : Natural)
      return Settings_Model;

   --  Return Settings with Column moved so it occupies slot To_Index in the
   --  detail column order. Delegates to Files.Types.Move_Column, so the name
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
      Column   : Files.Types.Detail_Column;
      To_Index : Files.Types.Detail_Column_Index)
      return Settings_Model;

   --  Return Settings with Group_By advanced to the next grouping mode, cycling
   --  back to No_Grouping after the final band.
   --
   --  @param Settings Settings model to update.
   --  @return Updated settings model.
   function Cycle_Group_By
     (Settings : Settings_Model)
      return Settings_Model;

   --  Report whether Path is currently stored in the favorites list.
   --
   --  @param Settings Settings model to query.
   --  @param Path Full item or folder path to test.
   --  @return True when Path is a stored favorite, False otherwise.
   function Is_Favorite
     (Settings : Settings_Model;
      Path     : String)
      return Boolean;

   --  Toggle Path in the favorites list, adding it when absent and removing it
   --  when present. The empty path is ignored.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path to add or remove.
   procedure Toggle_Favorite_Path
     (Settings : in out Settings_Model;
      Path     : String);

   --  Return the recently-opened paths, most-recent-first. The list is capped at
   --  Max_Recent_Items and never contains duplicates or the empty path.
   --
   --  @param Settings Settings model to query.
   --  @return Ordered recent paths, freshest first.
   function Recent_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector;

   --  Record Path as the most recently opened item: move it to the front,
   --  removing any earlier occurrence, and drop the oldest entries once the list
   --  exceeds Max_Recent_Items. The empty path is ignored. Records both files and
   --  folders.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path that was just opened.
   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String);

   --  Clear the entire recently-opened list.
   --
   --  @param Settings Settings model updated in place.
   procedure Clear_Recent
     (Settings : in out Settings_Model);

   --  Return the color label stored for Path.
   --
   --  @param Settings Settings model to query.
   --  @param Path Full item or folder path to look up.
   --  @return The stored color label, or No_Label when Path has none.
   function Label_Of
     (Settings : Settings_Model;
      Path     : String)
      return Files.Types.Color_Label;

   --  Assign Label to Path, replacing any existing label. Passing No_Label
   --  clears Path's label by removing its stored entry. The empty path is
   --  ignored.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path to label.
   --  @param Label Color label to assign, or No_Label to clear.
   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Types.Color_Label);

   --  Path-keyed color labels, as indexed by Index_Paths.
   package Path_Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Files.Types.Color_Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Files.Types."=");

   --  Favorite paths, as indexed by Index_Paths.
   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   --  The favorites and labels of one settings model, hashed by path so a
   --  caller that asks about many paths (one view snapshot asks once per
   --  listed item) pays one lookup per path instead of a scan of both lists.
   --  It is a copy: build it again after the settings change.
   type Path_Index is record
      Favorites : Path_Sets.Set;
      Labels    : Path_Label_Maps.Map;
   end record;

   --  Index the favorites and labels of Settings by path.
   --
   --  @param Settings Settings model to index.
   --  @return Index answering exactly as Is_Favorite and Label_Of on Settings do.
   function Index_Paths
     (Settings : Settings_Model)
      return Path_Index;

   --  Report whether Path is a stored favorite, as Is_Favorite on the indexed
   --  settings would.
   --
   --  @param Index Index built by Index_Paths.
   --  @param Path Full item or folder path to test.
   --  @return True when Path is a stored favorite, False otherwise.
   function Is_Favorite
     (Index : Path_Index;
      Path  : String)
      return Boolean;

   --  Return the color label stored for Path, as Label_Of on the indexed
   --  settings would.
   --
   --  @param Index Index built by Index_Paths.
   --  @param Path Full item or folder path to look up.
   --  @return The stored color label, or No_Label when Path has none.
   function Label_Of
     (Index : Path_Index;
      Path  : String)
      return Files.Types.Color_Label;

   --  Follow a rename or move: every label, favorite and recent path that is
   --  From, or lies inside the folder From, is rewritten to the same place
   --  under To, so a label stays with its item and a new item at the old path
   --  does not inherit it.
   --
   --  @param Settings Settings model updated in place.
   --  @param From Old full path of the moved item.
   --  @param To New full path of the moved item.
   --  @param Changed True when any stored path was rewritten.
   procedure Move_Path_References
     (Settings : in out Settings_Model;
      From     : String;
      To       : String;
      Changed  : out Boolean);

   --  Forget an item that is gone for good: every label, favorite and recent
   --  path that is Path, or lies inside the folder Path, is dropped, so a new
   --  item later created there does not inherit them.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full path of the removed item.
   --  @param Changed True when any stored path was dropped.
   procedure Forget_Path_References
     (Settings : in out Settings_Model;
      Path     : String;
      Changed  : out Boolean);

   --  Whether Settings, once written, would load again: Parse bounds the file
   --  (size and entry count) against hostile input, so an edit that grows it
   --  past those bounds -- thousands of labels -- must be refused, not saved.
   --
   --  @param Settings Settings model to check.
   --  @return True when To_Text (Settings) parses successfully.
   function Loadable (Settings : Settings_Model) return Boolean;

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

   --  Return the mapped filetype for Extension.
   --
   --  @param Settings Settings model to inspect.
   --  @param Extension File extension with or without a leading dot.
   --  @return Mapped filetype, or an empty string when no mapping exists.
   function Filetype_For_Extension
     (Settings  : Settings_Model;
      Extension : String)
      return String;

   --  Return the mapped icon for Filetype.
   --
   --  @param Settings Settings model to inspect.
   --  @param Filetype Filetype identifier.
   --  @return Mapped icon identifier, or an empty string when no mapping exists.
   function Icon_For_Filetype
     (Settings : Settings_Model;
      Filetype : String)
      return String;

   --  Normalize active modifiers into the token order required by open-action lookup.
   --
   --  @param Modifiers Active modifier set.
   --  @return Normalized token suffix without a leading filetype.
   function Modifier_Token
     (Modifiers : Guikit.Input.Modifier_Set)
      return String;

   --  Lookup an open action using full filetype-plus-modifier fallback rules.
   --
   --  @param Settings Settings model to inspect.
   --  @param Filetype Filetype identifier.
   --  @param Modifiers Active modifier set.
   --  @return Lookup result with selected action or localized error key.
   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Guikit.Input.Modifier_Set)
      return Action_Lookup_Result;

   --  Parse settings text into a settings model.
   --
   --  @param Text Settings file content.
   --  @return Parsed settings or a deterministic diagnostic key.
   function Parse
     (Text : String)
      return Settings_Parse_Result;

   --  Load settings from a filesystem path.
   --
   --  Missing files return default settings successfully. Existing invalid files
   --  return a failed parse result with a diagnostic key.
   --
   --  @param Path Settings file path.
   --  @return Loaded settings or a deterministic diagnostic key.
   function Load_File
     (Path : String)
      return Settings_Parse_Result;

   --  Return the default settings file content for first-run creation.
   --
   --  @return Default settings file text.
   function Default_Settings_Text return String;

   --  Serialize a settings model to settings-file text.
   --
   --  @param Settings Settings model to serialize.
   --  @return Settings file content.
   function To_Text
     (Settings : Settings_Model)
      return String;

   --  Build an editable settings draft from a settings model.
   --
   --  @param Settings Settings model to edit.
   --  @return Text draft suitable for UI editing.
   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft;

   --  Bring the pane-edited scalars of Draft up to date with a change made
   --  outside the pane (a command run while it is open), so the pane shows
   --  the change and its next save keeps it. A setting that did not change
   --  between Before and After keeps what the pane holds, an edit included.
   --
   --  @param Draft The pane's draft.
   --  @param Before Settings before the change.
   --  @param After Settings after it.
   --  @return Draft with each changed pane setting taken from After.
   function Refresh_Draft
     (Draft  : Settings_Draft;
      Before : Settings_Model;
      After  : Settings_Model)
      return Settings_Draft;

   --  Validate a settings draft without changing a settings model.
   --
   --  @param Draft Draft to validate.
   --  @return Validation result containing deterministic diagnostic key.
   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result;

   --  Validate a single draft field value.
   --
   --  @param Field Settings field index used by the settings editor.
   --  @param Text Candidate field text.
   --  @return Empty string when valid, otherwise a deterministic diagnostic key.
   function Field_Diagnostic
     (Field : Natural;
      Text  : String)
      return String;

   --  Apply a valid settings draft to an existing settings model.
   --
   --  @param Settings Settings model to update.
   --  @param Draft Valid draft values.
   --  @return Validation result containing updated settings or a diagnostic key.
   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result;

   --  Return a default settings draft, discarding any edited values.
   --
   --  @return Draft created from Default_Settings.
   function Reset_Draft_To_Defaults return Settings_Draft;

   --  Write default settings to Path when it does not already exist.
   --
   --  Parent directories are created as needed. Existing regular files are left
   --  unchanged. Existing non-regular paths are reported as not-file errors.
   --
   --  @param Path Settings file path to ensure.
   --  @return Write result with path and deterministic diagnostic key.
   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result;

   --  Write settings text to Path, creating parent directories as needed.
   --
   --  @param Path Settings file path.
   --  @param Text Settings text to write.
   --  @return Write result with path and deterministic diagnostic key.
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result;

   --  Return a normalized extension without a leading dot.
   --
   --  @param Extension Extension text to normalize.
   --  @return Lower-case extension without a leading dot.
   function Normalize_Extension
     (Extension : String)
      return String;

   --  Build an open action value.
   --
   --  @param Executable Executable path or command name.
   --  @param Arguments Action arguments.
   --  @param Use_Shell Whether explicit shell execution is requested.
   --  @return Open action value.
   function Make_Action
     (Executable : String;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False)
      return Open_Action;

   --  Return whether Argument contains a placeholder embedded in other text.
   --
   --  @param Argument Open-action argument to inspect.
   --  @return True when a known placeholder is not the whole argument.
   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean;

   --  Return whether any action argument contains an embedded placeholder.
   --
   --  @param Action Open action to inspect.
   --  @return True when any known placeholder is embedded in other text.
   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean;

   --  Return whether an action uses placeholders outside safe argument slots.
   --
   --  @param Action Open action to inspect.
   --  @return True when the executable contains a placeholder or any argument embeds one.
   function Has_Unsafe_Placeholder_Usage
     (Action : Open_Action)
      return Boolean;

   --  Substitute whole-argument placeholders for a selected file path.
   --
   --  @param Action Open action to expand.
   --  @param Path Full selected file path.
   --  @return Expanded action arguments.
   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action;
end Files.Settings;

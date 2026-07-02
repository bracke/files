with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Files.Types;

--  Settings loading, validation, and filetype-to-action mapping.
package Files.Settings is
   subtype UString is Files.Types.UString;
   package String_Vectors renames Files.Types.String_Vectors;

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

   type Sort_Field is
     (Sort_By_Name,
      Sort_By_Filetype,
      Sort_By_Size,
      Sort_By_Created,
      Sort_By_Modified);

   --  Selectable color theme. Theme_Dark is the default. The chosen value maps
   --  directly onto the renderer's palette (Files.Rendering.Theme_Kind).
   type Theme_Choice is (Theme_Dark, Theme_Light, Theme_High_Contrast);

   type Settings_Model is record
      Extension_Filetypes    : String_Maps.Map;
      Icon_Mappings          : String_Maps.Map;
      Open_Actions           : Action_Maps.Map;
      Default_View           : Files.Types.View_Mode := Files.Types.Small_Icons;
      Show_Hidden_Files      : Boolean := False;
      Sort_Field_Value       : Sort_Field := Sort_By_Name;
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
      Bookmark_Paths         : String_Vectors.Vector;
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
   end record;

   type Settings_Parse_Result is record
      Success   : Boolean := True;
      Settings  : Settings_Model;
      Error_Key : UString;
   end record;

   type Settings_Write_Result is record
      Success   : Boolean := True;
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

   type Settings_Draft is record
      Default_View_Mode      : UString;
      Show_Hidden_Files      : UString;
      Sort_Field_Value       : UString;
      Sort_Ascending         : UString;
      Theme                  : UString;
      Icon_Theme_Name        : UString;
      Font_Pixel_Size        : UString;
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
     (Modifiers : Files.Types.Modifier_Set)
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
      Modifiers : Files.Types.Modifier_Set)
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

   --  Validate, apply, and save a settings draft to Path.
   --
   --  @param Path Settings file path.
   --  @param Settings Base settings model.
   --  @param Draft Draft values to save.
   --  @return Write result with deterministic diagnostic key.
   function Save_Draft
     (Path     : String;
      Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Write_Result;

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

--  Test-only access to private subprograms of Files.Settings, kept out of the program.
package Files.Settings.Testing is

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

end Files.Settings.Testing;

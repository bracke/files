package body Files.Settings.Testing is

   function Scalar_Key (Setting : Scalar_Setting) return String
     renames Files.Settings.Scalar_Key;

   function Is_Pane_Setting (Setting : Scalar_Setting) return Boolean
     renames Files.Settings.Is_Pane_Setting;

   function Scalar_Text
     (Settings : Settings_Model;
      Setting  : Scalar_Setting)
      return String
     renames Files.Settings.Scalar_Text;

   procedure Set_Scalar
     (Settings  : in out Settings_Model;
      Setting   : Scalar_Setting;
      Text      : String;
      Error_Key : out UString)
     renames Files.Settings.Set_Scalar;

   procedure Add_Extension_Mapping
     (Settings  : in out Settings_Model;
      Extension : String;
      Filetype  : String)
     renames Files.Settings.Add_Extension_Mapping;

   procedure Add_Icon_Mapping
     (Settings : in out Settings_Model;
      Filetype : String;
      Icon     : String)
     renames Files.Settings.Add_Icon_Mapping;

   procedure Add_Open_Action
     (Settings : in out Settings_Model;
      Token    : String;
      Action   : Open_Action)
     renames Files.Settings.Add_Open_Action;

   function Modifier_Token
     (Modifiers : Guikit.Input.Modifier_Set)
      return String
     renames Files.Settings.Modifier_Token;

   function Default_Settings_Text return String
     renames Files.Settings.Default_Settings_Text;

   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean
     renames Files.Settings.Has_Embedded_Placeholder;

   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean
     renames Files.Settings.Has_Embedded_Placeholder;

end Files.Settings.Testing;

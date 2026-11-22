package body Files.Settings.Storage.Testing is

   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result renames Files.Settings.Storage.Save_Text;

   function Write
     (Settings_Path : String;
      Settings      : in out Settings_Model)
      return Settings_Write_Result renames Files.Settings.Storage.Write;

   function Default_Settings_Path
     (Home_Path : String)
      return String renames Files.Settings.Storage.Default_Settings_Path;

end Files.Settings.Storage.Testing;

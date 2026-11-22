package body Files.Settings.Storage.Testing is

   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result renames Files.Settings.Storage.Save_Text;

end Files.Settings.Storage.Testing;

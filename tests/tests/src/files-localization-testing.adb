package body Files.Localization.Testing is

   function Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String is (Locale_Config_Value (Path, Section, Key));

end Files.Localization.Testing;

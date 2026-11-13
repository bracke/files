--  Test-only access to private subprograms of Files.Localization, kept out of the program.
package Files.Localization.Testing is

   --  Files.Localization.Locale_Config_Value.
   --
   --  @param Path Configuration file to read.
   --  @param Section Section to look in, or "".
   --  @param Key Key to look up.
   --  @return The value, without one matching pair of surrounding quotes.
   function Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String;

end Files.Localization.Testing;

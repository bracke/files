--  What the suite reaches of Files.Settings.Storage that is not part of its interface.
package Files.Settings.Storage.Testing is

   --  Write settings text to Path, creating parent directories as needed.
   --
   --  @param Path Settings file path.
   --  @param Text Settings text to write.
   --  @return Write result with path and deterministic diagnostic key.
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result;

end Files.Settings.Storage.Testing;

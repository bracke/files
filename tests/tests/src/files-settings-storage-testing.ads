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

   --  Write Settings to Settings_Path, taking in another process's changes
   --  first (what Persist does after checking the settings load again).
   --
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Settings Settings to write; takes in another process's changes.
   --  @return The write's result.
   function Write
     (Settings_Path : String;
      Settings      : in out Settings_Model)
      return Settings_Write_Result;

   --  Configured_Settings_Path without the FILES_SETTINGS override.
   --
   --  @param Home_Path Home directory path.
   --  @return Default settings file path.
   function Default_Settings_Path
     (Home_Path : String)
      return String;

end Files.Settings.Storage.Testing;

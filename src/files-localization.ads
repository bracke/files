--  Default localization facade for files.
package Files.Localization is

   --  Normalize an operating-system locale name to the catalog locale form.
   --
   --  @param Value Locale text such as da_DK.UTF-8.
   --  @return Normalized locale such as da-DK, or en for empty, C, or POSIX.
   function Normalize_Locale (Value : String) return String;

   --  Return the process locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_MESSAGES, or LANG; en when none is usable.
   function System_Locale return String;

   --  Return the process date/time locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_TIME, or LANG; en when none is usable.
   function System_Time_Locale return String;

   --  Return the process numeric locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_NUMERIC, or LANG; en when none is usable.
   function System_Number_Locale return String;

   --  Render the localized text for Key.
   --
   --  @param Key Stable localization key.
   --  @param Locale Requested locale identifier, or empty to use System_Locale.
   --  @return Localized text when known, otherwise Key.
   function Text
     (Key    : String;
      Locale : String := "")
      return String;

end Files.Localization;

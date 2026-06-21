--  Default localization facade for files.
package Files.Localization is

   --  Render the localized text for Key.
   --
   --  @param Key Stable localization key.
   --  @param Locale Requested locale identifier.
   --  @return Localized text when known, otherwise Key.
   function Text
     (Key    : String;
      Locale : String := "en")
      return String;

end Files.Localization;

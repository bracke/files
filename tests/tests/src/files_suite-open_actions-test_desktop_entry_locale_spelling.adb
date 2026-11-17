with Files.Desktop_Applications;
with Files.Localization;
separate (Files_Suite.Open_Actions)
   --  Without a locale variable, Open With matches localized Name and Icon
   --  keys against the host's locale, which comes as a BCP 47 tag; a Desktop
   --  Entry spells a locale lang_COUNTRY@MODIFIER. A tag with a script
   --  ("sr-Latn-RS") turned into "sr_Latn_RS", which no entry uses, so a
   --  Serbian Latin desktop showed the untranslated name.
   procedure Test_Desktop_Entry_Locale_Spelling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check (Tag, Expected : String) is
      begin
         Files_Suite.Support.Assert_Equal
           (Files.Desktop_Applications.Desktop_Entry_Locale (Tag), Expected, Tag & " in desktop-entry spelling");
      end Check;
   begin
      Check ("sr-Latn-RS", "sr_RS@latin");
      Check ("sr-Cyrl-RS", "sr_RS@cyrillic");
      Check ("de-AT", "de_AT");
      Check ("fi", "fi");
      Check ("zh-Hant-TW", "zh_TW");
      Check ("es-419", "es_419");
      Check ("uz-Latn", "uz@latin");
      --  The variant Normalize_Locale keeps goes back to its modifier, both
      --  from the normalized tag and as a round trip of the POSIX locale.
      Check ("ca-ES-valencia", "ca_ES@valencia");
      Check (Files.Localization.Normalize_Locale ("ca_ES@valencia"), "ca_ES@valencia");
   end Test_Desktop_Entry_Locale_Spelling;

separate (Files_Suite.Startup)
   procedure Test_Locale_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("da_DK.UTF-8"),
         "da-DK",
         "locale normalization removes encoding and converts separator");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("en_us"),
         "en-US",
         "locale normalization canonicalizes language and region case");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("zh_hant_tw.UTF-8"),
         "zh-Hant-TW",
         "locale normalization preserves script catalog casing");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("es_419.UTF-8"),
         "es-419",
         "locale normalization preserves numeric region subtags");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("sr_RS.UTF-8@latin"),
         "sr-Latn-RS",
         "a script modifier becomes the script subtag, after the language");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("uz_UZ@cyrillic"),
         "uz-Cyrl-UZ",
         "a Cyrillic modifier names the Cyrl script");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("ca_ES.UTF-8@valencia"),
         "ca-ES-valencia",
         "the Valencian modifier becomes a variant subtag");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("sr@latin"),
         "sr-Latn",
         "a script modifier without a region");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("sr_Latn_RS@latin"),
         "sr-Latn-RS",
         "a script already given is not given twice");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("de_DE.UTF-8@euro"),
         "de-DE",
         "other modifiers are dropped");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("C"),
         "en",
         "C locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("POSIX"),
         "en",
         "POSIX locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("../../tmp/hostile"),
         "en",
         "path-bearing locale text falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("da" & Character'Val (0) & "DK"),
         "en",
         "a locale containing NUL falls back to English");
      Assert
        (Files.Localization.Normalize_Locale (String'(1 .. 65 => 'a')) = "en",
         "an oversized locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("en--US"),
         "en",
         "an empty locale component falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale (" pt-br "), "pt-BR", "blanks go and a hyphen separates as well");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("_DE"), "en", "a locale without a language falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("de_"), "en", "a trailing separator falls back to English");
      --  I18N's canonical form, its CLDR language aliases included: the
      --  catalogs are named by the current codes.
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("iw_IL.UTF-8"), "he-IL", "a retired language code is replaced");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Normalize_Locale ("sh_RS"), "sr-Latn-RS", "Serbo-Croatian is Serbian in Latin script");
   end Test_Locale_Normalization;

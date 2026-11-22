with Files.Localization.Testing;
with Files.Text_Case;

separate (Files_Suite.Startup)
   procedure Test_Locale_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("da_DK.UTF-8"),
         "da-DK",
         "locale normalization removes encoding and converts separator");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("en_us"),
         "en-US",
         "locale normalization canonicalizes language and region case");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("zh_hant_tw.UTF-8"),
         "zh-Hant-TW",
         "locale normalization preserves script catalog casing");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("es_419.UTF-8"),
         "es-419",
         "locale normalization preserves numeric region subtags");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("sr_RS.UTF-8@latin"),
         "sr-Latn-RS",
         "a script modifier becomes the script subtag, after the language");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("SR_rs.UTF-8@LATIN"),
         "sr-Latn-RS",
         "a modifier in upper case names the script as well");
      --  Lower-casing is ASCII only: a UTF-8 byte (here the lead byte C3 of
      --  "Ä") passes as it is, where Latin-1 lower-casing would make it E3.
      Files_Suite.Support.Assert_Equal
        (Files.Text_Case.To_Lower_Ascii ("Ä-DE"),
         "Ä-de",
         "only ASCII letters are lower-cased; a UTF-8 byte stays");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("de_DE@" & "Ä"),
         "de-DE",
         "a modifier that is not ASCII is dropped, not rewritten");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("uz_UZ@cyrillic"),
         "uz-Cyrl-UZ",
         "a Cyrillic modifier names the Cyrl script");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("ca_ES.UTF-8@valencia"),
         "ca-ES-valencia",
         "the Valencian modifier becomes a variant subtag");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("sr@latin"),
         "sr-Latn",
         "a script modifier without a region");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("sr_Latn_RS@latin"),
         "sr-Latn-RS",
         "a script already given is not given twice");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("de_DE.UTF-8@euro"),
         "de-DE",
         "other modifiers are dropped");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("C"),
         "en",
         "C locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("POSIX"),
         "en",
         "POSIX locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("../../tmp/hostile"),
         "en",
         "path-bearing locale text falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("da" & Character'Val (0) & "DK"),
         "en",
         "a locale containing NUL falls back to English");
      Assert
        (Files.Localization.Testing.Normalize_Locale (String'(1 .. 65 => 'a')) = "en",
         "an oversized locale falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("en--US"),
         "en",
         "an empty locale component falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale (" pt-br "), "pt-BR", "blanks go and a hyphen separates as well");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("_DE"), "en",
          "a locale without a language falls back to English");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("de_"), "en", "a trailing separator falls back to English");
      --  I18N's canonical form, its CLDR language aliases included: the
      --  catalogs are named by the current codes.
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("iw_IL.UTF-8"), "he-IL", "a retired language code is replaced");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Testing.Normalize_Locale ("sh_RS"), "sr-Latn-RS",
          "Serbo-Croatian is Serbian in Latin script");
   end Test_Locale_Normalization;

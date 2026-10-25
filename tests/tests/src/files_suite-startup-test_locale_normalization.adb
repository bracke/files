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
         "sr-RS",
         "locale normalization removes locale modifiers");
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
   end Test_Locale_Normalization;

separate (Files_Suite.Startup)
   procedure Test_Locale_Variable_Precedence (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "LC_ALL");
      Files_Suite.Support.Save (Environment, "LC_MESSAGES");
      Files_Suite.Support.Save (Environment, "LC_TIME");
      Files_Suite.Support.Save (Environment, "LC_NUMERIC");
      Files_Suite.Support.Save (Environment, "LANG");
      Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");
      Ada.Environment_Variables.Set ("LC_MESSAGES", "en_US.UTF-8");
      Ada.Environment_Variables.Set ("LC_TIME", "sv_SE.UTF-8");
      Ada.Environment_Variables.Set ("LC_NUMERIC", "fr_FR.UTF-8");
      Ada.Environment_Variables.Set ("LANG", "de_DE.UTF-8");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Locale,
         "da-DK",
         "LC_ALL has locale detection precedence");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Time_Locale,
         "da-DK",
         "LC_ALL has time-locale detection precedence");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Number_Locale,
         "da-DK",
         "LC_ALL has numeric-locale detection precedence");

      Ada.Environment_Variables.Clear ("LC_ALL");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Locale,
         "en-US",
         "LC_MESSAGES is used after LC_ALL");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Time_Locale,
         "sv-SE",
         "LC_TIME is used for date/time after LC_ALL");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Number_Locale,
         "fr-FR",
         "LC_NUMERIC is used for numbers after LC_ALL");

      Ada.Environment_Variables.Clear ("LC_MESSAGES");
      Files_Suite.Support.Assert_Equal (Files.Localization.System_Locale, "de-DE", "LANG is used after LC_MESSAGES");
      Ada.Environment_Variables.Clear ("LC_TIME");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Time_Locale,
         "de-DE",
         "LANG is used for date/time after LC_TIME");
      Ada.Environment_Variables.Clear ("LC_NUMERIC");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Number_Locale,
         "de-DE",
         "LANG is used for numbers after LC_NUMERIC");

      Ada.Environment_Variables.Set ("LC_ALL", "C");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Locale,
         "en",
         "C in LC_ALL overrides lower-precedence locale variables");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Time_Locale,
         "en",
         "C in LC_ALL overrides lower-precedence time locale");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.System_Number_Locale,
         "en",
         "C in LC_ALL overrides lower-precedence numeric locale");
   end Test_Locale_Variable_Precedence;

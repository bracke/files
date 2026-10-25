separate (Files_Suite.Startup)
   procedure Test_Detected_Locale_Catalogs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "LC_ALL");
      Files_Suite.Support.Save (Environment, "LC_MESSAGES");
      Files_Suite.Support.Save (Environment, "LC_TIME");
      Files_Suite.Support.Save (Environment, "LC_NUMERIC");
      Files_Suite.Support.Save (Environment, "LANG");
      --  The environment the precedence walk leaves behind: only LANG set.
      Ada.Environment_Variables.Clear ("LC_MESSAGES");
      Ada.Environment_Variables.Clear ("LC_TIME");
      Ada.Environment_Variables.Clear ("LC_NUMERIC");
      Ada.Environment_Variables.Set ("LANG", "de_DE.UTF-8");
      Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");
      Assert
        (Files.Localization.Text ("command.view.small") /= "Small Icons"
         and then Files.Localization.Text ("command.view.small") /= "command.view.small",
         "detected Danish locale loads translated app catalog resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.relative.today", Files.Localization.System_Time_Locale),
         "I dag",
         "detected Danish time locale uses date/time catalog resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.format.locale_date", "da-DK"),
         "%x",
         "Danish catalog includes named utilada date format patterns");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.month1.long", "sv-SE"),
         "januari",
         "regional locales fall back to generated base-language date resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.relative.today", "de-DE"),
         "Heute",
         "German catalog includes date/time resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("number.decimal", "de-DE"),
         ",",
         "German catalog has decimal symbol");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("number.group", "de-DE"),
         ".",
         "German catalog has group symbol");
      Assert
        (Files.Localization.Text ("details.size.unit.mib", "de-DE") /= "details.size.unit.mib",
         "German catalog has generated digital unit labels");
   end Test_Detected_Locale_Catalogs;

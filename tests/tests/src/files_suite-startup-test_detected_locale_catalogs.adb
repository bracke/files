with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Files.Localization.Testing;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Guards;
separate (Files_Suite.Startup)
   procedure Test_Detected_Locale_Catalogs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "LC_ALL");
      Files_Suite.Support.Guards.Save (Environment, "LC_MESSAGES");
      Files_Suite.Support.Guards.Save (Environment, "LC_TIME");
      Files_Suite.Support.Guards.Save (Environment, "LC_NUMERIC");
      Files_Suite.Support.Guards.Save (Environment, "LANG");
      --  The environment the precedence walk leaves behind: only LANG set.
      Ada.Environment_Variables.Clear ("LC_MESSAGES");
      Ada.Environment_Variables.Clear ("LC_TIME");
      Ada.Environment_Variables.Clear ("LC_NUMERIC");
      Ada.Environment_Variables.Set ("LANG", "de_DE.UTF-8");
      Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");
      Files.Localization.Testing.Reread_Locale_Environment;
      Assert
        (Files.Localization.Text ("command.view.small") /= "Small Icons"
         and then Files.Localization.Text ("command.view.small") /= "command.view.small",
         "detected Danish locale loads translated app catalog resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.relative.today", Files.Localization.System_Time_Locale),
         "I dag",
         "detected Danish time locale uses date/time catalog resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.weekday.monday", "sv-SE"),
         Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("måndag"),
         "regional locales fall back to generated base-language date resources");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.relative.today", "de-DE"),
         "Heute",
         "German catalog includes date/time resources");
      Assert
        (Files.Localization.Text ("details.size.unit.bytes", "de-DE") /= "details.size.unit.bytes",
         "German catalog has generated digital unit labels");
      --  A region's own value wins over its language's even when it equals
      --  the English one: the catalog that defines the key decides, not
      --  whether its text looks like the default standing in. No shipped
      --  catalog has such a key any more, so the test writes its own.
      declare
         Share    : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "share-region");
         Base     : constant String := Files_Suite.Support.Disk.Join (Share, "files.catalog");
         Language : constant String := Files_Suite.Support.Disk.Join (Share, "files-zh.catalog");
         Region   : constant String := Files_Suite.Support.Disk.Join (Share, "files-zh-Hant.catalog");
      begin
         Files_Suite.Support.Disk.Reset_Root;
         Ada.Directories.Create_Path (Share);
         Files_Suite.Support.Disk.Write_File
           (Base, "en.probe.unit = MB" & ASCII.LF & "en.probe.other = Other" & ASCII.LF);
         Files_Suite.Support.Disk.Write_File
           (Language,
            "zh.probe.unit = " & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("兆字节") & ASCII.LF
            & "zh.probe.other = " & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("其他") & ASCII.LF);
         Files_Suite.Support.Disk.Write_File (Region, "zh-Hant.probe.unit = MB" & ASCII.LF);
         Files_Suite.Support.Assert_Equal
           (Files.Localization.Testing.Text_With_Shards (Base, Language, Region, "zh-Hant", "probe.unit"),
            "MB",
            "Traditional Chinese keeps its MB, the English text, not Chinese's own unit name");
         Files_Suite.Support.Assert_Equal
           (Files.Localization.Testing.Text_With_Shards (Base, Language, Region, "zh-Hant", "probe.other"),
            Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("其他"),
            "a key the region does not define takes the language's");
         Files_Suite.Support.Disk.Reset_Root;
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("time.weekday.monday", "es-ES"),
         Files.Localization.Text ("time.weekday.monday", "es"),
         "a region without its own value still takes its language's");
   end Test_Detected_Locale_Catalogs;

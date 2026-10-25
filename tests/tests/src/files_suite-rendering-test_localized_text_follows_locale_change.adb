separate (Files_Suite.Rendering)
   --  A Quick Look image preview carries the full-resolution decoded image (not
   --  the 64px thumbnail) and draws at its aspect ratio.
   --  Files.Localization.Text remembers the system locale and each rendered
   --  label, since the snapshot asks for labels on every rebuild. A change of
   --  the locale variables must still be seen at the next call.
   procedure Test_Localized_Text_Follows_Locale_Change (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Key         : constant String := "info.kind.directory";
      English     : constant String := Files.Localization.Text (Key, "en");
      German      : constant String := Files.Localization.Text (Key, "de-DE");
   begin
      Files_Suite.Support.Save (Environment, "LC_ALL");
      Files_Suite.Support.Save (Environment, "LC_MESSAGES");
      Files_Suite.Support.Save (Environment, "LANG");
      Assert (English /= German and then German /= Key, "the key reads differently in English and German");

      Ada.Environment_Variables.Set ("LC_ALL", "en_US.UTF-8");
      Files_Suite.Support.Assert_Equal (Files.Localization.Text (Key), English, "LC_ALL=en_US reads English");
      Files_Suite.Support.Assert_Equal (Files.Localization.Text (Key), English, "and again, now remembered");

      Ada.Environment_Variables.Set ("LC_ALL", "de_DE.UTF-8");
      Files_Suite.Support.Assert_Equal (Files.Localization.System_Locale, "de-DE", "the new LC_ALL is the locale");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text (Key), German, "a changed LC_ALL is picked up after the cache is warm");

      Ada.Environment_Variables.Clear ("LC_ALL");
      Ada.Environment_Variables.Set ("LC_MESSAGES", "en_GB.UTF-8");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text (Key), English, "clearing LC_ALL falls back to LC_MESSAGES at once");
   end Test_Localized_Text_Follows_Locale_Change;

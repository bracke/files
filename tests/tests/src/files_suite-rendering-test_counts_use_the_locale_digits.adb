with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Files.Rendering.Display_Text;
with Files_Suite.Support.Guards;
with Files.Localization.Testing;
separate (Files_Suite.Rendering)
   --  A count in the status bar is written as the number locale writes it --
   --  its digits and its grouping -- like the sizes beside it, so an Arabic
   --  window does not mix ١٤ and 14.
   procedure Test_Counts_Use_The_Locale_Digits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "LC_ALL");
      Files_Suite.Support.Guards.Save (Environment, "LC_NUMERIC");
      Files_Suite.Support.Guards.Save (Environment, "LANG");

      Ada.Environment_Variables.Set ("LC_ALL", "en_US.UTF-8");
      Files.Localization.Testing.Reread_Locale_Environment;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Display_Text.Grouped_Integer_Text (1_234_567), "1,234,567", "English");
      Ada.Environment_Variables.Set ("LC_ALL", "de_DE.UTF-8");
      Files.Localization.Testing.Reread_Locale_Environment;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Display_Text.Grouped_Integer_Text (1_234_567), "1.234.567", "German");
      Ada.Environment_Variables.Set ("LC_ALL", "ar_EG.UTF-8");
      Files.Localization.Testing.Reread_Locale_Environment;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Display_Text.Grouped_Integer_Text (14),
         Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("١٤"),
         "Egyptian Arabic writes Arabic-Indic digits");
   end Test_Counts_Use_The_Locale_Digits;

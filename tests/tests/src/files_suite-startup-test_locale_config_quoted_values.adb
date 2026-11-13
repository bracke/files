with Files.Localization.Testing;
separate (Files_Suite.Startup)
   --  locale.conf is shell syntax: a value may be quoted, LANG="de_DE.UTF-8"
   --  or LANG='de_DE.UTF-8', and is read without one pair of matching quotes.
   procedure Test_Locale_Config_Quoted_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LF   : constant Character := ASCII.LF;
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "locale.conf");

      function Value (Key : String) return String is (Files.Localization.Testing.Config_Value (Path, "", Key));
   begin
      Files_Suite.Support.Reset_Root;
      Files_Suite.Support.Write_File
        (Path,
         "LANG=""de_DE.UTF-8""" & LF
         & "LC_TIME='da_DK.UTF-8'" & LF
         & "LC_NUMERIC=fr_FR.UTF-8" & LF
         & "LC_MONETARY=""sv_SE.UTF-8'" & LF
         & "LC_PAPER=""""" & LF
         & "LC_NAME=""" & LF);
      Files_Suite.Support.Assert_Equal (Value ("LANG"), "de_DE.UTF-8", "double quotes are stripped");
      Files_Suite.Support.Assert_Equal (Value ("LC_TIME"), "da_DK.UTF-8", "single quotes are stripped");
      Files_Suite.Support.Assert_Equal (Value ("LC_NUMERIC"), "fr_FR.UTF-8", "an unquoted value is kept");
      Files_Suite.Support.Assert_Equal
        (Value ("LC_MONETARY"), """sv_SE.UTF-8'", "quotes that do not match are kept");
      Files_Suite.Support.Assert_Equal (Value ("LC_PAPER"), "", "an empty quoted value is empty");
      Files_Suite.Support.Assert_Equal (Value ("LC_NAME"), """", "a lone quote is no pair");
      Files_Suite.Support.Reset_Root;
   end Test_Locale_Config_Quoted_Values;

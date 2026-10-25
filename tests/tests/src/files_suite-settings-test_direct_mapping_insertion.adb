separate (Files_Suite.Settings)
   procedure Test_Direct_Mapping_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  Exercise the genuine missing-action lookups deterministically; the
      --  host opener fallback would otherwise resolve unmapped lookups.
      Manual.Use_System_Default_Opener := False;
      Files.Settings.Add_Extension_Mapping (Manual, ".TXT", "text/first");
      Files.Settings.Add_Extension_Mapping (Manual, " txt ", " text/second ");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "TXT"),
         "text/second",
         "direct extension mapping trims values and replaces existing entries");
      Files.Settings.Add_Extension_Mapping (Manual, ".", "text/blank");
      Files.Settings.Add_Extension_Mapping (Manual, "blank", "   ");
      Files.Settings.Add_Extension_Mapping (Manual, "bad=extension", "text/bad");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & ASCII.LF & "extension", "text/bad-key");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & ASCII.VT & "extension", "text/bad-vtab-key");
      Files.Settings.Add_Extension_Mapping (Manual, "bad" & C1_Break & "extension", "text/bad-c1-key");
      Files.Settings.Add_Extension_Mapping
        (Manual,
         "bad" & Line_Separator & "extension",
         "text/bad-unicode-key");
      Files.Settings.Add_Extension_Mapping (Manual, "linebreak", "text/plain" & ASCII.LF & "bad");
      Files.Settings.Add_Extension_Mapping (Manual, "formfeed", "text/plain" & ASCII.FF & "bad");
      Files.Settings.Add_Extension_Mapping (Manual, "c1break", "text/plain" & C1_Break & "bad");
      Files.Settings.Add_Extension_Mapping
        (Manual,
         "unicodebreak",
         "text/plain" & Line_Separator & "bad");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "."),
         "",
         "direct extension mapping ignores empty normalized extension");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "blank"),
         "",
         "direct extension mapping ignores empty filetype value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad=extension"),
         "",
         "direct extension mapping ignores unrepresentable extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.LF & "extension"),
         "",
         "direct extension mapping ignores line-break extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & ASCII.VT & "extension"),
         "",
         "direct extension mapping ignores vertical-tab extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & C1_Break & "extension"),
         "",
         "direct extension mapping ignores C1 line-break extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "bad" & Line_Separator & "extension"),
         "",
         "direct extension mapping ignores Unicode line-separator extension keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "linebreak"),
         "",
         "direct extension mapping ignores unrepresentable values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "formfeed"),
         "",
         "direct extension mapping ignores form-feed values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "c1break"),
         "",
         "direct extension mapping ignores C1 line-break values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "unicodebreak"),
         "",
         "direct extension mapping ignores Unicode line-separator values");
      Files.Settings.Add_Icon_Mapping (Manual, " text/second ", " first-icon ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/second", " second-icon ");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/second"),
         "second-icon",
         "direct icon mapping trims values and replaces existing entries");
      Files.Settings.Add_Icon_Mapping (Manual, "   ", "blank-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/blank-icon", "   ");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad=icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & ASCII.LF & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & ASCII.VT & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/bad" & C1_Break & "icon", "bad-icon");
      Files.Settings.Add_Icon_Mapping
        (Manual,
         "text/bad" & Line_Separator & "icon",
         "bad-icon");
      Files.Settings.Add_Icon_Mapping (Manual, "text/linebreak-icon", "icon" & ASCII.LF & "bad");
      Files.Settings.Add_Icon_Mapping (Manual, "text/formfeed-icon", "icon" & ASCII.FF & "bad");
      Files.Settings.Add_Icon_Mapping (Manual, "text/c1break-icon", "icon" & C1_Break & "bad");
      Files.Settings.Add_Icon_Mapping
        (Manual,
         "text/unicodebreak-icon",
         "icon" & Line_Separator & "bad");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, ""),
         "",
         "direct icon mapping ignores empty filetype key");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/blank-icon"),
         "",
         "direct icon mapping ignores empty icon value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad=icon"),
         "",
         "direct icon mapping ignores unrepresentable filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.LF & "icon"),
         "",
         "direct icon mapping ignores line-break filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & ASCII.VT & "icon"),
         "",
         "direct icon mapping ignores vertical-tab filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & C1_Break & "icon"),
         "",
         "direct icon mapping ignores C1 line-break filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/bad" & Line_Separator & "icon"),
         "",
         "direct icon mapping ignores Unicode line-separator filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/linebreak-icon"),
         "",
         "direct icon mapping ignores unrepresentable values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/formfeed-icon"),
         "",
         "direct icon mapping ignores form-feed values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/c1break-icon"),
         "",
         "direct icon mapping ignores C1 line-break values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/unicodebreak-icon"),
         "",
         "direct icon mapping ignores Unicode line-separator values");
   end Test_Direct_Mapping_Insertion;

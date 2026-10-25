separate (Files_Suite.Settings)
   procedure Test_Open_Action_Placeholder_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/full", Guikit.Input.No_Modifiers);
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/archive.tar.gz");
      Assert (Lookup.Found, "full placeholder action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "/tmp/example",
         "parent placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "archive.tar.gz",
         "name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "archive.tar",
         "stem placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "gz",
         "extension placeholder expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/.profile");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         ".profile",
         "dotfile name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         ".profile",
         "dotfile stem keeps leading-dot name");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "dotfile extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/name.");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "name.",
         "trailing-dot name placeholder expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "name.",
         "trailing-dot stem keeps final separator");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "trailing-dot extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "",
         "empty path parent expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "",
         "empty path name expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "",
         "empty path stem expands to empty");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "empty path extension expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "relative.txt");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         ".",
         "relative path parent expands to current directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "relative.txt",
         "relative path name expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "relative",
         "relative path stem expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "txt",
         "relative path extension expands");
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Expanded := Files.Settings.Expand_Placeholders
           (Lookup.Action, "/tmp/example/a\b.txt");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (1)),
            "/tmp/example",
            "a POSIX backslash filename keeps its real parent");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (2)), "a\b.txt",
            "a POSIX backslash remains part of name and stem placeholders (name)");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (3)), "a\b",
            "a POSIX backslash remains part of name and stem placeholders (stem)");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (4)), "txt",
            "a POSIX backslash remains part of name and stem placeholders (extension)");
      end if;
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "C:\tmp\dir.with.dots",
         "Windows path parent expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "Windows path name expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "main",
         "Windows path stem expands");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "adb",
         "Windows path extension expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "C:\",
         "Windows drive-root path parent keeps root separator");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "Windows drive-root path name expands");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "C:\tmp\dir.with.dots\file");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "Windows placeholder extension ignores dotted directory names");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\folder\main.adb");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "\\server\share\folder",
         "UNC placeholder parent expands without losing the share root");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "main.adb",
         "UNC placeholder name expands from the leaf");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "main",
         "UNC placeholder stem expands from the leaf");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "adb",
         "UNC placeholder extension expands from the leaf");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "\\server\share\");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "\\server\share\",
         "UNC share-root parent preserves the share root");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "",
         "UNC share-root name expands to empty");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/trailing/");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "/tmp/example",
         "trailing separator parent expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "trailing",
         "trailing separator name expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (3)),
         "trailing",
         "trailing separator stem expands from trimmed path");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (4)),
         "",
         "trailing separator extension expands to empty");
   end Test_Open_Action_Placeholder_Expansion;

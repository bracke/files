separate (Files_Suite.Settings)
   procedure Test_Open_Action_Fallback_And_Quoting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "missing modifier action falls back to unmodified filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada",
         "fallback token is unmodified filetype");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "fallback open action lookup trims filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada",
         "trimmed fallback token is unmodified filetype");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quoted",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "quoted open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "quoted editor",
         "quoted executable parses");
      Files_Suite.Support.Assert_Equal
        (Natural (Lookup.Action.Arguments.Length),
         2,
         "quoted arguments parse as separate values");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "--project file",
         "quoted argument preserves spaces");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada",
         "quoted placeholder expands as one argument");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada/");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada/",
         "path placeholder preserves trailing separator verbatim");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/quote-char",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "quote-containing open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "quote""runner",
         "quoted executable preserves doubled quote");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "arg "" inner",
         "quoted argument preserves doubled quote");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/equals",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "equals-containing open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "--flag=value",
         "equals-containing action argument parses");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (2)),
         "arg=two words",
         "quoted equals-containing action argument parses");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/empty-arg",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "empty quoted argument open action is found");
      Files_Suite.Support.Assert_Equal
        (Natural (Lookup.Action.Arguments.Length),
         2,
         "empty quoted argument does not end parsing");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "",
         "empty quoted argument is preserved");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (2)),
         "after-empty",
         "argument after empty quoted argument is preserved");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "explicit shell open action is found");
      Assert (Lookup.Action.Use_Shell, "explicit shell prefix is preserved");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "shell runner",
         "shell executable can be quoted");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "{name}",
         "shell action arguments are still parsed as a vector");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/shell.txt");
      Assert (Expanded.Use_Shell, "placeholder expansion preserves explicit shell flag");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Executable),
         "shell runner",
         "placeholder expansion preserves executable");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "shell.txt",
         "shell action placeholder expands");
      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/shell-upper",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "uppercase shell open action is found");
      Assert (Lookup.Action.Use_Shell, "uppercase shell prefix is normalized");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "upper-runner",
         "uppercase shell executable parses");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "unmodified non-shell open action is found");
      Assert (not Lookup.Action.Use_Shell, "shell execution is opt-in through explicit prefix");
   end Test_Open_Action_Fallback_And_Quoting;

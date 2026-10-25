separate (Files_Suite.Settings)
   procedure Test_Open_Action_Modifier_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      Modifiers (Guikit.Input.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/x-ada", Modifiers);
      Assert (Lookup.Found, "modifier-specific open action is found");
      Files_Suite.Support.Assert_Equal (To_String (Lookup.Token), "text/x-ada+control", "modifier token is normalized");
      Files_Suite.Support.Assert_Equal (To_String (Lookup.Action.Executable), "editor", "action executable parses");
      Files_Suite.Support.Assert_Equal (Natural (Lookup.Action.Arguments.Length), 2, "action arguments parse");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, " text/x-ada ", Modifiers);
      Assert (Lookup.Found, "open action lookup normalizes filetype whitespace");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/x-ada+control",
         "whitespace-normalized lookup preserves modifier token");

      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (2)),
         "/tmp/example/main.ada",
         "path placeholder expands as one argument");

      Modifiers := Guikit.Input.No_Modifiers;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "application/ld+json",
         "structured-suffix filetype token keeps plus suffix");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "json-viewer",
         "structured-suffix open action executable parses");
      Modifiers (Guikit.Input.Control_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "application/ld+json", Modifiers);
      Assert (Lookup.Found, "structured-suffix modifier-specific open action is found");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "application/ld+json+control",
         "structured-suffix modifier token appends after filetype suffix");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "json-editor",
         "structured-suffix modifier-specific executable parses");
   end Test_Open_Action_Modifier_Lookup;

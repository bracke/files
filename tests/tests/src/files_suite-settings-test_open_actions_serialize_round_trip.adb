separate (Files_Suite.Settings)
   procedure Test_Open_Actions_Serialize_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup : Files.Settings.Action_Lookup_Result;
   begin
      declare
         Serialized : constant String := Files.Settings.To_Text (Parsed.Settings);
         Reloaded   : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Serialized);
      begin
         Assert (Reloaded.Success, "serialized settings text parses");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quoted", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized quoted action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "quoted editor",
            "serialized quoted action preserves executable spaces");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "--project file",
            "serialized quoted action preserves spaced argument");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (2)),
            "{path}",
            "serialized quoted action preserves placeholder argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/equals", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized equals-containing action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "--flag=value",
            "serialized open action preserves equals argument");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (2)),
            "arg=two words",
            "serialized open action preserves quoted equals argument");
         Lookup :=
           Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/quote-char", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized quote-containing action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "quote""runner",
            "serialized open action preserves executable quote");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "arg "" inner",
            "serialized open action preserves argument quote");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Reloaded.Settings, "text/empty-arg", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized empty-argument action reloads");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Arguments.Element (1)),
            "",
            "serialized open action preserves empty argument");
         Lookup := Files.Settings.Lookup_Open_Action (Reloaded.Settings, "text/shell", Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "serialized shell action reloads");
         Assert (Lookup.Action.Use_Shell, "serialized shell action preserves shell opt-in");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "shell runner",
            "serialized shell action preserves quoted executable");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "quote"),
            "text/""quoted",
            "serialized filetype mapping preserves quote");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Reloaded.Settings, "eq"),
            "text/with=equals",
            "serialized filetype mapping preserves equals");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-quote"),
            "quote""icon",
            "serialized icon mapping preserves quote");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Reloaded.Settings, "text/x-equals"),
            "icon=equals",
            "serialized icon mapping preserves equals");
      end;
      declare
         Odd_Settings : Files.Settings.Settings_Model := Parsed.Settings;
         Odd_Text     : Unbounded_String;
         Expected     : constant String :=
           "icon_theme = " & '"' & "files " & '"' & '"' & "basic" & '"';
      begin
         Odd_Settings.Icon_Theme_Name := To_Unbounded_String ("files ""basic");
         Odd_Text := To_Unbounded_String (Files.Settings.To_Text (Odd_Settings));
         Assert
           (Ada.Strings.Fixed.Index (To_String (Odd_Text), Expected) > 0,
            "serialized icon theme quotes embedded quote");
      end;
   end Test_Open_Actions_Serialize_Round_Trip;

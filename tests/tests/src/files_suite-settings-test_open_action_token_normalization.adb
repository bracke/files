separate (Files_Suite.Settings)
   procedure Test_Open_Action_Token_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
   begin
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/mixed", Modifiers);
      Assert (Lookup.Found, "settings modifier token is normalized on insertion");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/mixed+control+alt",
         "lookup token uses normalized modifier order");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "mixed",
         "normalized settings action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/spaced", Modifiers);
      Assert (Lookup.Found, "settings modifier token trims spaces around separators");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/spaced+control+alt",
         "spaced modifier token is normalized on lookup");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "spaced",
         "spaced modifier action is returned");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/duplicate", Modifiers);
      Assert (Lookup.Found, "duplicate settings modifiers are normalized on insertion");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/duplicate+control+alt",
         "duplicate modifier token is deduplicated and ordered");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "duplicate",
         "deduplicated settings action is returned");

      declare
         Normalized_Draft_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Normalized_Draft          : Files.Settings.Settings_Draft;
         Normalized_Load           : Files.Settings.Settings_Parse_Result;
         Normalized_Args           : Files.Types.String_Vectors.Vector;
      begin
         Normalized_Args.Append (To_Unbounded_String ("{path}"));
         Files.Settings.Add_Open_Action
           (Normalized_Draft_Settings,
            "text/plain+control+alt",
            Files.Settings.Make_Action ("existing", Normalized_Args));
         Normalized_Draft := Files.Settings.Make_Draft (Normalized_Draft_Settings);
         Normalized_Draft.Filetype_Extension := To_Unbounded_String (" .TXT ");
         Normalized_Draft.Filetype_Value := To_Unbounded_String ("text/x-overridden");
         Normalized_Draft.Icon_Filetype := To_Unbounded_String (" text/plain ");
         Normalized_Draft.Icon_Value := To_Unbounded_String ("text-updated");
         Normalized_Draft.Open_Action_Token := To_Unbounded_String (" text/plain + ALT + control ");
         Normalized_Draft.Open_Action_Command := To_Unbounded_String ("editor {path}");
         Normalized_Load := Files.Settings.Apply_Draft (Normalized_Draft_Settings, Normalized_Draft);
         Assert (Normalized_Load.Success, "normalized draft mapping replacement applies");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Normalized_Load.Settings, "txt"),
            "text/x-overridden",
            "normalized draft extension replaces existing row");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Normalized_Load.Settings, "text/plain"),
            "text-updated",
            "trimmed draft icon key replaces existing row");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Normalized_Load.Settings,
              "text/plain",
              [Guikit.Input.Control_Key | Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "normalized draft action lookup succeeds");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "editor",
            "normalized draft action replaces existing row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Extension_Filetypes.Length),
            Natural (Normalized_Draft_Settings.Extension_Filetypes.Length),
            "normalized draft extension replacement does not add a duplicate row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Icon_Mappings.Length),
            Natural (Normalized_Draft_Settings.Icon_Mappings.Length),
            "normalized draft icon replacement does not add a duplicate row");
         Files_Suite.Support.Assert_Equal
           (Natural (Normalized_Load.Settings.Open_Actions.Length),
            Natural (Normalized_Draft_Settings.Open_Actions.Length),
            "normalized draft action replacement does not add a duplicate row");

         Normalized_Draft.Open_Action_Token := To_Unbounded_String (" application/ld+json + control ");
         Normalized_Draft.Open_Action_Command := To_Unbounded_String ("json-editor {path}");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Field_Diagnostic (12, "application/ld+json+control"),
            "",
            "settings field accepts structured-suffix modifier tokens");
         Assert
           (Files.Settings.Validate_Draft (Normalized_Draft).Success,
            "draft validates structured-suffix modifier action");
         Normalized_Load := Files.Settings.Apply_Draft (Normalized_Draft_Settings, Normalized_Draft);
         Assert (Normalized_Load.Success, "draft applies structured-suffix modifier action");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Normalized_Load.Settings,
              "application/ld+json",
              [Guikit.Input.Control_Key => True, others => False]);
         Assert (Lookup.Found, "draft structured-suffix modifier action lookup succeeds");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Token),
            "application/ld+json+control",
            "draft structured-suffix modifier action token is normalized");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "draft structured-suffix modifier action executable parses");
      end;

      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing open action is represented as lookup data");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/missing+shift+meta",
         "missing open action records normalized attempted token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Error_Key),
         "error.open_action.missing",
         "missing open action reports deterministic diagnostic key");
      Modifiers (Guikit.Input.Control_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "text/missing", Modifiers);
      Assert (not Lookup.Found, "missing full-modifier open action is represented as lookup data");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/missing+shift+control+alt+meta",
         "missing open action records full normalized modifier order");
      Lookup := Files.Settings.Lookup_Open_Action (Parsed.Settings, "   ", Modifiers);
      Assert (not Lookup.Found, "empty filetype open action lookup is missing");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "",
         "empty filetype lookup reports no modifier-only token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Error_Key),
         "error.open_action.missing",
         "empty filetype lookup reports deterministic diagnostic key");
   end Test_Open_Action_Token_Normalization;

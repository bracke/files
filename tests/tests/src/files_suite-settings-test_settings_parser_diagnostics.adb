separate (Files_Suite.Settings)
   procedure Test_Settings_Parser_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Text   : Unbounded_String := To_Unbounded_String ("[bookmarks]" & ASCII.LF);
         Parsed : Files.Settings.Settings_Parse_Result;
      begin
         for Index in 1 .. 4_097 loop
            Append (Text, "bookmark = /tmp/item" & Natural'Image (Index) & ASCII.LF);
         end loop;
         Parsed := Files.Settings.Parse (To_String (Text));
         Assert
           (not Parsed.Success
            and then To_String (Parsed.Error_Key) = "error.settings.invalid",
            "settings parsing caps the number of persistent entries");
      end;
      declare
         Broken : Files.Settings.Settings_Parse_Result;
      begin
         Broken := Files.Settings.Parse ("[unknown]" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown sections");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.unknown_section",
            "unknown section reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries without equals");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.expected_equals",
            "missing equals reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("default_view_mode = details" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects entries before any section");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.missing_section",
            "missing section reports deterministic diagnostic");
         Broken := Files.Settings.Parse
           ("[settings]" & ASCII.LF
            & "show_hidden_files = true" & Character'Val (0) & "ignored"
            & ASCII.LF);
         Assert
           (not Broken.Success
            and then To_String (Broken.Error_Key) = "error.settings.invalid",
            "settings parser rejects embedded NUL bytes before interpreting fields");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & ". = text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty normalized extensions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "empty extension mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = ""text/plain" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unterminated quoted mappings");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "unterminated mapping quote reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[icons]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty icon mappings");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "empty icon mapping reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain = viewer prefix-{path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects embedded open-action placeholders");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "embedded placeholder reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/plain+control+ = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects trailing open-action modifier separator");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "trailing modifier separator reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "default_view_mode = compact" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown view mode values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_view_mode",
            "unknown view mode reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "icon_theme = neon" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown icon themes");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_icon_theme",
            "unknown icon theme reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "show_hidden_files = maybe" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid boolean values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_boolean",
            "invalid boolean reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[filetypes]" & ASCII.LF & "txt = text/plain" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break mapping values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "C1 line-break mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[filetypes]" & ASCII.LF & "txt = text/plain" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator mapping values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_mapping",
            "Unicode line-separator mapping value reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF & "text/c1 = viewer {path}" & C1_Break & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects C1 line-break open actions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "C1 line-break open action reports deterministic diagnostic");
         Broken :=
           Files.Settings.Parse
             ("[open-actions]" & ASCII.LF &
              "text/unicode = viewer {path}" & Line_Separator & "bad" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects Unicode line-separator open actions");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "Unicode line-separator open action reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = bogus" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects invalid sort fields");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_sort_field",
            "invalid sort field reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[settings]" & ASCII.LF & "unexpected = value" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown setting keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.unknown_key",
            "unknown setting key reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain+hyper = viewer {path}" & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects unknown open-action modifiers");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "unknown open-action modifier reports deterministic diagnostic");
         Broken := Files.Settings.Parse ("[open-actions]" & ASCII.LF & "text/plain =   " & ASCII.LF);
         Assert (not Broken.Success, "settings parser rejects empty open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken.Error_Key),
            "error.settings.invalid_open_action",
            "empty open-action command reports deterministic diagnostic");
      end;
   end Test_Settings_Parser_Diagnostics;

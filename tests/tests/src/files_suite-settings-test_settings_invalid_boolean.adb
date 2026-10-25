separate (Files_Suite.Settings)
   procedure Test_Settings_Invalid_Boolean (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bad_Path : constant String := Join (Root, "bad.conf");
      Bad      : Files.Settings.Settings_Parse_Result;
      Bad_Open : Files.Settings.Settings_Parse_Result;
      Bad_Tail : Files.Settings.Settings_Parse_Result;

      procedure Assert_Parse_Error
        (Text      : String;
         Error_Key : String;
         Message   : String)
      is
         Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
      begin
         Assert (not Parsed.Success, Message);
         Files_Suite.Support.Assert_Equal (To_String (Parsed.Error_Key), Error_Key, Message & " diagnostic key");
      end Assert_Parse_Error;
   begin
      Reset_Root;
      Write_File
        (Bad_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = maybe" & ASCII.LF);
      Bad := Files.Settings.Load_File (Bad_Path);
      Assert (not Bad.Success, "invalid boolean setting is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad.Error_Key),
         "error.settings.invalid_boolean",
         "invalid boolean reports a deterministic diagnostic key");

      Bad_Open :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""unterminated" & ASCII.LF);
      Assert (not Bad_Open.Success, "unterminated quoted open action is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad_Open.Error_Key),
         "error.settings.invalid_open_action",
         "unterminated quoted open action reports deterministic diagnostic key");

      Bad_Tail :=
        Files.Settings.Parse
          ("[open-actions]" & ASCII.LF &
           "text/plain = ""editor""junk {path}" & ASCII.LF);
      Assert (not Bad_Tail.Success, "quoted open action rejects trailing junk");
      Files_Suite.Support.Assert_Equal
        (To_String (Bad_Tail.Error_Key),
         "error.settings.invalid_open_action",
         "quoted open action trailing junk reports deterministic diagnostic key");

      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = edit""or {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unquoted open-action executable quote is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor ar""g" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unquoted open-action argument quote is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain =" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open action executable is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         " = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open action key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         """text/quoted-action"" = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "quoted open-action filetype key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "[text/bracketed-action] = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "bracketed open-action filetype key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "+control = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "modifier-only open action key is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+custom = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "unknown open-action modifier is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+ = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "dangling open-action modifier separator is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain+control+ = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "trailing open-action modifier separator is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain++control = editor {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "empty open-action modifier segment is rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor prefix-{path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "embedded open-action placeholders are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action executable placeholders are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = edit" & ASCII.VT & "or {path}" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action executable vertical tabs are rejected");
      Assert_Parse_Error
        ("[open-actions]" & ASCII.LF &
         "text/plain = editor arg" & ASCII.FF & "value" & ASCII.LF,
         "error.settings.invalid_open_action",
         "open-action argument form feeds are rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         " = text/plain" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty filetype extension mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt =" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty filetype value mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt = ""unterminated" & ASCII.LF,
         "error.settings.invalid_mapping",
         "unterminated quoted filetype mapping is rejected");
      Assert_Parse_Error
        ("[filetypes]" & ASCII.LF &
         "txt = ""text/plain""junk" & ASCII.LF,
         "error.settings.invalid_mapping",
         "quoted filetype mapping with trailing junk is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain =" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty icon mapping value is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         " = text" & ASCII.LF,
         "error.settings.invalid_mapping",
         "empty icon mapping key is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain = ""unterminated" & ASCII.LF,
         "error.settings.invalid_mapping",
         "unterminated quoted icon mapping is rejected");
      Assert_Parse_Error
        ("[icons]" & ASCII.LF &
         "text/plain = ""text""junk" & ASCII.LF,
         "error.settings.invalid_mapping",
         "quoted icon mapping with trailing junk is rejected");
      Assert_Parse_Error
        ("[unknown]" & ASCII.LF,
         "error.settings.unknown_section",
         "unknown settings section is rejected");
      Assert_Parse_Error
        ("[]" & ASCII.LF,
         "error.settings.unknown_section",
         "empty settings section name is rejected");
      Assert_Parse_Error
        ("[settings" & ASCII.LF,
         "error.settings.expected_equals",
         "unterminated settings section header is rejected");
      Assert_Parse_Error
        ("orphan = value" & ASCII.LF,
         "error.settings.missing_section",
         "settings entry before section is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "default_view_mode details" & ASCII.LF,
         "error.settings.expected_equals",
         "settings entry without equals is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "default_view_mode = tiled" & ASCII.LF,
         "error.settings.invalid_view_mode",
         "invalid view mode is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "unknown_key = true" & ASCII.LF,
         "error.settings.unknown_key",
         "unknown settings key is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_directories_first = false" & ASCII.LF,
         "error.settings.unknown_key",
         "removed sort-directories setting is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_field = random" & ASCII.LF,
         "error.settings.invalid_sort_field",
         "invalid sort field is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "sort_ascending = maybe" & ASCII.LF,
         "error.settings.invalid_boolean",
         "invalid sort direction boolean is rejected");
      Assert_Parse_Error
        ("[settings]" & ASCII.LF & "icon_theme = neon" & ASCII.LF,
         "error.settings.invalid_icon_theme",
         "invalid icon theme is rejected");
   end Test_Settings_Invalid_Boolean;

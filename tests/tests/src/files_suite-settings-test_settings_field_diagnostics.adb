separate (Files_Suite.Settings)
   procedure Test_Settings_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "details"),
         "",
         "settings field validates view mode");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "bad"),
         "error.settings.invalid_view_mode",
         "settings field reports invalid view mode");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (1, "details" & ASCII.LF & "large"),
         "error.settings.invalid_view_mode",
         "view-mode field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "true"),
         "",
         "settings field validates boolean");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "maybe"),
         "error.settings.invalid_boolean",
         "settings field reports invalid boolean");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (2, "true" & ASCII.LF & "false"),
         "error.settings.invalid_boolean",
         "boolean field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (5, "light"),
         "",
         "settings field validates theme value");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (5, "sepia"),
         "error.settings.invalid_theme",
         "settings field reports invalid theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (6, "files-basic"),
         "",
         "settings field validates icon theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (6, "unknown-theme"),
         "error.settings.invalid_icon_theme",
         "settings field reports invalid icon theme");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (3, "modified"),
         "",
         "settings field validates sort field");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (3, "date"),
         "error.settings.invalid_sort_field",
         "settings field reports invalid sort field");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/""quoted"),
         "",
         "filetype value field accepts raw quote-containing values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (7, "bad=extension"),
         "error.settings.invalid_mapping",
         "filetype extension field rejects unrepresentable keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & ASCII.LF & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & C1_Break & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects C1 line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (8, "text/plain" & Line_Separator & "bad"),
         "error.settings.invalid_mapping",
         "mapping value field rejects Unicode line separators");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (10, "quote""icon"),
         "",
         "icon value field accepts raw quote-containing values");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (9, "text/bad=icon"),
         "error.settings.invalid_mapping",
         "icon filetype field rejects unrepresentable keys");
   end Test_Settings_Field_Diagnostics;

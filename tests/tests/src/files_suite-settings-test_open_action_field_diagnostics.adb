separate (Files_Suite.Settings)
   procedure Test_Open_Action_Field_Diagnostics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain+control"),
         "",
         "action token field validates");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "+control"),
         "error.settings.invalid_open_action",
         "action token field reports invalid action token");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/bad=action"),
         "error.settings.invalid_open_action",
         "action token field rejects unrepresentable filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, """text/quoted-action"""),
         "error.settings.invalid_open_action",
         "action token field rejects quoted filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "[text/bracketed-action]"),
         "error.settings.invalid_open_action",
         "action token field rejects bracketed filetype keys");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain+control+"),
         "error.settings.invalid_open_action",
         "action token field reports trailing modifier separator");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (11, "text/plain" & ASCII.LF & "text/html"),
         "error.settings.invalid_open_action",
         "action token field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}"),
         "",
         "action command field validates");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """quoted editor"" ""--project file"" ""{path}"""),
         "",
         "action command field validates quoted tokens");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """quote""""runner"" ""arg """" inner"""),
         "",
         "action command field validates doubled quotes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "runner """" after-empty"),
         "",
         "action command field validates empty quoted argument");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer prefix-{path}"),
         "error.settings.invalid_open_action",
         "action command field reports embedded placeholder");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & ASCII.LF & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & Character'Val (0) & "ignored"),
         "error.settings.invalid_open_action",
         "action command field rejects embedded NUL bytes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & C1_Break & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects C1 line breaks");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, "viewer {path}" & Line_Separator & "other"),
         "error.settings.invalid_open_action",
         "action command field rejects Unicode line separators");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """unterminated"),
         "error.settings.invalid_open_action",
         "action command field reports unterminated quote");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (12, """editor""junk {path}"),
         "error.settings.invalid_open_action",
         "action command field reports quoted token trailing junk");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (0, "details"),
         "error.settings.invalid",
         "unknown settings field reports a deterministic diagnostic");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Field_Diagnostic (13, "details"),
         "error.settings.invalid",
         "out-of-range settings field reports a deterministic diagnostic");
      declare
         Command : Unbounded_String := To_Unbounded_String ("viewer");
      begin
         for Index in 1 .. 257 loop
            Append (Command, " argument" & Natural'Image (Index));
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Field_Diagnostic (12, To_String (Command)),
            "error.settings.invalid_open_action",
            "open actions with an excessive argument vector are rejected");
      end;
   end Test_Open_Action_Field_Diagnostics;

separate (Files_Suite.Settings)
   procedure Test_Draft_Mapping_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : constant Files.Settings.Settings_Model := Settings_With_Direct_Insertions;
   begin
      declare
         Quote_Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Manual);
         Applied     : Files.Settings.Settings_Parse_Result;
      begin
         Quote_Draft.Filetype_Extension := To_Unbounded_String ("quote");
         Quote_Draft.Filetype_Value := To_Unbounded_String ("text/""quoted");
         Quote_Draft.Icon_Filetype := To_Unbounded_String ("text/""quoted");
         Quote_Draft.Icon_Value := To_Unbounded_String ("quote""icon");
         Assert (Files.Settings.Validate_Draft (Quote_Draft).Success, "quote-containing draft validates");
         Applied := Files.Settings.Apply_Draft (Manual, Quote_Draft);
         Assert (Applied.Success, "quote-containing draft applies");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Applied.Settings, "quote"),
            "text/""quoted",
            "quote-containing draft preserves filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Applied.Settings, "text/""quoted"),
            "quote""icon",
            "quote-containing draft preserves icon mapping");
      end;
      declare
         Broken_Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Load  : Files.Settings.Settings_Parse_Result;
      begin
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are rejected");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid",
            "mismatched draft mapping vectors report deterministic diagnostic");
         Broken_Load := Files.Settings.Apply_Draft (Manual, Broken_Draft);
         Assert (not Broken_Load.Success, "mismatched draft mapping vectors are not applied");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Extension := To_Unbounded_String ("bad=extension");
         Broken_Draft.Filetype_Value := To_Unbounded_String ("text/bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable filetype key");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "current unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("bad=extension"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft filetype key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Filetype := To_Unbounded_String ("text/bad=icon");
         Broken_Draft.Icon_Value := To_Unbounded_String ("bad");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unrepresentable icon key");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "current unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/bad=icon"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft icon key reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("text/plain+hyper");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current unknown open-action modifier");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "current unknown open-action modifier reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("+control");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects current modifier-only open-action token");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "current modifier-only open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/bad=action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "unrepresentable draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Token := To_Unbounded_String ("""text/quoted-action""");
         Broken_Draft.Open_Action_Command := To_Unbounded_String ("viewer {path}");
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects quoted open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "quoted draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("[text/bracketed-action]"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects bracketed open-action keys");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "bracketed draft open-action key reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("+control"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects stored modifier-only open-action tokens");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "stored modifier-only draft open-action token reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("linebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable filetype values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Icon_Keys.Append (To_Unbounded_String ("text/linebreak-value"));
         Broken_Draft.Icon_Values.Append (To_Unbounded_String ("icon" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable icon values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "unrepresentable draft icon value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Filetype_Keys.Append (To_Unbounded_String ("unicodebreak-value"));
         Broken_Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator filetype values");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_mapping",
            "Unicode line-separator draft filetype value reports mapping diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/linebreak-action"));
         Broken_Draft.Open_Action_Commands.Append (To_Unbounded_String ("viewer {path}" & ASCII.LF & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects unrepresentable open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "unrepresentable draft open-action command reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append
           (To_Unbounded_String ("text/nul-action"));
         Broken_Draft.Open_Action_Commands.Append
           (To_Unbounded_String
              ("viewer {path}" & Character'Val (0) & "ignored"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert
           (not Broken_Load.Success,
            "draft rejects NUL-containing open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "NUL-containing draft action reports open-action diagnostic");
         Broken_Draft := Files.Settings.Make_Draft (Manual);
         Broken_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/unicodebreak-action"));
         Broken_Draft.Open_Action_Commands.Append
           (To_Unbounded_String ("viewer {path}" & Line_Separator & "bad"));
         Broken_Load := Files.Settings.Validate_Draft (Broken_Draft);
         Assert (not Broken_Load.Success, "draft rejects Unicode line-separator open-action commands");
         Files_Suite.Support.Assert_Equal
           (To_String (Broken_Load.Error_Key),
            "error.settings.invalid_open_action",
            "Unicode line-separator draft open-action command reports open-action diagnostic");
      end;
   end Test_Draft_Mapping_Validation;

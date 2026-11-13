separate (Check_All)
   procedure Check_Localization_Usage is
      Main_Manifest : constant String := Root & "/alire.toml";
      Localization  : constant String := Root & "/src/files-localization.adb";
      Check_Source  : constant String := Combined_Check_All;
   begin
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = ""^1.1.0""",
         "files must depend on the i18n crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "if Literal = ""cd /d """ & ASCII.LF
         & "        or else Literal = ""cd """,
         "hard-coded text checks must keep terminal shell-verb exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "function Diagnostic_Pragma_Length",
         "hard-coded text checks must exempt developer-diagnostic pragma messages");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "if Literal = ""untitled """,
         "hard-coded text checks must keep create-file name template exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""untitled.txt""",
         "hard-coded text checks must keep default create-file name exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""[Trash Info]""" & ASCII.LF
         & "        or else Literal = ""Path=""" & ASCII.LF
         & "        or else Literal = ""DeletionDate=""",
         "hard-coded text checks must keep trashinfo metadata exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""default_view_mode = """ & ASCII.LF
         & "        or else Literal = ""show_hidden_files = """ & ASCII.LF
         & "        or else Literal = ""sort_field = """ & ASCII.LF
         & "        or else Literal = ""sort_ascending = """ & ASCII.LF
         & "        or else Literal = ""high_contrast_theme = """ & ASCII.LF
         & "        or else Literal = ""icon_theme = """,
         "hard-coded text checks must keep settings syntax exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then Key /= ""settings.conf""" & ASCII.LF
         & "        and then not Contains (Key, ""|"")",
         "indirect localization key checks must ignore settings filenames");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then not Contains (Key, ""|"")",
         "indirect localization key checks must ignore structured metadata tokens");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then Name /= ""files-commands.adb""",
         "indirect localization key checks must not treat stable command identifiers as catalog keys");

      Check_No_User_Text_Literals_In_Source_Tree (Root & "/src");
      Check_Catalog_Unique_Keys;
      Check_Catalog_Format;
      Check_Catalog_Baseline_Keys;
      Check_Error_Localization_Test_Coverage;
      Require_Registered_Routine
        ("Test_Localization_Runtime_Labels",
         "the test of startup, runtime-smoke and CLI help labels");
      Require_Registered_Routine
        ("Test_Startup_And_Runtime_Smoke_Reports",
         "the test of the startup and runtime smoke reports");
      Require_Registered_Routine
        ("Test_Detected_Locale_Catalogs",
         "the test of translated locale catalog loading");
      --  The per-host locale calls, and the frameworks they need, are Hostkit's
      --  now and are guarded by check_hostkit's Require_Binding (verified there
      --  by a negative test, after this comment was written while that guard did
      --  not yet exist). What has to stay true here is that
      --  files asks the host one question rather than branching per OS on its
      --  way to the environment fallbacks.
      Require_Registered_Routine
        ("Test_Host_Locale_Fallbacks",
         "the test of asking the host for its locale");
      Require_Registered_Routine
        ("Test_Localization_Pane_Labels",
         "the test of pane, status and landmark labels");
      Require_Registered_Routine
        ("Test_Localization_Error_And_Command_Keys",
         "the test of error keys and command names and descriptions");
      Check_Command_Localization_Keys;
      Check_Indirect_Localization_Keys_In_Tree (Root & "/src");
      Check_Direct_Localization_Call_Keys_In_Tree (Root & "/src");
   end Check_Localization_Usage;

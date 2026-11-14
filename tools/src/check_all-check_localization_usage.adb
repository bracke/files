separate (Check_All)
   procedure Check_Localization_Usage is
      Main_Manifest : constant String := Root & "/alire.toml";
      Localization  : constant String := Root & "/src/files-localization.adb";
      Check_Source  : constant String := Combined_Check_All;

      --  Path's code, comments dropped and strings blanked, must say Pattern
      --  (a name, no quotes): searched in the raw text, a guard's pattern
      --  would satisfy itself, as its own literal is part of check_all's
      --  source.
      procedure Require_In_Code (Path : String; Pattern : String; Message : String) is
      begin
         if not Project_Tools.Files.File_Exists (Path)
           or else Ada.Strings.Fixed.Index
                     (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True),
                      Pattern) = 0
         then
            Put_Line (Standard_Error, Path & ": " & Message);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_In_Code;
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
      Require_In_Code
        (Check_Source,
         "function Diagnostic_Pragma_Length",
         "hard-coded text checks must exempt developer-diagnostic pragma messages");
      Require_In_Code
        (Root & "/tools/src/check_all-check_no_user_text_literals.adb",
         "Diagnostic_Pragma_Length (",
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
         "Except => ""files-commands.adb""",
         "indirect localization key checks must not treat stable command identifiers as catalog keys");

      For_Each_Ada_Source (Root & "/src", Check_No_User_Text_Literals'Access, Except => "files-localization.adb");
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
      For_Each_Ada_Source
        (Root & "/src", Check_Indirect_Localization_Keys_In_File'Access, Except => "files-commands.adb");
      For_Each_Ada_Source (Root & "/src", Check_Direct_Localization_Call_Keys_In_File'Access);
   end Check_Localization_Usage;

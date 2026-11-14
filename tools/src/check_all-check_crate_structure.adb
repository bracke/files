separate (Check_All)
   procedure Check_Crate_Structure is
      Main_Manifest  : constant String := Root & "/alire.toml";
      Top_Tests_Manifest : constant String := Root & "/tests/alire.toml";
      Tools_Manifest : constant String := Root & "/tools/alire.toml";
      Main_Project   : constant String := Root & "/files.gpr";
      Top_Tests_Project : constant String := Root & "/tests/tests.gpr";
      Tools_Project  : constant String := Root & "/tools/files_check_all.gpr";
      Main_Ignore    : constant String := Root & "/.gitignore";
      Top_Tests_Ignore : constant String := Root & "/tests/.gitignore";
      Tools_Ignore   : constant String := Root & "/tools/.gitignore";
   begin
      Require_Present
        ([To_Unbounded_String (Main_Project),
          To_Unbounded_String (Top_Tests_Manifest),
          To_Unbounded_String (Top_Tests_Project),
          To_Unbounded_String (Tools_Manifest),
          To_Unbounded_String (Tools_Project),
          To_Unbounded_String (Root & "/tools/src/check_all.adb"),
          To_Unbounded_String (Root & "/tools/src/cldr_to_catalog.adb"),
          To_Unbounded_String (Main_Ignore),
          To_Unbounded_String (Top_Tests_Ignore),
          To_Unbounded_String (Tools_Ignore)],
         "files checker tooling must be implemented as an Ada Alire helper crate");
      Require_In_Text
        (Main_Manifest,
         "name = ""files""",
         "files must be the main Alire crate");
      Require_In_Text
        (Main_Manifest,
         "executables = [""files""]",
         "files crate must build the files executable");
      Require_In_Text
        (Main_Manifest,
         "guikit = ""^0.1.0""",
         "files must depend on the guikit crate");
      Require_In_Text
        (Main_Manifest,
         "guikit = { path = ""../guikit"" }",
         "files must pin guikit to the local relative crate");
      Require_In_Text
        (Main_Manifest,
         "i18n = ""^1.1.0""",
         "files must depend on the i18n crate");
      Require_In_Text
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Require_In_Text
        (Main_Manifest,
         "textrender = ""^1.0.0""",
         "files must depend on the textrender crate");
      Require_In_Text
        (Main_Manifest,
         "textrender = { path = ""../textrender"" }",
         "files must pin textrender to the local relative crate");
      Require_In_Text
        (Main_Manifest,
         "df_vulkan = ",
         "files must depend on df_vulkan for rendering");
      Require_In_Text
        (Main_Manifest,
         "openglada_glfw = ",
         "files must depend on openglada_glfw for windowing");
      Require_In_Text
        (Main_Project,
         "for Source_Dirs use (""src/"", ""config/"");",
         "files project must build one source list for every host");
      Require_In_Text
        (Main_Project,
         "for Main use (""files-main.adb"");",
         "files project must build the Ada main program");
      Require_In_Text
        (Main_Project,
         "for Executable (""files-main.adb"") use ""files"";",
         "files project must produce the expected files executable");
      Require_In_Text
        (Main_Project,
         """-gnat2022""",
         "files project must compile as Ada 2022");
      Require_In_Text
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level tests build"", Root & ""/tests"", Alr, [1 => new String'(""build"")]);",
         "full validation must build the top-level tests sub-crate");
      Require_In_Text
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level AUnit tests"", Root & ""/tests"", ""./bin/tests"", []);",
         "full validation must run the top-level tests sub-crate");
      Require_In_Text
        (Top_Tests_Manifest,
         "files = ""^0.1.0""",
         "top-level tests sub-crate must depend on the files crate");
      Require_In_Text
        (Top_Tests_Manifest,
         "files = { path = "".."" }",
         "top-level tests sub-crate must pin the parent files crate by local relative path");
      Require_In_Text
        (Top_Tests_Manifest,
         "aunit = ",
         "top-level tests sub-crate must depend on AUnit");
      Require_In_Text
        (Top_Tests_Project,
         "for Source_Dirs use (""tests/src/""",
         "top-level tests sub-crate must build the AUnit suite sources");
      Require_In_Text
        (Top_Tests_Project,
         "for Main use (""tests.adb""",
         "top-level tests sub-crate must build the AUnit runner");
      Require_In_Text
        (Top_Tests_Project,
         """noop.adb""",
         "the suite must ship the no-op program its open-action tests launch");
      Require_In_Text
        (Top_Tests_Project,
         """failing.adb""",
         "the suite must ship the failing program its open-action tests launch");
      Require_In_Text
        (Tools_Manifest,
         "name = ""files_check_all""",
         "checker tooling must be a named Alire crate");
      Require_In_Text
        (Tools_Manifest,
         "executables = [""check_all"", ""cldr_to_catalog""]",
         "checker tooling crate must build all Ada helper executables");
      Require_In_Text
        (Tools_Manifest,
         "project_tools = ""^0.1.0""",
         "checker tooling must depend on the project_tools crate");
      Require_In_Text
        (Tools_Manifest,
         "project_tools = { path = ""../../project_tools"" }",
         "checker tooling must pin project_tools to the local relative crate");
      Require_In_Text
        (Tools_Project,
         "for Main use (""check_all.adb"", ""cldr_to_catalog.adb"", ""release_check.adb"");",
         "checker tooling project must build Ada tool mains");
      Require_In_Text
        (Tools_Project,
         "for Executable (""check_all.adb"") use ""check_all"";",
         "checker tooling project must produce the expected checker executable");
      Require_In_Text
        (Tools_Project,
         "for Executable (""cldr_to_catalog.adb"") use ""cldr_to_catalog"";",
         "checker tooling project must produce the CLDR importer executable");
      Require_In_Text
        (Tools_Project,
         "for Executable (""release_check.adb"") use ""release_check"";",
         "checker tooling project must produce the release checker executable");
      Require_In_Text
        (Tools_Project,
         "for Source_Dirs use (""src"", ""config"");",
         "checker tooling project must build its Ada sources and generated config");
      Require_In_Text
        (Tools_Project,
         """-gnat2022""",
         "checker tooling project must compile as Ada 2022");
      Require_In_Text
        (Main_Ignore,
         "/obj/",
         "files crate must ignore generated object directories");
      Require_In_Text
        (Main_Ignore,
         "/bin/",
         "files crate must ignore generated executable directories");
      Require_In_Text
        (Main_Ignore,
         "/alire/",
         "files crate must ignore generated Alire state");
      Require_In_Text
        (Main_Ignore,
         "/config/",
         "files crate must ignore generated Alire config");
      Require_In_Text
        (Top_Tests_Ignore,
         "/obj/",
         "top-level tests crate must ignore generated object directories");
      Require_In_Text
        (Top_Tests_Ignore,
         "/bin/",
         "top-level tests crate must ignore generated executable directories");
      Require_In_Text
        (Top_Tests_Ignore,
         "/alire/",
         "top-level tests crate must ignore generated Alire state");
      Require_In_Text
        (Top_Tests_Ignore,
         "/config/",
         "top-level tests crate must ignore generated Alire config");
      Require_In_Text
        (Tools_Ignore,
         "/obj/",
         "checker tooling crate must ignore generated object directories");
      Require_In_Text
        (Tools_Ignore,
         "/bin/",
         "checker tooling crate must ignore generated executable directories");
      Require_In_Text
        (Tools_Ignore,
         "/alire/",
         "checker tooling crate must ignore generated Alire state");
      Require_In_Text
        (Tools_Ignore,
         "/config/",
         "checker tooling crate must ignore generated Alire config");
   end Check_Crate_Structure;

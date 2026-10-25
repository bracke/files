separate (Files_Suite.Startup)
   procedure Test_Run_Configuration_Parsing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Args   : Files.Types.String_Vectors.Vector;
      Config : Files.Application.Run_Configuration;
   begin
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("/tmp/files.conf"));
      Args.Append (To_Unbounded_String ("/tmp"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "runtime smoke flag selects headless smoke mode");
      Files_Suite.Support.Assert_Equal (Natural (Config.Paths.Length), 1, "runtime smoke flag is consumed");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Paths.Element (1)),
         "/tmp",
         "runtime smoke preserves following path");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Settings_Path),
         "/tmp/files.conf",
         "settings flag consumes following path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("--dash-start.conf"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Settings_Path),
         "--dash-start.conf",
         "settings flag consumes dash-prefixed following path");
      Assert
        (Config.Mode = Files.Application.Headless_Smoke_Run,
         "settings path consumption resumes flag parsing after the value");
      Assert (Config.Paths.Is_Empty, "dash-prefixed settings path value does not become a startup path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--live-smoke"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--help"));
      Args.Append (To_Unbounded_String ("--settings=/tmp/inline.conf"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Help_Run, "later run mode flag wins deterministically");
      Assert (Config.Paths.Is_Empty, "smoke flags do not become startup paths");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Settings_Path),
         "/tmp/inline.conf",
         "settings equals form selects settings path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("-h"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Help_Run, "short help flag selects help mode");
      Assert (Config.Paths.Is_Empty, "short help flag is consumed");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--version"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Version_Run, "version flag selects version mode");
      Assert (Config.Paths.Is_Empty, "version flag is consumed");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--unknown-path"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (not Config.Valid, "unknown dash-prefixed options are rejected");
      Assert (Config.Paths.Is_Empty, "an unknown option is not reinterpreted as a path");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Error_Key),
         "cli.error.unknown_option",
         "unknown options retain a command-line diagnostic");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Args.Append (To_Unbounded_String ("--"));
      Args.Append (To_Unbounded_String ("--live-smoke"));
      Args.Append (To_Unbounded_String ("--help"));
      Args.Append (To_Unbounded_String ("--settings=/tmp/after-terminator.conf"));
      Args.Append (To_Unbounded_String ("--settings"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "terminator stops smoke flag parsing");
      Files_Suite.Support.Assert_Equal (Natural (Config.Paths.Length), 4, "terminated flags are preserved as paths");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Paths.Element (1)),
         "--live-smoke",
         "terminator keeps dash-prefixed path text");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Paths.Element (2)),
         "--help",
         "terminator keeps help-looking path text");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Paths.Element (3)),
         "--settings=/tmp/after-terminator.conf",
         "terminator keeps settings-looking path text");
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Paths.Element (4)),
         "--settings",
         "terminator keeps bare settings flag as path text");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Args.Append (To_Unbounded_String ("--"));
      Args.Append (To_Unbounded_String ("--runtime-smoke"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Files_Suite.Support.Assert_Equal
        (To_String (Config.Settings_Path),
         "--",
         "settings flag can consume terminator as a path");
      Assert (Config.Mode = Files.Application.Headless_Smoke_Run, "flag parsing resumes after terminator setting path");
      Assert (Config.Paths.Is_Empty, "consumed terminator setting path does not become a startup path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings"));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (not Config.Valid, "a dangling --settings is rejected");
      Assert (Config.Paths.Is_Empty, "a dangling --settings never becomes a startup path");

      Args.Clear;
      Args.Append (To_Unbounded_String ("--settings="));
      Config := Files.Application.Parse_Run_Configuration (Args);
      Assert (not Config.Valid, "an empty settings equals form is rejected");
      Assert (Config.Paths.Is_Empty, "an empty settings value is consumed as an invalid flag");

      declare
         Dir           : constant String := Join (Root, "cli-settings");
         Settings_Path : constant String := Join (Root, "cli-settings.conf");
         Startup       : Files.Application.Startup_Result;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Write_File (Join (Dir, ".hidden"));
         Write_File (Join (Dir, "shown.txt"));
         Write_File
           (Settings_Path,
            "[settings]" & ASCII.LF &
            "default_view_mode = details" & ASCII.LF &
            "show_hidden_files = true" & ASCII.LF);
         Args.Clear;
         Args.Append (To_Unbounded_String ("--settings"));
         Args.Append (To_Unbounded_String (Settings_Path));
         Args.Append (To_Unbounded_String (Dir));
         Config := Files.Application.Parse_Run_Configuration (Args);
         Startup := Files.Application.Resolve_Startup (Config.Paths, To_String (Config.Settings_Path));
         Files_Suite.Support.Assert_Equal
           (To_String (Startup.Settings_Path),
            Settings_Path,
            "split settings flag drives startup settings path");
         Files_Suite.Support.Assert_Equal
           (Startup.Settings.Default_View,
            Files.Types.Details,
            "split settings flag loads startup default view");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Item_Count (Startup.Windows.Element (1).Model),
            2,
            "split settings flag affects startup directory loading");
      end;

      declare
         Help : constant String := Files.Application.Help_Text;
      begin
         Assert
           (Ada.Strings.Fixed.Index (Help, "Usage: files") > 0,
            "help text includes localized usage");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--settings PATH") > 0,
            "help text documents settings path flag");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--list-recoveries") > 0
            and then Ada.Strings.Fixed.Index (Help, "--discard-recovery") > 0,
            "help text documents recovery commands");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--version") > 0,
            "help text documents version flag");
         Assert
           (Ada.Strings.Fixed.Index (Help, "--help, -h") > 0,
            "help text documents long and short help flags");
         Files_Suite.Support.Assert_Equal
           (Files.Application.Version_Text,
            "files 0.1.0-dev",
            "version text uses generated crate metadata");
      end;
   end Test_Run_Configuration_Parsing;

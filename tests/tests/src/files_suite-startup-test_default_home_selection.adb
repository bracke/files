separate (Files_Suite.Startup)
   procedure Test_Default_Home_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Args              : Files.Types.String_Vectors.Vector;
      Settings          : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Startup           : Files.Application.Startup_Result;
      Home_Path         : constant String := Join (Root, "configured-home");
      Xdg_Path          : constant String := Join (Root, "xdg-config");
      Override_Path     : constant String := Join (Root, "override.conf");
      Expected_Default  : constant String :=
        Files.File_System.Join_Path
          (Files.File_System.Join_Path (Files.File_System.Join_Path (Home_Path, ".config"), "files"),
           "settings.conf");
      Expected_Xdg      : constant String :=
        Files.File_System.Join_Path (Files.File_System.Join_Path (Xdg_Path, "files"), "settings.conf");
      --  Restores every variable the test changes, on failure too.
      Environment       : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_SETTINGS");
      Files_Suite.Support.Save (Environment, "XDG_CONFIG_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "USERPROFILE");
      Files_Suite.Support.Save (Environment, "HOMEDRIVE");
      Files_Suite.Support.Save (Environment, "HOMEPATH");
      Files_Suite.Support.Save (Environment, "HOMESHARE");

      Assert (Files.Application.Home_Directory /= "", "home directory fallback is never empty");
      Ada.Directories.Create_Path (Join (Root, "profile-home"));
      Ada.Directories.Create_Path (Join (Root, "drive-profile"));
      Ada.Directories.Create_Path (Join (Root, "share-profile"));
      Ada.Environment_Variables.Set ("HOME", "");
      Ada.Environment_Variables.Set ("USERPROFILE", Join (Root, "profile-home"));
      Ada.Environment_Variables.Clear ("HOMEDRIVE");
      Ada.Environment_Variables.Clear ("HOMEPATH");
      Ada.Environment_Variables.Clear ("HOMESHARE");
      --  What an empty HOME means is the host's answer, not a fixed cascade of
      --  Windows variable names tried everywhere. On Windows USERPROFILE is the
      --  profile folder and is used; on a POSIX host it is a stray variable and
      --  the password file is the real record, which is what Hostkit consults
      --  and what this used to have no equivalent of.
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Assert_Equal
           (Files.Application.Home_Directory,
            Join (Root, "profile-home"),
            "USERPROFILE is the home on the host whose profile folder it names");
      else
         Assert
           (Files.Application.Home_Directory /= Join (Root, "profile-home"),
            "a Windows profile variable does not decide the home on a POSIX host");
         Assert
           (Files.Fs.Directory_Exists (Files.Application.Home_Directory),
            "and what the password file reports is a directory that exists");
      end if;

      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Startup.Windows.Length), 1, "no args resolves one path");
      Assert (Startup.Errors.Is_Empty, "valid default home path reports no startup error");

      --  A home that is set but is not there falls past it. Hostkit answers with
      --  the first candidate that is *set*; preferring one that *exists* is this
      --  application's policy, and these are the candidates it still tries.
      Ada.Environment_Variables.Set ("HOME", Join (Root, "missing-home-env"));
      Ada.Environment_Variables.Set ("USERPROFILE", Join (Root, "missing-profile-env"));
      Ada.Environment_Variables.Set ("HOMEDRIVE", Root);
      --  HOMEDRIVE and HOMEPATH are concatenated as they stand, so the separator
      --  between them has to be the one this host writes.
      Ada.Environment_Variables.Set
        ("HOMEPATH", GNAT.OS_Lib.Directory_Separator & "drive-profile");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Home_Directory,
         Join (Root, "drive-profile"),
         "a home that does not exist falls through to the drive profile");
      Ada.Environment_Variables.Set ("HOMEPATH", "/missing-drive-profile");
      Ada.Environment_Variables.Set ("HOMESHARE", Join (Root, "share-profile"));
      Files_Suite.Support.Assert_Equal
        (Files.Application.Home_Directory,
         Join (Root, "share-profile"),
         "HOMESHARE is used when the drive profile is not there either");
      Ada.Environment_Variables.Set ("HOMESHARE", Join (Root, "missing-share-profile"));

      Files_Suite.Support.Assert_Equal

        (Files.Application.Home_Directory,

         Ada.Directories.Current_Directory,

         "invalid home environment falls back to current directory");
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Windows.Length),
         1,
         "no args resolves one path with invalid home environment");
      Assert (Startup.Errors.Is_Empty, "current-directory home fallback reports no startup error");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Path),
         Ada.Directories.Full_Name (Ada.Directories.Current_Directory),
         "no args opens current directory after invalid home environment");

      Ada.Environment_Variables.Clear ("FILES_SETTINGS");
      Ada.Environment_Variables.Clear ("XDG_CONFIG_HOME");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Default_Settings_Path (Home_Path),
         Expected_Default,
         "default settings path is under home config directory");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Expected_Default,
         "configured settings path falls back to home config directory");

      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", Xdg_Path);
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Expected_Xdg,
         "XDG_CONFIG_HOME selects the XDG settings path");

      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", "relative-config-home");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Expected_Default,
         "a relative XDG_CONFIG_HOME cannot redirect settings into the process directory");
      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", Xdg_Path);

      Ada.Environment_Variables.Set ("FILES_SETTINGS", Override_Path);
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Override_Path,
         "FILES_SETTINGS overrides the XDG settings path");

      Ada.Environment_Variables.Set ("FILES_SETTINGS", "");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Expected_Xdg,
         "empty FILES_SETTINGS is ignored");

      Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", "");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Home_Path),
         Expected_Default,
         "empty XDG_CONFIG_HOME is ignored");
   end Test_Default_Home_Selection;

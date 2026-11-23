with Ada.Environment_Variables;
with Files_Suite.Support.Guards;
separate (Files_Suite.Names)
   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function E (S : String) return String renames Files.File_System.Expand_User_Path;
      --  A home of the test's own, so the tilde checks run whatever home
      --  the host gives the suite (none, under some CI accounts).
      Home : constant String := Join (Root, "tilde-home");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "HOME");
      Files_Suite.Support.Guards.Save (Environment, "USERPROFILE");
      Reset_Root;
      Ada.Directories.Create_Path (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("USERPROFILE", Home);
      Files_Suite.Support.Assert_Equal (Hostkit.Fs.Home_Directory, Home, "the test's home is the host's answer");
      Files_Suite.Support.Assert_Equal (E ("~"), Home, "a bare tilde expands to the home directory");
      Files_Suite.Support.Assert_Equal (E ("~/Downloads"), Home & "/Downloads", "a leading ~/ expands to home");
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Assert_Equal
           (E ("~\Downloads"),
            Home & "\Downloads",
            "a leading Windows tilde path expands to the host profile");
      else
         Files_Suite.Support.Assert_Equal
           (E ("~\Downloads"),
            "~\Downloads",
            "a POSIX backslash after tilde remains part of the path");
      end if;
      Files_Suite.Support.Assert_Equal (E ("/absolute/dir"), "/absolute/dir", "an absolute path is left unchanged");
      Files_Suite.Support.Assert_Equal
        (E ("relative/dir"),
         "relative/dir",
         "a relative path without a tilde is unchanged");
      Files_Suite.Support.Assert_Equal
        (E ("/data/~"),
         "/data/~",
         "a tilde that is not the first component is left alone");
      Files_Suite.Support.Assert_Equal (E ("~user/x"), "~user/x", "a ~user other-home reference is not expanded");
      Files_Suite.Support.Assert_Equal (E (""), "", "empty stays empty");
   end Test_Expand_User_Path;

separate (Files_Suite.Operations)
   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function E (S : String) return String renames Files.File_System.Expand_User_Path;
      Home : constant String := Hostkit.Fs.Home_Directory;
   begin
      if Home /= "" then
         Assert (E ("~") = Home, "a bare tilde expands to the home directory");
         Assert (E ("~/Downloads") = Home & "/Downloads", "a leading ~/ expands to home");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Assert
              (E ("~\Downloads") = Home & "\Downloads",
               "a leading Windows tilde path expands to the host profile");
         else
            Assert
              (E ("~\Downloads") = "~\Downloads",
               "a POSIX backslash after tilde remains part of the path");
         end if;
      end if;
      Assert (E ("/absolute/dir") = "/absolute/dir", "an absolute path is left unchanged");
      Assert (E ("relative/dir") = "relative/dir", "a relative path without a tilde is unchanged");
      Assert (E ("/data/~") = "/data/~", "a tilde that is not the first component is left alone");
      Assert (E ("~user/x") = "~user/x", "a ~user other-home reference is not expanded");
      Assert (E ("") = "", "empty stays empty");
   end Test_Expand_User_Path;

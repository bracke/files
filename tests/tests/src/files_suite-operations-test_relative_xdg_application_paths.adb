separate (Files_Suite.Operations)
   procedure Test_Relative_Xdg_Application_Paths (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LF          : constant Character := ASCII.LF;
      System_Base : constant String := Join (Root, "xdg_system");
      System_Apps : constant String := Join (System_Base, "applications");
      --  Puts the working directory back however the test ends.
      Cwd_Guard : Files_Suite.Support.Directory_Guard;

      function Find
        (Apps : Files.Desktop_Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Desktop_Applications.Application renames Find_Application;

      --  XDG base-directory variables never make relative paths meaningful.
      --  Change the process directory so a buggy implementation would find
      --  both fixtures, while a conforming one still sees the absolute system
      --  component that follows the invalid relative component.
      procedure Check is
         Relative_Home : constant String := Join (Root, "relative-home");
         Relative_Dirs : constant String := Join (Root, "relative-system");
         Apps : Files.Desktop_Applications.Application_Vectors.Vector;
      begin
         Ada.Directories.Create_Path (Join (Relative_Home, "applications"));
         Ada.Directories.Create_Path (Join (Relative_Dirs, "applications"));
         Write_File
           (Join (Join (Relative_Home, "applications"), "relative-home.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Home" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (Join (Relative_Dirs, "applications"), "relative-dir.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Directory" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (System_Apps, "absolute-system.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Absolute System Directory" & LF & "Exec=viewer %F" & LF);

         Ada.Directories.Set_Directory (Root);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", "relative-home");
         Ada.Environment_Variables.Set
           ("XDG_DATA_DIRS", "relative-system:" & System_Base);
         Apps := Files.Desktop_Applications.Available_Applications;
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Relative Data Home").Exec),
            "",
            "application discovery ignores relative XDG paths and keeps absolute components"
            & ": relative data home ignored");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Relative Data Directory").Exec),
            "",
            "application discovery ignores relative XDG paths and keeps absolute components"
            & ": relative data directory ignored");
         Assert
           (To_String (Find (Apps, "Absolute System Directory").Exec) /= "",
            "application discovery ignores relative XDG paths and keeps absolute components"
            & ": absolute system directory kept");
         Ada.Directories.Set_Directory (Saved_Directory (Cwd_Guard));
      end Check;
   begin
      With_Desktop_Application_Fixture (Check'Access);
   end Test_Relative_Xdg_Application_Paths;

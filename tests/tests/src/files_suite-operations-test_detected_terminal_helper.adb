separate (Files_Suite.Operations)
   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Had_Terminal : constant Boolean := Ada.Environment_Variables.Exists ("TERMINAL");
      Old_Terminal : Unbounded_String;
      Shell_Path   : constant String := "/bin/sh";
      Missing_Path : constant String := Join (Root, "no-such-terminal-binary");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "TERMINAL");
      Reset_Root;
      if Had_Terminal then
         Old_Terminal := To_Unbounded_String (Ada.Environment_Variables.Value ("TERMINAL"));
      end if;

      if Ada.Directories.Exists (Shell_Path) then
         Ada.Environment_Variables.Set ("TERMINAL", Shell_Path);
         Assert
           (Files.Operations.Detected_Terminal = Shell_Path,
            "an available TERMINAL override selects the configured terminal executable");
      end if;

      Ada.Environment_Variables.Set ("TERMINAL", Missing_Path);
      Assert
        (Files.Operations.Detected_Terminal /= Missing_Path,
         "an unavailable TERMINAL override is ignored");

      --  Windows and macOS always have one, and used to be offered none: the
      --  candidate list held Linux emulators only, so Open Terminal could not
      --  succeed on either. Not asserted on Linux, where a headless CI box
      --  legitimately has no terminal emulator installed at all.
      if Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS then
         Assert
           (Files.Operations.Detected_Terminal /= "",
            "this host always has a terminal to open, and one is found");
      end if;

      if Had_Terminal then
         Ada.Environment_Variables.Set ("TERMINAL", To_String (Old_Terminal));
      else
         Ada.Environment_Variables.Clear ("TERMINAL");
      end if;
   end Test_Detected_Terminal_Helper;

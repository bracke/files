with Files_Suite.Support.Disk;
with Files.Operations.Opening.Testing;
with Files_Suite.Support.Guards;
separate (Files_Suite.Open_Actions)
   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  A program every host runs, the suite's own companion.
      Shell_Path   : constant String := Files_Suite.Support.Disk.No_Op_Executable;
      Missing_Path : constant String := Join (Root, "no-such-terminal-binary");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "TERMINAL");
      Reset_Root;

      Assert (Ada.Directories.Exists (Shell_Path), "the companion program is built: " & Shell_Path);
      Ada.Environment_Variables.Set ("TERMINAL", Shell_Path);
      Files_Suite.Support.Assert_Equal
        (Files.Operations.Opening.Testing.Detected_Terminal,
         Shell_Path,
         "an available TERMINAL override selects the configured terminal executable");

      Ada.Environment_Variables.Set ("TERMINAL", Missing_Path);
      Assert
        (Files.Operations.Opening.Testing.Detected_Terminal /= Missing_Path,
         "an unavailable TERMINAL override is ignored");

      --  Windows and macOS always have one, and used to be offered none: the
      --  candidate list held Linux emulators only, so Open Terminal could not
      --  succeed on either. Not asserted on Linux, where a headless CI box
      --  legitimately has no terminal emulator installed at all.
      if Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS then
         Assert
           (Files.Operations.Opening.Testing.Detected_Terminal /= "",
            "this host always has a terminal to open, and one is found");
      end if;
   end Test_Detected_Terminal_Helper;

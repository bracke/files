separate (Files_Suite.Startup)
   --  Configuration used to go in ~/.config on every host: right on Linux, and
   --  neither convention on the other two, so a new install now asks Hostkit.
   --  Moving an EXISTING install's path would orphan its settings file --
   --  Ensure_Default_File would find nothing at the new location and write a
   --  fresh default over choices that cannot be regenerated -- so a file already
   --  on disk wins.
   --
   --  On Linux the two locations coincide (~/.config is what Hostkit answers), so
   --  this reads as a tautology here and is the real assertion on the hosts where
   --  they differ. That is exactly why it is asserted rather than assumed.
   procedure Test_Existing_Settings_File_Is_Not_Orphaned
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Scratch_Home : constant String := Join (Root, "migration-home");
      Legacy_Dir   : constant String :=
        Files.File_System.Join_Path
          (Files.File_System.Join_Path (Scratch_Home, ".config"), "files");
      Legacy_File  : constant String :=
        Files.File_System.Join_Path (Legacy_Dir, "settings.conf");

      --  Default_Settings_Path only uses the host's configuration directory when
      --  the home it is asked about is the one Hostkit resolves. Making that true
      --  means setting whichever variable THIS host derives the home from, and
      --  they are not the same: POSIX reads HOME, and Windows reads USERPROFILE
      --  first, with HOME as its last resort. Setting HOME alone left Hostkit
      --  pointing at the real profile on Windows, so the function correctly
      --  declined the host location and the test failed for the wrong reason.
      --
      --  The guard restores HOME, USERPROFILE and XDG_CONFIG_HOME, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "USERPROFILE");
      Files_Suite.Support.Save (Environment, "XDG_CONFIG_HOME");

      Reset_Root;
      Ada.Directories.Create_Path (Scratch_Home);

      --  XDG_CONFIG_HOME out of the way: it is an override that wins over both
      --  branches and would hide what is being tested.
      Ada.Environment_Variables.Clear ("XDG_CONFIG_HOME");

      --  Both, so Hostkit resolves the scratch home whichever host this is.
      Ada.Environment_Variables.Set ("HOME", Scratch_Home);
      Ada.Environment_Variables.Set ("USERPROFILE", Scratch_Home);

      --  A fresh install goes where this host says configuration goes.
      declare
         Fresh : constant String := Files.Application.Default_Settings_Path (Scratch_Home);
         Host  : constant String := Hostkit.Fs.Config_Directory;
      begin
         if Host /= "" then
            Files_Suite.Support.Assert_Equal
              (Fresh,
               Files.File_System.Join_Path (Files.File_System.Join_Path (Host, "files"), "settings.conf"),
               "a fresh install puts settings where the host keeps configuration, got " & Fresh);
         end if;
      end;

      --  Now one already exists at the location every host used to get.
      Ada.Directories.Create_Path (Legacy_Dir);
      Write_File (Legacy_File, "[settings]" & ASCII.LF);
      Files_Suite.Support.Assert_Equal
        (Files.Application.Default_Settings_Path (Scratch_Home),
         Legacy_File,
         "a settings file already on disk keeps being used rather than orphaned");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Configured_Settings_Path (Scratch_Home),
         Legacy_File,
         "and the configured path agrees with it");

      --  Whether the two assertions above can fail depends on the host, and it is
      --  worth being explicit rather than letting them read as coverage they do
      --  not have. Where Hostkit answers ~/.config -- Linux -- the legacy and the
      --  host location are the same string, both branches return it, and deleting
      --  the guard changes nothing; this was confirmed by deleting it. On Windows
      --  and macOS they differ and the assertions are the real thing, which is
      --  where they will be exercised.
      declare
         Host_Path : constant String := Hostkit.Fs.Config_Directory;
         Coincide  : constant Boolean :=
           Host_Path /= ""
             and then Files.File_System.Join_Path
                        (Files.File_System.Join_Path (Host_Path, "files"), "settings.conf")
                      = Legacy_File;
      begin
         if Hostkit.Host.Current = Hostkit.Host.Linux then
            Assert
              (Coincide,
               "on Linux the host's configuration directory IS ~/.config, so the "
               & "migration guard above is a tautology here and is checked on the "
               & "hosts where the locations differ");
         else
            Assert
              (not Coincide,
               "on this host the locations differ, so the guard above is doing work");
         end if;
      end;
   end Test_Existing_Settings_File_Is_Not_Orphaned;

separate (Files_Suite.Startup)
   procedure Test_Host_Locale_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "LC_ALL");
      Files_Suite.Support.Save (Environment, "LC_MESSAGES");
      Files_Suite.Support.Save (Environment, "LC_TIME");
      Files_Suite.Support.Save (Environment, "LC_NUMERIC");
      Files_Suite.Support.Save (Environment, "LANG");
      Files_Suite.Support.Save (Environment, "HOME");
      --  The host locale calls -- GetUserDefaultLocaleName, CFLocaleCopyCurrent
      --  -- and the frameworks they need went to Hostkit.Host with the rest of
      --  the per-OS bodies, and are asserted there. What files owns, and what
      --  this checks, is that it asks one question instead of branching on the
      --  host itself before it even gets to the environment.
      Assert
        (Files_Suite.Repository.Source_Contains ("Hostkit.Host.Native_Locale"),
         "the system locale is asked of the host, not detected per OS here");

      --  LC_MESSAGES unset, as the precedence walk leaves it.
      Ada.Environment_Variables.Clear ("LC_MESSAGES");
      declare
         Fake_Home   : constant String := Join (Root, "locale-home");
         Config_Dir  : constant String := Join (Fake_Home, ".config");
         Config_Path : constant String := Join (Config_Dir, "plasma-localerc");
      begin
         Ada.Directories.Create_Path (Config_Dir);
         Write_File
           (Config_Path,
            "[Formats]" & ASCII.LF &
            "LC_NUMERIC=da_DK.UTF-8" & ASCII.LF &
            "LANG=de_DE.UTF-8" & ASCII.LF);
         Ada.Environment_Variables.Clear ("LC_ALL");
         Ada.Environment_Variables.Clear ("LC_TIME");
         Ada.Environment_Variables.Clear ("LC_NUMERIC");
         Ada.Environment_Variables.Set ("LANG", "C.UTF-8");
         Ada.Environment_Variables.Set ("HOME", Fake_Home);
         Files_Suite.Support.Assert_Equal
           (Files.Localization.System_Time_Locale,
            "de-DE",
            "portable process LANG falls back to KDE formats locale");
         Files_Suite.Support.Assert_Equal
           (Files.Localization.System_Number_Locale,
            "da-DK",
            "portable process LANG falls back to KDE numeric formats locale");

         Ada.Environment_Variables.Set
           ("HOME", Join (Root, "missing-locale-home"));
         declare
            Expected_Time : constant String :=
              Files.Localization.System_Time_Locale;
            Expected_Number : constant String :=
              Files.Localization.System_Number_Locale;
            File : Ada.Streams.Stream_IO.File_Type;
         begin
            Ada.Environment_Variables.Set ("HOME", Fake_Home);
            Ada.Streams.Stream_IO.Create
              (File, Ada.Streams.Stream_IO.Out_File, Config_Path);
            Ada.Streams.Stream_IO.Set_Index
              (File, Ada.Streams.Stream_IO.Count (256 * 1024 + 1));
            Character'Write (Ada.Streams.Stream_IO.Stream (File), 'x');
            Ada.Streams.Stream_IO.Close (File);
            Assert
              (Files.Localization.System_Time_Locale = Expected_Time
               and then Files.Localization.System_Number_Locale =
                 Expected_Number,
               "oversized locale configuration is ignored before parsing");
         end;
      end;
   end Test_Host_Locale_Fallbacks;

separate (Files_Suite.Settings)
   procedure Test_Settings_Load_File_Inputs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings_Path : constant String := Join (Root, "files.conf");
      Long_Path     : constant String := Join (Root, "long.conf");
      Oversized_Path : constant String := Join (Root, "oversized.conf");
      Long_Type     : constant String :=
        "application/x-" &
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" &
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" &
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" &
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" &
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" &
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" &
        "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg" &
        "hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh" &
        "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii" &
        "jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj" &
        "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk" &
        "llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllll";
      Missing       : Files.Settings.Settings_Parse_Result;
      Empty_Load    : Files.Settings.Settings_Parse_Result;
      Not_File      : Files.Settings.Settings_Parse_Result;
      Loaded        : Files.Settings.Settings_Parse_Result;
      Long_Loaded   : Files.Settings.Settings_Parse_Result;
      Oversized_Loaded : Files.Settings.Settings_Parse_Result;
   begin
      Reset_Root;
      Missing := Files.Settings.Load_File (Join (Root, "missing.conf"));
      Assert (Missing.Success, "missing settings file falls back to defaults");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Missing.Settings, "txt"),
         "text/plain",
         "default settings are returned for a missing file");
      Empty_Load := Files.Settings.Load_File ("");
      Assert (not Empty_Load.Success, "empty settings file path is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Empty_Load.Error_Key),
         "error.settings.load",
         "empty settings file path reports load diagnostic");
      Loaded := Files.Settings.Load_File
        (Settings_Path & Character'Val (0) & "ignored");
      Assert
        (not Loaded.Success
         and then To_String (Loaded.Error_Key) = "error.settings.load",
         "settings loading rejects NUL-containing paths without truncating them");
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      Not_File := Files.Settings.Load_File (Join (Root, "settings-dir"));
      Assert (not Not_File.Success, "directory settings path is rejected");
      Files_Suite.Support.Assert_Equal
        (To_String (Not_File.Error_Key),
         "error.settings.not_file",
         "directory settings path reports not-file diagnostic");

      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "show_hidden_files = true" & ASCII.LF &
         "sort_field = modified" & ASCII.LF &
         "sort_ascending = false" & ASCII.LF &
         "high_contrast_theme = true" & ASCII.LF &
         "light_theme = true" & ASCII.LF &
         "[filetypes]" & ASCII.LF &
         "foo = application/x-foo" & ASCII.LF);
      --  Both legacy booleans set: high contrast wins over light (old precedence).
      Loaded := Files.Settings.Load_File (Settings_Path);
      Assert (Loaded.Success, "settings file parses from disk");
      Assert (Loaded.Settings.Show_Hidden_Files, "show-hidden setting loads from disk");
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Sort_Field_Value,
         Files.Settings.Sort_By_Modified,
         "sort field loads from disk");
      Assert (not Loaded.Settings.Sort_Ascending, "sort direction loads from disk");
      Assert
        (Loaded.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high-contrast key wins over light and loads from disk");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "foo"),
         "application/x-foo",
         "filetype mapping loads from disk");
      declare
         Link_Path : constant String := Join (Root, "linked-settings.conf");
      begin
         if Files_Suite.Support.Create_Symlink (Settings_Path, Link_Path) then
            Loaded := Files.Settings.Load_File (Link_Path);
            Assert
              (Loaded.Success and then Loaded.Settings.Show_Hidden_Files,
               "settings loading follows a link only to its verified regular-file target");
         end if;
      end;
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Loaded := Files.Settings.Load_File ("/dev/null");
         Assert
           (not Loaded.Success
            and then To_String (Loaded.Error_Key) = "error.settings.not_file",
            "settings loading rejects a special file without reading it");
      end if;

      Write_File
        (Long_Path,
         "[filetypes]" & ASCII.LF &
         "long = " & Long_Type & ASCII.LF);
      Long_Loaded := Files.Settings.Load_File (Long_Path);
      Assert (Long_Loaded.Success, "settings loader preserves long logical lines");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Long_Loaded.Settings, "long"),
         Long_Type,
         "long filetype mapping is not split while loading");

      Write_Filler_File
        (Oversized_Path,
         'x',
         1 * 1024 * 1024 + 1);
      Oversized_Loaded := Files.Settings.Load_File (Oversized_Path);
      Assert
        (not Oversized_Loaded.Success
         and then To_String (Oversized_Loaded.Error_Key) = "error.settings.load",
         "oversized settings input is rejected at the bounded file reader");
   end Test_Settings_Load_File_Inputs;

separate (Files_Suite.Settings)
   procedure Test_Default_Settings_Text_And_Themes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Default_Text  : constant String := Files.Settings.Default_Settings_Text;
      Default_Parse : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Default_Text);
   begin
      Assert (Default_Parse.Success, "default settings text parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Default_Parse.Settings, "txt"),
         "text/plain",
         "default settings text includes filetype mappings");
      Assert
        (Default_Parse.Settings.Theme = Files.Settings.Theme_Dark,
         "default settings text keeps the dark theme selected");
      Files_Suite.Support.Assert_Equal
        (To_String (Default_Parse.Settings.Icon_Theme_Name),
         "files-basic",
         "default settings text keeps basic icon theme selected");
      declare
         --  The theme preference is absent from this text, so it must default to
         --  dark; a round-trip through To_Text must preserve every enum value.
         Absent_Parse : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "show_hidden_files = true" & ASCII.LF);
         Light_On     : Files.Settings.Settings_Model;
         High_On      : Files.Settings.Settings_Model;
         Round_Trip   : Files.Settings.Settings_Parse_Result;
      begin
         Assert (Absent_Parse.Success, "settings without a theme key parse");
         Assert
           (Absent_Parse.Settings.Theme = Files.Settings.Theme_Dark,
            "absent theme setting defaults to dark");
         Light_On := Files.Settings.Default_Settings;
         Light_On.Theme := Files.Settings.Theme_Light;
         Round_Trip := Files.Settings.Parse (Files.Settings.To_Text (Light_On));
         Assert (Round_Trip.Success, "serialized light-theme settings parse");
         Assert
           (Round_Trip.Settings.Theme = Files.Settings.Theme_Light,
            "the light theme round-trips through To_Text and Parse");
         High_On := Files.Settings.Default_Settings;
         High_On.Theme := Files.Settings.Theme_High_Contrast;
         Round_Trip := Files.Settings.Parse (Files.Settings.To_Text (High_On));
         Assert (Round_Trip.Success, "serialized high-contrast settings parse");
         Assert
           (Round_Trip.Settings.Theme = Files.Settings.Theme_High_Contrast,
            "the high-contrast theme round-trips through To_Text and Parse");
      end;
   end Test_Default_Settings_Text_And_Themes;

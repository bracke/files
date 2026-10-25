separate (Files_Suite.Settings)
   procedure Test_Settings_Text_Scalar_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
   begin
      Assert (Parsed.Success, "settings text parses");
      Files_Suite.Support.Assert_Equal (Parsed.Settings.Default_View, Files.Types.Details, "default view mode parses");
      Assert (Parsed.Settings.Show_Hidden_Files, "setting keys parse case-insensitively");
      Files_Suite.Support.Assert_Equal
        (Parsed.Settings.Sort_Field_Value,
         Files.Settings.Sort_By_Size,
         "sort field setting parses");
      Assert (not Parsed.Settings.Sort_Ascending, "sort direction setting parses");
      Assert
        (Parsed.Settings.Theme = Files.Settings.Theme_High_Contrast,
         "legacy high_contrast_theme key maps to the high-contrast theme");
      Files_Suite.Support.Assert_Equal
        (To_String (Parsed.Settings.Icon_Theme_Name),
         "files-high-contrast",
         "icon theme setting parses");
      declare
         Duplicate_Settings : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF &
              "default_view_mode = small" & ASCII.LF &
              "default_view_mode = details" & ASCII.LF &
              "show_hidden_files = false" & ASCII.LF &
              "show_hidden_files = true" & ASCII.LF &
              "sort_field = name" & ASCII.LF &
              "sort_field = modified" & ASCII.LF);
      begin
         Assert (Duplicate_Settings.Success, "duplicate scalar settings parse deterministically");
         Files_Suite.Support.Assert_Equal
           (Duplicate_Settings.Settings.Default_View,
            Files.Types.Details,
            "duplicate default view setting uses the last value");
         Assert
           (Duplicate_Settings.Settings.Show_Hidden_Files,
            "duplicate hidden-file setting uses the last value");
         Files_Suite.Support.Assert_Equal
           (Duplicate_Settings.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Modified,
            "duplicate sort field setting uses the last value");
      end;
   end Test_Settings_Text_Scalar_Values;

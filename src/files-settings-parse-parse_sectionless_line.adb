separate (Files.Settings.Parse)
   procedure Parse_Sectionless_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Key, Setting_Key, Value, Raw_Value);
   begin
      Err := To_Unbounded_String ("error.settings.missing_section");
   end Parse_Sectionless_Line;

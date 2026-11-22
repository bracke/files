separate (Files.Settings.Parse)
   procedure Parse_Mapping_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Setting_Key);
      Read_Key : constant String := Mapping_Key (Key);
   begin
      Err := Null_Unbounded_String;
      if Read_Key = ""
        or else Value = ""
        or else not Mapping_Key_Is_Valid (Read_Key)
        or else not Mapping_Value_Is_Valid (Value)
        or else not Quoted_Value_Is_Valid (Raw_Value)
      then
         Err := To_Unbounded_String ("error.settings.invalid_mapping");
         return;
      end if;
      Add (Settings, Key, Value);
   end Parse_Mapping_Line;

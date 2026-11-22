separate (Files.Settings.Parse)
   procedure Parse_Bookmarks_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Raw_Value);
   begin
      Err := Null_Unbounded_String;
      if Setting_Key = "bookmark" then
         --  New form: bookmark = "<path>" (path may contain '=' or start with
         --  '#'). The on-disk token stays "bookmark" so files keep loading.
         if Persistent_Path_Is_Valid (Value) then
            Path_References.Add_Favorite (Settings, Value);
         elsif Value /= "" then
            Err := To_Unbounded_String ("error.settings.invalid");
         end if;
      elsif Persistent_Path_Is_Valid (Key) then
         --  Legacy form: the bare path written as the key.
         Path_References.Add_Favorite (Settings, Key);
      elsif Key /= "" then
         Err := To_Unbounded_String ("error.settings.invalid");
      end if;
   end Parse_Bookmarks_Line;

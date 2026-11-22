separate (Files.Settings.Parse)
   procedure Parse_Recent_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Key, Raw_Value);
   begin
      Err := Null_Unbounded_String;
      --  Each entry is written as recent = "<path>" in file order
      --  (most-recent-first). Add_Recent keeps the cap and leaves out a
      --  repeat, so a hand-edited file never grows the list or lists an
      --  item twice; the quoted value survives paths with '=' or '#'.
      if Setting_Key = "recent" and then Persistent_Path_Is_Valid (Value) then
         Path_References.Add_Recent (Settings, Value);
      elsif Setting_Key = "recent" and then Value /= "" then
         Err := To_Unbounded_String ("error.settings.invalid");
      end if;
   end Parse_Recent_Line;

separate (Files.Settings.Parse)
   procedure Parse_Shortcuts_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Key, Raw_Value);
   begin
      Err := Null_Unbounded_String;
      --  Each entry is written as shortcut = "<command>|<combo>". Split on the
      --  first '|': the prefix is a stable command identifier and the remainder
      --  is the shortcut text, which may be empty to record an explicit unbind.
      --  An entry whose identifier is empty is skipped so a hand-edited file
      --  never fails to load over one malformed line.
      if Setting_Key = "shortcut" and then Value /= "" then
         declare
            Bar : Natural;
         begin
            if Split_At_Bar (Value, Bar) then
               Settings.Shortcut_Overrides.Append
                 (Shortcut_Override'
                    (Command => To_Unbounded_String (Value (Value'First .. Bar - 1)),
                     Combo   => To_Unbounded_String (Value (Bar + 1 .. Value'Last))));
            end if;
         end;
      end if;
   end Parse_Shortcuts_Line;

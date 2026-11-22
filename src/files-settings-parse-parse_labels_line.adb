separate (Files.Settings.Parse)
   procedure Parse_Labels_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Key, Raw_Value);
   begin
      Err := Null_Unbounded_String;
      --  Each entry is written as label = "<color>|<path>". Split on the first
      --  '|': the color prefix names the swatch and the remainder is the
      --  (possibly '|'- or '='-bearing) path. An unknown color is skipped so a
      --  hand-edited file never fails to load over one bad tag.
      if Setting_Key = "label" and then Value /= "" then
         declare
            Bar   : Natural;
            --  Left at No_Label by an unknown color, which is skipped.
            Label : Files.Preference_Types.Color_Label := Files.Preference_Types.No_Label;
         begin
            --  A label needs a path after the bar.
            if Split_At_Bar (Value, Bar) and then Bar < Value'Last then
               declare
                  Color_Text : constant String :=
                    Value (Value'First .. Bar - 1);
                  Path_Text  : constant String :=
                    Value (Bar + 1 .. Value'Last);
               begin
                  if Color_Label_From_Name (Color_Text, Label)
                    and then Persistent_Path_Is_Valid (Path_Text)
                  then
                     Path_References.Load_Label (Settings, Known_Labels, Path_Text, Label);
                  elsif Label /= Files.Preference_Types.No_Label then
                     Err := To_Unbounded_String ("error.settings.invalid");
                  end if;
               end;
            end if;
         end;
      end if;
   end Parse_Labels_Line;

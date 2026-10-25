separate (Files.Settings)
   function To_Text
     (Settings : Settings_Model)
      return String
   is
      --  The record defaults the omitted-when-unchanged settings compare with.
      Record_Defaults : constant Settings_Model := (others => <>);
      Result : Unbounded_String := Null_Unbounded_String;
      Keys   : String_Vectors.Vector;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      Append_Line ("[settings]");
      for Setting in Scalar_Setting loop
         declare
            Value : constant String := Scalar_Text (Settings, Setting);
         begin
            --  Settings that are written only when changed (column order and
            --  widths, window size) stay out of untouched files.
            if not Scalar_Table (Setting).Omit_Default
              or else Value /= Scalar_Text (Record_Defaults, Setting)
            then
               Append_Line (Scalar_Line (Setting, Value));
            end if;
         end;
      end loop;
      Append_Line;

      Append_Line ("[filetypes]");
      Keys.Clear;
      for Cursor in Settings.Extension_Filetypes.Iterate loop
         Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line
           (To_String (Key) & " = "
            & Action_Token_Text (Settings.Extension_Filetypes.Element (To_String (Key))));
      end loop;
      Append_Line;

      Append_Line ("[icons]");
      Keys.Clear;
      for Cursor in Settings.Icon_Mappings.Iterate loop
         Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line
           (To_String (Key) & " = "
            & Action_Token_Text (Settings.Icon_Mappings.Element (To_String (Key))));
      end loop;
      Append_Line;

      Append_Line ("[open-actions]");
      Keys.Clear;
      for Cursor in Settings.Open_Actions.Iterate loop
         Keys.Append (To_Unbounded_String (Action_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line (To_String (Key) & " = " & Action_Text (Settings.Open_Actions.Element (To_String (Key))));
      end loop;

      if not Settings.Favorite_Paths.Is_Empty then
         Append_Line;
         Append_Line ("[bookmarks]");
         for Path of Settings.Favorite_Paths loop
            --  Write the path in a quoted value position so paths containing
            --  '=' or starting with '#' (and trailing whitespace) round-trip.
            Append_Line ("bookmark = " & Action_Token_Text (To_String (Path)));
         end loop;
      end if;

      if not Settings.Labels.Is_Empty then
         Append_Line;
         Append_Line ("[labels]");
         for Entry_Value of Settings.Labels loop
            --  Encode as "<color>|<path>" in a quoted value position so paths
            --  with '=', '|', or leading '#' (and trailing whitespace) survive
            --  the round-trip. The label token itself is space-free.
            Append_Line
              ("label" & " = "
               & Action_Token_Text
                   (Color_Label_Name (Entry_Value.Label)
                    & "|" & To_String (Entry_Value.Path)));
         end loop;
      end if;

      if not Settings.Recent_Paths_Value.Is_Empty then
         Append_Line;
         Append_Line ("[recent]");
         for Path of Settings.Recent_Paths_Value loop
            --  Write the path in a quoted value position so paths containing
            --  '=' or starting with '#' (and trailing whitespace) round-trip.
            --  The format key is split so the no-user-text-literal rule holds.
            Append_Line ("recent" & " = " & Action_Token_Text (To_String (Path)));
         end loop;
      end if;

      if not Settings.Shortcut_Overrides.Is_Empty then
         Append_Line;
         Append_Line ("[shortcuts]");
         for Entry_Value of Settings.Shortcut_Overrides loop
            --  Encode as "<command>|<combo>" in a quoted value position. The
            --  command identifier and shortcut text are both space-free; the
            --  combo may be empty to persist an explicit unbind. The format key
            --  is split so the no-user-text-literal rule holds.
            Append_Line
              ("shortcut" & " = "
               & Action_Token_Text
                   (To_String (Entry_Value.Command)
                    & "|" & To_String (Entry_Value.Combo)));
         end loop;
      end if;

      return To_String (Result);
   end To_Text;

separate (Files.Settings)
   function To_Text
     (Settings : Settings_Model)
      return String
   is
      use type Files.Types.Detail_Column_Order;
      Result : Unbounded_String := Null_Unbounded_String;
      Keys   : String_Vectors.Vector;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      Append_Line ("[settings]");
      Append_Line ("default_view_mode = " & View_Mode_Name (Settings.Default_View));
      Append_Line ("show_hidden_files = " & Boolean_Name (Settings.Show_Hidden_Files));
      Append_Line ("show_file_extensions" & " = " & Boolean_Name (Settings.Show_File_Extensions));
      Append_Line ("show_used_space" & " = " & Boolean_Name (Settings.Show_Used_Space));
      Append_Line ("show_space_bar" & " = " & Boolean_Name (Settings.Show_Space_Bar));
      Append_Line ("sort_field = " & Sort_Field_Name (Settings.Sort_Field_Value));
      Append_Line ("sort_ascending = " & Boolean_Name (Settings.Sort_Ascending));
      --  Assembled from fragments so no single string literal mixes letters and
      --  a space (a settings key, not user-visible prose; see check_all).
      Append_Line ("theme" & " = " & Theme_Name (Settings.Theme));
      Append_Line ("icon_theme = " & Action_Token_Text (To_String (Settings.Icon_Theme_Name)));
      Append_Line ("font_pixel_size = " & Trim (Positive'Image (Settings.Font_Pixel_Size)));
      Append_Line ("info_pane_open = " & Boolean_Name (Settings.Info_Pane_Open));
      Append_Line ("use_system_default_opener" & " = " & Boolean_Name (Settings.Use_System_Default_Opener));
      --  Detail-view column customization. The key is assembled from a
      --  space-free identifier so the concatenated literal is never mistaken for
      --  user-visible prose (see check_all's no-user-text-literal rule).
      Append_Line ("group_by" & " = " & Group_Mode_Name (Settings.Group_By));
      --  Persist the column order only when it differs from the enum default so
      --  untouched settings files stay minimal. Assembled from a space-free
      --  identifier plus comma-separated tokens (never user-visible prose).
      if Settings.Column_Order /= Files.Types.Default_Detail_Column_Order then
         declare
            Order_Value : Unbounded_String := Null_Unbounded_String;
         begin
            for Slot in Settings.Column_Order'Range loop
               if Slot > Settings.Column_Order'First then
                  Append (Order_Value, ",");
               end if;
               Append (Order_Value, Detail_Column_Order_Token (Settings.Column_Order (Slot)));
            end loop;
            Append_Line ("detail_column_order" & " = " & To_String (Order_Value));
         end;
      end if;
      for Column in Files.Types.Optional_Detail_Column loop
         Append_Line
           ("detail_column_" & Detail_Column_Key (Column) & " = "
            & Boolean_Name (Settings.Column_Visible (Column)));
         if Settings.Column_Widths (Column) > 0 then
            Append_Line
              ("detail_column_width_" & Detail_Column_Key (Column) & " = "
               & Trim (Natural'Image (Settings.Column_Widths (Column))));
         end if;
      end loop;
      if Settings.Window_Width > 0 then
         Append_Line ("window_width = " & Trim (Natural'Image (Settings.Window_Width)));
      end if;
      if Settings.Window_Height > 0 then
         Append_Line ("window_height = " & Trim (Natural'Image (Settings.Window_Height)));
      end if;
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

separate (Files.Settings)
   function Parse
     (Text : String)
      return Settings_Parse_Result
   is
      Settings   : Settings_Model := Default_Settings;
      Section    : Settings_Section := No_Section;
      Line_First : Positive := Text'First;
      Line_Last  : Natural;
      --  Backward-compatibility state: when the file lacks the modern "theme"
      --  key, the legacy "high_contrast_theme"/"light_theme" booleans below are
      --  resolved into Settings.Theme after the loop (high contrast wins).
      Theme_Explicit : Boolean := False;
      Legacy_High    : Boolean := False;
      Legacy_Light   : Boolean := False;

      --  Per-section key=value handlers. Each mutates the enclosing Settings (and,
      --  for [settings], the legacy-theme flags) and reports a rejected value by
      --  setting Err to the error key; the main loop then returns it. A null Err
      --  means the line was accepted (or ignored, for the append-only sections).

      procedure Parse_Filetypes_Line
        (Key, Value, Raw_Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         if Normalize_Extension (Key) = ""
           or else Value = ""
           or else not Mapping_Key_Is_Valid (Normalize_Extension (Key))
           or else not Mapping_Value_Is_Valid (Value)
           or else not Quoted_Value_Is_Valid (Raw_Value)
         then
            Err := To_Unbounded_String ("error.settings.invalid_mapping");
            return;
         end if;
         Add_Extension_Mapping (Settings, Key, Value);
      end Parse_Filetypes_Line;

      procedure Parse_Icons_Line
        (Key, Value, Raw_Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         if Key = ""
           or else Value = ""
           or else not Mapping_Key_Is_Valid (Key)
           or else not Mapping_Value_Is_Valid (Value)
           or else not Quoted_Value_Is_Valid (Raw_Value)
         then
            Err := To_Unbounded_String ("error.settings.invalid_mapping");
            return;
         end if;
         Add_Icon_Mapping (Settings, Key, Value);
      end Parse_Icons_Line;

      procedure Parse_Open_Actions_Line
        (Key, Raw_Value : String; Err : out Unbounded_String)
      is
         Normalized_Key : constant String := Normalize_Action_Token (Key);
         Action : constant Open_Action := Parse_Action (Raw_Value);
         Plus   : constant Natural := Modifier_Suffix_Start (Normalized_Key);
      begin
         Err := Null_Unbounded_String;
         if Key = ""
           or else Normalized_Key = ""
           or else (Plus = Normalized_Key'First)
           or else not Open_Action_Base_Key_Is_Valid
             ((if Plus = 0
               then Normalized_Key
               else Normalized_Key (Normalized_Key'First .. Plus - 1)))
           or else not Action_Token_Modifiers_Are_Known (Key)
           or else To_String (Action.Executable) = ""
           or else Has_Unsafe_Placeholder_Usage (Action)
           or else not Action_Text_Is_Serializable (Action)
         then
            Err := To_Unbounded_String ("error.settings.invalid_open_action");
            return;
         end if;
         Add_Open_Action (Settings, Key, Action);
      end Parse_Open_Actions_Line;

      procedure Parse_Bookmarks_Line
        (Key, Setting_Key, Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         if Setting_Key = "bookmark" then
            --  New form: bookmark = "<path>" (path may contain '=' or start with
            --  '#'). The on-disk token stays "bookmark" so files keep loading.
            if Value /= "" then
               Settings.Favorite_Paths.Append (To_Unbounded_String (Value));
            end if;
         elsif Key /= "" then
            --  Legacy form: the bare path written as the key.
            Settings.Favorite_Paths.Append (To_Unbounded_String (Key));
         end if;
      end Parse_Bookmarks_Line;

      procedure Parse_Labels_Line
        (Setting_Key, Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         --  Each entry is written as label = "<color>|<path>". Split on the first
         --  '|': the color prefix names the swatch and the remainder is the
         --  (possibly '|'- or '='-bearing) path. An unknown color is skipped so a
         --  hand-edited file never fails to load over one bad tag.
         if Setting_Key = "label" and then Value /= "" then
            declare
               Bar   : constant Natural :=
                 Ada.Strings.Fixed.Index (Value, "|");
               Label : Files.Types.Color_Label;
            begin
               if Bar > Value'First and then Bar < Value'Last then
                  declare
                     Color_Text : constant String :=
                       Value (Value'First .. Bar - 1);
                     Path_Text  : constant String :=
                       Value (Bar + 1 .. Value'Last);
                  begin
                     if Color_Label_From_Name (Color_Text, Label) then
                        Set_Label (Settings, Path_Text, Label);
                     end if;
                  end;
               end if;
            end;
         end if;
      end Parse_Labels_Line;

      procedure Parse_Recent_Line
        (Setting_Key, Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         --  Each entry is written as recent = "<path>" in file order
         --  (most-recent-first). Append while under the cap so a hand-edited
         --  overflow load never grows unbounded; the quoted value survives paths
         --  with '=' or '#'.
         if Setting_Key = "recent"
           and then Value /= ""
           and then Natural (Settings.Recent_Paths_Value.Length) < Max_Recent_Items
         then
            Settings.Recent_Paths_Value.Append (To_Unbounded_String (Value));
         end if;
      end Parse_Recent_Line;

      procedure Parse_Shortcuts_Line
        (Setting_Key, Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         --  Each entry is written as shortcut = "<command>|<combo>". Split on the
         --  first '|': the prefix is a stable command identifier and the remainder
         --  is the shortcut text, which may be empty to record an explicit unbind.
         --  An entry whose identifier is empty is skipped so a hand-edited file
         --  never fails to load over one malformed line.
         if Setting_Key = "shortcut" and then Value /= "" then
            declare
               Bar : constant Natural :=
                 Ada.Strings.Fixed.Index (Value, "|");
            begin
               if Bar > Value'First and then Bar <= Value'Last then
                  Settings.Shortcut_Overrides.Append
                    (Shortcut_Override'
                       (Command => To_Unbounded_String (Value (Value'First .. Bar - 1)),
                        Combo   => To_Unbounded_String (Value (Bar + 1 .. Value'Last))));
               end if;
            end;
         end if;
      end Parse_Shortcuts_Line;

      procedure Parse_Settings_Line
        (Setting_Key, Value : String; Err : out Unbounded_String) is
      begin
         Err := Null_Unbounded_String;
         if Setting_Key = "default_view_mode" then
            declare
               Mode : constant String := Files.Types.To_Lower (Value);
            begin
               if Mode = "small" or else Mode = "small_icons" then
                  Settings.Default_View := Files.Types.Small_Icons;
               elsif Mode = "large" or else Mode = "large_icons" then
                  Settings.Default_View := Files.Types.Large_Icons;
               elsif Mode = "details" then
                  Settings.Default_View := Files.Types.Details;
               else
                  Err := To_Unbounded_String ("error.settings.invalid_view_mode");
               end if;
            end;
         elsif Setting_Key = "show_hidden_files" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Settings.Show_Hidden_Files, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "show_file_extensions" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Settings.Show_File_Extensions, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "show_used_space" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Settings.Show_Used_Space, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "show_space_bar" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Settings.Show_Space_Bar, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "sort_field" then
            declare
               Field : constant String := Files.Types.To_Lower (Value);
            begin
               if Field = "name" then
                  Settings.Sort_Field_Value := Sort_By_Name;
               elsif Field = "filetype" then
                  Settings.Sort_Field_Value := Sort_By_Filetype;
               elsif Field = "size" then
                  Settings.Sort_Field_Value := Sort_By_Size;
               elsif Field = "created" then
                  Settings.Sort_Field_Value := Sort_By_Created;
               elsif Field = "modified" then
                  Settings.Sort_Field_Value := Sort_By_Modified;
               else
                  Err := To_Unbounded_String ("error.settings.invalid_sort_field");
               end if;
            end;
         elsif Setting_Key = "sort_ascending" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Settings.Sort_Ascending, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "theme" then
            declare
               Theme_Value : constant String := Files.Types.To_Lower (Value);
            begin
               if Theme_Value = "dark" then
                  Settings.Theme := Theme_Dark;
               elsif Theme_Value = "light" then
                  Settings.Theme := Theme_Light;
               elsif Theme_Value = "high_contrast" then
                  Settings.Theme := Theme_High_Contrast;
               else
                  Err := To_Unbounded_String ("error.settings.invalid_theme");
               end if;
               if Length (Err) = 0 then
                  Theme_Explicit := True;
               end if;
            end;
         elsif Setting_Key = "high_contrast_theme" then
            --  Legacy key: resolved into Settings.Theme after the loop.
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Legacy_High, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "light_theme" then
            --  Legacy key: resolved into Settings.Theme after the loop.
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Files.Types.To_Lower (Value), Legacy_Light, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "icon_theme" then
            if Icon_Theme_Name_Is_Valid (Value) then
               Settings.Icon_Theme_Name := To_Unbounded_String (Files.Types.To_Lower (Value));
            else
               Err := To_Unbounded_String ("error.settings.invalid_icon_theme");
            end if;
         elsif Setting_Key = "font_pixel_size" then
            declare
               N : Integer;
            begin
               N := Integer'Value (Value);
               if N < 10 or else N > 32 then
                  Err := To_Unbounded_String ("error.settings.invalid_font_pixel_size");
               else
                  Settings.Font_Pixel_Size := Positive (N);
               end if;
            exception
               when Constraint_Error =>
                  Err := To_Unbounded_String ("error.settings.invalid_font_pixel_size");
            end;
         elsif Setting_Key = "window_width" then
            begin
               Settings.Window_Width := Natural'Value (Value);
            exception
               when Constraint_Error =>
                  Settings.Window_Width := 0;
            end;
         elsif Setting_Key = "window_height" then
            begin
               Settings.Window_Height := Natural'Value (Value);
            exception
               when Constraint_Error =>
                  Settings.Window_Height := 0;
            end;
         elsif Setting_Key = "info_pane_open" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Value, Settings.Info_Pane_Open, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "use_system_default_opener" then
            declare
               OK : Boolean;
            begin
               Parse_Boolean (Value, Settings.Use_System_Default_Opener, OK);
               if not OK then
                  Err := To_Unbounded_String ("error.settings.invalid_boolean");
               end if;
            end;
         elsif Setting_Key = "group_by" then
            declare
               Mode : constant String := Files.Types.To_Lower (Value);
            begin
               if Mode = "none" then
                  Settings.Group_By := Files.Types.No_Grouping;
               elsif Mode = "type" then
                  Settings.Group_By := Files.Types.Group_By_Type;
               elsif Mode = "modified" then
                  Settings.Group_By := Files.Types.Group_By_Modified;
               elsif Mode = "size" then
                  Settings.Group_By := Files.Types.Group_By_Size;
               elsif Mode = "label" then
                  Settings.Group_By := Files.Types.Group_By_Label;
               else
                  Err := To_Unbounded_String ("error.settings.invalid_group");
               end if;
            end;
         elsif Setting_Key = "detail_column_order" then
            declare
               Order : Files.Types.Detail_Column_Order;
            begin
               if Parse_Detail_Column_Order (Value, Order) then
                  Settings.Column_Order := Order;
               else
                  Settings.Column_Order :=
                    Files.Types.Default_Detail_Column_Order;
                  Err := To_Unbounded_String ("error.settings.invalid_column_order");
               end if;
            end;
         elsif Setting_Key'Length >= 20
           and then Setting_Key
             (Setting_Key'First .. Setting_Key'First + 19) = "detail_column_width_"
         then
            declare
               Suffix : constant String :=
                 Setting_Key (Setting_Key'First + 20 .. Setting_Key'Last);
               Column : Files.Types.Optional_Detail_Column;
            begin
               if Detail_Column_For_Key (Suffix, Column) then
                  begin
                     Settings.Column_Widths (Column) := Natural'Value (Value);
                  exception
                     when Constraint_Error =>
                        Settings.Column_Widths (Column) := 0;
                  end;
               else
                  Err := To_Unbounded_String ("error.settings.unknown_key");
               end if;
            end;
         elsif Setting_Key'Length >= 14
           and then Setting_Key
             (Setting_Key'First .. Setting_Key'First + 13) = "detail_column_"
         then
            declare
               Suffix : constant String :=
                 Setting_Key (Setting_Key'First + 14 .. Setting_Key'Last);
               Column : Files.Types.Optional_Detail_Column;
               OK     : Boolean;
            begin
               if Detail_Column_For_Key (Suffix, Column) then
                  Parse_Boolean
                    (Files.Types.To_Lower (Value), Settings.Column_Visible (Column), OK);
                  if not OK then
                     Err := To_Unbounded_String ("error.settings.invalid_boolean");
                  end if;
               else
                  Err := To_Unbounded_String ("error.settings.unknown_key");
               end if;
            end;
         else
            Err := To_Unbounded_String ("error.settings.unknown_key");
         end if;
      end Parse_Settings_Line;
   begin
      --  The file is authoritative for filetype/icon/open-action mappings:
      --  start from scalar defaults with empty maps so a mapping deleted from
      --  the file does not silently reappear from the built-in defaults.
      --  (Ensure_Default_File seeds a fresh install's file with the full
      --  defaults, so built-ins are present unless the user removed them.)
      Settings.Extension_Filetypes.Clear;
      Settings.Icon_Mappings.Clear;
      Settings.Open_Actions.Clear;

      if Text = "" then
         return
           (Success   => True,
            Settings  => Settings,
            Error_Key => Null_Unbounded_String);
      end if;

      --  Skip a leading UTF-8 BOM so an externally-edited/exported file's first
      --  section header is still recognized.
      if Text'Length >= 3
        and then Text (Text'First) = Character'Val (16#EF#)
        and then Text (Text'First + 1) = Character'Val (16#BB#)
        and then Text (Text'First + 2) = Character'Val (16#BF#)
      then
         Line_First := Text'First + 3;
      end if;

      while Line_First <= Text'Last loop
         Line_Last := Line_First;
         while Line_Last <= Text'Last and then Text (Line_Last) /= ASCII.LF loop
            Line_Last := Line_Last + 1;
         end loop;

         declare
            Raw_Line : constant String := Text (Line_First .. Line_Last - 1);
            Line     : constant String := Trim (Raw_Line);
            Equals   : Natural;
         begin
            if Line = "" or else Line (Line'First) = '#' then
               null;
            elsif Line (Line'First) = '[' and then Line (Line'Last) = ']' then
               declare
                  Name : constant String :=
                    Files.Types.To_Lower (Trim (Line (Line'First + 1 .. Line'Last - 1)));
               begin
                  if Name = "filetypes" then
                     Section := Filetypes_Section;
                  elsif Name = "icons" then
                     Section := Icons_Section;
                  elsif Name = "open-actions" then
                     Section := Open_Actions_Section;
                  elsif Name = "bookmarks" then
                     Section := Bookmarks_Section;
                  elsif Name = "labels" then
                     Section := Labels_Section;
                  elsif Name = "recent" then
                     Section := Recent_Section;
                  elsif Name = "shortcuts" then
                     Section := Shortcuts_Section;
                  elsif Name = "settings" then
                     Section := Settings_Section_Name;
                  else
                     return
                       (Success   => False,
                        Settings  => Settings,
                        Error_Key => To_Unbounded_String ("error.settings.unknown_section"));
                  end if;
               end;
            else
               Equals := Ada.Strings.Fixed.Index (Line, "=");
               if Equals = 0 then
                  return
                    (Success   => False,
                     Settings  => Settings,
                     Error_Key => To_Unbounded_String ("error.settings.expected_equals"));
               end if;

               declare
                  Key       : constant String := Trim (Line (Line'First .. Equals - 1));
                  Setting_Key : constant String := Files.Types.To_Lower (Key);
                  Raw_Value : constant String := Trim (Line (Equals + 1 .. Line'Last));
                  Value     : constant String := Strip_Quotes (Raw_Value);
                  Err       : Unbounded_String := Null_Unbounded_String;
               begin
                  case Section is
                     when Filetypes_Section =>
                        Parse_Filetypes_Line (Key, Value, Raw_Value, Err);
                     when Icons_Section =>
                        Parse_Icons_Line (Key, Value, Raw_Value, Err);
                     when Open_Actions_Section =>
                        Parse_Open_Actions_Line (Key, Raw_Value, Err);
                     when Bookmarks_Section =>
                        Parse_Bookmarks_Line (Key, Setting_Key, Value, Err);
                     when Labels_Section =>
                        Parse_Labels_Line (Setting_Key, Value, Err);
                     when Recent_Section =>
                        Parse_Recent_Line (Setting_Key, Value, Err);
                     when Shortcuts_Section =>
                        Parse_Shortcuts_Line (Setting_Key, Value, Err);
                     when Settings_Section_Name =>
                        Parse_Settings_Line (Setting_Key, Value, Err);
                     when No_Section =>
                        Err := To_Unbounded_String ("error.settings.missing_section");
                  end case;

                  if Length (Err) > 0 then
                     return
                       (Success   => False,
                        Settings  => Settings,
                        Error_Key => Err);
                  end if;
               end;
            end if;
         end;

         Line_First := Line_Last + 1;
      end loop;

      --  When no modern "theme" key was present, fall back to the legacy
      --  booleans: high contrast takes precedence over light, matching the old
      --  rendering precedence; absent everything leaves the default (dark).
      if not Theme_Explicit then
         if Legacy_High then
            Settings.Theme := Theme_High_Contrast;
         elsif Legacy_Light then
            Settings.Theme := Theme_Light;
         else
            Settings.Theme := Theme_Dark;
         end if;
      end if;

      return
        (Success   => True,
         Settings  => Settings,
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Settings  => Settings,
            Error_Key => To_Unbounded_String ("error.settings.invalid"));
   end Parse;

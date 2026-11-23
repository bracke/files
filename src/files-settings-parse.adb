with Files.Preference_Types;
with Files.Diagnostics;
with Files.Settings.Path_References;
with Files.Settings.Open_Actions;

separate (Files.Settings)
   function Parse
     (Text : String)
      return Settings_Parse_Result
   is
      use type Files.Preference_Types.Color_Label;

      Settings   : Settings_Model := Default_Settings;
      Section    : Settings_Section := No_Section;
      Line_First : Positive := Text'First;
      Line_Last  : Natural;
      --  Backward-compatibility state: when the file lacks the modern "theme"
      --  key, the legacy "high_contrast_theme"/"light_theme" booleans below are
      --  resolved into Settings.Theme after the loop (high contrast wins).
      Theme_Explicit : Boolean := False;
      Legacy_Theme   : array (Legacy_Theme_Flag) of Boolean := [others => False];
      Entry_Count    : Natural := 0;
      --  The labels read so far, by matched path (Path_References.Load_Label).
      Known_Labels   : Path_References.Label_Position_Maps.Map;

      --  Per-section key=value handlers, dispatched through Line_Handlers
      --  below. Each takes the line's key as written (Key), lower-cased
      --  (Setting_Key), its unquoted value (Value) and its value as written
      --  (Raw_Value), mutates the enclosing Settings (and, for [settings], the
      --  legacy-theme flags) and reports a rejected value by setting Err to the
      --  error key; the main loop then returns it. A null Err means the line was
      --  accepted (or ignored, for the append-only sections).

      --  A [filetypes] or [icons] line: a non-empty valid key (as Mapping_Key
      --  reads it) mapped to a non-empty valid, correctly quoted value.
      generic
         with function Mapping_Key (Key : String) return String;
         with procedure Add (Settings : in out Settings_Model; Key, Value : String);
      procedure Parse_Mapping_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String);

      procedure Parse_Mapping_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      function Icon_Key (Key : String) return String is (Key);

      procedure Parse_Filetypes_Line is new Parse_Mapping_Line
        (Files.File_Types.Normalize_Extension, Add_Extension_Mapping);
      procedure Parse_Icons_Line is new Parse_Mapping_Line (Icon_Key, Add_Icon_Mapping);

      procedure Parse_Open_Actions_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      procedure Parse_Bookmarks_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      --  Find the first '|' of a "<head>|<tail>" entry. The head must not be
      --  empty; the tail may be.
      --
      --  @param Value The entry.
      --  @param Bar Where the '|' is, when it splits Value.
      --  @return Whether Value has a '|' after a non-empty head.
      function Split_At_Bar (Value : String; Bar : out Natural) return Boolean is
      begin
         Bar := Ada.Strings.Fixed.Index (Value, "|");
         return Bar > Value'First;
      end Split_At_Bar;

      procedure Parse_Labels_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      procedure Parse_Recent_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      procedure Parse_Shortcuts_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      procedure Parse_Settings_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      --  A key=value line before any section header.
      procedure Parse_Sectionless_Line
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String) is separate;

      type Line_Handler is access procedure
        (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String);

      --  The handler for a key=value line in each section.
      Line_Handlers : constant array (Settings_Section) of Line_Handler :=
        [No_Section            => Parse_Sectionless_Line'Access,
         Filetypes_Section     => Parse_Filetypes_Line'Access,
         Icons_Section         => Parse_Icons_Line'Access,
         Open_Actions_Section  => Parse_Open_Actions_Line'Access,
         Bookmarks_Section     => Parse_Bookmarks_Line'Access,
         Labels_Section        => Parse_Labels_Line'Access,
         Recent_Section        => Parse_Recent_Line'Access,
         Shortcuts_Section     => Parse_Shortcuts_Line'Access,
         Settings_Section_Name => Parse_Settings_Line'Access];

      --  The section a header named Name (lower-cased) opens; False when no
      --  section has that name.
      function Section_Named
        (Name  : String;
         Named : out Settings_Section)
         return Boolean is separate;

      --  One line of the file, without its line feed: a comment or blank
      --  line is skipped, a header opens its section, and an entry goes to
      --  its section's handler (Line_Handlers). Err is the key of what
      --  makes the file unreadable, else empty.
      procedure Parse_Line (Raw_Line : String; Err : out Unbounded_String) is separate;

      function Failed (Error_Key : String) return Settings_Parse_Result is
        (Success => False, Settings => Settings, Error_Key => To_Unbounded_String (Error_Key));
   begin
      if Text'Length > Max_Settings_Text_Bytes or else Contains_Nul (Text) then
         return Failed ("error.settings.invalid");
      end if;

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
            Err : Unbounded_String;
         begin
            Parse_Line (Text (Line_First .. Line_Last - 1), Err);
            if Length (Err) > 0 then
               return (Success => False, Settings => Settings, Error_Key => Err);
            end if;
         end;

         Line_First := Line_Last + 1;
      end loop;

      --  When no modern "theme" key was present, fall back to the legacy
      --  booleans: high contrast takes precedence over light, matching the old
      --  rendering precedence; absent everything leaves the default (dark).
      if not Theme_Explicit then
         if Legacy_Theme (Legacy_High_Contrast) then
            Settings.Theme := Theme_High_Contrast;
         elsif Legacy_Theme (Legacy_Light) then
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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Settings");
         return Failed ("error.settings.invalid");
   end Parse;

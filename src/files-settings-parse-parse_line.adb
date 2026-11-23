with Files.Text_Case;

separate (Files.Settings.Parse)
   procedure Parse_Line (Raw_Line : String; Err : out Unbounded_String) is
      Line   : constant String := Trim (Raw_Line);
      Equals : Natural;
   begin
      Err := Null_Unbounded_String;
      if Raw_Line'Length > Max_Settings_Line_Bytes then
         Err := To_Unbounded_String ("error.settings.invalid");
      elsif Line = "" or else Line (Line'First) = '#' then
         null;
      elsif Line (Line'First) = '[' and then Line (Line'Last) = ']' then
         declare
            Name  : constant String :=
              Files.Text_Case.To_Lower_Ascii (Trim (Line (Line'First + 1 .. Line'Last - 1)));
            Named : Settings_Section;
         begin
            if Section_Named (Name, Named) then
               Section := Named;
            else
               Err := To_Unbounded_String ("error.settings.unknown_section");
            end if;
         end;
      elsif Entry_Count >= Max_Settings_Entries then
         Err := To_Unbounded_String ("error.settings.invalid");
      else
         Entry_Count := Entry_Count + 1;
         Equals := Ada.Strings.Fixed.Index (Line, "=");
         if Equals = 0 then
            Err := To_Unbounded_String ("error.settings.expected_equals");
            return;
         end if;
         declare
            Key         : constant String := Trim (Line (Line'First .. Equals - 1));
            Setting_Key : constant String := Files.Text_Case.To_Lower_Ascii (Key);
            Raw_Value   : constant String := Trim (Line (Equals + 1 .. Line'Last));
            Value       : constant String := Strip_Quotes (Raw_Value);
         begin
            Line_Handlers (Section).all (Key, Setting_Key, Value, Raw_Value, Err);
         end;
      end if;
   end Parse_Line;

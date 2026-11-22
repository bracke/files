separate (Files.Settings.Parse)
   procedure Parse_Settings_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Key, Raw_Value);
      Setting : Scalar_Setting;
      OK      : Boolean;
   begin
      Err := Null_Unbounded_String;
      for Flag in Legacy_Theme_Flag loop
         if Setting_Key = Legacy_Theme_Keys (Flag).all then
            --  Legacy key: resolved into Settings.Theme after the loop.
            Parse_Boolean (Files.Text_Case.To_Lower_Ascii (Value), Legacy_Theme (Flag), OK);
            if not OK then
               Err := To_Unbounded_String ("error.settings.invalid_boolean");
            end if;
            return;
         end if;
      end loop;

      if Scalar_For_Key (Setting_Key, Setting) then
         Set_Scalar (Settings, Setting, Value, Err);
         if Setting = Theme_Setting and then Length (Err) = 0 then
            Theme_Explicit := True;
         end if;
      else
         Err := To_Unbounded_String ("error.settings.unknown_key");
      end if;
   end Parse_Settings_Line;

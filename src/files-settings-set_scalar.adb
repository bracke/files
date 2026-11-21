with Files.Preference_Types;
separate (Files.Settings)
   procedure Set_Scalar
     (Settings  : in out Settings_Model;
      Setting   : Scalar_Setting;
      Text      : String;
      Error_Key : out UString)
   is
      Column : constant Files.Preference_Types.Optional_Detail_Column := Scalar_Table (Setting).Column;
      Lower  : constant String := Files.Types.To_Lower_Ascii (Text);
      Valid  : Boolean := True;

      --  Parse Text as a plain decimal number: one or more ASCII digits and
      --  nothing else. Unlike Natural'Value this rejects Ada literal syntax
      --  (16#400#, 1_024, 1E3) and surrounding blanks, and it reports a value
      --  beyond Natural'Last as invalid instead of raising.
      function Parse_Decimal (Number : out Natural) return Boolean is
         Digit : Natural;
      begin
         Number := 0;
         if Text'Length = 0 then
            return False;
         end if;
         for Ch of Text loop
            if Ch not in '0' .. '9' then
               Number := 0;
               return False;
            end if;
            Digit := Character'Pos (Ch) - Character'Pos ('0');
            if Number > (Natural'Last - Digit) / 10 then
               Number := 0;
               return False;
            end if;
            Number := Number * 10 + Digit;
         end loop;
         return True;
      end Parse_Decimal;

      --  A persisted window dimension: zero (or an invalid value) keeps the
      --  platform default, anything else is clamped into the supported range.
      function Window_Dimension return Natural is
         N : Natural;
      begin
         if not Parse_Decimal (N) or else N = 0 then
            return 0;
         end if;
         return Natural'Min (Natural'Max (N, Min_Window_Dimension), Max_Window_Dimension);
      end Window_Dimension;
   begin
      case Setting is
         when Default_View_Mode_Setting =>
            --  Read back exactly the tokens View_Mode_Name writes, plus the
            --  older short spellings "small" and "large".
            Valid := False;
            for Mode in Files.Preference_Types.View_Mode loop
               if Lower = View_Mode_Name (Mode) then
                  Settings.Default_View := Mode;
                  Valid := True;
               end if;
            end loop;
            if Lower = "small" then
               Settings.Default_View := Files.Preference_Types.Small_Icons;
               Valid := True;
            elsif Lower = "large" then
               Settings.Default_View := Files.Preference_Types.Large_Icons;
               Valid := True;
            end if;
         when Show_Hidden_Files_Setting =>
            Parse_Boolean (Lower, Settings.Show_Hidden_Files, Valid);
         when Show_File_Extensions_Setting =>
            Parse_Boolean (Lower, Settings.Show_File_Extensions, Valid);
         when Show_Used_Space_Setting =>
            Parse_Boolean (Lower, Settings.Show_Used_Space, Valid);
         when Show_Space_Bar_Setting =>
            Parse_Boolean (Lower, Settings.Show_Space_Bar, Valid);
         when Sort_Field_Setting =>
            --  Read back exactly the tokens Sort_Field_Name writes.
            Valid := False;
            for Field in Files.Types.Sort_Field loop
               if Lower = Sort_Field_Name (Field) then
                  Settings.Sort_Field_Value := Field;
                  Valid := True;
               end if;
            end loop;
         when Sort_Ascending_Setting =>
            Parse_Boolean (Lower, Settings.Sort_Ascending, Valid);
         when Theme_Setting =>
            Valid := False;
            for Theme in Theme_Choice loop
               if Lower = Theme_Name (Theme) then
                  Settings.Theme := Theme;
                  Valid := True;
               end if;
            end loop;
         when Icon_Theme_Setting =>
            Valid := Files.Icon_Themes.Is_Name (Text);
            if Valid then
               Settings.Icon_Theme := Files.Icon_Themes.Value (Text);
            end if;
         when Font_Pixel_Size_Setting =>
            declare
               N : Natural;
            begin
               Valid := Parse_Decimal (N)
                 and then N >= Min_Font_Pixel_Size
                 and then N <= Max_Font_Pixel_Size;
               if Valid then
                  Settings.Font_Pixel_Size := Positive (N);
               end if;
            end;
         when Info_Pane_Open_Setting =>
            Parse_Boolean (Lower, Settings.Info_Pane_Open, Valid);
         when Use_System_Default_Opener_Setting =>
            Parse_Boolean (Lower, Settings.Use_System_Default_Opener, Valid);
         when Group_By_Setting =>
            Valid := False;
            for Mode in Files.Preference_Types.Group_Mode loop
               if Lower = Group_Mode_Name (Mode) then
                  Settings.Group_By := Mode;
                  Valid := True;
               end if;
            end loop;
         when Detail_Column_Order_Setting =>
            declare
               Order : Files.Preference_Types.Detail_Column_Order;
            begin
               --  A rejected order comes back as the default order.
               Valid := Parse_Detail_Column_Order (Text, Order);
               Settings.Column_Order := Order;
            end;
         when Detail_Column_Modified_Setting
            | Detail_Column_Size_Setting
            | Detail_Column_Filetype_Setting
            | Detail_Column_Created_Setting
            | Detail_Column_Permissions_Setting =>
            Parse_Boolean (Lower, Settings.Column_Visible (Column), Valid);
         when Detail_Column_Width_Modified_Setting
            | Detail_Column_Width_Size_Setting
            | Detail_Column_Width_Filetype_Setting
            | Detail_Column_Width_Created_Setting
            | Detail_Column_Width_Permissions_Setting =>
            declare
               Width : Natural;
            begin
               --  An invalid width resets to the proportional default (0); a
               --  valid one goes through With_Column_Width so it gets the same
               --  minimum clamp as an interactive resize.
               if not Parse_Decimal (Width) then
                  Width := 0;
               end if;
               Settings := With_Column_Width (Settings, Column, Width);
            end;
         when Window_Width_Setting =>
            Settings.Window_Width := Window_Dimension;
         when Window_Height_Setting =>
            Settings.Window_Height := Window_Dimension;
      end case;

      Error_Key :=
        (if Valid then Null_Unbounded_String else To_Unbounded_String (Scalar_Error_Key (Setting)));
   end Set_Scalar;

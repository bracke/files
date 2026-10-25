separate (Files.Settings)
   procedure Set_Scalar
     (Settings  : in out Settings_Model;
      Setting   : Scalar_Setting;
      Text      : String;
      Error_Key : out UString)
   is
      Column : constant Files.Types.Optional_Detail_Column := Scalar_Table (Setting).Column;
      Lower  : constant String := Files.Types.To_Lower (Text);
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
            if Lower = "small" or else Lower = "small_icons" then
               Settings.Default_View := Files.Types.Small_Icons;
            elsif Lower = "large" or else Lower = "large_icons" then
               Settings.Default_View := Files.Types.Large_Icons;
            elsif Lower = "details" then
               Settings.Default_View := Files.Types.Details;
            else
               Valid := False;
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
            if Lower = "dark" then
               Settings.Theme := Theme_Dark;
            elsif Lower = "light" then
               Settings.Theme := Theme_Light;
            elsif Lower = "high_contrast" then
               Settings.Theme := Theme_High_Contrast;
            else
               Valid := False;
            end if;
         when Icon_Theme_Setting =>
            Valid := Icon_Theme_Name_Is_Valid (Text);
            if Valid then
               Settings.Icon_Theme_Name := To_Unbounded_String (Lower);
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
            --  Historically matched case-sensitively, unlike the other flags.
            Parse_Boolean (Text, Settings.Info_Pane_Open, Valid);
         when Use_System_Default_Opener_Setting =>
            --  Historically matched case-sensitively, unlike the other flags.
            Parse_Boolean (Text, Settings.Use_System_Default_Opener, Valid);
         when Group_By_Setting =>
            if Lower = "none" then
               Settings.Group_By := Files.Types.No_Grouping;
            elsif Lower = "type" then
               Settings.Group_By := Files.Types.Group_By_Type;
            elsif Lower = "modified" then
               Settings.Group_By := Files.Types.Group_By_Modified;
            elsif Lower = "size" then
               Settings.Group_By := Files.Types.Group_By_Size;
            elsif Lower = "label" then
               Settings.Group_By := Files.Types.Group_By_Label;
            else
               Valid := False;
            end if;
         when Detail_Column_Order_Setting =>
            declare
               Order : Files.Types.Detail_Column_Order;
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

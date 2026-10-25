separate (Files_Suite.Settings)
   --  Numeric settings are plain decimal digits: Ada literal syntax that
   --  Natural'Value would accept is rejected, window sizes are clamped into
   --  Min_Window_Dimension .. Max_Window_Dimension, and column widths get the
   --  same minimum clamp as an interactive resize.
   procedure Test_Settings_Numeric_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Parse_Setting (Line : String) return Files.Settings.Settings_Parse_Result is
        (Files.Settings.Parse ("[settings]" & ASCII.LF & Line & ASCII.LF));

      function Width_Of (Value : String) return Natural is
        (Parse_Setting ("window_width = " & Value).Settings.Window_Width);

      function Size_Column_Width_Of (Value : String) return Natural is
        (Parse_Setting ("detail_column_width_size = " & Value).Settings.Column_Widths (Files.Types.Size_Column));

      Font_Literals : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("16#10#"), To_Unbounded_String ("1_6"), To_Unbounded_String ("16E0"),
         To_Unbounded_String ("99999999999999999999")];

      Normal : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Parse
          ("[settings]" & ASCII.LF
           & "window_width = 1280" & ASCII.LF
           & "window_height = 800" & ASCII.LF
           & "font_pixel_size = 18" & ASCII.LF
           & "detail_column_width_modified = 175" & ASCII.LF);
   begin
      Assert (Normal.Success, "plain decimal numeric settings parse");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Window_Width, 1280, "a normal window width is unchanged");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Window_Height, 800, "a normal window height is unchanged");
      Files_Suite.Support.Assert_Equal (Normal.Settings.Font_Pixel_Size, 18, "a normal font pixel size is unchanged");
      Files_Suite.Support.Assert_Equal
        (Normal.Settings.Column_Widths (Files.Types.Modified_Column), 175, "a normal column width is unchanged");

      Files_Suite.Support.Assert_Equal (Width_Of ("16#400#"), 0, "a based window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("1_024"), 0, "an underscored window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("1E3"), 0, "an exponent window width literal is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("+800"), 0, "a signed window width is rejected");
      Files_Suite.Support.Assert_Equal (Width_Of ("0"), 0, "a zero window width keeps the platform default");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("1000000"), Files.Settings.Max_Window_Dimension, "a huge window width is clamped to the maximum");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("10"), Files.Settings.Min_Window_Dimension, "a tiny window width is clamped to the minimum");
      Files_Suite.Support.Assert_Equal
        (Width_Of ("99999999999999999999"), 0, "a window width beyond Natural'Last is rejected, not raised");
      Files_Suite.Support.Assert_Equal
        (Parse_Setting ("window_height = 1000000").Settings.Window_Height,
         Files.Settings.Max_Window_Dimension,
         "a huge window height is clamped to the maximum");

      Files_Suite.Support.Assert_Equal
        (Size_Column_Width_Of ("5"),
         Files.Types.Minimum_Detail_Column_Width,
         "a column width below the minimum is clamped up to it");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("200"), 200, "a column width above the minimum is kept");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("16#C8#"), 0, "a based column width literal is rejected");
      Files_Suite.Support.Assert_Equal (Size_Column_Width_Of ("2_00"), 0, "an underscored column width is rejected");

      for Literal of Font_Literals loop
         declare
            Parsed : constant Files.Settings.Settings_Parse_Result :=
              Parse_Setting ("font_pixel_size = " & To_String (Literal));
         begin
            Assert (not Parsed.Success, "font pixel size literal " & To_String (Literal) & " is rejected");
            Files_Suite.Support.Assert_Equal
              (To_String (Parsed.Error_Key),
               "error.settings.invalid_font_pixel_size",
               "font pixel size literal " & To_String (Literal) & " reports the font size diagnostic");
         end;
      end loop;
   end Test_Settings_Numeric_Values;

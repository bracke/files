separate (Files.Settings)
   function Scalar_Text
     (Settings : Settings_Model;
      Setting  : Scalar_Setting)
      return String
   is
      Column : constant Files.Types.Optional_Detail_Column := Scalar_Table (Setting).Column;

      function Order_Text return String is
         Order_Value : Unbounded_String := Null_Unbounded_String;
      begin
         for Slot in Settings.Column_Order'Range loop
            if Slot > Settings.Column_Order'First then
               Append (Order_Value, ",");
            end if;
            Append (Order_Value, Detail_Column_Order_Token (Settings.Column_Order (Slot)));
         end loop;
         return To_String (Order_Value);
      end Order_Text;
   begin
      case Setting is
         when Default_View_Mode_Setting =>
            return View_Mode_Name (Settings.Default_View);
         when Show_Hidden_Files_Setting =>
            return Boolean_Name (Settings.Show_Hidden_Files);
         when Show_File_Extensions_Setting =>
            return Boolean_Name (Settings.Show_File_Extensions);
         when Show_Used_Space_Setting =>
            return Boolean_Name (Settings.Show_Used_Space);
         when Show_Space_Bar_Setting =>
            return Boolean_Name (Settings.Show_Space_Bar);
         when Sort_Field_Setting =>
            return Sort_Field_Name (Settings.Sort_Field_Value);
         when Sort_Ascending_Setting =>
            return Boolean_Name (Settings.Sort_Ascending);
         when Theme_Setting =>
            return Theme_Name (Settings.Theme);
         when Icon_Theme_Setting =>
            return To_String (Settings.Icon_Theme_Name);
         when Font_Pixel_Size_Setting =>
            return Trim (Positive'Image (Settings.Font_Pixel_Size));
         when Info_Pane_Open_Setting =>
            return Boolean_Name (Settings.Info_Pane_Open);
         when Use_System_Default_Opener_Setting =>
            return Boolean_Name (Settings.Use_System_Default_Opener);
         when Group_By_Setting =>
            return Group_Mode_Name (Settings.Group_By);
         when Detail_Column_Order_Setting =>
            return Order_Text;
         when Detail_Column_Modified_Setting
            | Detail_Column_Size_Setting
            | Detail_Column_Filetype_Setting
            | Detail_Column_Created_Setting
            | Detail_Column_Permissions_Setting =>
            return Boolean_Name (Settings.Column_Visible (Column));
         when Detail_Column_Width_Modified_Setting
            | Detail_Column_Width_Size_Setting
            | Detail_Column_Width_Filetype_Setting
            | Detail_Column_Width_Created_Setting
            | Detail_Column_Width_Permissions_Setting =>
            return Trim (Natural'Image (Settings.Column_Widths (Column)));
         when Window_Width_Setting =>
            return Trim (Natural'Image (Settings.Window_Width));
         when Window_Height_Setting =>
            return Trim (Natural'Image (Settings.Window_Height));
      end case;
   end Scalar_Text;

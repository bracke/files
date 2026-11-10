with Files.Images.Netpbm;
separate (Files.File_System.Thumbnails)
   function Try_Write_Decoded_P3_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Pixels : Pixel_Vectors.Vector;
      Source_Width  : Natural := 0;
      Source_Height : Natural := 0;
      Max_Value     : Natural := 0;
      Read_Succeeded : Boolean := False;
      Read_Complete  : Boolean := False;
      Text : constant String :=
        Read_Bounded_Regular_File (Source_Path, Max_Fast_Decode_Source_Bytes, Read_Succeeded, Read_Complete);
      Scan_Index : Positive := Text'First;

      --  The next field of the source; "" at its end.
      function Next_Field return String is
         First : Positive;
         Last  : Natural;
      begin
         Files.Images.Netpbm.Next_Field (Text, Scan_Index, First, Last);
         return Text (First .. Last);
      end Next_Field;

      function Next_Natural
        (Value : out Natural)
         return Boolean is (Files.Images.Netpbm.Natural_Of (Next_Field, Value));

      function Scaled_Channel (Value : Natural) return Natural is
        (Natural (Files.Images.Netpbm.Channel (Value, Max_Value)));
   begin
      if not Read_Succeeded or else not Read_Complete then
         return False;
      end if;

      if Next_Field /= "P3" then
         return False;
      end if;

      if not Next_Natural (Source_Width)
        or else not Next_Natural (Source_Height)
        or else not Next_Natural (Max_Value)
        or else Source_Width = 0
        or else Source_Height = 0
        or else Max_Value = 0
        or else Max_Value > 65_535
        or else Source_Width > Max_Source_Side
        or else Source_Height > Max_Source_Side
        or else Source_Width * Source_Height > Max_Source_Pixels
      then
         return False;
      end if;

      for Pixel_Index in 1 .. Source_Width * Source_Height loop
         declare
            Red   : Natural;
            Green : Natural;
            Blue  : Natural;
         begin
            if not Next_Natural (Red)
              or else not Next_Natural (Green)
              or else not Next_Natural (Blue)
              or else Red > Max_Value
              or else Green > Max_Value
              or else Blue > Max_Value
            then
               return False;
            end if;

            Pixels.Append
              (New_Item =>
                 Rgba_Pixel'
                   (Red   => Scaled_Channel (Red),
                    Green => Scaled_Channel (Green),
                    Blue  => Scaled_Channel (Blue),
                    Alpha => 255));
         end;
      end loop;

      if Next_Field /= "" then
         return False;
      end if;

      Write_Pixels_As_Ppm (Target_Path, Size, Pixels, Source_Width, Source_Height);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Try_Write_Decoded_P3_Thumbnail;

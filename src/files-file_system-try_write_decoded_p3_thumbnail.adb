separate (Files.File_System)
   function Try_Write_Decoded_P3_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Token   : Unbounded_String;
      Content : Unbounded_String;
      Scan_Index : Positive := 1;
      Pixels : Pixel_Vectors.Vector;
      Source_Width  : Natural := 0;
      Source_Height : Natural := 0;
      Max_Value     : Natural := 0;
      Read_Succeeded : Boolean := False;
      Read_Complete  : Boolean := False;

      function Next_Token return Boolean is
         Value : Character;
      begin
         Token := Null_Unbounded_String;
         while Scan_Index <= Length (Content) loop
            Value := Element (Content, Scan_Index);
            Scan_Index := Scan_Index + 1;
            if Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
               if Length (Token) > 0 then
                  return True;
               end if;
            elsif Value = '#' then
               while Scan_Index <= Length (Content)
                 and then Element (Content, Scan_Index) /= ASCII.LF
                 and then Element (Content, Scan_Index) /= ASCII.CR
               loop
                  Scan_Index := Scan_Index + 1;
               end loop;
               if Length (Token) > 0 then
                  return True;
               end if;
            else
               Append (Token, Value);
            end if;
         end loop;

         return Length (Token) > 0;
      end Next_Token;

      function Next_Natural
        (Value : out Natural)
         return Boolean is
      begin
         if not Next_Token then
            return False;
         end if;

         Value := Natural'Value (To_String (Token));
         return True;
      exception
         when others =>
            return False;
      end Next_Natural;

      function Scaled_Channel
        (Value : Natural)
         return Natural is
      begin
         if Max_Value = 0 then
            return 0;
         elsif Max_Value = 255 then
            return Natural'Min (Value, 255);
         end if;

         return Natural'Min ((Value * 255) / Max_Value, 255);
      end Scaled_Channel;
   begin
      Content := To_Unbounded_String
        (Read_Bounded_Regular_File
           (Source_Path, Max_Fast_Decode_Source_Bytes,
            Read_Succeeded, Read_Complete));
      if not Read_Succeeded or else not Read_Complete then
         return False;
      end if;

      if not Next_Token or else To_String (Token) /= "P3" then
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

      if Next_Token then
         return False;
      end if;

      Write_Pixels_As_Ppm (Target_Path, Size, Pixels, Source_Width, Source_Height);
      return True;
   exception
      when others =>
         return False;
   end Try_Write_Decoded_P3_Thumbnail;

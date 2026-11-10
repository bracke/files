with Files.Images.Netpbm;
separate (Files.File_System.Thumbnails)
   function Try_Write_Decoded_P3_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Pixels         : Pixel_Vectors.Vector;
      Rgba           : Files.Types.Byte_Vectors.Vector;
      Source_Width   : Natural;
      Source_Height  : Natural;
      Read_Succeeded : Boolean := False;
      Read_Complete  : Boolean := False;
      Text : constant String :=
        Read_Bounded_Regular_File (Source_Path, Max_Fast_Decode_Source_Bytes, Read_Succeeded, Read_Complete);
   begin
      if not Read_Succeeded
        or else not Read_Complete
        or else not Files.Images.Netpbm.Decode_P3
          (Text, Max_Source_Side, Max_Source_Pixels, Source_Width, Source_Height, Rgba)
      then
         return False;
      end if;

      for Pixel in 0 .. Source_Width * Source_Height - 1 loop
         declare
            At_Red : constant Natural := Rgba.First_Index + 4 * Pixel;
         begin
            Pixels.Append
              (Rgba_Pixel'
                 (Red   => Natural (Rgba.Element (At_Red)),
                  Green => Natural (Rgba.Element (At_Red + 1)),
                  Blue  => Natural (Rgba.Element (At_Red + 2)),
                  Alpha => 255));
         end;
      end loop;
      Write_Pixels_As_Ppm (Target_Path, Size, Pixels, Source_Width, Source_Height);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Try_Write_Decoded_P3_Thumbnail;

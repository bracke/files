separate (Files.File_System.Thumbnails)
   function Try_Write_Gdk_Pixbuf_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Image   : constant Files.Images.Decoded_Image :=
        Files.Images.Decode_Image_To_Pixels (Source_Path, Size);
      Decoded : Pixel_Vectors.Vector;
   begin
      if not Image.Available
        or else Image.Width = 0
        or else Image.Height = 0
        or else Natural (Image.Pixels.Length) /= Image.Width * Image.Height * 4
      then
         return False;
      end if;
      Decoded.Reserve_Capacity
        (Ada.Containers.Count_Type (Image.Width * Image.Height));
      for Index in 0 .. Image.Width * Image.Height - 1 loop
         declare
            --  The pixel vector is indexed from First_Index (1), not 0: read
            --  from 0 and the first Element raised, which the handler below
            --  turned into "not decoded" -- every JPEG got the stand-in.
            Offset : constant Positive := Image.Pixels.First_Index + Index * 4;
         begin
            Decoded.Append
              (Rgba_Pixel'
                 (Red   => Natural (Image.Pixels.Element (Offset)),
                  Green => Natural (Image.Pixels.Element (Offset + 1)),
                  Blue  => Natural (Image.Pixels.Element (Offset + 2)),
                  Alpha => Natural (Image.Pixels.Element (Offset + 3))));
         end;
      end loop;
      Write_Pixels_As_Ppm (Target_Path, Size, Decoded, Image.Width, Image.Height);
      return True;
   exception
      when others =>
         return False;
   end Try_Write_Gdk_Pixbuf_Thumbnail;

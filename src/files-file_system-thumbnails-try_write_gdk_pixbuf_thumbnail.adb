separate (Files.File_System.Thumbnails)
   function Try_Write_Gdk_Pixbuf_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Image   : constant Decoded_Image :=
        Decode_Image_To_Pixels (Source_Path, Size);
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
         Decoded.Append
           (Rgba_Pixel'
              (Red   => Natural (Image.Pixels.Element (Index * 4)),
               Green => Natural (Image.Pixels.Element (Index * 4 + 1)),
               Blue  => Natural (Image.Pixels.Element (Index * 4 + 2)),
               Alpha => Natural (Image.Pixels.Element (Index * 4 + 3))));
      end loop;
      Write_Pixels_As_Ppm (Target_Path, Size, Decoded, Image.Width, Image.Height);
      return True;
   exception
      when others =>
         return False;
   end Try_Write_Gdk_Pixbuf_Thumbnail;

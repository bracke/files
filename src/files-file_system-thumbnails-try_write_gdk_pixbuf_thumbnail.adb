separate (Files.File_System.Thumbnails)
   function Try_Write_Gdk_Pixbuf_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      Image   : constant Files.Images.Decoded_Image :=
        Files.Images.Decode_Image_To_Pixels (Source_Path, Size);
   begin
      if not Image.Available
        or else Image.Width = 0
        or else Image.Height = 0
        or else Natural (Image.Pixels.Length) /= Image.Width * Image.Height * 4
      then
         return False;
      end if;
      Write_Pixels_As_Ppm (Target_Path, Size, Image.Pixels, Image.Width, Image.Height);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Try_Write_Gdk_Pixbuf_Thumbnail;

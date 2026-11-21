with Files.IO.Capped_Files;
with Files.Images.Png;
separate (Files.File_System.Thumbnails)
   function Try_Write_Decoded_Png_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      use type Files.IO.Capped_Files.Read_Status;
      Status : Files.IO.Capped_Files.Read_Status;
      Raw    : constant String :=
        Files.IO.Capped_Files.Read_Capped
          (Source_Path, Max_Fast_Decode_Source_Bytes, Files.IO.Capped_Files.Refuse_Links, Status);
      Image  : Files.Images.Png.Raster;
   begin
      if Status /= Files.IO.Capped_Files.Read_Complete or else not Files.Images.Png.Decode (Raw, Image) then
         return False;
      end if;
      Write_Pixels_As_Ppm (Target_Path, Size, Image.Pixels, Image.Width, Image.Height);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Try_Write_Decoded_Png_Thumbnail;

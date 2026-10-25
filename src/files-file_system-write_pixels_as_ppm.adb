separate (Files.File_System)
--  Binary P6, not the ASCII P3 this used to write.
--
--  Identical pixels either way, but a 64x64 thumbnail is 12 KB here and
--  was 43 KB as text, and the loader on the directory-listing path had to
--  turn some twelve thousand ASCII numbers per thumbnail into as many
--  strings to read one back.
--
--  Stream_IO rather than Text_IO, and not only for the line endings:
--  Alire's switches carry -gnatW8, so Text_IO would try to encode every
--  pixel byte above 127 as UTF-8 on the way out and corrupt the image.
--  Load_Cached_Thumbnail reads both formats, so caches written before
--  this keep working rather than being silently discarded.
procedure Write_Pixels_As_Ppm
  (Target_Path   : String;
   Size          : Positive;
   Pixels        : Pixel_Vectors.Vector;
   Source_Width  : Natural;
   Source_Height : Natural)
is
   use Ada.Streams;

   Output : Stream_IO.File_Type;
   Row_Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size) * 3);

   procedure Put_Header (Text : String) is
      Buffer : Stream_Element_Array (1 .. Text'Length);
   begin
      for Index in Text'Range loop
         Buffer (Stream_Element_Offset (Index - Text'First + 1)) :=
           Stream_Element (Character'Pos (Text (Index)));
      end loop;

      Stream_IO.Write (Output, Buffer);
   end Put_Header;

   function Against_White
     (Channel, Alpha : Natural) return Stream_Element is
     (Stream_Element
        ((Channel * Alpha + 255 * (255 - Alpha) + 127) / 255));
begin
   Stream_IO.Create (Output, Stream_IO.Out_File, Target_Path, Form => "shared=no");
   Put_Header
     ("P6" & ASCII.LF
      & Image_No_Space (Size) & " " & Image_No_Space (Size) & ASCII.LF
      & "255" & ASCII.LF);

   for Row in 0 .. Size - 1 loop
      for Column in 0 .. Size - 1 loop
         declare
            Source_Row    : constant Natural := Row * Source_Height / Size;
            Source_Column : constant Natural := Column * Source_Width / Size;
            Source_Index  : constant Natural := Source_Row * Source_Width + Source_Column;
            Pixel         : constant Rgba_Pixel := Pixels.Element (Source_Index);
            At_Byte       : constant Stream_Element_Offset :=
              Stream_Element_Offset (Column) * 3 + 1;
         begin
            --  PPM has no alpha channel. Composite rather than exposing
            --  arbitrary RGB values hidden beneath transparent pixels.
            Row_Bytes (At_Byte)     := Against_White (Pixel.Red, Pixel.Alpha);
            Row_Bytes (At_Byte + 1) := Against_White (Pixel.Green, Pixel.Alpha);
            Row_Bytes (At_Byte + 2) := Against_White (Pixel.Blue, Pixel.Alpha);
         end;
      end loop;

      Stream_IO.Write (Output, Row_Bytes);
   end loop;

   Stream_IO.Close (Output);
exception
   when others =>
      if Stream_IO.Is_Open (Output) then
         Stream_IO.Close (Output);
      end if;
      raise;
end Write_Pixels_As_Ppm;

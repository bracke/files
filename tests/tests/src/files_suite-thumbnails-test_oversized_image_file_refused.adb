with Files.Images;
separate (Files_Suite.Thumbnails)
   --  A valid 1 x 1 PNG decodes from a file; the same file with only its IHDR
   --  size patched to 40000 x 40000 (CRC recomputed, image data unchanged) is
   --  refused. The loader would read the patched file as far as the real one,
   --  so the refusal comes from the header check before decoding. Quick Look
   --  and the gdk-pixbuf thumbnail writer both decode through this path. A
   --  real 4K screenshot, past the in-memory (emoji) pixel bound, still
   --  decodes: the file bounds apply.
   procedure Test_Oversized_Image_File_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Interfaces.Unsigned_32;
      use type Ada.Streams.Stream_Element_Offset;
      --  Generated with zlib: signature, IHDR, one IDAT (one red pixel), IEND.
      Small_Hex : constant String :=
        "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
        & "0000000d49444154789c63f8cfc0f01f00050001ff89993d1d0000000049454e44ae426082";
      Huge_Hex  : constant String :=
        "89504e470d0a1a0a0000000d4948445200009c4000009c400806000000510c0e05"
        & "0000000d49444154789c63f8cfc0f01f00050001ff89993d1d0000000049454e44ae426082";
      Small     : constant String := Join (Root, "small.png");
      Huge      : constant String := Join (Root, "huge.png");
      Screen    : constant String := Join (Root, "screen.png");
      Width     : constant := 3840;
      Height    : constant := 2160;
      Decoded   : Files.Images.Decoded_Image;

      function Bytes (Hex : String) return String is
         Result : String (1 .. Hex'Length / 2);
      begin
         for Index in Result'Range loop
            Result (Index) := Character'Val
              (Integer'Value ("16#" & Hex (Hex'First + 2 * (Index - 1) .. Hex'First + 2 * Index - 1) & "#"));
         end loop;
         return Result;
      end Bytes;

      function Big_Endian (Value : Interfaces.Unsigned_32) return String is
        [Character'Val (Natural (Interfaces.Shift_Right (Value, 24) and 16#FF#)),
         Character'Val (Natural (Interfaces.Shift_Right (Value, 16) and 16#FF#)),
         Character'Val (Natural (Interfaces.Shift_Right (Value, 8) and 16#FF#)),
         Character'Val (Natural (Value and 16#FF#))];

      --  A PNG chunk: length, type, data, and the CRC-32 of type and data.
      function Chunk (Kind, Data : String) return String is
         Crc : Interfaces.Unsigned_32 := 16#FFFF_FFFF#;
      begin
         for Item of String'(Kind & Data) loop
            Crc := Crc xor Interfaces.Unsigned_32 (Character'Pos (Item));
            for Bit in 1 .. 8 loop
               Crc :=
                 (if (Crc and 1) = 1 then Interfaces.Shift_Right (Crc, 1) xor 16#EDB8_8320#
                  else Interfaces.Shift_Right (Crc, 1));
            end loop;
         end loop;
         return Big_Endian (Interfaces.Unsigned_32 (Data'Length)) & Kind & Data & Big_Endian (Crc xor 16#FFFF_FFFF#);
      end Chunk;
   begin
      Reset_Root;
      Write_Binary_File (Small, Bytes (Small_Hex));
      Write_Binary_File (Huge, Bytes (Huge_Hex));
      Assert (Bytes (Small_Hex)'Length = Bytes (Huge_Hex)'Length, "the patched file differs only in its header");

      --  A solid grey 3840 x 2160 PNG, its scanlines zlib-compressed a row
      --  at a time, so no buffer holds the whole image.
      declare
         --  Every scanline: filter byte 0 (none), then one grey byte a pixel.
         Row        : constant Ada.Streams.Stream_Element_Array (1 .. Width + 1) := [1 => 0, others => 128];
         Output     : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
         Out_Last   : Ada.Streams.Stream_Element_Offset;
         In_Last    : Ada.Streams.Stream_Element_Offset;
         Filter     : Zlib.Compression_Filter_Type;
         Image_Data : Unbounded_String;

         procedure Take_Output is
         begin
            for Index in Output'First .. Out_Last loop
               Append (Image_Data, Character'Val (Output (Index)));
            end loop;
         end Take_Output;
      begin
         Zlib.Deflate_Init (Filter, Mode => Zlib.Fixed);
         for Line in 1 .. Height loop
            declare
               First : Ada.Streams.Stream_Element_Offset := Row'First;
            begin
               while First <= Row'Last loop
                  Zlib.Compress (Filter, Row (First .. Row'Last), In_Last, Output, Out_Last);
                  Take_Output;
                  First := In_Last + 1;
               end loop;
            end;
         end loop;
         for Attempt in 1 .. 10_000 loop
            Zlib.Compress_Flush (Filter, Output, Out_Last, Zlib.Finish);
            Take_Output;
            exit when Zlib.Compress_Stream_End (Filter);
         end loop;
         Assert (Zlib.Compress_Stream_End (Filter), "the screenshot's pixels compress");
         Zlib.Compress_Close (Filter);
         Write_Binary_File
           (Screen,
            Bytes ("89504e470d0a1a0a")
            --  Width, height, bit depth 8, greyscale, deflate, no filter, no interlace.
            & Chunk ("IHDR", Big_Endian (Width) & Big_Endian (Height) & Bytes ("0800000000"))
            & Chunk ("IDAT", To_String (Image_Data))
            & Chunk ("IEND", ""));
      end;

      Decoded := Files.Images.Decode_Image_To_Pixels (Small, 256);
      Assert (Decoded.Available and then Decoded.Width = 1 and then Decoded.Height = 1,
              "the 1 x 1 PNG decodes from its file");

      Decoded := Files.Images.Decode_Image_To_Pixels (Screen, 256);
      Assert (Decoded.Available, "a 3840 x 2160 PNG decodes: past the in-memory pixel bound, within the file bound");
      Assert (Decoded.Width <= 256 and then Decoded.Height <= 256 and then Decoded.Width > Decoded.Height,
              "and it is scaled to fit, keeping its shape");

      Decoded := Files.Images.Decode_Image_To_Pixels (Small, 256);
      Assert (not Decoded.Extent_Refused, "a small image passes the header check");
      Decoded := Files.Images.Decode_Image_To_Pixels (Screen, 256);
      Assert (not Decoded.Extent_Refused, "a 4K screenshot passes the header check");

      Decoded := Files.Images.Decode_Image_To_Pixels (Huge, 256);
      Assert (not Decoded.Available, "the same PNG declaring 40000 x 40000 pixels is refused");
      --  Its one pixel of data would fail a decode anyway: only the reason
      --  shows the header check, not the decoder, refused it.
      Assert (Decoded.Extent_Refused, "the refusal comes from the declared extent, before any decoder");
      Files_Suite.Support.Assert_Equal
        (Natural (Decoded.Pixels.Length), 0, "a refused image file carries no pixels");
   end Test_Oversized_Image_File_Refused;

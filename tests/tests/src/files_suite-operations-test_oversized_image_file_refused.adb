with Files.Images;
separate (Files_Suite.Operations)
   --  A valid 1 x 1 PNG decodes from a file; the same file with only its IHDR
   --  size patched to 40000 x 40000 (CRC recomputed, image data unchanged) is
   --  refused. The loader would read the patched file as far as the real one,
   --  so the refusal comes from the header check before decoding. Quick Look
   --  and the gdk-pixbuf thumbnail writer both decode through this path.
   procedure Test_Oversized_Image_File_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Generated with zlib: signature, IHDR, one IDAT (one red pixel), IEND.
      Small_Hex : constant String :=
        "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
        & "0000000d49444154789c63f8cfc0f01f00050001ff89993d1d0000000049454e44ae426082";
      Huge_Hex  : constant String :=
        "89504e470d0a1a0a0000000d4948445200009c4000009c400806000000510c0e05"
        & "0000000d49444154789c63f8cfc0f01f00050001ff89993d1d0000000049454e44ae426082";
      Small     : constant String := Join (Root, "small.png");
      Huge      : constant String := Join (Root, "huge.png");
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
   begin
      Reset_Root;
      Write_Binary_File (Small, Bytes (Small_Hex));
      Write_Binary_File (Huge, Bytes (Huge_Hex));
      Assert (Bytes (Small_Hex)'Length = Bytes (Huge_Hex)'Length, "the patched file differs only in its header");

      Decoded := Files.Images.Decode_Image_To_Pixels (Small, 256);
      Assert (Decoded.Available and then Decoded.Width = 1 and then Decoded.Height = 1,
              "the 1 x 1 PNG decodes from its file");

      Decoded := Files.Images.Decode_Image_To_Pixels (Huge, 256);
      Assert (not Decoded.Available, "the same PNG declaring 40000 x 40000 pixels is refused");
      Files_Suite.Support.Assert_Equal
        (Natural (Decoded.Pixels.Length), 0, "a refused image file carries no pixels");
   end Test_Oversized_Image_File_Refused;

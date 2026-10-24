separate (Files_Suite.Operations)
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Emoji_Path : constant String :=
        "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf";
      F : Textrender.Fonts.Font;
      use type Textrender.Fonts.Colour_Image_Format;
   begin
      if not Ada.Directories.Exists (Emoji_Path) then
         Files_Suite.Support.Skip ("Test_Decode_Emoji_Png_From_Font", "not Ada.Directories.Exists (Emoji_Path)");
         return;
      end if;

      Assert (Textrender.Fonts.Load (F, Emoji_Path) = Textrender.Fonts.Loaded,
              "the emoji font loads");

      declare
         Index : Natural := 0;
         Grinning : constant Textrender.Fonts.Codepoint := 16#1F600#;
      begin
         Assert (Textrender.Fonts.Glyph_Index_Of (F, Grinning, Index),
                 "the font maps the grinning face");

         declare
            Bitmap : constant Textrender.Fonts.Colour_Bitmap :=
              Textrender.Fonts.Colour_Bitmap_For (F, Index, 16);
         begin
            Assert (Bitmap.Format = Textrender.Fonts.Png_Colour_Image,
                    "and has a PNG for it");

            declare
               Data : Ada.Streams.Stream_Element_Array
                 (1 .. Ada.Streams.Stream_Element_Offset (Bitmap.Data_Length));
               Width, Height : Natural := 0;
            begin
               for Offset in 0 .. Bitmap.Data_Length - 1 loop
                  Data (Ada.Streams.Stream_Element_Offset (Offset + 1)) :=
                    Ada.Streams.Stream_Element
                      (Textrender.Fonts.Byte_At (F, Bitmap.Data_Offset + Offset));
               end loop;

               --  The extent must be readable without decoding, and must agree
               --  with what the font's own metrics claimed.
               Assert (Files.File_System.Image_Bytes_Extent (Data, Width, Height),
                       "the PNG header is readable");
               Assert (Width = Bitmap.Width and then Height = Bitmap.Height,
                       "and agrees with the font's metrics:"
                       & Natural'Image (Width) & " x" & Natural'Image (Height)
                       & " against" & Natural'Image (Bitmap.Width)
                       & " x" & Natural'Image (Bitmap.Height));

               declare
                  Decoded : constant Files.File_System.Decoded_Image :=
                    Files.File_System.Decode_Image_Bytes (Data);
                  Opaque_Pixels : Natural := 0;
                  Coloured      : Natural := 0;
               begin
                  Assert (Decoded.Available, "the picture decodes");
                  Assert (Decoded.Width = Width and then Decoded.Height = Height,
                          "at the size its header declared");
                  Assert
                    (Natural (Decoded.Pixels.Length) = Width * Height * 4,
                     "with four bytes per pixel");

                  --  A grinning face is mostly opaque and mostly not grey. Both
                  --  matter: an all-transparent result would satisfy a length
                  --  check, and so would a greyscale one.
                  for Pixel in 0 .. Width * Height - 1 loop
                     declare
                        --  Byte_Vectors is indexed from 1, not 0.
                        R : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 1));
                        G : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 2));
                        B : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 3));
                        A : constant Natural := Natural (Decoded.Pixels.Element (Pixel * 4 + 4));
                     begin
                        if A > 200 then
                           Opaque_Pixels := Opaque_Pixels + 1;

                           if abs (R - G) > 40 or else abs (G - B) > 40 then
                              Coloured := Coloured + 1;
                           end if;
                        end if;
                     end;
                  end loop;

                  Assert (Opaque_Pixels > (Width * Height) / 10,
                          "and is substantially opaque, got"
                          & Natural'Image (Opaque_Pixels) & " of"
                          & Natural'Image (Width * Height));
                  Assert (Coloured > 0,
                          "and actually carries colour rather than grey");
               end;
            end;
         end;
      end;

      Textrender.Fonts.Reset (F);
   end Test_Decode_Emoji_Png_From_Font;

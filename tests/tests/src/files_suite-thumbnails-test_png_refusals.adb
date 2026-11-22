with Files.Images.Png;
separate (Files_Suite.Thumbnails)
   --  The in-Ada PNG reader decodes only 8-bit, non-interlaced RGB or RGBA,
   --  and refuses everything else so the full decoder gets the file: each
   --  case changes one thing about a 2 x 2 image it decodes.
   procedure Test_Png_Refusals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Signature : constant String :=
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#);

      --  Two rows of two pixels, each row led by filter type 0.
      function Rows (Channels : Positive) return String is
         Row : constant String := Byte (0) & [1 .. 2 * Channels => Byte (16#40#)];
      begin
         return Row & Row;
      end Rows;

      function Header
        (Depth      : Natural := 8;
         Color_Type : Natural := 2;
         Interlace  : Natural := 0) return String is
        (Chunk ("IHDR", Be32 (2) & Be32 (2) & Byte (Depth) & Byte (Color_Type) & Byte (0) & Byte (0)
                        & Byte (Interlace)));

      --  A PNG from its IHDR, the chunks before IDAT, the raster and the
      --  chunks after it.
      function Png
        (Ihdr    : String := Header;
         Before  : String := "";
         Raster  : String := Rows (3);
         After   : String := "") return String is
        (Signature & Ihdr & Before & Chunk ("IDAT", Stored_Zlib_Stream (Raster)) & After & Chunk ("IEND", ""));

      type Case_Entry is record
         Name    : Unbounded_String;
         Data    : Unbounded_String;
         Decodes : Boolean;
      end record;

      function Entry_Of (Name, Data : String; Decodes : Boolean := False) return Case_Entry is
        ((To_Unbounded_String (Name), To_Unbounded_String (Data), Decodes));

      Plain     : constant String := Png;
      Bad_Crc   : String := Plain;
      RGB_Rows  : constant String := Rows (3);
      One_Row   : constant String := RGB_Rows (RGB_Rows'First .. RGB_Rows'First + 6);
      Cases     : constant array (Positive range <>) of Case_Entry :=
        [Entry_Of ("8-bit RGB", Plain, Decodes => True),
         Entry_Of ("8-bit RGBA", Png (Header (Color_Type => 6), Raster => Rows (4)), Decodes => True),
         Entry_Of ("an ancillary chunk", Png (Before => Chunk ("teXt", "a" & Byte (0) & "b")), Decodes => True),
         Entry_Of ("Adam7 interlacing", Png (Header (Interlace => 1))),
         Entry_Of ("a palette", Png (Header (Color_Type => 3), Before => Chunk ("PLTE", [1 .. 3 => Byte (0)]),
                                     Raster => Rows (1))),
         Entry_Of ("grey", Png (Header (Color_Type => 0), Raster => Rows (1))),
         Entry_Of ("16-bit samples", Png (Header (Depth => 16), Raster => Rows (6))),
         Entry_Of ("an unknown critical chunk", Png (Before => Chunk ("QUUX", "x"))),
         Entry_Of ("tRNS after the image data", Png (After => Chunk ("tRNS", [1 .. 6 => Byte (0)]))),
         Entry_Of ("a raster one row short", Png (Raster => One_Row)),
         Entry_Of ("a raster a byte long", Png (Raster => Rows (3) & Byte (0))),
         Entry_Of ("no IEND", Plain (Plain'First .. Plain'Last - 12)),
         Entry_Of ("bytes after IEND", Plain & Byte (0)),
         Entry_Of ("not a PNG signature", "GIF89a" & Plain (Plain'First + 6 .. Plain'Last))];
   begin
      --  The IHDR chunk's CRC is bytes 30 .. 33 of the file.
      Bad_Crc (Bad_Crc'First + 32) := Character'Val ((Character'Pos (Bad_Crc (Bad_Crc'First + 32)) + 1) mod 256);
      declare
         Ignored : Files.Images.Png.Raster;
      begin
         Assert (not Files.Images.Png.Decode (Bad_Crc, Ignored), "a chunk with a bad CRC is refused");
      end;

      for Item of Cases loop
         declare
            Image   : Files.Images.Png.Raster;
            Decoded : constant Boolean := Files.Images.Png.Decode (To_String (Item.Data), Image);
         begin
            Assert (Decoded = Item.Decodes,
                    To_String (Item.Name) & (if Item.Decodes then " is decoded" else " is refused"));
            if Decoded then
               Assert (Image.Width = 2 and then Image.Height = 2
                       and then Natural (Image.Pixels.Length) = 2 * 2 * 4,
                       To_String (Item.Name) & " decodes to 2 x 2 RGBA");
            end if;
         end;
      end loop;
   end Test_Png_Refusals;

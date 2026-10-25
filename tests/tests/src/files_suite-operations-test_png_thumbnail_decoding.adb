separate (Files_Suite.Operations)
   procedure Test_Png_Thumbnail_Decoding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Thumbnail : Files.File_System.Thumbnail_Result;
      Decoded_Png_Source : constant String := Join (Root, "decoded-picture.png");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
   begin
      Reset_Root;
      --  Decode a COMPLETE PNG (IHDR + a real IDAT + IEND) through the pure-Ada
      --  fast path. The other cases use an IDAT-less header, so this is the only
      --  test that actually drives inflate + unfilter + pixel decode -- and thus
      --  the heap-backed raster buffer. A solid colour must survive the decode
      --  and downscale, so its distinctive red value appears in the written pixels.
      declare
         Png_W   : constant := 60;
         Png_H   : constant := 60;
         --  A well-formed PNG: signature, then an IHDR chunk (with a CRC slot,
         --  unlike Minimal_Png_Header) declaring 8-bit truecolour, non-interlaced.
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#);
         Ihdr    : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (Png_W)
           & Byte (0) & Byte (0) & Byte (0) & Byte (Png_H)
           & Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
         Raster  : Unbounded_String;
         Png_Src : constant String := Join (Root, "decodable-rgb.png");
         Decoded : Files.File_System.Thumbnail_Result;
      begin
         for Row in 1 .. Png_H loop
            Append (Raster, Byte (0));  -- PNG row filter type 0 (None)
            for Col in 1 .. Png_W loop
               Append (Raster, Byte (173) & Byte (89) & Byte (211));
            end loop;
         end loop;
         Write_Binary_File
           (Png_Src,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("IDAT", Stored_Zlib_Stream (To_String (Raster)))
            & Chunk ("IEND", ""));
         Decoded := Files.File_System.Generate_Thumbnail (Png_Src, Thumbnail_Cache, Size => 8);
         Assert
           (Decoded.Status = Files.File_System.Thumbnail_Generated,
            "a complete PNG decodes through the pure-Ada fast path");
         Assert
           (File_Has_Bytes (To_String (Decoded.Thumbnail_Path), Byte (173) & Byte (89) & Byte (211)),
            "the decoded solid colour survives inflate/unfilter/downscale");
      end;

      declare
         Source : constant String := Join (Root, "png-inflate-overrun.png");
         Pixel  : constant String := Byte (173) & Byte (89) & Byte (211);
         Raster : constant String :=
           Byte (0) & Pixel & Pixel & Byte (0) & Pixel & Pixel;
         Generated : Files.File_System.Thumbnail_Result;
      begin
         --  The IHDR declares exactly fourteen inflated scanline bytes.  The
         --  extra byte used to be silently retained by the one-shot inflater,
         --  which first allocated the entire attacker-controlled expansion.
         Write_Binary_File
           (Source, Minimal_Png_RGB (2, 2, Raster & Byte (99)));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated,
            "an invalid PNG expansion falls back to a generated thumbnail");
         Assert
           (not File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Pixel & Pixel & Pixel & Pixel),
            "PNG inflate rejects output beyond the declared raster budget");
      end;

      Write_Binary_File
        (Decoded_Png_Source,
         Minimal_Png_RGB
           (2,
            2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));
      Thumbnail := Files.File_System.Generate_Thumbnail (Decoded_Png_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PNG thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0)),
         "decoded PNG thumbnail preserves source pixel colors: red pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0)),
         "decoded PNG thumbnail preserves source pixel colors: green pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PNG thumbnail preserves source pixel colors: blue pixel");

      declare
         Source : constant String := Join (Root, "transparent-picture.png");
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#)
           & Byte (16#1A#) & Byte (16#0A#);
         Ihdr : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (2)
           & Byte (0) & Byte (0) & Byte (0) & Byte (1)
           & Byte (8) & Byte (6) & Byte (0) & Byte (0) & Byte (0);
         Raster : constant String :=
           Byte (0)
           & Byte (255) & Byte (0) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255) & Byte (255);
         Generated : Files.File_System.Thumbnail_Result;
      begin
         Write_Binary_File
           (Source,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("IDAT", Stored_Zlib_Stream (Raster))
            & Chunk ("IEND", ""));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated,
            "an RGBA PNG produces a thumbnail");
         Assert
           (File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Byte (255) & Byte (255) & Byte (255)
               & Byte (0) & Byte (0) & Byte (255)
               & Byte (255) & Byte (255) & Byte (255)
               & Byte (0) & Byte (0) & Byte (255))
            and then not File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Byte (255) & Byte (0) & Byte (0)
               & Byte (0) & Byte (0) & Byte (255)
               & Byte (255) & Byte (0) & Byte (0)
               & Byte (0) & Byte (0) & Byte (255)),
            "transparent PNG pixels are composited instead of exposing hidden RGB");
      end;

      declare
         Source : constant String := Join (Root, "transparent-key-picture.png");
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#)
           & Byte (16#1A#) & Byte (16#0A#);
         Ihdr : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (2)
           & Byte (0) & Byte (0) & Byte (0) & Byte (1)
           & Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
         Transparent_Red : constant String :=
           Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (0);
         Raster : constant String :=
           Byte (0)
           & Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255);
         Expected : constant String :=
           Byte (255) & Byte (255) & Byte (255)
           & Byte (0) & Byte (0) & Byte (255)
           & Byte (255) & Byte (255) & Byte (255)
           & Byte (0) & Byte (0) & Byte (255);
         Hidden : constant String :=
           Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255)
           & Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255);
         Generated : Files.File_System.Thumbnail_Result;
      begin
         Write_Binary_File
           (Source,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("tRNS", Transparent_Red)
            & Chunk ("IDAT", Stored_Zlib_Stream (Raster))
            & Chunk ("IEND", ""));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated,
            "true-colour PNG tRNS transparency is composited against white: generated");
         Assert
           (File_Has_Bytes (To_String (Generated.Thumbnail_Path), Expected),
            "true-colour PNG tRNS transparency is composited against white: composited colour");
         Assert
           (not File_Has_Bytes (To_String (Generated.Thumbnail_Path), Hidden),
            "true-colour PNG tRNS transparency is composited against white: hidden colour absent");
      end;
   end Test_Png_Thumbnail_Decoding;

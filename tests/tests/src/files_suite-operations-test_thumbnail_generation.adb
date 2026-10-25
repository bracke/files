separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Thumbnail : Files.File_System.Thumbnail_Result;
      Thumbnail_Source : constant String := Join (Root, "picture.png");
      Ppm_Thumbnail_Source : constant String := Join (Root, "picture.ppm");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
   begin
      Reset_Root;
      Write_Binary_File (Thumbnail_Source, Minimal_Png_Header (48, 32));
      Thumbnail := Files.File_System.Generate_Thumbnail (Thumbnail_Source, Thumbnail_Cache, Size => 8);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "thumbnail generation succeeds");
      Assert (Thumbnail.Width = 8 and then Thumbnail.Height = 8, "thumbnail reports requested dimensions");
      Assert
        (Ada.Directories.Exists (To_String (Thumbnail.Thumbnail_Path)),
         "thumbnail generation writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "P6"),
         "thumbnail artifact is a binary PPM image");
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         declare
            Available : Boolean := False;
         begin
            Assert
              (Files.File_System.Permission_Bits_Of (Thumbnail_Cache, Available)
                 mod 8#1000# = 8#700# and then Available,
               "thumbnail cache is owner-only");
            Assert
              (Files.File_System.Permission_Bits_Of
                 (To_String (Thumbnail.Thumbnail_Path), Available)
                 mod 8#1000# = 8#600# and then Available,
               "thumbnail artifact is owner-only");
         end;
      end if;
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "8 8"),
         "thumbnail artifact records requested image dimensions");
      declare
         Oversized : constant Files.File_System.Thumbnail_Result :=
           Files.File_System.Generate_Thumbnail
             (Thumbnail_Source, Thumbnail_Cache, Size => 2_049);
      begin
         Assert
           (Oversized.Status = Files.File_System.Thumbnail_Failed
            and then Length (Oversized.Thumbnail_Path) = 0,
            "oversized public thumbnail requests fail before allocating an image");
      end;
      declare
         Cache_Path : constant String := To_String (Thumbnail.Thumbnail_Path);
         Victim : constant String := Join (Root, "thumbnail-cache-victim");
      begin
         Ada.Directories.Delete_File (Cache_Path);
         Write_File (Victim, "must stay intact");
         if Files_Suite.Support.Create_Symlink (Victim, Cache_Path) then
            Thumbnail := Files.File_System.Generate_Thumbnail
              (Thumbnail_Source, Thumbnail_Cache, Size => 8);
            Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated,
                    "thumbnail generation replaces a cache symlink safely");
            Assert (not Hostkit.Fs.Is_Link (Cache_Path),
                    "thumbnail publication replaces the cache entry, not its target");
            Assert (File_Has_Bytes (Victim, "must stay intact"),
                    "thumbnail generation never truncates a cache symlink target");
            Assert (not Ada.Directories.Exists (Cache_Path & ".tmp")
                      and then not Hostkit.Fs.Is_Link (Cache_Path & ".tmp"),
                    "thumbnail publication leaves no temporary cache file");
         else
            Files_Suite.Support.Link_Not_Made ("Test_Thumbnail_Generation", Files_Suite.Support.Symbolic_Link);
         end if;
      end;

      declare
         Header : constant String := Minimal_Png_Header (4_097, 1_024);
         Data : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Header'Length));
         Width, Height : Natural;
      begin
         for Index in Header'Range loop
            Data (Ada.Streams.Stream_Element_Offset (Index - Header'First + 1)) :=
              Ada.Streams.Stream_Element (Character'Pos (Header (Index)));
         end loop;
         Assert
           (not Files.File_System.Image_Bytes_Extent (Data, Width, Height),
            "encoded images above the colour-glyph pixel budget are rejected: rejected");
         Files_Suite.Support.Assert_Equal
           (Width,
            0,
            "encoded images above the colour-glyph pixel budget are rejected: width cleared");
         Files_Suite.Support.Assert_Equal
           (Height,
            0,
            "encoded images above the colour-glyph pixel budget are rejected: height cleared");
         declare
            Decoded : constant Files.File_System.Decoded_Image :=
              Files.File_System.Decode_Image_Bytes (Data);
         begin
            Assert
              (not Decoded.Available and then Decoded.Pixels.Is_Empty,
               "the in-memory decoder rejects oversized dimensions before loading pixels");
         end;
      end;
      --  A real JPEG (8 x 8, solid red, baseline, 4:4:4) is decoded through the
      --  native image loader: none of the in-Ada decoders reads JPEG, so red
      --  pixels can only have come from it.
      declare
         Jpeg_Hex : constant String :=
           "FFD8FFE000104A46494600010100000100010000FFDB0043000302020302020303030304030304050805050404050A07" &
           "0706080C0A0C0C0B0A0B0B0D0E12100D0E110E0B0B1016101113141515150C0F171816141812141514FFDB0043010304" &
           "0405040509050509140D0B0D141414141414141414141414141414141414141414141414141414141414141414141414" &
           "1414141414141414141414141414FFC00011080008000803011100021101031101FFC400140001000000000000000000" &
           "00000000000008FFC40014100100000000000000000000000000000000FFC40015010101000000000000000000000000" &
           "00000709FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F003A03154DFFD9";
         Jpeg_Source : constant String := Join (Root, "red.jpg");
         Jpeg_Bytes  : String (1 .. Jpeg_Hex'Length / 2);
         Decoded     : Files.File_System.Decoded_Image;
      begin
         for Index in Jpeg_Bytes'Range loop
            Jpeg_Bytes (Index) :=
              Byte (Natural'Value ("16#" & Jpeg_Hex (Jpeg_Hex'First + 2 * (Index - 1) .. Jpeg_Hex'First + 2 * Index - 1)
                                   & "#"));
         end loop;
         Write_Binary_File (Jpeg_Source, Jpeg_Bytes);
         Decoded := Files.File_System.Decode_Image_To_Pixels (Jpeg_Source, 8);
         Assert (Decoded.Available, "a real JPEG decodes through the native image loader");
         Assert
           (Decoded.Width in 1 .. 8 and then Decoded.Height in 1 .. 8,
            "the decoded JPEG fits the requested box (" & Decoded.Width'Image & " x" & Decoded.Height'Image & ")");
         Assert
           (Natural (Decoded.Pixels.Length) >= 4,
            "the decoded JPEG carries RGBA pixels");
         declare
            Red   : constant Natural := Natural (Decoded.Pixels.Element (Decoded.Pixels.First_Index));
            Green : constant Natural := Natural (Decoded.Pixels.Element (Decoded.Pixels.First_Index + 1));
            Blue  : constant Natural := Natural (Decoded.Pixels.Element (Decoded.Pixels.First_Index + 2));
         begin
            Assert
              (Red > 200 and then Green < 60 and then Blue < 60,
               "the decoded JPEG keeps its red (got" & Red'Image & "," & Green'Image & "," & Blue'Image & ")");
         end;
      end;

      Write_File
        (Ppm_Thumbnail_Source,
         "P3" & ASCII.LF
         & "# decoded thumbnail fixture" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 0 255 0" & ASCII.LF
         & "0 0 255 255 255 255" & ASCII.LF);
      Thumbnail := Files.File_System.Generate_Thumbnail (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PPM thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0)),
         "decoded PPM thumbnail preserves source pixel colors: red pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0)),
         "decoded PPM thumbnail preserves source pixel colors: green pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PPM thumbnail preserves source pixel colors: blue pixel");

      Thumbnail := Files.File_System.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Files_Suite.Support.Assert_Equal
        (To_String (Thumbnail.Error_Key),
         "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");
   end Test_Thumbnail_Generation;

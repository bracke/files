with Files.File_System.Thumbnails;
with Files.Images;
separate (Files_Suite.Thumbnails)
   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Thumbnail : Files.File_System.Thumbnails.Thumbnail_Result;
      Thumbnail_Source : constant String := Join (Root, "picture.png");
      Ppm_Thumbnail_Source : constant String := Join (Root, "picture.ppm");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
   begin
      Reset_Root;
      Write_Binary_File (Thumbnail_Source, Minimal_Png_Header (48, 32));
      Thumbnail := Files.File_System.Thumbnails.Generate_Thumbnail (Thumbnail_Source, Thumbnail_Cache, Size => 8);
      --  A PNG with only its header: no decoder reads it, and it still gets
      --  the stand-in thumbnail.
      Assert (Thumbnail.Status = Files.File_System.Thumbnails.Thumbnail_Generated,
              "an image no decoder reads still gets a stand-in thumbnail");
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
         Oversized : constant Files.File_System.Thumbnails.Thumbnail_Result :=
           Files.File_System.Thumbnails.Generate_Thumbnail
             (Thumbnail_Source, Thumbnail_Cache, Size => 2_049);
      begin
         Assert
           (Oversized.Status = Files.File_System.Thumbnails.Thumbnail_Failed
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
            Thumbnail := Files.File_System.Thumbnails.Generate_Thumbnail
              (Thumbnail_Source, Thumbnail_Cache, Size => 8);
            Assert (Thumbnail.Status = Files.File_System.Thumbnails.Thumbnail_Generated,
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
           (not Files.Images.Image_Bytes_Extent (Data, Width, Height),
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
            Decoded : constant Files.Images.Decoded_Image :=
              Files.Images.Decode_Image_Bytes (Data);
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
         Jpeg_Source : constant String := Join (Root, "red.jpg");
         Jpeg_Bytes  : constant String := Files_Suite.Support.Red_Jpeg_8x8;
         Decoded     : Files.Images.Decoded_Image;
      begin
         Write_Binary_File (Jpeg_Source, Jpeg_Bytes);
         Decoded := Files.Images.Decode_Image_To_Pixels (Jpeg_Source, 8);
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
         --  And its thumbnail is made from those pixels, not the stand-in a
         --  failed decode falls back to: the cached PPM's first pixel is red.
         declare
            Made   : constant Files.File_System.Thumbnails.Thumbnail_Result :=
              Files.File_System.Thumbnails.Generate_Thumbnail (Jpeg_Source, Thumbnail_Cache, Size => 8);
            Raw    : constant String := Project_Tools.Files.Read_Raw_File (To_String (Made.Thumbnail_Path));
            Lines  : Natural := 0;
            First  : Natural := 0;
         begin
            Assert (Made.Status = Files.File_System.Thumbnails.Thumbnail_Generated, "the JPEG gets a thumbnail");
            --  A PPM header is three lines: magic, size, depth.
            for Index in Raw'Range loop
               if Raw (Index) = ASCII.LF then
                  Lines := Lines + 1;
                  if Lines = 3 then
                     First := Index + 1;
                     exit;
                  end if;
               end if;
            end loop;
            Assert (First > 0 and then First + 2 <= Raw'Last, "the thumbnail holds pixels");
            Assert
              (Character'Pos (Raw (First)) > 200
               and then Character'Pos (Raw (First + 1)) < 60
               and then Character'Pos (Raw (First + 2)) < 60,
               "the JPEG's thumbnail is red, from its pixels (got"
               & Natural'Image (Character'Pos (Raw (First))) & ","
               & Natural'Image (Character'Pos (Raw (First + 1))) & ","
               & Natural'Image (Character'Pos (Raw (First + 2))) & ")");
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
      Thumbnail := Files.File_System.Thumbnails.Generate_Thumbnail (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnails.Thumbnail_Generated, "decoded PPM thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0)),
         "decoded PPM thumbnail preserves source pixel colors: red pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0)),
         "decoded PPM thumbnail preserves source pixel colors: green pixel");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PPM thumbnail preserves source pixel colors: blue pixel");

      --  An edited picture is a new thumbnail: the cache name follows the
      --  source's revision, so the old one is not served for it.
      declare
         Before : constant String :=
           Files.File_System.Thumbnails.Thumbnail_Path_For (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
         Moved  : Boolean;
      begin
         Write_File
           (Ppm_Thumbnail_Source,
            "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF & "0 0 255" & ASCII.LF);
         Moved := Hostkit.Metadata.Set_File_Times (Ppm_Thumbnail_Source, 1_700_000_000, 1_700_000_000);
         Assert (Moved, "the edit gets a time of its own");
         declare
            After : constant String :=
              Files.File_System.Thumbnails.Thumbnail_Path_For (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
         begin
            Assert (After /= Before, "an edited picture has a thumbnail of its own");
            Thumbnail := Files.File_System.Thumbnails.Generate_Thumbnail
              (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
            Assert (To_String (Thumbnail.Thumbnail_Path) = After
                    and then File_Is
                      (After,
                       "P6" & ASCII.LF & "2 2" & ASCII.LF & "255" & ASCII.LF
                       & Byte (0) & Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (255)
                       & Byte (0) & Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (255)),
                    "made from what the picture is now: blue");
         end;
      end;

      Thumbnail :=
        Files.File_System.Thumbnails.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnails.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Files_Suite.Support.Assert_Equal
        (To_String (Thumbnail.Error_Key),
         "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");
   end Test_Thumbnail_Generation;

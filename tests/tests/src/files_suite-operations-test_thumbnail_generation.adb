with Files_Suite.Repository;
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
           (not Files.File_System.Image_Bytes_Extent (Data, Width, Height)
            and then Width = 0 and then Height = 0,
            "encoded images above the colour-glyph pixel budget are rejected");
         declare
            Decoded : constant Files.File_System.Decoded_Image :=
              Files.File_System.Decode_Image_Bytes (Data);
         begin
            Assert
              (not Decoded.Available and then Decoded.Pixels.Is_Empty,
               "the in-memory decoder rejects oversized dimensions before loading pixels");
         end;
      end;
      Assert
        (Files_Suite.Repository.Source_Contains ("gdk_pixbuf_loader_new"),
         "JPEG thumbnail decoding is routed through the native image loader binding");

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
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PPM thumbnail preserves source pixel colors");

      Thumbnail := Files.File_System.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Files_Suite.Support.Assert_Equal
        (To_String (Thumbnail.Error_Key),
         "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");
   end Test_Thumbnail_Generation;

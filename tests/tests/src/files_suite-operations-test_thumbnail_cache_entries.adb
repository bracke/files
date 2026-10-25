separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Cache_Entries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Cache_Home : constant String := Join (Root, "cache-home");
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Reset_Root;
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);

      --  The cache key now includes the source revision, but an artifact
      --  written in the old ASCII P3 image format under the current key
      --  must still load. Put one there by hand and read it back.
      declare
         Legacy_Source : constant String := Join (Root, "legacy-cached.png");
         Legacy_Load   : Files.File_System.Directory_Load_Result;
         Found_Legacy  : Boolean := False;
         Ascii_Pixels  : Unbounded_String;
      begin
         Write_Binary_File (Legacy_Source, Minimal_Png_Header (8, 8));
         declare
            Legacy_Cache : constant String :=
              Files.File_System.Thumbnail_Path_For
                (Legacy_Source,
                 Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                 64);
         begin
            --  2x2 of red, green, blue, white in the old ASCII form.
            Append (Ascii_Pixels, "P3" & ASCII.LF & "2 2" & ASCII.LF & "255" & ASCII.LF);
            Append (Ascii_Pixels, "255 0 0 0 255 0" & ASCII.LF & "0 0 255 255 255 255" & ASCII.LF);
            Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Legacy_Cache));
            Write_File (Legacy_Cache, To_String (Ascii_Pixels));
         end;

         Legacy_Load := Files.File_System.Load_Directory (Root, Settings);
         for Item of Legacy_Load.Items loop
            if To_String (Item.Name) = "legacy-cached.png" then
               Found_Legacy := True;
               Assert
                 (Item.Thumbnail_Available,
                  "a thumbnail cached in the old ASCII format still loads");
               Assert
                 (Item.Thumbnail_Width = 2 and then Item.Thumbnail_Height = 2,
                  "and reports the dimensions its own header declares");
               Files_Suite.Support.Assert_Equal
                 (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels),
                  2 * 2 * 4,
                  "and yields renderable pixels");
            end if;
         end loop;

         Assert (Found_Legacy, "the legacy-cached item is listed");
      end;

      declare
         Commented_Source : constant String := Join (Root, "commented-cached.txt");
         Trailing_Source  : constant String := Join (Root, "trailing-cached.txt");
         Commented_Cache  : Unbounded_String;
         Trailing_Cache   : Unbounded_String;
         Cache_Load       : Files.File_System.Directory_Load_Result;
         Found_Commented  : Boolean := False;
         Found_Trailing   : Boolean := False;
      begin
         Write_File (Commented_Source, "not an image");
         Write_File (Trailing_Source, "not an image");
         Commented_Cache := To_Unbounded_String
           (Files.File_System.Thumbnail_Path_For
              (Commented_Source,
               Files.File_System.Default_Thumbnail_Cache_Directory (Root),
               64));
         Trailing_Cache := To_Unbounded_String
           (Files.File_System.Thumbnail_Path_For
              (Trailing_Source,
               Files.File_System.Default_Thumbnail_Cache_Directory (Root),
               64));
         Write_Binary_File
           (To_String (Commented_Cache),
            "P6" & ASCII.LF & "# cached preview" & ASCII.LF
            & "1 # width" & ASCII.LF & "1" & ASCII.LF & "255" & ASCII.LF
            & Byte (10) & Byte (20) & Byte (30));
         Write_Binary_File
           (To_String (Trailing_Cache),
            "P6" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF
            & Byte (10) & Byte (20) & Byte (30) & Byte (40));

         Cache_Load := Files.File_System.Load_Directory (Root, Settings);
         for Item of Cache_Load.Items loop
            if To_String (Item.Name) = "commented-cached.txt" then
               Found_Commented := True;
               Assert
                 (Item.Thumbnail_Available,
                  "a binary cached PPM accepts comments between header fields: available");
               Files_Suite.Support.Assert_Equal
                 (Item.Thumbnail_Width,
                  1,
                  "a binary cached PPM accepts comments between header fields: width");
               Files_Suite.Support.Assert_Equal
                 (Item.Thumbnail_Height,
                  1,
                  "a binary cached PPM accepts comments between header fields: height");
            elsif To_String (Item.Name) = "trailing-cached.txt" then
               Found_Trailing := True;
               Assert
                 (not Item.Thumbnail_Available
                  and then Files.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels),
                  "a binary cached PPM rejects bytes beyond its declared raster");
            end if;
         end loop;
         Assert
           (Found_Commented and then Found_Trailing,
            "the binary cache parser fixtures are listed");
      end;

      --  Cache files are persistent input, not trusted decoded pixels.  In
      --  particular, PPM samples above maxval used to be silently clamped;
      --  reject that corrupt entry for a non-image item so auto-generation
      --  cannot hide the loader result from this regression check.
      declare
         Corrupt_Source : constant String := Join (Root, "corrupt-cached.txt");
         Corrupt_Cache  : Unbounded_String;
         Corrupt_Load   : Files.File_System.Directory_Load_Result;
         Found_Corrupt  : Boolean := False;
      begin
         Write_File (Corrupt_Source, "not an image");
         Corrupt_Cache := To_Unbounded_String
           (Files.File_System.Thumbnail_Path_For
              (Corrupt_Source,
               Files.File_System.Default_Thumbnail_Cache_Directory (Root),
               64));
         Write_File
           (To_String (Corrupt_Cache),
            "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF
            & "256 0 0" & ASCII.LF);

         Corrupt_Load := Files.File_System.Load_Directory (Root, Settings);
         for Item of Corrupt_Load.Items loop
            if To_String (Item.Name) = "corrupt-cached.txt" then
               Found_Corrupt := True;
               Assert
                 (not Item.Thumbnail_Available
                  and then Files.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels),
                  "a cached PPM sample above maxval is rejected");
            end if;
         end loop;
         Assert (Found_Corrupt, "the corrupt-cache fixture is listed");
      end;

      declare
         Revision_Source : constant String := Join (Root, "revision-cached.ppm");
         First_Path, Second_Path : Unbounded_String;
         Unix_Now : constant Long_Long_Integer :=
           Long_Long_Integer
             (Ada.Calendar."-" (Ada.Calendar.Clock, Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0)));
      begin
         --  The edit keeps the size, so only the modification time tells the
         --  versions apart. Date them explicitly rather than sleeping between
         --  the writes: a filesystem that keeps whole (or, on FAT, even) seconds
         --  would give two writes a moment apart the same time, and Windows
         --  stamps from a clock that advances in steps of about 16 ms.
         Write_File
           (Revision_Source,
            "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF & "255 0 0" & ASCII.LF);
         Assert (Hostkit.Metadata.Set_File_Times (Revision_Source, Unix_Now - 200, Unix_Now - 200),
                 "date the original image");
         First_Path := To_Unbounded_String
           (Files.File_System.Thumbnail_Path_For
              (Revision_Source,
               Files.File_System.Default_Thumbnail_Cache_Directory (Root), 64));
         Write_File
           (Revision_Source,
            "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF & "0 0 255" & ASCII.LF);
         Assert (Hostkit.Metadata.Set_File_Times (Revision_Source, Unix_Now - 100, Unix_Now - 100),
                 "date the edit later than the original");
         Second_Path := To_Unbounded_String
           (Files.File_System.Thumbnail_Path_For
              (Revision_Source,
               Files.File_System.Default_Thumbnail_Cache_Directory (Root), 64));
         Assert
           (First_Path /= Second_Path,
            "editing an image changes its thumbnail cache key");
      end;
   end Test_Thumbnail_Cache_Entries;

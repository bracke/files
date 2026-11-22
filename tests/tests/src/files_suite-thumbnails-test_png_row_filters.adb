with Files.Images.Png;
separate (Files_Suite.Thumbnails)
   --  Each of PNG's row filters (Sub, Up, Average, Paeth), on a small image
   --  whose bytes all differ, in RGB and RGBA: the rows are filtered here as
   --  the PNG specification defines it, and the decoder must give back the
   --  exact pixels.
   procedure Test_Png_Row_Filters (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Width  : constant := 3;
      Height : constant := 3;

      Signature : constant String :=
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#);

      type Filter_Row_Types is array (1 .. Height) of Natural;

      --  The unfiltered sample at Column of Row, distinct across the image.
      function Sample (Row, Column, Channels : Natural) return Natural is
        ((Row * 97 + Column * 31 + Channels * 7 + 13) mod 256);

      function Row_Bytes (Row, Channels : Natural) return String is
         Result : String (1 .. Width * Channels);
      begin
         for Column in Result'Range loop
            Result (Column) := Byte (Sample (Row, Column, Channels));
         end loop;
         return Result;
      end Row_Bytes;

      function Paeth (Left, Up, Upper : Natural) return Natural is
         P  : constant Integer := Left + Up - Upper;
         PA : constant Natural := abs (P - Left);
         PB : constant Natural := abs (P - Up);
         PC : constant Natural := abs (P - Upper);
      begin
         return (if PA <= PB and then PA <= PC then Left elsif PB <= PC then Up else Upper);
      end Paeth;

      --  Row filtered with Filter, given the unfiltered row above (or none).
      function Filtered (Current, Above : String; Filter, Channels : Natural) return String is
         Result : String (1 .. Current'Length + 1);
      begin
         Result (1) := Byte (Filter);
         for I in Current'Range loop
            declare
               Value : constant Natural := Character'Pos (Current (I));
               Left  : constant Natural := (if I > Channels then Character'Pos (Current (I - Channels)) else 0);
               Up    : constant Natural := (if Above = "" then 0 else Character'Pos (Above (I)));
               Upper : constant Natural :=
                 (if Above = "" or else I <= Channels then 0 else Character'Pos (Above (I - Channels)));
               Predicted : constant Natural :=
                 (case Filter is
                     when 1 => Left,
                     when 2 => Up,
                     when 3 => (Left + Up) / 2,
                     when 4 => Paeth (Left, Up, Upper),
                     when others => 0);
            begin
               Result (I + 1) := Byte ((Value - Predicted) mod 256);
            end;
         end loop;
         return Result;
      end Filtered;

      function Png (Channels : Positive; Filters : Filter_Row_Types) return String is
         Raster : Unbounded_String;
      begin
         for Row in 1 .. Height loop
            Append
              (Raster,
               Filtered (Row_Bytes (Row, Channels), (if Row = 1 then "" else Row_Bytes (Row - 1, Channels)),
                         Filters (Row), Channels));
         end loop;
         return Signature
           & Chunk ("IHDR", Be32 (Width) & Be32 (Height) & Byte (8) & Byte (if Channels = 4 then 6 else 2)
                            & Byte (0) & Byte (0) & Byte (0))
           & Chunk ("IDAT", Stored_Zlib_Stream (To_String (Raster)))
           & Chunk ("IEND", "");
      end Png;

      procedure Check (Name : String; Channels : Positive; Filters : Filter_Row_Types) is
         Image   : Files.Images.Png.Raster;
         Decoded : constant Boolean := Files.Images.Png.Decode (Png (Channels, Filters), Image);
         Index   : Positive := 1;
      begin
         Assert (Decoded and then Image.Width = Width and then Image.Height = Height
                 and then Natural (Image.Pixels.Length) = Width * Height * 4,
                 Name & " is decoded");
         for Row in 1 .. Height loop
            declare
               Expected : constant String := Row_Bytes (Row, Channels);
            begin
               for Pixel in 0 .. Width - 1 loop
                  for Channel in 1 .. 4 loop
                     declare
                        Want : constant Natural :=
                          (if Channel <= Channels then Character'Pos (Expected (Pixel * Channels + Channel)) else 255);
                        Got  : constant Natural := Natural (Image.Pixels.Element (Index));
                     begin
                        Assert (Got = Want,
                                Name & ": row" & Row'Image & ", pixel" & Pixel'Image & ", channel" & Channel'Image
                                & " is" & Got'Image & ", not" & Want'Image);
                     end;
                     Index := Index + 1;
                  end loop;
               end loop;
            end;
         end loop;
      end Check;

      Names : constant array (1 .. 4) of String (1 .. 7) := ["Sub    ", "Up     ", "Average", "Paeth  "];
   begin
      for Filter in 1 .. 4 loop
         Check (Names (Filter) & " RGB", 3, [others => Filter]);
         Check (Names (Filter) & " RGBA", 4, [others => Filter]);
      end loop;
      Check ("mixed filters RGB", 3, [1, 4, 3]);
      Check ("mixed filters RGBA", 4, [2, 1, 4]);
   end Test_Png_Row_Filters;

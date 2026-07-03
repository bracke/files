package body Files.Gui.Frame_Analysis is

   use type Interfaces.Unsigned_8;

   Bytes_Per_Pixel : constant := 4;
   --  RGBA8 packs four components per pixel.

   Quantization_Bits : constant := 4;
   --  Colors are quantized to the top 4 bits per channel so that near-identical
   --  shades collapse into one bucket. This keeps the distinct-color estimate
   --  robust against anti-aliasing and gradients.

   Bucket_Shift  : constant := 8 - Quantization_Bits;
   Bucket_Levels : constant := 2 ** Quantization_Bits;
   Bucket_Count  : constant := Bucket_Levels ** 3;

   subtype Bucket_Range is Natural range 0 .. Bucket_Count - 1;
   type Bucket_Counts is array (Bucket_Range) of Natural;
   type Band_Seen_Array is array (Band_Index, Bucket_Range) of Boolean;

   Ink_Channel_Distance : constant := 60;
   --  Minimum summed absolute per-channel difference from the background color
   --  for a pixel to count as ink.

   Background_Fraction_Ceiling : constant Float := 0.995;
   --  The most common color must cover strictly less than this fraction of the
   --  frame, so a flat (blank) frame fails.

   Min_Distinct_Colors : constant := 2;

   --  Return the quantized color bucket for a pixel's RGB components.
   function Bucket_Of
     (Red   : Interfaces.Unsigned_8;
      Green : Interfaces.Unsigned_8;
      Blue  : Interfaces.Unsigned_8)
      return Bucket_Range
   is
      R : constant Natural := Natural (Red) / (2 ** Bucket_Shift);
      G : constant Natural := Natural (Green) / (2 ** Bucket_Shift);
      B : constant Natural := Natural (Blue) / (2 ** Bucket_Shift);
   begin
      return (R * Bucket_Levels * Bucket_Levels) + (G * Bucket_Levels) + B;
   end Bucket_Of;

   --  Return the band that owns row Row of a Height-row frame.
   function Band_Of (Row : Natural; Height : Natural) return Band_Index is
      Raw : constant Natural := (Row * Band_Count) / Natural'Max (Height, 1);
   begin
      return Band_Index (1 + Natural'Min (Raw, Band_Count - 1));
   end Band_Of;

   --  Shared background-color reference derived from a whole frame. Both
   --  Analyze and the region helpers use this so their ink distance is
   --  measured against the identical background color.
   type Frame_Reference is record
      Valid            : Boolean := False;
      Distinct         : Natural := 0;
      Background_Count  : Natural := 0;
      Red              : Natural := 0;
      Green            : Natural := 0;
      Blue             : Natural := 0;
   end record;

   --  Compute the frame's background reference: the average color of the
   --  single most common quantized color bucket, plus the distinct-color count
   --  and the dominant bucket's pixel count. Returns Valid => False when the
   --  buffer is too small for the stated dimensions or the dimensions are zero.
   function Compute_Reference
     (Data   : Byte_Array;
      Width  : Natural;
      Height : Natural)
      return Frame_Reference
   is
      Total_Pixels : constant Natural := Width * Height;
      Required     : constant Natural := Total_Pixels * Bytes_Per_Pixel;
      Counts       : Bucket_Counts := [others => 0];
      Background    : Bucket_Range := 0;
      Distinct      : Natural := 0;
      Sum_R         : Long_Long_Integer := 0;
      Sum_G         : Long_Long_Integer := 0;
      Sum_B         : Long_Long_Integer := 0;
      Result        : Frame_Reference;
   begin
      if Width = 0 or else Height = 0
        or else Total_Pixels = 0
        or else Data'Length < Required
      then
         return Result;
      end if;

      --  Pass 1: quantized color histogram.
      for Pixel in 0 .. Total_Pixels - 1 loop
         declare
            Base   : constant Positive := Data'First + Pixel * Bytes_Per_Pixel;
            Bucket : constant Bucket_Range :=
              Bucket_Of (Data (Base), Data (Base + 1), Data (Base + 2));
         begin
            if Counts (Bucket) = 0 then
               Distinct := Distinct + 1;
            end if;
            Counts (Bucket) := Counts (Bucket) + 1;
         end;
      end loop;

      --  Identify the dominant (background) bucket.
      for Bucket in Bucket_Range loop
         if Counts (Bucket) > Counts (Background) then
            Background := Bucket;
         end if;
      end loop;

      --  Pass 2: average color of the background bucket, for ink distance.
      for Pixel in 0 .. Total_Pixels - 1 loop
         declare
            Base : constant Positive := Data'First + Pixel * Bytes_Per_Pixel;
         begin
            if Bucket_Of (Data (Base), Data (Base + 1), Data (Base + 2)) = Background then
               Sum_R := Sum_R + Long_Long_Integer (Data (Base));
               Sum_G := Sum_G + Long_Long_Integer (Data (Base + 1));
               Sum_B := Sum_B + Long_Long_Integer (Data (Base + 2));
            end if;
         end;
      end loop;

      Result.Valid := True;
      Result.Distinct := Distinct;
      Result.Background_Count := Counts (Background);
      if Counts (Background) > 0 then
         Result.Red   := Natural (Sum_R / Long_Long_Integer (Counts (Background)));
         Result.Green := Natural (Sum_G / Long_Long_Integer (Counts (Background)));
         Result.Blue  := Natural (Sum_B / Long_Long_Integer (Counts (Background)));
      end if;
      return Result;
   end Compute_Reference;

   --  Return the summed absolute per-channel distance from a reference color.
   function Ink_Distance
     (Red, Green, Blue : Interfaces.Unsigned_8;
      Reference        : Frame_Reference)
      return Natural
   is
   begin
      return abs (Natural (Red) - Reference.Red)
        + abs (Natural (Green) - Reference.Green)
        + abs (Natural (Blue) - Reference.Blue);
   end Ink_Distance;

   function Analyze
     (Data   : Byte_Array;
      Width  : Natural;
      Height : Natural;
      Format : Pixel_Format := Pixel_Format_RGBA8)
      return Frame_Metrics
   is
      pragma Unreferenced (Format);
      Metrics       : Frame_Metrics;
      Total_Pixels  : constant Natural := Width * Height;
      Required      : constant Natural := Total_Pixels * Bytes_Per_Pixel;
      Band_Seen     : Band_Seen_Array := [others => [others => False]];
      Band_Ink      : array (Band_Index) of Natural := [others => 0];
      Ink_Total      : Natural := 0;
      Reference      : Frame_Reference;
   begin
      if Width = 0 or else Height = 0
        or else Total_Pixels = 0
        or else Data'Length < Required
      then
         return Metrics;
      end if;

      --  Passes 1 and 2: histogram, dominant bucket and background color.
      Reference := Compute_Reference (Data, Width, Height);
      if not Reference.Valid then
         return Metrics;
      end if;

      --  Pass 3: ink detection and per-band content.
      for Row in 0 .. Height - 1 loop
         declare
            Band : constant Band_Index := Band_Of (Row, Height);
         begin
            for Column in 0 .. Width - 1 loop
               declare
                  Base   : constant Positive :=
                    Data'First + ((Row * Width) + Column) * Bytes_Per_Pixel;
                  Bucket : constant Bucket_Range :=
                    Bucket_Of (Data (Base), Data (Base + 1), Data (Base + 2));
                  Distance : constant Natural :=
                    Ink_Distance (Data (Base), Data (Base + 1), Data (Base + 2), Reference);
               begin
                  Band_Seen (Band, Bucket) := True;
                  if Distance >= Ink_Channel_Distance then
                     Ink_Total := Ink_Total + 1;
                     Band_Ink (Band) := Band_Ink (Band) + 1;
                  end if;
               end;
            end loop;
         end;
      end loop;

      Metrics.Analyzed := True;
      Metrics.Width := Width;
      Metrics.Height := Height;
      Metrics.Total_Pixels := Total_Pixels;
      Metrics.Distinct_Colors := Reference.Distinct;
      Metrics.Background_Fraction :=
        Float (Reference.Background_Count) / Float (Total_Pixels);
      Metrics.Ink_Pixels := Ink_Total;
      Metrics.Ink_Fraction := Float (Ink_Total) / Float (Total_Pixels);

      for Band in Band_Index loop
         declare
            Distinct_In_Band : Natural := 0;
         begin
            for Bucket in Bucket_Range loop
               if Band_Seen (Band, Bucket) then
                  Distinct_In_Band := Distinct_In_Band + 1;
                  exit when Distinct_In_Band > 1;
               end if;
            end loop;
            Metrics.Band_Has_Content (Band) :=
              Distinct_In_Band > 1 or else Band_Ink (Band) > 0;
         end;
      end loop;

      return Metrics;
   end Analyze;

   function All_Bands_Have_Content (Metrics : Frame_Metrics) return Boolean is
   begin
      for Band in Band_Index loop
         if not Metrics.Band_Has_Content (Band) then
            return False;
         end if;
      end loop;
      return True;
   end All_Bands_Have_Content;

   function Bands_With_Content (Metrics : Frame_Metrics) return Natural is
      Total : Natural := 0;
   begin
      for Band in Band_Index loop
         if Metrics.Band_Has_Content (Band) then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Bands_With_Content;

   function Passed (Metrics : Frame_Metrics) return Boolean is
      Min_Ink : constant Natural := Natural'Max (32, Metrics.Total_Pixels / 5_000);
   begin
      return Metrics.Analyzed
        and then Metrics.Total_Pixels > 0
        and then Metrics.Distinct_Colors >= Min_Distinct_Colors
        and then Metrics.Background_Fraction < Background_Fraction_Ceiling
        and then Metrics.Ink_Pixels >= Min_Ink
        and then All_Bands_Have_Content (Metrics);
   end Passed;

   function Region_Ink_Fraction
     (Data   : Byte_Array;
      Width  : Natural;
      Height : Natural;
      Format : Pixel_Format := Pixel_Format_RGBA8;
      X      : Natural;
      Y      : Natural;
      W      : Natural;
      H      : Natural)
      return Float
   is
      pragma Unreferenced (Format);
      Total_Pixels : constant Natural := Width * Height;
      Required     : constant Natural := Total_Pixels * Bytes_Per_Pixel;
      Reference    : Frame_Reference;
      X_End        : Natural;
      Y_End        : Natural;
      Area         : Natural;
      Ink          : Natural := 0;
   begin
      if Width = 0 or else Height = 0
        or else Total_Pixels = 0
        or else Data'Length < Required
        or else W = 0 or else H = 0
        or else X >= Width or else Y >= Height
      then
         return 0.0;
      end if;

      --  Clamp the exclusive right/bottom edges to the frame.
      X_End := Natural'Min (X + W, Width);
      Y_End := Natural'Min (Y + H, Height);
      Area := (X_End - X) * (Y_End - Y);
      if Area = 0 then
         return 0.0;
      end if;

      Reference := Compute_Reference (Data, Width, Height);
      if not Reference.Valid then
         return 0.0;
      end if;

      for Row in Y .. Y_End - 1 loop
         for Column in X .. X_End - 1 loop
            declare
               Base : constant Positive :=
                 Data'First + ((Row * Width) + Column) * Bytes_Per_Pixel;
            begin
               if Ink_Distance (Data (Base), Data (Base + 1), Data (Base + 2), Reference)
                    >= Ink_Channel_Distance
               then
                  Ink := Ink + 1;
               end if;
            end;
         end loop;
      end loop;

      return Float (Ink) / Float (Area);
   end Region_Ink_Fraction;

   function Region_Has_Ink
     (Data         : Byte_Array;
      Width        : Natural;
      Height       : Natural;
      Format       : Pixel_Format := Pixel_Format_RGBA8;
      X            : Natural;
      Y            : Natural;
      W            : Natural;
      H            : Natural;
      Min_Fraction : Float := Default_Region_Ink_Fraction)
      return Boolean is
   begin
      return Region_Ink_Fraction (Data, Width, Height, Format, X, Y, W, H) >= Min_Fraction;
   end Region_Has_Ink;

end Files.Gui.Frame_Analysis;

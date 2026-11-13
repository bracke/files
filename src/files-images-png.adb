with Ada.Unchecked_Deallocation;
with Files.Diagnostics;
with GNAT.CRC32;
with Interfaces;
with Zlib;

package body Files.Images.Png is

   use type Ada.Streams.Stream_Element_Offset;

   subtype Offset is Ada.Streams.Stream_Element_Offset;

   type Stream_Element_Array_Access is access Ada.Streams.Stream_Element_Array;

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Ada.Streams.Stream_Element_Array,
      Name   => Stream_Element_Array_Access);

   --  Where one IDAT chunk's payload lies in the file, from byte First to
   --  byte Last (zero-based).
   type Byte_Range is record
      First : Natural := 0;
      Last  : Natural := 0;
   end record;

   package Range_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Byte_Range);

   --  What the chunk walk read: IHDR's fields, tRNS's colour, and where the
   --  compressed raster lies.
   type Layout is record
      Width             : Natural := 0;
      Height            : Natural := 0;
      Bit_Depth         : Natural := 0;
      Color_Type        : Natural := 0;
      Interlace         : Natural := 0;
      Transparent       : Boolean := False;
      Transparent_Red   : Natural := 0;
      Transparent_Green : Natural := 0;
      Transparent_Blue  : Natural := 0;
      Image_Data        : Range_Vectors.Vector;
      Image_Data_Length : Natural := 0;
   end record;

   --  The byte at zero-based Index, or 0 past the end.
   function Byte (Data : String; Index : Natural) return Natural is
     (if Index >= Data'Length then 0 else Character'Pos (Data (Data'First + Index)));

   --  The big-endian 32-bit value at zero-based Index, clamped as U32_BE.
   function U32 (Data : String; Index : Natural) return Natural is
      Word : constant Ada.Streams.Stream_Element_Array (0 .. 3) :=
        [for Position in Offset range 0 .. 3 =>
           Ada.Streams.Stream_Element (Byte (Data, Index + Natural (Position)))];
   begin
      return U32_BE (Word, 0);
   end U32;

   --  Whether the CRC stored at Crc_Start covers the chunk's type and data,
   --  from Type_Start up to Crc_Start.
   function Chunk_Crc_Is_Valid
     (Data       : String;
      Type_Start : Natural;
      Crc_Start  : Natural) return Boolean
   is
      use type Interfaces.Unsigned_32;
      Context  : GNAT.CRC32.CRC32;
      Buffer   : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Cursor   : Natural := Type_Start;
      Expected : constant Interfaces.Unsigned_32 :=
        Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte (Data, Crc_Start)), 24)
        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte (Data, Crc_Start + 1)), 16)
        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte (Data, Crc_Start + 2)), 8)
        or Interfaces.Unsigned_32 (Byte (Data, Crc_Start + 3));
   begin
      GNAT.CRC32.Initialize (Context);
      while Cursor < Crc_Start loop
         declare
            Count : constant Natural := Natural'Min (Natural (Buffer'Length), Crc_Start - Cursor);
         begin
            for Index in 0 .. Count - 1 loop
               Buffer (Buffer'First + Offset (Index)) := Ada.Streams.Stream_Element (Byte (Data, Cursor + Index));
            end loop;
            GNAT.CRC32.Update (Context, Buffer (Buffer'First .. Buffer'First + Offset (Count) - 1));
            Cursor := Cursor + Count;
         end;
      end loop;
      return GNAT.CRC32.Get_Value (Context) = Expected;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Images.Png");
         return False;
   end Chunk_Crc_Is_Valid;

   --  Walk every chunk from the signature to IEND, checking each CRC and
   --  the order and form of the chunks this reader knows, and keep what
   --  decoding needs. False for anything this reader does not decode.
   function Walk_Chunks (Data : String; Found : out Layout) return Boolean is
      Head : constant Ada.Streams.Stream_Element_Array (0 .. 23) :=
        [for Index in Offset range 0 .. 23 => Ada.Streams.Stream_Element (Byte (Data, Natural (Index)))];
      Position   : Natural := 8;
      Saw_Ihdr   : Boolean := False;
      Saw_Plte   : Boolean := False;
      Saw_Idat   : Boolean := False;
      Ended_Idat : Boolean := False;
      Saw_Iend   : Boolean := False;
   begin
      Found := (others => <>);
      --  The signature, then IHDR (length 13) first.
      if Data'Length < Head'Length or else not PNG_Header (Head, Found.Width, Found.Height) then
         return False;
      end if;

      while Position + 12 <= Data'Length loop
         declare
            Length_Value : constant Natural := U32 (Data, Position);
            Kind         : constant String := Data (Data'First + Position + 4 .. Data'First + Position + 7);
            Data_Start   : constant Natural := Position + 8;
            Crc_Start    : constant Natural := Data_Start + Length_Value;
         begin
            if Data_Start + Length_Value + 4 > Data'Length then
               return False;
            elsif not Chunk_Crc_Is_Valid (Data, Position + 4, Crc_Start) then
               return False;
            end if;

            if Kind = "IHDR" then
               if Saw_Ihdr or else Position /= 8 or else Length_Value /= 13 then
                  return False;
               end if;
               Saw_Ihdr := True;
               Found.Bit_Depth := Byte (Data, Data_Start + 8);
               Found.Color_Type := Byte (Data, Data_Start + 9);
               Found.Interlace := Byte (Data, Data_Start + 12);
               --  Compression and filter method 0 are the only ones.
               if Byte (Data, Data_Start + 10) /= 0 or else Byte (Data, Data_Start + 11) /= 0 then
                  return False;
               end if;
            elsif Kind = "IDAT" then
               if not Saw_Ihdr or else Ended_Idat then
                  return False;
               end if;
               Saw_Idat := True;
               if Length_Value > 0 then
                  Found.Image_Data.Append (Byte_Range'(First => Data_Start, Last => Crc_Start - 1));
                  Found.Image_Data_Length := Found.Image_Data_Length + Length_Value;
               end if;
            elsif Kind = "IEND" then
               if not Saw_Ihdr or else not Saw_Idat or else Length_Value /= 0 then
                  return False;
               end if;
               Saw_Iend := True;
               Position := Crc_Start + 4;
               exit;
            elsif Kind = "PLTE" then
               if not Saw_Ihdr
                 or else Saw_Plte
                 or else Saw_Idat
                 or else Length_Value = 0
                 or else Length_Value mod 3 /= 0
                 or else Length_Value > 768
               then
                  return False;
               end if;
               Saw_Plte := True;
            elsif Kind = "tRNS" then
               --  For the true-colour format decoded here, tRNS identifies
               --  one fully transparent RGB sample.  It must precede IDAT;
               --  silently ignoring it exposes RGB data that should be
               --  invisible in the generated opaque PPM thumbnail.
               if not Saw_Ihdr
                 or else Found.Transparent
                 or else Saw_Idat
                 or else Found.Color_Type /= 2
                 or else Found.Bit_Depth /= 8
                 or else Length_Value /= 6
                 or else Byte (Data, Data_Start) /= 0
                 or else Byte (Data, Data_Start + 2) /= 0
                 or else Byte (Data, Data_Start + 4) /= 0
               then
                  return False;
               end if;
               Found.Transparent := True;
               Found.Transparent_Red := Byte (Data, Data_Start + 1);
               Found.Transparent_Green := Byte (Data, Data_Start + 3);
               Found.Transparent_Blue := Byte (Data, Data_Start + 5);
            else
               if Saw_Idat then
                  Ended_Idat := True;
               end if;
               --  Unknown critical chunks change decoding semantics.  This
               --  minimal decoder may ignore ancillary chunks only.
               if Kind (Kind'First) in 'A' .. 'Z' then
                  return False;
               end if;
            end if;

            Position := Crc_Start + 4;
         end;
      end loop;

      --  Adam7-interlaced PNGs have a different IDAT layout than the single
      --  raster this decoder assumes; they are left to the full decoder
      --  rather than producing a garbled thumbnail.
      return Saw_Iend
        and then Position = Data'Length
        and then Found.Width /= 0
        and then Found.Height /= 0
        and then Found.Width <= Max_Source_Side
        and then Found.Height <= Max_Source_Side
        --  The inflated raster is bounded by RAM, not the stack: it is
        --  heap-allocated.
        and then Found.Width * Found.Height <= Max_Source_Pixels
        and then Found.Bit_Depth = 8
        and then Found.Interlace = 0
        and then Found.Image_Data_Length > 0;
   end Walk_Chunks;

   --  The IDAT payloads joined, as the one zlib stream they make.
   function Compressed_Raster (Data : String; Found : Layout) return Stream_Element_Array_Access is
      Result : Stream_Element_Array_Access :=
        new Ada.Streams.Stream_Element_Array (0 .. Offset (Found.Image_Data_Length) - 1);
      Next   : Offset := Result'First;
   begin
      for Chunk of Found.Image_Data loop
         for Index in Chunk.First .. Chunk.Last loop
            Result (Next) := Ada.Streams.Stream_Element (Byte (Data, Index));
            Next := Next + 1;
         end loop;
      end loop;
      return Result;
   exception
      when others =>
         Free (Result);
         raise;
   end Compressed_Raster;

   --  Inflate Compressed into exactly Inflated'Length bytes. A stream that
   --  expands past that budget is refused as soon as it does, instead of
   --  first being materialized as an attacker-controlled allocation; one
   --  that ends short of it, or has bytes after its end, is refused too.
   function Inflate
     (Compressed : Ada.Streams.Stream_Element_Array;
      Inflated   : in out Ada.Streams.Stream_Element_Array) return Boolean
   is
      Filter   : Zlib.Filter_Type;
      Position : Offset := Compressed'First;
      Filled   : Offset := Inflated'First;
      Output   : Ada.Streams.Stream_Element_Array (1 .. Files.Types.IO_Chunk_Bytes);

      procedure Close_Filter is
      begin
         if Zlib.Is_Open (Filter) then
            Zlib.Close (Filter, Ignore_Error => True);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Images.Png");
      end Close_Filter;

      function Append_Output (Last : Offset) return Boolean is
         Count : constant Offset := (if Last < Output'First then 0 else Last - Output'First + 1);
      begin
         if Count > Inflated'Last + 1 - Filled then
            return False;
         end if;
         Inflated (Filled .. Filled + Count - 1) := Output (Output'First .. Output'First + Count - 1);
         Filled := Filled + Count;
         return True;
      end Append_Output;
   begin
      Zlib.Inflate_Init (Filter, Header => Zlib.Zlib_Header);

      while Position <= Compressed'Last loop
         declare
            In_Last  : Offset;
            Out_Last : Offset;
            Before   : constant Offset := Position;
         begin
            Zlib.Translate (Filter, Compressed (Position .. Compressed'Last), In_Last, Output, Out_Last);
            if not Append_Output (Out_Last) then
               Close_Filter;
               return False;
            end if;
            if In_Last >= Before then
               Position := In_Last + 1;
            end if;
            if Zlib.Stream_End (Filter) then
               if Position <= Compressed'Last then
                  Close_Filter;
                  return False;
               end if;
               exit;
            end if;
            if In_Last < Before and then Out_Last < Output'First then
               Close_Filter;
               return False;
            end if;
         end;
      end loop;

      while not Zlib.Stream_End (Filter) loop
         declare
            Empty    : constant Ada.Streams.Stream_Element_Array (1 .. 0) := [];
            In_Last  : Offset;
            Out_Last : Offset;
         begin
            Zlib.Translate (Filter, Empty, In_Last, Output, Out_Last, Zlib.Finish);
            if not Append_Output (Out_Last)
              or else (Out_Last < Output'First and then not Zlib.Stream_End (Filter))
            then
               Close_Filter;
               return False;
            end if;
         end;
      end loop;

      if Filled /= Inflated'Last + 1 then
         Close_Filter;
         return False;
      end if;
      Zlib.Close (Filter);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Images.Png");
         Close_Filter;
         return False;
   end Inflate;

   --  The Paeth predictor: whichever of Left, Up and Upper is nearest to
   --  Left + Up - Upper.
   function Paeth (Left, Up, Upper : Natural) return Natural is
      P  : constant Integer := Integer (Left) + Integer (Up) - Integer (Upper);
      PA : constant Natural := Natural (abs (P - Integer (Left)));
      PB : constant Natural := Natural (abs (P - Integer (Up)));
      PC : constant Natural := Natural (abs (P - Integer (Upper)));
   begin
      if PA <= PB and then PA <= PC then
         return Left;
      elsif PB <= PC then
         return Up;
      else
         return Upper;
      end if;
   end Paeth;

   --  Undo one row's filter: Raw is the filtered row, Previous the row
   --  above as reconstructed (zeros for the first), Current the row as it
   --  was. False for a filter type past 4.
   function Unfilter_Row
     (Filter   : Natural;
      Raw      : Ada.Streams.Stream_Element_Array;
      Channels : Positive;
      Previous : Ada.Streams.Stream_Element_Array;
      Current  : out Ada.Streams.Stream_Element_Array) return Boolean is
   begin
      Current := [others => 0];
      if Filter > 4 then
         return False;
      end if;
      for Column in 0 .. Natural (Current'Length) - 1 loop
         declare
            Value : constant Natural := Natural (Raw (Raw'First + Offset (Column)));
            Left  : constant Natural :=
              (if Column >= Channels then Natural (Current (Current'First + Offset (Column - Channels))) else 0);
            Up    : constant Natural := Natural (Previous (Previous'First + Offset (Column)));
            Upper : constant Natural :=
              (if Column >= Channels then Natural (Previous (Previous'First + Offset (Column - Channels))) else 0);
            Sum   : constant Natural :=
              (case Filter is
                  when 1 => Value + Left,
                  when 2 => Value + Up,
                  when 3 => Value + (Left + Up) / 2,
                  when 4 => Value + Paeth (Left, Up, Upper),
                  when others => Value);
         begin
            Current (Current'First + Offset (Column)) := Ada.Streams.Stream_Element (Sum mod 256);
         end;
      end loop;
      return True;
   end Unfilter_Row;

   --  Append one reconstructed row's pixels; without an alpha channel a
   --  pixel of the tRNS colour is fully transparent, any other opaque.
   procedure Append_Row
     (Row      : Ada.Streams.Stream_Element_Array;
      Found    : Layout;
      Channels : Positive;
      Pixels   : in out Pixel_Vectors.Vector)
   is
      function Sample (Column, Channel : Natural) return Natural is
        (Natural (Row (Row'First + Offset (Column * Channels + Channel))));
   begin
      for Column in 0 .. Found.Width - 1 loop
         Pixels.Append
           (Rgba_Pixel'
              (Red   => Sample (Column, 0),
               Green => Sample (Column, 1),
               Blue  => Sample (Column, 2),
               Alpha =>
                 (if Channels = 4 then Sample (Column, 3)
                  elsif Found.Transparent
                    and then Sample (Column, 0) = Found.Transparent_Red
                    and then Sample (Column, 1) = Found.Transparent_Green
                    and then Sample (Column, 2) = Found.Transparent_Blue
                  then 0
                  else 255)));
      end loop;
   end Append_Row;

   function Decode (Data : String; Image : out Raster) return Boolean is
      Found    : Layout;
      Channels : Natural;
   begin
      Image := (others => <>);
      if not Walk_Chunks (Data, Found) then
         return False;
      end if;
      Channels := (case Found.Color_Type is when 2 => 3, when 6 => 4, when others => 0);
      if Channels = 0 then
         return False;
      end if;

      declare
         Row_Stride : constant Natural := Found.Width * Channels;
         Needed     : constant Natural := Found.Height * (Row_Stride + 1);
         Compressed : Stream_Element_Array_Access := Compressed_Raster (Data, Found);
         Inflated   : Stream_Element_Array_Access;
         Previous   : Ada.Streams.Stream_Element_Array (0 .. Offset (Row_Stride - 1)) := [others => 0];
         Current    : Ada.Streams.Stream_Element_Array (0 .. Offset (Row_Stride - 1));
      begin
         Inflated := new Ada.Streams.Stream_Element_Array (0 .. Offset (Needed) - 1);
         if not Inflate (Compressed.all, Inflated.all) then
            Free (Compressed);
            Free (Inflated);
            return False;
         end if;
         Free (Compressed);

         Image.Pixels.Reserve_Capacity (Ada.Containers.Count_Type (Found.Width * Found.Height));
         for Row in 0 .. Found.Height - 1 loop
            declare
               --  Each row is its filter type byte, then its samples.
               Base : constant Offset := Offset (Row * (Row_Stride + 1));
            begin
               if not Unfilter_Row
                 (Filter   => Natural (Inflated (Base)),
                  Raw      => Inflated (Base + 1 .. Base + Offset (Row_Stride)),
                  Channels => Channels,
                  Previous => Previous,
                  Current  => Current)
               then
                  Free (Inflated);
                  Image := (others => <>);
                  return False;
               end if;
               Append_Row (Current, Found, Channels, Image.Pixels);
               Previous := Current;
            end;
         end loop;
         Free (Inflated);
      exception
         when others =>
            Free (Compressed);
            Free (Inflated);
            raise;
      end;

      Image.Width := Found.Width;
      Image.Height := Found.Height;
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Images.Png");
         Image := (others => <>);
         return False;
   end Decode;

end Files.Images.Png;

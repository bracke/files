separate (Files.File_System)
   function Try_Write_Decoded_Png_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is
      use type GNAT.OS_Lib.File_Descriptor;
      File       : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Bytes_Read : Integer;
      Bytes      : Thumbnail_Byte_Vectors.Vector;
      Idat       : Thumbnail_Byte_Vectors.Vector;
      Width  : Natural := 0;
      Height : Natural := 0;
      Bit_Depth  : Natural := 0;
      Color_Type : Natural := 0;
      Interlace  : Natural := 0;
      Position   : Natural := 8;
      Channels   : Natural := 0;
      Pixels     : Pixel_Vectors.Vector;
      Saw_Ihdr   : Boolean := False;
      Saw_Plte   : Boolean := False;
      Saw_Trns   : Boolean := False;
      Saw_Idat   : Boolean := False;
      Ended_Idat : Boolean := False;
      Saw_Iend   : Boolean := False;
      Transparent_Red   : Natural := 0;
      Transparent_Green : Natural := 0;
      Transparent_Blue  : Natural := 0;

      function Is_Png_Signature return Boolean is
      begin
         return Natural (Bytes.Length) >= 8
           and then Byte_At (Bytes, 0) = 16#89#
           and then Byte_At (Bytes, 1) = Character'Pos ('P')
           and then Byte_At (Bytes, 2) = Character'Pos ('N')
           and then Byte_At (Bytes, 3) = Character'Pos ('G')
           and then Byte_At (Bytes, 4) = 16#0D#
           and then Byte_At (Bytes, 5) = 16#0A#
           and then Byte_At (Bytes, 6) = 16#1A#
           and then Byte_At (Bytes, 7) = 16#0A#;
      end Is_Png_Signature;

      function Chunk_Type
        (Index : Natural)
         return String is
      begin
         return
           Character'Val (Byte_At (Bytes, Index))
           & Character'Val (Byte_At (Bytes, Index + 1))
           & Character'Val (Byte_At (Bytes, Index + 2))
           & Character'Val (Byte_At (Bytes, Index + 3));
      end Chunk_Type;

      function Chunk_Crc_Is_Valid
        (Type_Start : Natural;
         Crc_Start  : Natural) return Boolean
      is
         use type Interfaces.Unsigned_32;
         Context : GNAT.CRC32.CRC32;
         Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Cursor  : Natural := Type_Start;
         Expected : constant Interfaces.Unsigned_32 :=
           Interfaces.Shift_Left
             (Interfaces.Unsigned_32 (Byte_At (Bytes, Crc_Start)), 24)
           or Interfaces.Shift_Left
             (Interfaces.Unsigned_32 (Byte_At (Bytes, Crc_Start + 1)), 16)
           or Interfaces.Shift_Left
             (Interfaces.Unsigned_32 (Byte_At (Bytes, Crc_Start + 2)), 8)
           or Interfaces.Unsigned_32 (Byte_At (Bytes, Crc_Start + 3));
      begin
         GNAT.CRC32.Initialize (Context);
         while Cursor < Crc_Start loop
            declare
               Count : constant Natural := Natural'Min
                 (Natural (Buffer'Length), Crc_Start - Cursor);
            begin
               for Index in 0 .. Count - 1 loop
                  Buffer
                    (Buffer'First + Ada.Streams.Stream_Element_Offset (Index)) :=
                      Bytes.Element (Cursor + Index);
               end loop;
               GNAT.CRC32.Update
                 (Context,
                  Buffer
                    (Buffer'First
                     .. Buffer'First
                       + Ada.Streams.Stream_Element_Offset (Count) - 1));
               Cursor := Cursor + Count;
            end;
         end loop;
         return GNAT.CRC32.Get_Value (Context) = Expected;
      exception
         when others =>
            return False;
      end Chunk_Crc_Is_Valid;

      function Paeth
        (Left  : Natural;
         Up    : Natural;
         Upper : Natural)
         return Natural
      is
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
   begin
      File := Files.Fs_Primitives.Open_Regular_Read (Source_Path);
      if File = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;
      loop
         Bytes_Read := GNAT.OS_Lib.Read
           (File, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0 then
            raise Ada.Directories.Use_Error;
         end if;
         exit when Bytes_Read = 0;
         if Long_Long_Integer (Natural (Bytes.Length))
             + Long_Long_Integer (Bytes_Read) >
               Long_Long_Integer (Max_Fast_Decode_Source_Bytes)
         then
            GNAT.OS_Lib.Close (File);
            File := GNAT.OS_Lib.Invalid_FD;
            return False;
         end if;
         for Index in Buffer'First
           .. Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1
         loop
            Bytes.Append (Buffer (Index));
         end loop;
      end loop;
      GNAT.OS_Lib.Close (File);
      File := GNAT.OS_Lib.Invalid_FD;

      if not Is_Png_Signature then
         return False;
      end if;

      while Position + 12 <= Natural (Bytes.Length) loop
         declare
            Length_Value : constant Natural := U32_BE_From (Bytes, Position);
            Kind         : constant String := Chunk_Type (Position + 4);
            Data_Start   : constant Natural := Position + 8;
            Data_Last    : constant Natural := Data_Start + Length_Value - 1;
            Crc_Start    : constant Natural := Data_Start + Length_Value;
         begin
            if Data_Start + Length_Value + 4 > Natural (Bytes.Length) then
               return False;
            elsif not Chunk_Crc_Is_Valid (Position + 4, Crc_Start) then
               return False;
            end if;

            if Kind = "IHDR" then
               if Saw_Ihdr or else Position /= 8 or else Length_Value /= 13 then
                  return False;
               end if;
               Saw_Ihdr := True;
               Width := U32_BE_From (Bytes, Data_Start);
               Height := U32_BE_From (Bytes, Data_Start + 4);
               Bit_Depth := Byte_At (Bytes, Data_Start + 8);
               Color_Type := Byte_At (Bytes, Data_Start + 9);
               Interlace := Byte_At (Bytes, Data_Start + 12);
               if Byte_At (Bytes, Data_Start + 10) /= 0
                 or else Byte_At (Bytes, Data_Start + 11) /= 0
               then
                  return False;
               end if;
            elsif Kind = "IDAT" then
               if not Saw_Ihdr or else Ended_Idat then
                  return False;
               end if;
               Saw_Idat := True;
               if Length_Value > 0 then
                  for Index in Data_Start .. Data_Last loop
                     Idat.Append (Bytes.Element (Index));
                  end loop;
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
                 or else Saw_Trns
                 or else Saw_Idat
                 or else Color_Type /= 2
                 or else Bit_Depth /= 8
                 or else Length_Value /= 6
                 or else Byte_At (Bytes, Data_Start) /= 0
                 or else Byte_At (Bytes, Data_Start + 2) /= 0
                 or else Byte_At (Bytes, Data_Start + 4) /= 0
               then
                  return False;
               end if;
               Saw_Trns := True;
               Transparent_Red := Byte_At (Bytes, Data_Start + 1);
               Transparent_Green := Byte_At (Bytes, Data_Start + 3);
               Transparent_Blue := Byte_At (Bytes, Data_Start + 5);
            else
               if Saw_Idat then
                  Ended_Idat := True;
               end if;
               --  Unknown critical chunks change decoding semantics.  This
               --  minimal decoder may ignore ancillary chunks only.
               if Kind (Kind'First) in 'A' .. 'Z' and then Kind /= "PLTE" then
                  return False;
               end if;
            end if;

            Position := Crc_Start + 4;
         end;
      end loop;

      if not Saw_Iend
        or else Position /= Natural (Bytes.Length)
        or else Width = 0
        or else Height = 0
        or else Width > Max_Source_Side
        or else Height > Max_Source_Side
        --  Guard against absurd dimensions (the inflated raster is bounded by
        --  RAM, not the stack -- see the heap-backed raster vector below).
        or else Width * Height > Max_Source_Pixels
        or else Bit_Depth /= 8
        or else Interlace /= 0
        or else Idat.Is_Empty
      then
         --  Adam7-interlaced PNGs have a different IDAT layout than the
         --  single raster this decoder assumes; defer to the gdk-pixbuf
         --  fallback rather than producing a garbled thumbnail.
         return False;
      elsif Color_Type = 2 then
         Channels := 3;
      elsif Color_Type = 6 then
         Channels := 4;
      else
         return False;
      end if;

      declare
         Row_Stride : constant Natural := Width * Channels;
         Needed     : constant Natural := Height * (Row_Stride + 1);
         Compressed : Stream_Element_Array_Access :=
           Bytes_To_Stream_Array (Idat);
         Inflated   : Thumbnail_Byte_Vectors.Vector;
         Previous   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
           [others => 0];
         Current    : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
           [others => 0];

         function Inflate_Raster return Boolean is
            use type Ada.Containers.Count_Type;

            Filter   : Zlib.Filter_Type;
            Position : Ada.Streams.Stream_Element_Offset :=
              Compressed'First;
            Output   : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);

            procedure Close_Filter is
            begin
               if Zlib.Is_Open (Filter) then
                  Zlib.Close (Filter, Ignore_Error => True);
               end if;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
            end Close_Filter;

            function Append_Output
              (Last : Ada.Streams.Stream_Element_Offset) return Boolean
            is
               Count : constant Natural :=
                 (if Last < Output'First then 0
                  else Natural (Last - Output'First + 1));
            begin
               if Count > Needed - Natural (Inflated.Length) then
                  return False;
               end if;
               for Index in Output'First .. Last loop
                  Inflated.Append (Output (Index));
               end loop;
               return True;
            end Append_Output;
         begin
            Inflated.Reserve_Capacity (Ada.Containers.Count_Type (Needed));
            Zlib.Inflate_Init (Filter, Header => Zlib.Zlib_Header);

            while Position <= Compressed'Last loop
               declare
                  In_Last  : Ada.Streams.Stream_Element_Offset;
                  Out_Last : Ada.Streams.Stream_Element_Offset;
                  Before   : constant Ada.Streams.Stream_Element_Offset := Position;
               begin
                  Zlib.Translate
                    (Filter,
                     Compressed (Position .. Compressed'Last),
                     In_Last,
                     Output,
                     Out_Last);
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
                  In_Last  : Ada.Streams.Stream_Element_Offset;
                  Out_Last : Ada.Streams.Stream_Element_Offset;
               begin
                  Zlib.Translate
                    (Filter, Empty, In_Last, Output, Out_Last, Zlib.Finish);
                  if not Append_Output (Out_Last)
                    or else (Out_Last < Output'First
                      and then not Zlib.Stream_End (Filter))
                  then
                     Close_Filter;
                     return False;
                  end if;
               end;
            end loop;

            if Inflated.Length /= Ada.Containers.Count_Type (Needed) then
               Close_Filter;
               return False;
            end if;
            Zlib.Close (Filter);
            return True;
         exception
            when others =>
               Close_Filter;
               return False;
         end Inflate_Raster;
      begin
         --  Stream into the exact declared raster budget.  A compressed
         --  payload that expands past it is invalid instead of being fully
         --  materialized first as an attacker-controlled allocation.
         if not Inflate_Raster then
            Free_Stream_Element_Array (Compressed);
            return False;
         end if;

         for Row in 0 .. Height - 1 loop
            declare
               Filter : constant Natural := Byte_At (Inflated, Row * (Row_Stride + 1));
               Base   : constant Natural := Row * (Row_Stride + 1) + 1;
            begin
               if Filter > 4 then
                  Free_Stream_Element_Array (Compressed);
                  return False;
               end if;

               for Column in 0 .. Row_Stride - 1 loop
                  declare
                     Raw   : constant Natural := Byte_At (Inflated, Base + Column);
                     Left  : constant Natural :=
                       (if Column >= Channels
                        then Natural (Current (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                        else 0);
                     Up    : constant Natural :=
                       Natural (Previous (Ada.Streams.Stream_Element_Offset (Column)));
                     Upper : constant Natural :=
                       (if Column >= Channels
                        then Natural (Previous (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                        else 0);
                     Value : Natural := Raw;
                  begin
                     case Filter is
                        when 0 =>
                           null;
                        when 1 =>
                           Value := Raw + Left;
                        when 2 =>
                           Value := Raw + Up;
                        when 3 =>
                           Value := Raw + (Left + Up) / 2;
                        when 4 =>
                           Value := Raw + Paeth (Left, Up, Upper);
                        when others =>
                           null;
                     end case;
                     Current (Ada.Streams.Stream_Element_Offset (Column)) :=
                       Ada.Streams.Stream_Element (Value mod 256);
                  end;
               end loop;

               for Column in 0 .. Width - 1 loop
                  Pixels.Append
                    (Rgba_Pixel'
                       (Red   =>
                          Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels))),
                        Green =>
                          Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 1))),
                        Blue  =>
                          Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 2))),
                        Alpha =>
                          (if Channels = 4
                           then Natural
                             (Current
                                (Ada.Streams.Stream_Element_Offset
                                   (Column * Channels + 3)))
                           elsif Saw_Trns
                             and then Natural
                               (Current
                                  (Ada.Streams.Stream_Element_Offset
                                     (Column * Channels))) = Transparent_Red
                             and then Natural
                               (Current
                                  (Ada.Streams.Stream_Element_Offset
                                     (Column * Channels + 1))) = Transparent_Green
                             and then Natural
                               (Current
                                  (Ada.Streams.Stream_Element_Offset
                                     (Column * Channels + 2))) = Transparent_Blue
                           then 0
                           else 255)));
               end loop;

               Previous := Current;
            end;
         end loop;
         Free_Stream_Element_Array (Compressed);
      exception
         when others =>
            Free_Stream_Element_Array (Compressed);
            raise;
      end;

      Write_Pixels_As_Ppm (Target_Path, Size, Pixels, Width, Height);
      return True;
   exception
      when others =>
         if File /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (File);
         end if;
         return False;
   end Try_Write_Decoded_Png_Thumbnail;

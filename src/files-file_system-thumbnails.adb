with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Directories;
with Ada.Characters;
with Ada.Streams;
with System;
with System.Address_To_Access_Conversions;
with Files.File_Types;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Ada.Characters.Handling;
with Zlib;

separate (Files.File_System)
package body Thumbnails is
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Directories.File_Kind;

   use type Files.Types.Item_Kind;
   use type System.Address;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   function Gdk_Pixbuf_New_From_File_At_Size
     (Filename : Interfaces.C.Strings.chars_ptr;
      Width    : C_Int;
      Height   : C_Int;
      Error    : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_new_from_file_at_size";

   function Gdk_Pixbuf_Get_Width
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_width";

   function Gdk_Pixbuf_Get_Height
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_height";

   function Gdk_Pixbuf_Get_N_Channels
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_n_channels";

   function Gdk_Pixbuf_Get_Rowstride
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_rowstride";

   function Gdk_Pixbuf_Get_Pixels
     (Pixbuf : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_pixels";

   procedure G_Object_Unref
     (Object : System.Address)
   with Import, Convention => C, External_Name => "g_object_unref";

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   function Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is
   begin
      if Pointer /= Interfaces.C.Strings.Null_Ptr then
         begin
            Interfaces.C.Strings.Free (Pointer);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Free;

   function Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Name : constant String := Ada.Directories.Simple_Name (Source_Path);
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' and then Index < Name'Last then
            return Files.Types.To_Lower (Name (Index + 1 .. Name'Last));
         end if;
      end loop;

      return "file";
   exception
      when others =>
         return "file";
   end Thumbnail_Extension;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Extension : constant String := Thumbnail_Extension (Source_Path);
      Result    : Unbounded_String;
   begin
      for Value of Extension loop
         if Ada.Characters.Handling.Is_Alphanumeric (Value) then
            Append (Result, Value);
         else
            Append (Result, '_');
         end if;
      end loop;

      if Length (Result) = 0 then
         return "file";
      end if;

      return To_String (Result);
   end Sanitized_Thumbnail_Extension;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Result  : Long_Long_Integer := 0;
   begin
      for Value of Source_Path loop
         Result := (Result * 33 + Long_Long_Integer (Character'Pos (Value))) mod Modulus;
      end loop;

      return Natural (Result);
   end Thumbnail_Path_Checksum;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is
      Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
      Home      : constant String := Safe_Environment_Value ("HOME");
   begin
      if Xdg_Cache /= "" then
         return Join_Path (Join_Path (Xdg_Cache, "files"), "thumbnails");
      elsif Home /= "" then
         return Join_Path (Join_Path (Join_Path (Home, ".cache"), "files"), "thumbnails");
      else
         return Join_Path (Fallback_Directory, ".files-thumbnails");
      end if;
   end Default_Thumbnail_Cache_Directory;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is
   begin
      return
        Join_Path
          (Cache_Directory,
           "thumb_"
           & Sanitized_Thumbnail_Extension (Source_Path)
           & "_"
           & Image_No_Space (Size)
           & "_"
           & Image_No_Space (Thumbnail_Path_Checksum (Source_Path))
           & ".ppm");
   end Thumbnail_Path_For;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is
      Extension : constant String := Files.File_Types.Extension_Of (Name);
   begin
      if Kind = Files.Types.Directory_Item
        or else Kind = Files.Types.Symlink_Item
      then
         return False;
      end if;

      return Starts_With (Files.Types.To_Lower (Filetype), "image/")
        or else Files.Types.To_Lower (Icon_Id) = "image"
        or else Extension = "png"
        or else Extension = "jpg"
        or else Extension = "jpeg"
        or else Extension = "gif"
        or else Extension = "bmp"
        or else Extension = "webp"
        or else Extension = "tif"
        or else Extension = "tiff"
        or else Extension = "ppm";
   end Is_Image_Item;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Total  : Natural := 0;
   begin
      if Max_Bytes = 0 then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Total < Max_Bytes loop
         Stream_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            exit when Total >= Max_Bytes;
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Natural (Buffer (Index))));
            Total := Total + 1;
         end loop;
      end loop;

      Stream_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         Safe_Close (File);
         return Ada.Strings.Unbounded.To_String (Result);
   end Read_Preview_Text;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is
      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);
      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Pixbuf : System.Address := System.Null_Address;
      Result : Decoded_Image;
   begin
      Pixbuf :=
        Gdk_Pixbuf_New_From_File_At_Size
          (Filename => C_Path,
           Width    => C_Int (Max_Size),
           Height   => C_Int (Max_Size),
           Error    => System.Null_Address);
      Interfaces.C.Strings.Free (C_Path);

      if Pixbuf = System.Null_Address then
         return Result;
      end if;

      declare
         Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
         Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
         Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
         Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
         Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
         Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
           Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
      begin
         if Width = 0
           or else Height = 0
           or else Width > Max_Size
           or else Height > Max_Size
           or else Channels < 3
           or else Rowstride < Width * Channels
           or else Pixels_Address = System.Null_Address
           or else Raw = null
         then
            G_Object_Unref (Pixbuf);
            return Result;
         end if;

         --  Copy row-major RGBA (alpha from the source or opaque when absent),
         --  matching the byte layout the icon-atlas thumbnail rasterizer reads.
         for Row in 0 .. Height - 1 loop
            for Column in 0 .. Width - 1 loop
               declare
                  Offset : constant Natural := Row * Rowstride + Column * Channels;
               begin
                  Result.Pixels.Append (Raw.all (Offset));
                  Result.Pixels.Append (Raw.all (Offset + 1));
                  Result.Pixels.Append (Raw.all (Offset + 2));
                  Result.Pixels.Append (if Channels >= 4 then Raw.all (Offset + 3) else 255);
               end;
            end loop;
         end loop;

         G_Object_Unref (Pixbuf);
         Result.Available := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   exception
      when others =>
         Safe_Free (C_Path);
         if Pixbuf /= System.Null_Address then
            G_Object_Unref (Pixbuf);
         end if;
         return (Available => False, Width => 0, Height => 0,
                 Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Decode_Image_To_Pixels;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
   is
      File : Ada.Text_IO.File_Type;

      function Clamp_Channel (Value : Natural) return Natural is
      begin
         return Value mod 256;
      end Clamp_Channel;

      function File_Size_Signal return Natural is
      begin
         return Natural (Long_Long_Integer'Min (Long_Long_Integer (Ada.Directories.Size (Source_Path)), 65_535));
      exception
         when others =>
            return 0;
      end File_Size_Signal;

      --  Cap the input given to the pure-Ada PNG/PPM decoders, which read the
      --  whole file into memory before validating its magic bytes. A valid
      --  image within the 2048x2048 decode cap is at most a few MB, so 32 MiB is
      --  generous; a larger (or unreadable-size) file skips the slurping fast
      --  path and falls through to the streaming gdk-pixbuf loader, so a huge
      --  non-image named *.png can no longer be read into RAM on a directory
      --  browse (a memory/CPU denial of service).
      Max_Fast_Decode_Source_Bytes : constant Long_Long_Integer := 33_554_432;

      function Source_Fits_Fast_Decode return Boolean is
      begin
         return Long_Long_Integer (Ada.Directories.Size (Source_Path))
                  <= Max_Fast_Decode_Source_Bytes;
      exception
         when others =>
            return False;
      end Source_Fits_Fast_Decode;

      type Rgb_Pixel is record
         Red   : Natural := 0;
         Green : Natural := 0;
         Blue  : Natural := 0;
      end record;

      package Pixel_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Rgb_Pixel);

      package Thumbnail_Byte_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Ada.Streams.Stream_Element);

      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);

      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      function Byte_At
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural is
      begin
         if Index >= Natural (Data.Length) then
            return 0;
         end if;

         return Natural (Data.Element (Index));
      end Byte_At;

      function U32_BE_From
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural
      is
         use type Interfaces.Unsigned_32;
         Value : constant Interfaces.Unsigned_32 :=
           Interfaces.Unsigned_32 (Byte_At (Data, Index)) * 16#1000000#
           + Interfaces.Unsigned_32 (Byte_At (Data, Index + 1)) * 16#10000#
           + Interfaces.Unsigned_32 (Byte_At (Data, Index + 2)) * 16#100#
           + Interfaces.Unsigned_32 (Byte_At (Data, Index + 3));
      begin
         --  Compute in Unsigned_32 (modular, no overflow) and clamp: a crafted
         --  PNG length/dimension with the high bit set exceeds Natural'Last, and
         --  the old Natural arithmetic overflowed into a Constraint_Error.
         --  Callers reject the resulting too-large dimension anyway.
         return Natural (Interfaces.Unsigned_32'Min (Value, Interfaces.Unsigned_32 (Natural'Last)));
      end U32_BE_From;

      function Bytes_To_Stream_Array
        (Data : Thumbnail_Byte_Vectors.Vector)
         return Ada.Streams.Stream_Element_Array
      is
         Result : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Data.Length) - 1);
      begin
         for Index in 0 .. Natural (Data.Length) - 1 loop
            Result (Ada.Streams.Stream_Element_Offset (Index)) := Data.Element (Index);
         end loop;

         return Result;
      end Bytes_To_Stream_Array;

      procedure Write_Pixels_As_Ppm
        (Target_Path   : String;
         Pixels        : Pixel_Vectors.Vector;
         Source_Width  : Natural;
         Source_Height : Natural)
      is
         Output : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Target_Path);
         Ada.Text_IO.Put_Line (Output, "P3");
         Ada.Text_IO.Put_Line (Output, Image_No_Space (Size) & " " & Image_No_Space (Size));
         Ada.Text_IO.Put_Line (Output, "255");
         for Row in 0 .. Size - 1 loop
            for Column in 0 .. Size - 1 loop
               declare
                  Source_Row    : constant Natural := Row * Source_Height / Size;
                  Source_Column : constant Natural := Column * Source_Width / Size;
                  Source_Index  : constant Natural := Source_Row * Source_Width + Source_Column;
                  Pixel         : constant Rgb_Pixel := Pixels.Element (Source_Index);
               begin
                  Ada.Text_IO.Put
                    (Output,
                     Image_No_Space (Pixel.Red) & " "
                     & Image_No_Space (Pixel.Green) & " "
                     & Image_No_Space (Pixel.Blue));
                  if Column < Size - 1 then
                     Ada.Text_IO.Put (Output, " ");
                  end if;
               end;
            end loop;
            Ada.Text_IO.New_Line (Output);
         end loop;
         Ada.Text_IO.Close (Output);
      exception
         when others =>
            Safe_Close (Output);
            raise;
      end Write_Pixels_As_Ppm;

      function Try_Write_Decoded_P3_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         Input  : Ada.Text_IO.File_Type;
         Token  : Unbounded_String;
         Content : Unbounded_String;
         Scan_Index : Positive := 1;
         Pixels : Pixel_Vectors.Vector;
         Source_Width  : Natural := 0;
         Source_Height : Natural := 0;
         Max_Value     : Natural := 0;

         function Next_Token return Boolean is
            Value : Character;
         begin
            Token := Null_Unbounded_String;
            while Scan_Index <= Length (Content) loop
               Value := Element (Content, Scan_Index);
               Scan_Index := Scan_Index + 1;
               if Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
                  if Length (Token) > 0 then
                     return True;
                  end if;
               else
                  Append (Token, Value);
               end if;
            end loop;

            return Length (Token) > 0;
         end Next_Token;

         function Next_Natural
           (Value : out Natural)
            return Boolean is
         begin
            if not Next_Token then
               return False;
            end if;

            Value := Natural'Value (To_String (Token));
            return True;
         exception
            when others =>
               return False;
         end Next_Natural;

         function Scaled_Channel
           (Value : Natural)
            return Natural is
         begin
            if Max_Value = 0 then
               return 0;
            elsif Max_Value = 255 then
               return Natural'Min (Value, 255);
            end if;

            return Natural'Min ((Value * 255) / Max_Value, 255);
         end Scaled_Channel;
      begin
         Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Source_Path);
         while not Ada.Text_IO.End_Of_File (Input) loop
            declare
               Buffer  : String (1 .. 4096);
               Last    : Natural;
               Comment : Natural := 0;
            begin
               Ada.Text_IO.Get_Line (Input, Buffer, Last);
               for Index in 1 .. Last loop
                  if Buffer (Index) = '#' then
                     Comment := Index;
                     exit;
                  end if;
               end loop;

               if Last = 0 then
                  null;
               elsif Comment = 0 then
                  Append (Content, Buffer (1 .. Last));
               elsif Comment > 1 then
                  Append (Content, Buffer (1 .. Comment - 1));
               end if;
               Append (Content, ' ');
            end;
         end loop;
         Ada.Text_IO.Close (Input);

         if not Next_Token or else To_String (Token) /= "P3" then
            return False;
         end if;

         if not Next_Natural (Source_Width)
           or else not Next_Natural (Source_Height)
           or else not Next_Natural (Max_Value)
           or else Source_Width = 0
           or else Source_Height = 0
           or else Max_Value = 0
           or else Source_Width > 4096
           or else Source_Height > 4096
           or else Source_Width * Source_Height > 4_194_304
         then
            return False;
         end if;

         for Pixel_Index in 1 .. Source_Width * Source_Height loop
            declare
               Red   : Natural;
               Green : Natural;
               Blue  : Natural;
            begin
               if not Next_Natural (Red) or else not Next_Natural (Green) or else not Next_Natural (Blue) then
                  return False;
               end if;

               Pixels.Append
                 (New_Item =>
                    Rgb_Pixel'
                      (Red   => Scaled_Channel (Red),
                       Green => Scaled_Channel (Green),
                       Blue  => Scaled_Channel (Blue)));
            end;
         end loop;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Source_Width, Source_Height);
         return True;
      exception
         when others =>
            Safe_Close (Input);
            return False;
      end Try_Write_Decoded_P3_Thumbnail;

      function Try_Write_Decoded_Png_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Last   : Ada.Streams.Stream_Element_Offset;
         Bytes  : Thumbnail_Byte_Vectors.Vector;
         Idat   : Thumbnail_Byte_Vectors.Vector;
         Width  : Natural := 0;
         Height : Natural := 0;
         Bit_Depth  : Natural := 0;
         Color_Type : Natural := 0;
         Interlace  : Natural := 0;
         Position   : Natural := 8;
         Channels   : Natural := 0;
         Pixels     : Pixel_Vectors.Vector;

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
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Source_Path);
         while not Ada.Streams.Stream_IO.End_Of_File (File) loop
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            for Index in 1 .. Last loop
               Bytes.Append (Buffer (Index));
            end loop;
         end loop;
         Ada.Streams.Stream_IO.Close (File);

         if not Is_Png_Signature then
            return False;
         end if;

         while Position + 12 <= Natural (Bytes.Length) loop
            declare
               Length_Value : constant Natural := U32_BE_From (Bytes, Position);
               Kind         : constant String := Chunk_Type (Position + 4);
               Data_Start   : constant Natural := Position + 8;
               Data_Last    : constant Natural := Data_Start + Length_Value - 1;
            begin
               if Data_Start + Length_Value + 4 > Natural (Bytes.Length) then
                  return False;
               end if;

               if Kind = "IHDR" then
                  if Length_Value < 13 then
                     return False;
                  end if;
                  Width := U32_BE_From (Bytes, Data_Start);
                  Height := U32_BE_From (Bytes, Data_Start + 4);
                  Bit_Depth := Byte_At (Bytes, Data_Start + 8);
                  Color_Type := Byte_At (Bytes, Data_Start + 9);
                  Interlace := Byte_At (Bytes, Data_Start + 12);
               elsif Kind = "IDAT" then
                  if Length_Value > 0 then
                     for Index in Data_Start .. Data_Last loop
                        Idat.Append (Bytes.Element (Index));
                     end loop;
                  end if;
               elsif Kind = "IEND" then
                  exit;
               end if;

               Position := Data_Start + Length_Value + 4;
            end;
         end loop;

         if Width = 0
           or else Height = 0
           or else Width > 4096
           or else Height > 4096
           --  Guard against absurd dimensions (the inflated raster is bounded by
           --  RAM, not the stack -- see the heap-backed raster vector below).
           or else Width * Height > 4_194_304
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
            Compressed : constant Ada.Streams.Stream_Element_Array := Bytes_To_Stream_Array (Idat);
            Source     : Zlib.Byte_Array (0 .. Natural (Compressed'Length) - 1);
            --  The full inflated raster lives in a heap-backed vector, not a
            --  stack/secondary-stack array, so a large image cannot exhaust the
            --  stack -- it is bounded by RAM instead.
            Inflated   : Thumbnail_Byte_Vectors.Vector;
            Decode_Status : Zlib.Status_Code := Zlib.Ok;
            Previous   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
            Current    : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
         begin
            for I in Source'Range loop
               Source (I) :=
                 Zlib.Byte (Compressed (Compressed'First + Ada.Streams.Stream_Element_Offset (I)));
            end loop;
            --  Inflate the zlib-wrapped PNG IDAT stream with the pure-Ada zlib
            --  crate (no system libz dependency).
            declare
               use type Zlib.Status_Code;
               Raw_Inflated : constant Zlib.Byte_Array :=
                 Zlib.Inflate_With_Header (Source, Zlib.Zlib_Header, Decode_Status);
            begin
               if Decode_Status /= Zlib.Ok or else Raw_Inflated'Length < Needed then
                  return False;
               end if;
               Inflated.Reserve_Capacity (Ada.Containers.Count_Type (Needed));
               for I in 0 .. Needed - 1 loop
                  Inflated.Append
                    (Ada.Streams.Stream_Element (Raw_Inflated (Raw_Inflated'First + I)));
               end loop;
            end;

            for Row in 0 .. Height - 1 loop
               declare
                  Filter : constant Natural := Byte_At (Inflated, Row * (Row_Stride + 1));
                  Base   : constant Natural := Row * (Row_Stride + 1) + 1;
               begin
                  if Filter > 4 then
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
                       (Rgb_Pixel'
                          (Red   =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels))),
                           Green =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 1))),
                           Blue  =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 2)))));
                  end loop;

                  Previous := Current;
               end;
            end loop;
         end;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Width, Height);
         return True;
      exception
         when others =>
            Safe_Close (File);
            return False;
      end Try_Write_Decoded_Png_Thumbnail;

      function Try_Write_Gdk_Pixbuf_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Source_Path);
         Pixbuf : System.Address := System.Null_Address;
      begin
         Pixbuf :=
           Gdk_Pixbuf_New_From_File_At_Size
             (Filename => C_Path,
              Width    => C_Int (Size),
              Height   => C_Int (Size),
              Error    => System.Null_Address);
         Interfaces.C.Strings.Free (C_Path);

         if Pixbuf = System.Null_Address then
            return False;
         end if;

         declare
            Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
            Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
            Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
            Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
            Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
            Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
              Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
            Decoded   : Pixel_Vectors.Vector;
         begin
            if Width = 0
              or else Height = 0
              or else Width > 4096
              or else Height > 4096
              or else Channels < 3
              or else Rowstride < Width * Channels
              or else Pixels_Address = System.Null_Address
              or else Raw = null
            then
               G_Object_Unref (Pixbuf);
               return False;
            end if;

            for Row in 0 .. Height - 1 loop
               for Column in 0 .. Width - 1 loop
                  declare
                     Offset : constant Natural := Row * Rowstride + Column * Channels;
                  begin
                     Decoded.Append
                       (Rgb_Pixel'
                          (Red   => Natural (Raw.all (Offset)),
                           Green => Natural (Raw.all (Offset + 1)),
                           Blue  => Natural (Raw.all (Offset + 2))));
                  end;
               end loop;
            end loop;

            G_Object_Unref (Pixbuf);
            Pixbuf := System.Null_Address;
            --  Null the handle before any further work: Write_Pixels_As_Ppm can
            --  raise, and the exception handler unrefs Pixbuf when non-null.
            Write_Pixels_As_Ppm (Target_Path, Decoded, Width, Height);
            return True;
         end;
      exception
         when others =>
            Safe_Free (C_Path);
            if Pixbuf /= System.Null_Address then
               G_Object_Unref (Pixbuf);
            end if;
            return False;
      end Try_Write_Gdk_Pixbuf_Thumbnail;

      Checksum  : Natural := 0;
      Size_Bias : Natural := 0;
      Target    : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Source_Path) then
         return
           (Status         => Thumbnail_Source_Missing,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.source_missing"));
      elsif Ada.Directories.Kind (Source_Path) /= Ada.Directories.Ordinary_File then
         return
           (Status         => Thumbnail_Unsupported,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.unsupported"));
      end if;

      Ada.Directories.Create_Path (Cache_Directory);
      Target := To_Unbounded_String (Thumbnail_Path_For (Source_Path, Cache_Directory, Size));
      if (Source_Fits_Fast_Decode
          and then (Try_Write_Decoded_Png_Thumbnail (To_String (Target))
                    or else Try_Write_Decoded_P3_Thumbnail (To_String (Target))))
        or else Try_Write_Gdk_Pixbuf_Thumbnail (To_String (Target))
      then
         return
           (Status         => Thumbnail_Generated,
            Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => Null_Unbounded_String);
      end if;

      Checksum := Thumbnail_Path_Checksum (Source_Path);
      Size_Bias := File_Size_Signal;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Target));
      Ada.Text_IO.Put_Line (File, "P3");
      Ada.Text_IO.Put_Line (File, Image_No_Space (Size) & " " & Image_No_Space (Size));
      Ada.Text_IO.Put_Line (File, "255");
      for Row in 0 .. Size - 1 loop
         for Column in 0 .. Size - 1 loop
            declare
               Cell   : constant Natural := Natural'Max (1, Size / 8);
               Stripe : constant Natural := (Row / Cell + Column / Cell) mod 2;
               Red    : constant Natural := Clamp_Channel (Checksum + Row * 5 + Size_Bias / 7 + Stripe * 28);
               Green  : constant Natural := Clamp_Channel (Checksum / 257 + Column * 7 + Size_Bias / 11);
               Blue   : constant Natural := Clamp_Channel (Checksum / 65_521 + Row + Column * 3 + Size_Bias / 13);
            begin
               Ada.Text_IO.Put
                 (File,
                  Image_No_Space (Red) & " "
                  & Image_No_Space (Green) & " "
                  & Image_No_Space (Blue));
               if Column < Size - 1 then
                  Ada.Text_IO.Put (File, " ");
               end if;
            end;
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);

      return
        (Status         => Thumbnail_Generated,
         Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
         Thumbnail_Path => Target,
         Width          => Size,
         Height         => Size,
         Error_Key      => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         return
           (Status         => Thumbnail_Failed,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.failed"));
   end Generate_Thumbnail;

end Thumbnails;

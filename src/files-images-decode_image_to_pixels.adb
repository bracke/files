separate (Files.Images)
function Decode_Image_To_Pixels
  (Path     : String;
   Max_Size : Positive)
   return Decoded_Image
is
   type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
   pragma Convention (C, Gdk_Pixel_Array);
   package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
   use type Gdk_Pixel_Pointers.Object_Pointer;

   use type GNAT.OS_Lib.File_Descriptor;
   Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Loader     : System.Address := System.Null_Address;
   Loader_Was_Closed : Boolean := False;
   Signal_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
   Requested_Size : aliased C_Int := C_Int (Max_Size);
   Buffer     : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
   Bytes_Read : Integer;
   Total      : Natural := 0;
   Result     : Decoded_Image;

   --  Whether a declared extent is one a file decode accepts.
   function Within_Source_Bounds (Width, Height : Natural) return Boolean is
     (Width > 0 and then Height > 0
      and then Width <= Max_File_Source_Side and then Height <= Max_File_Source_Side
      and then Width <= Max_File_Source_Pixels / Height);

   --  gdk-pixbuf allocates the full source while consuming the stream, before
   --  the post-decode checks run: refuse a file whose header declares more
   --  than the bounds, as Decode_Image_Bytes does for bytes in memory. Head
   --  is the file's first bytes. A format no loader recognizes is left to
   --  the loader to refuse.
   function Declared_Extent_Allowed (Head : Ada.Streams.Stream_Element_Array) return Boolean is
      Width, Height : Natural;
   begin
      if PNG_Header (Head, Width, Height) then
         return Image_Bytes_Extent (Head, Width, Height) and then Within_Source_Bounds (Width, Height);
      end if;
      declare
         Name        : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
         Info_Width  : aliased C_Int := 0;
         Info_Height : aliased C_Int := 0;
         Format      : constant System.Address :=
           Gdk_Pixbuf_Get_File_Info (Name, Info_Width'Access, Info_Height'Access);
      begin
         Safe_Free (Name);
         if Format = System.Null_Address or else Info_Width <= 0 or else Info_Height <= 0 then
            return True;
         end if;
         return Within_Source_Bounds (Natural (Info_Width), Natural (Info_Height));
      end;
   end Declared_Extent_Allowed;

   procedure Clean is
      Ignored : Interfaces.C.int;
      pragma Unreferenced (Ignored);
   begin
      Safe_Free (Signal_Name);
      if Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Descriptor);
         Descriptor := GNAT.OS_Lib.Invalid_FD;
      end if;
      if Loader /= System.Null_Address then
         if not Loader_Was_Closed then
            Ignored := Loader_Close (Loader, System.Null_Address);
         end if;
         G_Object_Unref (Loader);
         Loader := System.Null_Address;
      end if;
   end Clean;
begin
   if Max_Size > Max_Decoded_Side then
      return Result;
   end if;

   Descriptor := Files.Fs_Primitives.Open_Regular_Read (Path);
   if Descriptor = GNAT.OS_Lib.Invalid_FD then
      return Result;
   end if;
   --  The first block is read before the loader exists, so its header can
   --  refuse an oversized image; the loop below feeds it to the loader first.
   Bytes_Read := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, Integer (Buffer'Length));
   if Bytes_Read < 0
     or else not Declared_Extent_Allowed
       (Buffer (Buffer'First .. Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1))
   then
      Clean;
      return Result;
   end if;
   Loader := Loader_New;
   if Loader = System.Null_Address then
      Clean;
      return Result;
   end if;
   Signal_Name := Interfaces.C.Strings.New_String ("size-prepared");
   if Signal_Connect_Data
     (Loader, Signal_Name, Loader_Size_Prepared'Address,
      Requested_Size'Address, System.Null_Address, 0) = 0
   then
      Clean;
      return Result;
   end if;
   Safe_Free (Signal_Name);

   loop
      --  Until something was fed, Buffer still holds the first block.
      if Total > 0 then
         Bytes_Read := GNAT.OS_Lib.Read
           (Descriptor, Buffer'Address, Integer (Buffer'Length));
      end if;
      if Bytes_Read < 0
        or else Bytes_Read > Integer (Max_Decode_Source_Bytes - Total)
      then
         Clean;
         return Result;
      end if;
      exit when Bytes_Read = 0;
      Total := Total + Bytes_Read;
      if Loader_Write
        (Loader, Buffer (Buffer'First)'Address,
         Interfaces.C.size_t (Bytes_Read), System.Null_Address) = 0
      then
         Clean;
         return Result;
      end if;
   end loop;
   GNAT.OS_Lib.Close (Descriptor);
   Descriptor := GNAT.OS_Lib.Invalid_FD;

   if Loader_Close (Loader, System.Null_Address) = 0 then
      Loader_Was_Closed := True;
      Clean;
      return Result;
   end if;
   Loader_Was_Closed := True;

   declare
      Pixbuf    : constant System.Address := Loader_Get_Pixbuf (Loader);
   begin
      if Pixbuf = System.Null_Address then
         Clean;
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
           or else Channels not in 3 .. 4
           or else Rowstride < Width * Channels
           or else Rowstride > Gdk_Pixel_Array'Length / Height
           or else Pixels_Address = System.Null_Address
           or else Raw = null
         then
            Clean;
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
                  Result.Pixels.Append (if Channels = 4 then Raw.all (Offset + 3) else 255);
               end;
            end loop;
         end loop;

         Clean;
         Result.Available := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Images");
      Clean;
      return (Available => False, Width => 0, Height => 0,
              Pixels => Files.Types.Byte_Vectors.Empty_Vector);
end Decode_Image_To_Pixels;

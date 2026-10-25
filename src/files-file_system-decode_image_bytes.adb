separate (Files.File_System)
function Decode_Image_Bytes
  (Data : Ada.Streams.Stream_Element_Array)
   return Decoded_Image
is
   type Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
   pragma Convention (C, Pixel_Array);
   package Pixel_Pointers is new System.Address_To_Access_Conversions (Pixel_Array);
   use type Pixel_Pointers.Object_Pointer;

   Result : Decoded_Image;
   Loader : System.Address := System.Null_Address;
   Declared_Width, Declared_Height : Natural := 0;

   procedure Release_Loader is
   begin
      if Loader /= System.Null_Address then
         G_Object_Unref (Loader);
         Loader := System.Null_Address;
      end if;
   end Release_Loader;
begin
   --  gdk-pixbuf allocates while consuming the stream. Validate the PNG's
   --  declared extent first so a compressed image cannot force an
   --  unbounded allocation before the post-decode checks run.
   if not Image_Bytes_Extent (Data, Declared_Width, Declared_Height) then
      return Result;
   end if;

   Loader := Loader_New;

   if Loader = System.Null_Address then
      return Result;
   end if;

   if Loader_Write
        (Loader, Data (Data'First)'Address,
         Interfaces.C.size_t (Data'Length), System.Null_Address) = 0
   then
      --  Close before giving up: the loader owns a partial image otherwise.
      declare
         Ignored : constant Interfaces.C.int := Loader_Close (Loader, System.Null_Address);
         pragma Unreferenced (Ignored);
      begin
         Release_Loader;
         return Result;
      end;
   end if;

   declare
      Closed : constant Interfaces.C.int := Loader_Close (Loader, System.Null_Address);

      Pixbuf : constant System.Address := Loader_Get_Pixbuf (Loader);
   begin
      if Closed = 0 or else Pixbuf = System.Null_Address then
         Release_Loader;
         return Result;
      end if;

      declare
         Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
         Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
         Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
         Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
         Address   : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
         Raw       : constant Pixel_Pointers.Object_Pointer :=
           Pixel_Pointers.To_Pointer (Address);
      begin
         if Width /= Declared_Width
           or else Height /= Declared_Height
           or else Channels not in 3 .. 4
           or else Rowstride < Width * Channels
           or else Rowstride > Pixel_Array'Length / Height
           or else Address = System.Null_Address
           or else Raw = null
         then
            Release_Loader;
            return Result;
         end if;

         Result.Width := Width;
         Result.Height := Height;
         Result.Pixels.Reserve_Capacity
           (Ada.Containers.Count_Type (Width * Height * 4));

         for Row in 0 .. Height - 1 loop
            for Column in 0 .. Width - 1 loop
               declare
                  At_Source : constant Natural := Row * Rowstride + Column * Channels;
               begin
                  Result.Pixels.Append (Raw.all (At_Source));
                  Result.Pixels.Append (Raw.all (At_Source + 1));
                  Result.Pixels.Append (Raw.all (At_Source + 2));

                  --  Three channels means no alpha in the source; an emoji
                  --  without alpha is opaque, not invisible.
                  Result.Pixels.Append
                    (if Channels >= 4 then Raw.all (At_Source + 3) else 255);
               end;
            end loop;
         end loop;

         Result.Available := True;
      end;

      Release_Loader;
   end;

   return Result;
exception
   when others =>
      Release_Loader;

      return (Available => False, Width => 0, Height => 0,
              Pixels => Files.Types.Byte_Vectors.Empty_Vector);
end Decode_Image_Bytes;

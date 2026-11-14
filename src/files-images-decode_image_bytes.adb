separate (Files.Images)
function Decode_Image_Bytes
  (Data : Ada.Streams.Stream_Element_Array)
   return Decoded_Image
is
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

      --  The image gdk-pixbuf made must be the one the header declared.
      if Natural (Gdk_Pixbuf_Get_Width (Pixbuf)) = Declared_Width
        and then Natural (Gdk_Pixbuf_Get_Height (Pixbuf)) = Declared_Height
      then
         Copy_Pixbuf_Rgba (Pixbuf, Result);
      end if;

      Release_Loader;
   end;

   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Images");
      Release_Loader;

      return (Available => False, Width => 0, Height => 0,
              Pixels => Files.Types.Byte_Vectors.Empty_Vector, Extent_Refused => False);
end Decode_Image_Bytes;

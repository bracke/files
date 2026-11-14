separate (Files.Images)
function Decode_Image_To_Pixels
  (Path     : String;
   Max_Size : Positive)
   return Decoded_Image
is
   use type GNAT.OS_Lib.File_Descriptor;
   Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Loader     : System.Address := System.Null_Address;
   Loader_Was_Closed : Boolean := False;
   Signal_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
   Requested_Size : aliased C_Int := C_Int (Max_Size);
   Buffer     : Ada.Streams.Stream_Element_Array (1 .. Files.Types.IO_Chunk_Bytes);
   Bytes_Read : Integer;
   Total      : Natural := 0;
   Result     : Decoded_Image;

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
   if Bytes_Read < 0 then
      Clean;
      return Result;
   elsif not Declared_Extent_Allowed
     (Path, Buffer (Buffer'First .. Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1))
   then
      Clean;
      Result.Extent_Refused := True;
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
      --  Within the size asked for; Copy_Pixbuf_Rgba checks the rest.
      if Natural (Gdk_Pixbuf_Get_Width (Pixbuf)) <= Max_Size
        and then Natural (Gdk_Pixbuf_Get_Height (Pixbuf)) <= Max_Size
      then
         Copy_Pixbuf_Rgba (Pixbuf, Result);
      end if;
      Clean;
      return Result;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Images");
      Clean;
      return (Available => False, Width => 0, Height => 0,
              Pixels => Files.Types.Byte_Vectors.Empty_Vector, Extent_Refused => False);
end Decode_Image_To_Pixels;

separate (Files.File_System)
function Read_Bounded_Regular_File
  (Path : String; Max_Bytes : Natural;
   Success, Complete : out Boolean) return String
is
   use type GNAT.OS_Lib.File_Descriptor;
   Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Result     : Ada.Strings.Unbounded.Unbounded_String;
   Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Bytes_Read : Integer;
   Total      : Natural := 0;
begin
   Success := False;
   Complete := False;

   Descriptor := Files.Fs_Primitives.Open_Regular_Read (Path);
   if Descriptor = GNAT.OS_Lib.Invalid_FD then
      return "";
   end if;

   while Total < Max_Bytes loop
      Bytes_Read := GNAT.OS_Lib.Read
        (Descriptor,
         Buffer'Address,
         Integer'Min (Integer (Buffer'Length), Max_Bytes - Total));
      if Bytes_Read < 0 then
         raise Ada.Directories.Use_Error;
      end if;
      if Bytes_Read = 0 then
         Complete := True;
         exit;
      end if;
      for Index in Buffer'First
        .. Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1
      loop
         Ada.Strings.Unbounded.Append
           (Result, Character'Val (Natural (Buffer (Index))));
         Total := Total + 1;
      end loop;
   end loop;

   if not Complete then
      --  Reaching the cap is not evidence that the complete file was read.
      --  Probe one byte so strict parsers cannot accept a truncated prefix
      --  after a file grows or is replaced between the size check and open.
      Bytes_Read := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, 1);
      if Bytes_Read < 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Complete := Bytes_Read = 0;
   end if;

   GNAT.OS_Lib.Close (Descriptor);
   Descriptor := GNAT.OS_Lib.Invalid_FD;
   Success := True;
   return Ada.Strings.Unbounded.To_String (Result);
exception
   when others =>
      if Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Descriptor);
      end if;
      Complete := False;
      return Ada.Strings.Unbounded.To_String (Result);
end Read_Bounded_Regular_File;

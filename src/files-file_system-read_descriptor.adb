separate (Files.File_System)
procedure Read_Descriptor
  (File   : GNAT.OS_Lib.File_Descriptor;
   Buffer : out Ada.Streams.Stream_Element_Array;
   Last   : out Ada.Streams.Stream_Element_Offset)
is
   Bytes_Read : constant Integer :=
     GNAT.OS_Lib.Read (File, Buffer'Address, Integer (Buffer'Length));
begin
   if Bytes_Read < 0 then
      raise Ada.Directories.Use_Error;
   end if;
   Last := Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1;
end Read_Descriptor;

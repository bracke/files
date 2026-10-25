separate (Files.File_System)
function Bytes_To_Stream_Array
  (Data : Thumbnail_Byte_Vectors.Vector)
   return Stream_Element_Array_Access
is
   Result : Stream_Element_Array_Access :=
     new Ada.Streams.Stream_Element_Array
       (0 .. Ada.Streams.Stream_Element_Offset (Data.Length) - 1);
begin
   for Index in 0 .. Natural (Data.Length) - 1 loop
      Result (Ada.Streams.Stream_Element_Offset (Index)) :=
        Data.Element (Index);
   end loop;

   return Result;
exception
   when others =>
      Free_Stream_Element_Array (Result);
      raise;
end Bytes_To_Stream_Array;

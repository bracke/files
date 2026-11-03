separate (Files.File_System.Thumbnails)
function U32_BE_From
  (Data  : Thumbnail_Byte_Vectors.Vector;
   Index : Natural)
   return Natural
is
   Word : constant Ada.Streams.Stream_Element_Array (0 .. 3) :=
     [for Offset in Ada.Streams.Stream_Element_Offset range 0 .. 3 =>
        Ada.Streams.Stream_Element (Byte_At (Data, Index + Natural (Offset)))];
begin
   return Files.Images.U32_BE (Word, 0);
end U32_BE_From;

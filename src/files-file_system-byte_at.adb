separate (Files.File_System)
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

separate (Files.File_System.Thumbnails)
function Thumbnail_Path_Checksum
  (Source_Path : String)
   return Natural
is
   Result : Natural := 0;
begin
   for Value of Source_Path loop
      Result := Mix_Checksum (Result, Long_Long_Integer (Character'Pos (Value)), Step => 33);
   end loop;

   return Result;
end Thumbnail_Path_Checksum;

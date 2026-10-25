separate (Files.File_System)
function File_Size_Signal (Source_Path : String) return Natural is
begin
   return Natural (Long_Long_Integer'Min (Long_Long_Integer (Ada.Directories.Size (Source_Path)), 65_535));
exception
   when others =>
      return 0;
end File_Size_Signal;

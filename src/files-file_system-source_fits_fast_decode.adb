separate (Files.File_System)
function Source_Fits_Fast_Decode (Source_Path : String) return Boolean is
begin
   return Long_Long_Integer (Ada.Directories.Size (Source_Path))
            <= Long_Long_Integer (Max_Fast_Decode_Source_Bytes);
exception
   when others =>
      return False;
end Source_Fits_Fast_Decode;

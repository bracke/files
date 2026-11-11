separate (Files.File_System.Thumbnails)
function Source_Fits_Fast_Decode (Source_Path : String) return Boolean is
begin
   return Long_Long_Integer (Files.Fs_Primitives.Size (Source_Path))
            <= Long_Long_Integer (Max_Fast_Decode_Source_Bytes);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      return False;
end Source_Fits_Fast_Decode;

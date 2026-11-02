separate (Files.File_System.Thumbnails)
function Clamp_Channel (Value : Natural) return Natural is
begin
   return Value mod 256;
end Clamp_Channel;

separate (Files.File_System)
function Clamp_Channel (Value : Natural) return Natural is
begin
   return Value mod 256;
end Clamp_Channel;

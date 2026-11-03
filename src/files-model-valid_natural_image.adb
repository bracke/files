separate (Files.Model)
function Valid_Natural_Image (Value : UString) return Boolean is
   Mode : Natural;
begin
   return Files.Undo_Payloads.Parse_Mode (To_String (Value), Mode);
end Valid_Natural_Image;

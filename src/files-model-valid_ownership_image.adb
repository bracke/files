separate (Files.Model)
function Valid_Ownership_Image (Value : UString) return Boolean is
   Parsed : Files.Undo_Payloads.Ownership;
begin
   return Files.Undo_Payloads.Parse_Ownership (To_String (Value), Parsed);
end Valid_Ownership_Image;

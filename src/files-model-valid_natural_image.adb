separate (Files.Model)
function Valid_Natural_Image (Value : UString) return Boolean is
   Text : constant String := Ada.Strings.Fixed.Trim (To_String (Value), Ada.Strings.Both);
   Parsed : Natural;
   pragma Unreferenced (Parsed);
begin
   if Text = "" then
      return False;
   end if;
   Parsed := Natural'Value (Text);
   return True;
exception
   when others =>
      return False;
end Valid_Natural_Image;

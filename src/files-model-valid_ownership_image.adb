separate (Files.Model)
function Valid_Ownership_Image (Value : UString) return Boolean is
   Text       : constant String := To_String (Value);
   First_Nul  : Natural := 0;
   Second_Nul : Natural := 0;
begin
   if Text = "" then
      return False;
   end if;
   for Index in Text'Range loop
      if Text (Index) = ASCII.NUL then
         First_Nul := Index;
         exit;
      end if;
   end loop;
   if First_Nul /= 0 then
      for Index in First_Nul + 1 .. Text'Last loop
         if Text (Index) = ASCII.NUL then
            Second_Nul := Index;
            exit;
         end if;
      end loop;
      if Second_Nul = 0 then
         return False;
      end if;
      for Index in Second_Nul + 1 .. Text'Last loop
         if Text (Index) = ASCII.NUL then
            return False;
         end if;
      end loop;
   end if;
   declare
      Numeric_Last : constant Natural :=
        (if First_Nul = 0 then Text'Last else First_Nul - 1);
      Numeric : constant String := Ada.Strings.Fixed.Trim
        (Text (Text'First .. Numeric_Last), Ada.Strings.Both);
      Space : constant Natural := Ada.Strings.Fixed.Index (Numeric, " ");
      User, Group : Natural;
      pragma Unreferenced (User, Group);
   begin
      if Space = 0 then
         return False;
      end if;
      User := Natural'Value (Numeric (Numeric'First .. Space - 1));
      Group := Natural'Value (Numeric (Space + 1 .. Numeric'Last));
      return True;
   end;
exception
   when others =>
      return False;
end Valid_Ownership_Image;

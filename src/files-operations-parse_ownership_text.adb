separate (Files.Operations)
function Parse_Ownership_Text
  (Text : String; User_Id, Group_Id : out Natural;
   User_Name, Group_Name : out Files.Types.UString) return Boolean
is
   First_Nul  : Natural := 0;
   Second_Nul : Natural := 0;
begin
   User_Id := 0;
   Group_Id := 0;
   User_Name := Null_Unbounded_String;
   Group_Name := Null_Unbounded_String;
   if Text = "" then
      return False;
   end if;
   for Index in Text'Range loop
      if Text (Index) = ASCII.NUL then
         First_Nul := Index;
         exit;
      end if;
   end loop;
   declare
      Numeric_Last : constant Natural :=
        (if First_Nul = 0 then Text'Last else First_Nul - 1);
      Space : constant Natural := Ada.Strings.Fixed.Index
        (Text (Text'First .. Numeric_Last), " ");
   begin
      if Space = 0 then
         return False;
      end if;
      User_Id := Natural'Value (Text (Text'First .. Space - 1));
      Group_Id := Natural'Value (Text (Space + 1 .. Numeric_Last));
   end;
   if First_Nul = 0 then
      return True;
   end if;
   for Index in First_Nul + 1 .. Text'Last loop
      if Text (Index) = ASCII.NUL then
         Second_Nul := Index;
         exit;
      end if;
   end loop;
   if Second_Nul = 0 then
      return False;
   end if;
   User_Name := To_Unbounded_String
     (Text (First_Nul + 1 .. Second_Nul - 1));
   Group_Name := To_Unbounded_String
     (Text (Second_Nul + 1 .. Text'Last));
   return True;
exception
   when others =>
      User_Id := 0;
      Group_Id := 0;
      User_Name := Null_Unbounded_String;
      Group_Name := Null_Unbounded_String;
      return False;
end Parse_Ownership_Text;

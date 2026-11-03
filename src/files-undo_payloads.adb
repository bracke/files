with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Files.Undo_Payloads is
   use Ada.Strings.Unbounded;

   function Ownership_Text (Value : Ownership) return String is
     (Files.Types.Account_Image (Value.User_Id) & " " & Files.Types.Account_Image (Value.Group_Id)
      & ASCII.NUL & To_String (Value.User_Name)
      & ASCII.NUL & To_String (Value.Group_Name));

   function Parse_Ownership (Text : String; Value : out Ownership) return Boolean is
      First_Nul  : constant Natural := Ada.Strings.Fixed.Index (Text, [1 => ASCII.NUL]);
      Second_Nul : constant Natural :=
        (if First_Nul = 0 then 0 else Ada.Strings.Fixed.Index (Text (First_Nul + 1 .. Text'Last), [1 => ASCII.NUL]));
      Numeric    : constant String :=
        Ada.Strings.Fixed.Trim
          (Text (Text'First .. (if First_Nul = 0 then Text'Last else First_Nul - 1)), Ada.Strings.Both);
      Space      : constant Natural := Ada.Strings.Fixed.Index (Numeric, " ");
   begin
      Value := (others => <>);
      --  The names come as a pair, and neither holds a NUL.
      if Space = 0
        or else (First_Nul /= 0 and then Second_Nul = 0)
        or else (Second_Nul /= 0
                 and then Ada.Strings.Fixed.Index (Text (Second_Nul + 1 .. Text'Last), [1 => ASCII.NUL]) /= 0)
      then
         return False;
      end if;
      declare
         User  : constant Files.Types.Parsed_Account_Id :=
           Files.Types.Parse_Account_Id (Numeric (Numeric'First .. Space - 1));
         Group : constant Files.Types.Parsed_Account_Id :=
           Files.Types.Parse_Account_Id (Numeric (Space + 1 .. Numeric'Last));
      begin
         if not User.Valid or else not Group.Valid then
            return False;
         end if;
         Value.User_Id := User.Id;
         Value.Group_Id := Group.Id;
      end;
      if First_Nul /= 0 then
         Value.User_Name := To_Unbounded_String (Text (First_Nul + 1 .. Second_Nul - 1));
         Value.Group_Name := To_Unbounded_String (Text (Second_Nul + 1 .. Text'Last));
      end if;
      return True;
   exception
      when others =>
         Value := (others => <>);
         return False;
   end Parse_Ownership;

   function Mode_Text (Mode : Natural) return String is (Natural'Image (Mode));

   function Parse_Mode (Text : String; Mode : out Natural) return Boolean is
      Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   begin
      Mode := 0;
      if Clean = "" or else (for some C of Clean => C not in '0' .. '9') then
         return False;
      end if;
      Mode := Natural'Value (Clean);
      return True;
   exception
      when others =>
         Mode := 0;
         return False;
   end Parse_Mode;

   function Is_Mode_Text (Text : String) return Boolean is
      Mode : Natural;
   begin
      return Parse_Mode (Text, Mode);
   end Is_Mode_Text;

   function Is_Ownership_Text (Text : String) return Boolean is
      Value : Ownership;
   begin
      return Parse_Ownership (Text, Value);
   end Is_Ownership_Text;

end Files.Undo_Payloads;

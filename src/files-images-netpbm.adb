package body Files.Images.Netpbm is

   function Is_Blank (C : Character) return Boolean is (C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

   procedure Next_Field
     (Text    : String;
      At_Byte : in out Positive;
      First   : out Positive;
      Last    : out Natural) is
   begin
      loop
         while At_Byte <= Text'Last and then Is_Blank (Text (At_Byte)) loop
            At_Byte := At_Byte + 1;
         end loop;
         exit when At_Byte > Text'Last or else Text (At_Byte) /= '#';
         while At_Byte <= Text'Last and then Text (At_Byte) not in ASCII.LF | ASCII.CR loop
            At_Byte := At_Byte + 1;
         end loop;
      end loop;
      First := At_Byte;
      while At_Byte <= Text'Last and then not Is_Blank (Text (At_Byte)) and then Text (At_Byte) /= '#' loop
         At_Byte := At_Byte + 1;
      end loop;
      Last := At_Byte - 1;
   end Next_Field;

   function Natural_Of (Field : String; Value : out Natural) return Boolean is
   begin
      Value := 0;
      if Field = "" then
         return False;
      end if;
      for C of Field loop
         if C not in '0' .. '9'
           or else Value > (Natural'Last - (Character'Pos (C) - Character'Pos ('0'))) / 10
         then
            return False;
         end if;
         Value := Value * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;
      return True;
   end Natural_Of;

   function Channel (Value : Natural; Max_Value : Natural) return Interfaces.Unsigned_8 is
     (if Max_Value = 0 then 0
      elsif Max_Value = 255 then Interfaces.Unsigned_8 (Natural'Min (Value, 255))
      else Interfaces.Unsigned_8 (Natural'Min ((Value * 255) / Max_Value, 255)));

end Files.Images.Netpbm;

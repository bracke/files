--  Hexadecimal digits, as the program's on-disk and diagnostic texts write
--  and read them: one alphabet per case and the value of a digit.
package Files.Hex_Text
  with Pure
is
   --  The digits 0-9 then a-f, indexed from 1 by value + 1.
   Lower_Digits : constant String := "0123456789abcdef";

   --  The digits 0-9 then A-F, indexed from 1 by value + 1.
   Upper_Digits : constant String := "0123456789ABCDEF";

   --  @param Item A character that may be a hex digit.
   --  @return Its value 0 .. 15 (either case), or -1 when it is not one.
   function Digit_Value (Item : Character) return Integer is
     (case Item is
         when '0' .. '9' => Character'Pos (Item) - Character'Pos ('0'),
         when 'a' .. 'f' => Character'Pos (Item) - Character'Pos ('a') + 10,
         when 'A' .. 'F' => Character'Pos (Item) - Character'Pos ('A') + 10,
         when others => -1);

   --  @param Code A byte value.
   --  @return Its two lower-case hex digits.
   function Byte_Lower (Code : Natural) return String is
     ([Lower_Digits (Code / 16 mod 16 + 1), Lower_Digits (Code mod 16 + 1)]);

   --  @param Code A byte value.
   --  @return Its two upper-case hex digits.
   function Byte_Upper (Code : Natural) return String is
     ([Upper_Digits (Code / 16 mod 16 + 1), Upper_Digits (Code mod 16 + 1)]);
end Files.Hex_Text;

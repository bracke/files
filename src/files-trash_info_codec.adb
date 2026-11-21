with Ada.Strings.Unbounded;

package body Files.Trash_Info_Codec is

   use Ada.Strings.Unbounded;

   Hex : constant String := "0123456789ABCDEF";

   function Is_Unreserved (Value : Character) return Boolean is
     (Value in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '-' | '.' | '_' | '~' | '/');

   function Hex_Value (Item : Character) return Integer is
     (case Item is
         when '0' .. '9' => Character'Pos (Item) - Character'Pos ('0'),
         when 'A' .. 'F' => Character'Pos (Item) - Character'Pos ('A') + 10,
         when 'a' .. 'f' => Character'Pos (Item) - Character'Pos ('a') + 10,
         when others => -1);

   function Encode (Path : String) return String is
      Result : Unbounded_String;
   begin
      for Value of Path loop
         if Is_Unreserved (Value) then
            Append (Result, Value);
         else
            declare
               Code : constant Natural := Character'Pos (Value);
            begin
               Append (Result, '%');
               Append (Result, Hex (Code / 16 + 1));
               Append (Result, Hex (Code mod 16 + 1));
            end;
         end if;
      end loop;
      return To_String (Result);
   end Encode;

   function Decode (Value : String) return String is
      Result : Unbounded_String;
      Index  : Natural := Value'First;
   begin
      while Index <= Value'Last loop
         if Value (Index) = '%' and then Index <= Value'Last - 2 then
            declare
               High : constant Integer := Hex_Value (Value (Index + 1));
               Low  : constant Integer := Hex_Value (Value (Index + 2));
            begin
               if High >= 0 and then Low >= 0 then
                  Append (Result, Character'Val (High * 16 + Low));
                  Index := Index + 3;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         else
            Append (Result, Value (Index));
            Index := Index + 1;
         end if;
      end loop;
      return To_String (Result);
   end Decode;

end Files.Trash_Info_Codec;

with Ada.Strings.Unbounded;
with Files.Hex_Text;

package body Files.File_System.Trash.Info_Codec is

   use Ada.Strings.Unbounded;

   function Is_Unreserved (Value : Character) return Boolean is
     (Value in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '-' | '.' | '_' | '~' | '/');

   function Encode (Path : String) return String is
      Result : Unbounded_String;
   begin
      for Value of Path loop
         if Is_Unreserved (Value) then
            Append (Result, Value);
         else
            Append (Result, '%' & Files.Hex_Text.Byte_Upper (Character'Pos (Value)));
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
               High : constant Integer := Files.Hex_Text.Digit_Value (Value (Index + 1));
               Low  : constant Integer := Files.Hex_Text.Digit_Value (Value (Index + 2));
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

end Files.File_System.Trash.Info_Codec;

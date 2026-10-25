separate (Files.File_System)
function Mount_Field
  (Line  : String;
   Index : Positive)
   return String
is
   Current : Positive := 1;
   Start   : Natural := 0;

   function Octal_Value (Value : Character) return Natural is
   begin
      return
        (if Value in '0' .. '7'
         then Character'Pos (Value) - Character'Pos ('0')
         else Natural'Last);
   end Octal_Value;

   function Decode (Value : String) return String is
      Result : Unbounded_String;
      Position : Natural := Value'First;
   begin
      while Position <= Value'Last loop
         if Value (Position) = '\'
           and then Position + 3 <= Value'Last
           and then Octal_Value (Value (Position + 1)) /= Natural'Last
           and then Octal_Value (Value (Position + 2)) /= Natural'Last
           and then Octal_Value (Value (Position + 3)) /= Natural'Last
         then
            declare
               Code : constant Natural :=
                 Octal_Value (Value (Position + 1)) * 64
                 + Octal_Value (Value (Position + 2)) * 8
                 + Octal_Value (Value (Position + 3));
            begin
               if Code <= Character'Pos (Character'Last) then
                  Append (Result, Character'Val (Code));
                  Position := Position + 4;
               else
                  Append (Result, Value (Position));
                  Position := Position + 1;
               end if;
            end;
         else
            Append (Result, Value (Position));
            Position := Position + 1;
         end if;
      end loop;
      return To_String (Result);
   end Decode;
begin
   for Position in Line'Range loop
      if Line (Position) /= ' ' and then Start = 0 then
         Start := Position;
      elsif Line (Position) = ' ' and then Start /= 0 then
         if Current = Index then
            return Decode (Line (Start .. Position - 1));
         end if;
         Current := Current + 1;
         Start := 0;
      end if;
   end loop;

   if Start /= 0 and then Current = Index then
      return Decode (Line (Start .. Line'Last));
   end if;

   return "";
end Mount_Field;

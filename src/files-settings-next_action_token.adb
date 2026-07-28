separate (Files.Settings)
   function Next_Action_Token
     (Text  : String;
      Start : Positive;
      Last  : out Natural;
      Found : out Boolean;
      Valid : out Boolean)
      return String
   is
      First : Natural := Start;
      Value : Unbounded_String := Null_Unbounded_String;
   begin
      Found := False;
      Valid := True;
      while First <= Text'Last
        and then (Text (First) = ' ' or else Text (First) = ASCII.HT)
      loop
         First := First + 1;
      end loop;

      if First > Text'Last then
         Last := Text'Last + 1;
         return "";
      end if;

      if Text (First) = '"' then
         Found := True;
         Last := First + 1;
         loop
            if Last > Text'Last then
               Valid := False;
               return "";
            elsif Text (Last) = '"' then
               if Last < Text'Last and then Text (Last + 1) = '"' then
                  Append (Value, '"');
                  Last := Last + 2;
               else
                  exit;
               end if;
            else
               Append (Value, Text (Last));
               Last := Last + 1;
            end if;
         end loop;

         Last := Last + 1;
         if Last <= Text'Last
           and then Text (Last) /= ' '
           and then Text (Last) /= ASCII.HT
         then
            Valid := False;
            return "";
         end if;

         return To_String (Value);
      else
         Found := True;
         Last := First;
         while Last <= Text'Last
           and then Text (Last) /= ' '
           and then Text (Last) /= ASCII.HT
         loop
            if Text (Last) = '"' then
               Valid := False;
               return "";
            end if;
            Last := Last + 1;
         end loop;

         return Text (First .. Last - 1);
      end if;
   end Next_Action_Token;

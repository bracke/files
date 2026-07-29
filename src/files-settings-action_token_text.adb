separate (Files.Settings)
   function Action_Token_Text (Value : String) return String is
      Needs_Quotes : Boolean := Value = "";
      Result       : Unbounded_String := Null_Unbounded_String;
   begin
      for Character_Value of Value loop
         if Character_Value = ' ' or else Character_Value = ASCII.HT then
            Needs_Quotes := True;
         elsif Character_Value = '"' then
            Needs_Quotes := True;
         end if;
      end loop;

      if not Needs_Quotes then
         return Value;
      end if;

      Append (Result, '"');
      for Character_Value of Value loop
         if Character_Value = '"' then
            Append (Result, """""");
         else
            Append (Result, Character_Value);
         end if;
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Action_Token_Text;

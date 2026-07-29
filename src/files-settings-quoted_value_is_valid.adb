separate (Files.Settings)
   function Quoted_Value_Is_Valid (Text : String) return Boolean is
      Clean : constant String := Trim (Text);
      Index : Natural;
   begin
      if Clean = "" then
         return True;
      elsif Clean (Clean'First) /= '"' then
         return Ada.Strings.Fixed.Index (Clean, """") = 0;
      elsif Clean'Length < 2 or else Clean (Clean'Last) /= '"' then
         return False;
      end if;

      Index := Clean'First + 1;
      while Index < Clean'Last loop
         if Clean (Index) = '"' then
            if Index + 1 < Clean'Last and then Clean (Index + 1) = '"' then
               Index := Index + 2;
            else
               return False;
            end if;
         else
            Index := Index + 1;
         end if;
      end loop;

      return True;
   end Quoted_Value_Is_Valid;

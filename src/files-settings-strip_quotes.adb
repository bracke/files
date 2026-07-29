separate (Files.Settings)
   function Strip_Quotes (Text : String) return String is
      Clean : constant String := Trim (Text);
      Value : Unbounded_String := Null_Unbounded_String;
      Index : Natural;
   begin
      if Clean'Length >= 2
        and then Clean (Clean'First) = '"'
        and then Clean (Clean'Last) = '"'
      then
         Index := Clean'First + 1;
         while Index < Clean'Last loop
            if Clean (Index) = '"'
              and then Index + 1 < Clean'Last
              and then Clean (Index + 1) = '"'
            then
               Append (Value, '"');
               Index := Index + 2;
            else
               Append (Value, Clean (Index));
               Index := Index + 1;
            end if;
         end loop;

         return To_String (Value);
      end if;

      return Clean;
   end Strip_Quotes;

separate (Files.File_System)
   function Valid_Leaf_Name (Name : String) return Boolean is
      Index     : Integer := Name'First;
      Codepoint : Natural := 0;
   begin
      if Name = ""
        or else Name = "."
        or else Name = ".."
        or else Name (Name'Last) = ' '
        or else Name (Name'Last) = '.'
        or else Is_Windows_Device_Name (Name)
        or else not Files.UTF8.Is_Valid (Name)
        or else Is_All_Whitespace (Name)
        or else Ends_With_Whitespace (Name)
      then
         return False;
      end if;

      while Index <= Name'Last loop
         Files.UTF8.Decode_Next_Codepoint (Name, Index, Codepoint);

         if Codepoint < 32
           or else Codepoint = 127
           or else Codepoint in 16#80# .. 16#9F#
         then
            return False;
         elsif Codepoint < 128 then
            declare
               Character_Value : constant Character := Character'Val (Codepoint);
            begin
               if Character_Value = '/'
                 or else Character_Value = '\'
                 or else Character_Value = '<'
                 or else Character_Value = '>'
                 or else Character_Value = ':'
                 or else Character_Value = Character'Val (34)
                 or else Character_Value = '|'
                 or else Character_Value = '?'
                 or else Character_Value = '*'
               then
                  return False;
               end if;
            end;
         end if;
      end loop;

      return True;
   end Valid_Leaf_Name;

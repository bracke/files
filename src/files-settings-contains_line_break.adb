separate (Files.Settings)
   function Contains_Line_Break (Text : String) return Boolean is
      Index     : Integer := Text'First;
      Codepoint : Natural := 0;
   begin
      while Index <= Text'Last loop
         declare
            Byte_Value : constant Natural := Character'Pos (Text (Index));
         begin
            if Byte_Value = Character'Pos (ASCII.LF)
              or else Byte_Value = Character'Pos (ASCII.CR)
              or else Byte_Value = Character'Pos (ASCII.VT)
              or else Byte_Value = Character'Pos (ASCII.FF)
              or else Byte_Value = 133
            then
               return True;
            end if;
         end;

         Files.UTF8.Decode_Next_Codepoint (Text, Index, Codepoint);
         if Codepoint = Character'Pos (ASCII.LF)
           or else Codepoint = Character'Pos (ASCII.CR)
           or else Codepoint = Character'Pos (ASCII.VT)
           or else Codepoint = Character'Pos (ASCII.FF)
           or else Codepoint = 16#0085#
           or else Codepoint = 16#2028#
           or else Codepoint = 16#2029#
         then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Line_Break;

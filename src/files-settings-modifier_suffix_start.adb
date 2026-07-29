separate (Files.Settings)
   function Modifier_Suffix_Start (Token : String) return Natural is
      Clean     : constant String := Trim (Token);
      Candidate : Natural := Ada.Strings.Fixed.Index (Clean, "+");
   begin
      while Candidate /= 0 loop
         declare
            Position : Natural := Candidate + 1;
            Valid    : Boolean :=
              Candidate > Clean'First
              and then Candidate < Clean'Last
              and then Clean (Candidate - 1) /= '+';
         begin
            while Valid and then Position <= Clean'Last loop
               declare
                  Last : Natural := Position;
               begin
                  while Last <= Clean'Last and then Clean (Last) /= '+' loop
                     Last := Last + 1;
                  end loop;

                  if Last = Position
                    or else not Modifier_Name_Is_Known (Clean (Position .. Last - 1))
                  then
                     Valid := False;
                  end if;

                  Position := Last + 1;
               end;
            end loop;

            if Valid then
               return Candidate;
            end if;
         end;

         if Candidate = Clean'Last then
            return 0;
         end if;

         declare
            Next : Natural := 0;
         begin
            for Index in Candidate + 1 .. Clean'Last loop
               if Clean (Index) = '+' then
                  Next := Index;
                  exit;
               end if;
            end loop;
            Candidate := Next;
         end;
      end loop;

      return 0;
   end Modifier_Suffix_Start;

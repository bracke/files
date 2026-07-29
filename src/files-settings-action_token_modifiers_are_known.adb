separate (Files.Settings)
   function Action_Token_Modifiers_Are_Known (Token : String) return Boolean is
      Clean    : constant String := Trim (Token);
      Plus     : constant Natural := Modifier_Suffix_Start (Clean);
      Position : Natural := Plus + 1;
   begin
      if Plus = 0 then
         return Ada.Strings.Fixed.Index (Clean, "+") = 0
           or else Plus_Suffix_Is_Structured_Filetype (Clean);
      elsif Plus = Clean'Last or else Clean (Clean'Last) = '+' then
         return False;
      end if;

      while Position <= Clean'Last loop
         declare
            Last : Natural := Position;
         begin
            while Last <= Clean'Last and then Clean (Last) /= '+' loop
               Last := Last + 1;
            end loop;

            if Last = Position then
               return False;
            else
               declare
                  Name : constant String := Files.Types.To_Lower (Trim (Clean (Position .. Last - 1)));
               begin
                  if Name /= "shift"
                    and then Name /= "control"
                    and then Name /= "alt"
                    and then Name /= "meta"
                  then
                     return False;
                  end if;
               end;
            end if;

            Position := Last + 1;
         end;
      end loop;

      return True;
   end Action_Token_Modifiers_Are_Known;

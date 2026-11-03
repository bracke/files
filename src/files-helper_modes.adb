package body Files.Helper_Modes is

   function Mode_Of (Argument : String; Found : out Boolean) return Helper_Mode is
   begin
      for Mode in Helper_Mode loop
         if Argument = Flag (Mode) then
            Found := True;
            return Mode;
         end if;
      end loop;
      Found := False;
      return Helper_Mode'First;
   end Mode_Of;

end Files.Helper_Modes;

separate (Files.Settings.Parse)
   function Section_Named
     (Name  : String;
      Named : out Settings_Section)
      return Boolean is
   begin
      for Candidate in Named_Section loop
         if Section_Names (Candidate).all = Name then
            Named := Candidate;
            return True;
         end if;
      end loop;
      Named := No_Section;
      return False;
   end Section_Named;

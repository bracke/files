separate (Files.File_System.Roots)
   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String
   is
      Current : Positive := 1;
      Start   : Natural := 0;
   begin
      for Position in Line'Range loop
         if Line (Position) /= ' ' and then Start = 0 then
            Start := Position;
         elsif Line (Position) = ' ' and then Start /= 0 then
            if Current = Index then
               return Line (Start .. Position - 1);
            end if;
            Current := Current + 1;
            Start := 0;
         end if;
      end loop;

      if Start /= 0 and then Current = Index then
         return Line (Start .. Line'Last);
      end if;

      return "";
   end Mount_Field;

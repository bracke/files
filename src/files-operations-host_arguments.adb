separate (Files.Operations)
   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
   is
      Result : Hostkit.String_Vectors.Vector;
   begin
      for Argument of Arguments loop
         Result.Append (Argument);
      end loop;

      return Result;
   end Host_Arguments;

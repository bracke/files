separate (Files.File_System)
   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.File_Permission_Bits (Path, Available);
   end Permission_Bits_Of;

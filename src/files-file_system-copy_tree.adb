separate (Files.File_System)
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
      return Mutation_Result is
   begin
      Copy_Tree (Source_Path, Destination_Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.copy.failed"));
   end Copy_Tree;

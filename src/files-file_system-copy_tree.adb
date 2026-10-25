separate (Files.File_System)
function Copy_Tree
  (Source_Path, Destination_Path : String;
   Identity, Tree_Revision_Value : out Files.Types.UString;
   Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   return Mutation_Result is
begin
   Files.Io_Errors.Reset;
   Support.Copy_To_New_Path
     (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Batch => Batch);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when others =>
      Identity := Null_Unbounded_String;
      Tree_Revision_Value := Null_Unbounded_String;
      return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.copy.failed"));
end Copy_Tree;

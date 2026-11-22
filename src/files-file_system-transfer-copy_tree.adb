separate (Files.File_System.Transfer)
function Copy_Tree
  (Source_Path, Destination_Path : String;
   Identity, Tree_Revision_Value : out Files.Types.UString;
   Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   return Mutation_Result is
begin
   Files.IO.Errors.Reset;
   Copying.Copy_To_New_Path
     (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Batch => Batch);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Identity := Null_Unbounded_String;
      Tree_Revision_Value := Null_Unbounded_String;
      return (Success => False, Error_Key => Files.IO.Errors.Error_Key ("error.copy.failed"));
end Copy_Tree;

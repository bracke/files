separate (Files.File_System.Trash.Move_To_Trash)
--  Hand the item to the Finder's trash. The Finder says where it put the
--  item -- in ~/.Trash, or in its volume's .Trashes/<uid>, renamed there if
--  the name was taken -- so that is the trashed path, and Undo puts the
--  item back from it (Trash_Base_Of knows the Finder's layout). A host that
--  took it without saying where leaves an item Undo cannot restore.
function Send_To_Finder_Trash return Mutation_Result is
   Request : constant Native_Trash_Request :=
     (Backend                 => Backend,
      Path                    => To_Unbounded_String (Path),
      Requires_Native_Api     => True,
      Can_Use_Current_Process => True);
   Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
   Where      : Files.Types.UString;
begin
   if not Evaluation.Supported then
      return
        (Success   => False,
         Error_Key =>
           (if Evaluation.Error_Key = Null_Unbounded_String
            then To_Unbounded_String ("error.trash.failed")
            else Evaluation.Error_Key));
   elsif Native_Trash_Refused or else not Hostkit.Trash.Move_To_Trash (Path, Where) then
      return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   Trashed_Path := Where;
   return (Success => True, Error_Key => Null_Unbounded_String);
end Send_To_Finder_Trash;

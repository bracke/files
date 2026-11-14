separate (Files.File_System.Move_To_Trash)
--  Hand the item to the Finder's trash. These backends were written and
--  then never called: everything went down the freedesktop path.
--
--  The Finder owns the item afterwards, so there is no path to hand back --
--  which is also why an undo cannot restore it, and says so.
function Send_To_Finder_Trash return Mutation_Result is
   Request : constant Native_Trash_Request :=
     (Backend                 => Backend,
      Path                    => To_Unbounded_String (Path),
      Requires_Native_Api     => True,
      Can_Use_Current_Process => True);

   Native : constant Native_Trash_Result := Trash_Natively (Request);
begin
   if Native.Completed then
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;

   return
     (Success   => False,
      Error_Key =>
        (if Native.Error_Key = Null_Unbounded_String
         then To_Unbounded_String ("error.trash.failed")
         else Native.Error_Key));
end Send_To_Finder_Trash;

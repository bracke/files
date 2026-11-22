separate (Files.File_System.Trash.Move_To_Trash)
--  Move the item into the trash: a rename, or a copy and delete across
--  devices. On failure the info file goes again, unless a copy was left in
--  the trash.
--
--  @return The outcome; success when the item is in the trash.
function Move_Item return Mutation_Result is
   Route : Recovery.Move_Route;
   Identity, Revision : UString;
   Copy_Kept : Boolean;
   --  Cross-device (EXDEV): the home trash is on a different mount than the
   --  file, so the move is a copy-then-delete into the trash.
   Moved : constant Mutation_Result :=
     Recovery.Move_Or_Copy (Path, To_String (Target), "error.trash.failed", Route, Identity, Revision, Copy_Kept);
begin
   if not Moved.Success then
      --  A copy left in the trash keeps its info file, so it stays listed
      --  and restorable.
      if Copy_Kept then
         Trashed_Path := Target;
      else
         Delete_Info_File_If_Present;
      end if;
   end if;
   return Moved;
end Move_Item;

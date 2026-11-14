separate (Files.File_System.Move_To_Trash)
--  Move the item into the trash: a rename, or a copy and delete across
--  devices. On failure the info file goes again, unless a copy was left in
--  the trash.
--
--  @return The outcome; success when the item is in the trash.
function Move_Item return Mutation_Result is
   use type Hostkit.Fs.Move_Outcome;
   Outcome : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
begin
   begin
      Outcome := Support.Move_No_Replace_Outcome (Path, To_String (Target));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         Outcome := Hostkit.Fs.Move_Refused;
   end;
   if Outcome /= Hostkit.Fs.Moved and then not Support.Copy_May_Replace_Move (Outcome) then
      --  Refused for a reason a copy would meet too: no copy and delete.
      declare
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
      begin
         Delete_Info_File_If_Present;
         return Failed;
      end;
   elsif Outcome /= Hostkit.Fs.Moved then
      --  Cross-device (EXDEV): rename cannot move across filesystems, so
      --  the home trash is on a different mount than the file. Fall back
      --  to copy-then-delete into the trash.
      declare
         Identity, Revision : UString;
         Copy_Kept : Boolean;
         Moved : constant Mutation_Result :=
           Recovery.Move_By_Copy (Path, To_String (Target), "error.trash.failed", Identity, Revision, Copy_Kept);
      begin
         if not Moved.Success then
            --  A copy left in the trash keeps its info file, so it stays
            --  listed and restorable.
            if Copy_Kept then
               Trashed_Path := Target;
            else
               Delete_Info_File_If_Present;
            end if;
            return Moved;
         end if;
      end;
   end if;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Move_Item;

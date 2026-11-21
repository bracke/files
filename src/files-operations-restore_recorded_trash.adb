separate (Files.Operations)
function Restore_Recorded_Trash (Original : Files.Undo.History.Replaced_Original) return Boolean is
   Path     : constant String := To_String (Original.Trash);
   Identity : constant String := To_String (Original.Identity);
   Target   : constant String := To_String (Original.Target);
begin
   if Identity = "" or else Target = "" then
      return False;
   end if;
   --  Already restored (a retry after a crash before its marker was
   --  written): the item is at its original path, by its identity, and no
   --  longer in the trash.
   if Files.IO.Fs_Primitives.Entry_Is_Absent (Path) and then Files.File_Identities.Token (Target) = Identity then
      return True;
   end if;
   return Files.File_System.Trash.Restore_From_Trash (Path, Identity, Target).Success;
end Restore_Recorded_Trash;

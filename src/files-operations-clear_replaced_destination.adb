separate (Files.Operations)
--  Remove a destination that a Replace decision must overwrite by moving it
--  to the trash. A failed trash operation aborts replacement. Never
--  touches a destination that is also the source (a paste onto itself).
function Clear_Replaced_Destination
  (Path    : String;
   Source  : String;
   Trashed : out Files.Types.UString)
   return Boolean is
begin
   Trashed := Null_Unbounded_String;
   if not Exists_Safely (Path) or else Path = Source then
      return True;
   end if;

   declare
      Result : constant Files.File_System.Mutation_Result :=
        Files.File_System.Preserve_For_Replace (Path, Trashed);
   begin
      if Result.Success then
         return True;
      end if;
   end;

   return False;
end Clear_Replaced_Destination;

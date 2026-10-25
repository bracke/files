separate (Files.Operations)
function Restore_Recorded_Trash
  (Path : Files.Types.UString; Identities, Targets : Files.Types.String_Vectors.Vector;
   Index : Positive) return Boolean is
begin
   if Index > Identities.Last_Index or else Length (Identities (Index)) = 0
     or else Index > Targets.Last_Index or else Length (Targets (Index)) = 0
   then
      return False;
   end if;
   return Files.File_System.Restore_From_Trash
     (To_String (Path), To_String (Identities (Index)), To_String (Targets (Index))).Success;
end Restore_Recorded_Trash;

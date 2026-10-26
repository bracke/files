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
   --  Already restored (a retry after a crash before its marker was
   --  written): the item is at its original path, by its identity, and no
   --  longer in the trash.
   if not Ada.Directories.Exists (To_String (Path))
     and then not Hostkit.Fs.Is_Link (To_String (Path))
     and then Files.File_Identities.Token (To_String (Targets (Index))) = To_String (Identities (Index))
   then
      return True;
   end if;
   return Files.File_System.Restore_From_Trash
     (To_String (Path), To_String (Identities (Index)), To_String (Targets (Index))).Success;
end Restore_Recorded_Trash;

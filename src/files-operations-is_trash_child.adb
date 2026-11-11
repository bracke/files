separate (Files.Operations)
function Is_Trash_Child (Path : String) return Boolean is
begin
   return Path /= ""
     and then (Is_Trash_Directory (Files.Fs_Primitives.Parent_Directory (Path))
               or else Files.File_System.Is_Volume_Trash_Item (Path));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return False;
end Is_Trash_Child;

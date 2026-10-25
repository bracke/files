separate (Files.Operations)
function Is_Trash_Child (Path : String) return Boolean is
begin
   return Path /= ""
     and then Is_Trash_Directory (Ada.Directories.Containing_Directory (Path));
exception
   when others =>
      return False;
end Is_Trash_Child;

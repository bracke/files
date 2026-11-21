separate (Files.File_System.Available_Root_Entries)
function Filesystem_Type_For (Path : String) return String is
   Found : Boolean;
   Mount : constant Hostkit.Mounts.Mount := Hostkit.Mounts.Find (Mounts, Path, Found);
begin
   return (if Found then To_String (Mount.Filesystem_Type) else "");
end Filesystem_Type_For;

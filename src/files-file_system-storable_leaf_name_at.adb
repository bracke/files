separate (Files.File_System)
function Storable_Leaf_Name_At
  (Name      : String;
   Directory : String)
   return Boolean
is
begin
   if Hostkit.Fs.Uses_Dos_Filename_Rules (Directory) then
      return Valid_Leaf_Name (Name, Windows_Rules);
   end if;
   return Name /= "" and then Name /= "." and then Name /= ".."
     and then (for all C of Name => C /= '/' and then C /= ASCII.NUL);
end Storable_Leaf_Name_At;

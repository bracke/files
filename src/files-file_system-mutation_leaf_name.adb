with Hostkit.Path_Text;

separate (Files.File_System)
function Mutation_Leaf_Name (Path : String) return String is
begin
   --  A path that ends in a separator names no leaf to create or rename to.
   if Path = "" or else Hostkit.Path_Text.Is_Separator_In (Path, Path (Path'Last)) then
      return "";
   end if;

   return Files.Fs_Primitives.Leaf_Text (Path);
end Mutation_Leaf_Name;

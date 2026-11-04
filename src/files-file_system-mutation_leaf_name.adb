separate (Files.File_System)
function Mutation_Leaf_Name (Path : String) return String is
begin
   if Path = "" then
      return "";
   end if;

   return Ada.Directories.Simple_Name (Path);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Mutation_Leaf_Name;

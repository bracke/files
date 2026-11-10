separate (Files.File_System)
function Mutation_Leaf_Name (Path : String) return String is
begin
   if Path = "" then
      return "";
   end if;

   return Ada.Directories.Simple_Name (Path);
exception
   when Refused : Ada.Directories.Name_Error =>
      --  A name GNAT will not parse; the filesystem gives the real cause.
      Files.Diagnostics.Note (Refused, "Files.File_System");
      return Files.Fs_Primitives.Leaf_Text (Path);
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Mutation_Leaf_Name;

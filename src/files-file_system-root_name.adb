separate (Files.File_System)
function Root_Name (Path : String; Kind : Root_Kind) return String is
begin
   case Kind is
      when Root_Filesystem | Root_Home | Root_Current =>
         return "";
      when Root_Mount | Root_User_Mount | Root_Network_Mount | Root_Favorite =>
         return Files.Fs_Primitives.Leaf_Text (Path);
      when Root_Windows_Drive =>
         return Path;
   end case;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Path;
end Root_Name;

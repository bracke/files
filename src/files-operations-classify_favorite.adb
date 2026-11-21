separate (Files.Operations)
function Classify_Favorite (Path : String) return Favorite_Target is
begin
   --  refusal-safe: only the shown kind of a favorite; nothing is removed
   if Path = "" or else not Files.IO.Fs_Primitives.Exists (Path) then
      return Favorite_Stale;
   elsif Files.IO.Fs_Primitives.Directory_Exists (Path) then
      return Favorite_Folder;
   end if;
   return Favorite_File;
exception
   when Failure : others =>
      Files.Diagnostics.Note (Failure, "Files.Operations");
      return Favorite_Stale;
end Classify_Favorite;

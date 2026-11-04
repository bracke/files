separate (Files.Operations)
function Hard_Link_Snapshot (Source : String) return String is
begin
   return Files.File_System.Tree_Revision (Source);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return "";
end Hard_Link_Snapshot;

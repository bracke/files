separate (Files.Operations)
function Hard_Link_Snapshot (Source : String) return String is
begin
   return Files.File_System.Tree_Revision (Source);
exception
   when others =>
      return "";
end Hard_Link_Snapshot;

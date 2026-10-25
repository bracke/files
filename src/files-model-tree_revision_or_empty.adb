separate (Files.Model)
function Tree_Revision_Or_Empty (Path : String) return String is
begin
   return Files.File_System.Tree_Revision (Path);
exception
   --  A creation may already be published when its snapshot is captured.
   --  Keep the operation successful, but omit unsafe Undo for this entry.
   when others =>
      return "";
end Tree_Revision_Or_Empty;
